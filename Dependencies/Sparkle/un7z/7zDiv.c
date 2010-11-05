#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>

#include "7zDiv.h"



int LookInStream_SeekTo(CLookToRead *stream, UInt64 offset) {
	Int64 t = offset;
	return LookToRead_Seek(stream, &t, SEEK_SET);
}

int LookInStream_Read2(CLookToRead *stream, void *buf, size_t size, int errorType) {
	while (size != 0) {
		size_t processed = size;
		RINOK(LookToRead_Read(stream, buf, &processed));
		if (processed == 0) {
			return errorType;
		}
		buf = (void *)((Byte *)buf + processed);
		size -= processed;
	}
	return SZ_OK;
}

int LookInStream_Read(CLookToRead *stream, void *buf, size_t size) {
	return LookInStream_Read2(stream, buf, size, SZ_ERROR_INPUT_EOF);
}

int LookToRead_Look_Exact(CLookToRead *stream, void **buf, size_t *size) {
	int res = SZ_OK;
	size_t size2 = stream->size - stream->pos;
	if (size2 == 0 && *size > 0) {
		stream->pos = 0;
		if (*size > LookToRead_BUF_SIZE) {
			*size = LookToRead_BUF_SIZE;
		}
		res = FileInStream_Read(*stream->file, stream->buf, size);
		size2 = stream->size = *size;
	}
	if (size2 < *size)
		*size = size2;
	*buf = stream->buf + stream->pos;
	return res;
}

int LookToRead_Skip(CLookToRead *stream, size_t offset) {
	stream->pos += offset;
	return SZ_OK;
}

int LookToRead_Read(CLookToRead *stream, void *buf, size_t *size) {
	size_t rem = stream->size - stream->pos;
	if (rem == 0) {
		return FileInStream_Read(*stream->file, buf, size);
	}
	if (rem > *size) {
		rem = *size;
	}
	memcpy(buf, stream->buf + stream->pos, rem);
	stream->pos += rem;
	*size = rem;
	return SZ_OK;
}

int LookToRead_Seek(CLookToRead *stream, Int64 *pos, int whence) {
	stream->pos = 0;
	stream->size = 0;
	return FileInStream_Seek(*stream->file, pos, whence);
}

void LookToRead_Init(CLookToRead *stream) {
	stream->pos = 0;
	stream->size = 0;
}



void Buf_Init(CBuf *p) {
	p->data = 0;
	p->size = 0;
}

int Buf_Create(CBuf *p, size_t size) {
	p->size = 0;
	if (size == 0) {
		p->data = 0;
		return 1;
	}
	p->data = (Byte *)malloc(size);
	if (p->data != 0) {
		p->size = size;
		return 1;
	}
	return 0;
}

void Buf_Free(CBuf *p) {
	free(p->data);
	p->data = 0;
	p->size = 0;
}


#define kCrcPoly 0xEDB88320
UInt32 g_CrcTable[256];

void CrcGenerateTable(void) {
	UInt32 i;
	for (i = 0; i < 256; i++) {
		UInt32 r = i;
		int j;
		for (j = 0; j < 8; j++) {
			r = (r >> 1) ^ (kCrcPoly & ~((r & 1) - 1));
		}
		g_CrcTable[i] = r;
	}
}

UInt32 CrcUpdate(UInt32 v, const void *data, size_t size) {
	const Byte *p = (const Byte *)data;
	for (; size > 0 ; size--, p++) {
		v = CRC_UPDATE_BYTE(v, *p);
	}
	return v;
}

UInt32 CrcCalc(const void *data, size_t size) {
	return CrcUpdate(CRC_INIT_VAL, data, size) ^ 0xFFFFFFFF;
}


Byte k7zSignature[k7zSignatureSize] = {'7', 'z', 0xBC, 0xAF, 0x27, 0x1C};



int createPathForFile(const char *filePath, int relativePathLen, Byte isDir) {
	int length = strlen(filePath);
	char path[length + 1];
	memcpy(path, filePath, length + 1);
	char *charPos = path + relativePathLen;
	char *maxPos = 0;
	
	while ((charPos = strstr(charPos, "/")) != NULL) {
		*charPos = 0;
		maxPos = charPos;
		charPos++;
	}	
	if (isDir) {
		maxPos = path + length;
	}
	
	charPos = path + relativePathLen;
	while (charPos < maxPos) {
		if (!directoryExists(path)) {
			if (mkdir(path, 0755) != 0) {
				return 1;
			}
		}
		
		while (*(++charPos) != 0) {}
		*charPos = '/';
	}
	
	return 0;
}

int directoryExists(const char *path) {
	struct stat st;
	if (stat(path, &st) == 0 && st.st_mode & S_IFDIR) {
		return 1;
	}
	return 0;
}


int FileInStream_Read(FILE *pp, void *buf, size_t *size) {
	size_t originalSize = *size;
	*size = fread(buf, 1, originalSize, pp);
	
	return *size == originalSize ? SZ_OK : SZ_ERROR_READ;
}

int FileInStream_Seek(FILE *pp, Int64 *pos, int whence) {
	int res = fseek(pp, (long)*pos, whence);
	*pos = ftell(pp);
	return res;
}

