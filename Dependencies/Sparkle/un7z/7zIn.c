#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "7zDecode.h"
#include "7zIn.h"
#include "7zDiv.h"



void SzCoderInfo_Init(CSzCoderInfo *p) {
	Buf_Init(&p->Props);
}

void SzCoderInfo_Free(CSzCoderInfo *p) {
	Buf_Free(&p->Props);
	SzCoderInfo_Init(p);
}

void SzFolder_Init(CSzFolder *p) {
	p->Coders = 0;
	p->BindPairs = 0;
	p->PackStreams = 0;
	p->UnpackSizes = 0;
	p->NumCoders = 0;
	p->NumBindPairs = 0;
	p->NumPackStreams = 0;
	p->UnpackCRCDefined = 0;
	p->UnpackCRC = 0;
	p->NumUnpackStreams = 0;
}

void SzFolder_Free(CSzFolder *p) {
	UInt32 i;
	if (p->Coders) {
		for (i = 0; i < p->NumCoders; i++) {
			SzCoderInfo_Free(&p->Coders[i]);
		}
	}
	free(p->Coders);
	free(p->BindPairs);
	free(p->PackStreams);
	free(p->UnpackSizes);
	SzFolder_Init(p);
}

UInt32 SzFolder_GetNumOutStreams(CSzFolder *p) {
	UInt32 result = 0;
	UInt32 i;
	for (i = 0; i < p->NumCoders; i++) {
		result += p->Coders[i].NumOutStreams;
	}
	return result;
}

int SzFolder_FindBindPairForInStream(CSzFolder *p, UInt32 inStreamIndex) {
	UInt32 i;
	for (i = 0; i < p->NumBindPairs; i++) {
		if (p->BindPairs[i].InIndex == inStreamIndex) {
			return i;
		}
	}
	return -1;
}


int SzFolder_FindBindPairForOutStream(CSzFolder *p, UInt32 outStreamIndex) {
	UInt32 i;
	for (i = 0; i < p->NumBindPairs; i++) {
		if (p->BindPairs[i].OutIndex == outStreamIndex) {
			return i;
		}
	}
	return -1;
}

UInt64 SzFolder_GetUnpackSize(CSzFolder *p) {
	int i = (int)SzFolder_GetNumOutStreams(p);
	if (i == 0) {
		return 0;
	}
	for (i--; i >= 0; i--){
		if (SzFolder_FindBindPairForOutStream(p, i) < 0) {
			return p->UnpackSizes[i];
		}
	}
	return 0;
}

void SzFile_Init(CSzFileItem *p) {
	p->HasStream = 1;
	p->IsDir = 0;
	p->IsAnti = 0;
	p->FileCRCDefined = 0;
	p->MTimeDefined = 0;
	p->Name = 0;
	p->AttribDefined = 0;
}

static void SzFile_Free(CSzFileItem *p) {
	free(p->Name);
	SzFile_Init(p);
}

void SzAr_Init(CSzAr *p) {
	p->PackSizes = 0;
	p->PackCRCsDefined = 0;
	p->PackCRCs = 0;
	p->Folders = 0;
	p->Files = 0;
	p->NumPackStreams = 0;
	p->NumFolders = 0;
	p->NumFiles = 0;
}

void SzAr_Free(CSzAr *p) {
	UInt32 i;
	if (p->Folders) {
		for (i = 0; i < p->NumFolders; i++) {
			SzFolder_Free(&p->Folders[i]);
		}
	}
	if (p->Files) {
		for (i = 0; i < p->NumFiles; i++) {
			SzFile_Free(&p->Files[i]);
		}
	}
	free(p->PackSizes);
	free(p->PackCRCsDefined);
	free(p->PackCRCs);
	free(p->Folders);
	free(p->Files);
	SzAr_Init(p);
}




#define RINOM(x) { if ((x) == 0) return SZ_ERROR_MEM; }

#define NUM_FOLDER_CODERS_MAX 32
#define NUM_CODER_STREAMS_MAX 32

void SzArEx_Init(CSzArEx *p) {
	SzAr_Init(&p->db);
	p->FolderStartPackStreamIndex = 0;
	p->PackStreamStartPositions = 0;
	p->FolderStartFileIndex = 0;
	p->FileIndexToFolderIndexMap = 0;
}

void SzArEx_Free(CSzArEx *p) {
	free(p->FolderStartPackStreamIndex);
	free(p->PackStreamStartPositions);
	free(p->FolderStartFileIndex);
	free(p->FileIndexToFolderIndexMap);
	SzAr_Free(&p->db);
	SzArEx_Init(p);
}

#define MY_ALLOC(T, p, size) { if ((size) == 0) p = 0; else \
if ((p = (T *)malloc((size) * sizeof(T))) == 0) return SZ_ERROR_MEM; }

static int SzArEx_Fill(CSzArEx *p) {
	UInt32 startPos = 0;
	UInt64 startPosSize = 0;
	UInt32 i;
	UInt32 folderIndex = 0;
	UInt32 indexInFolder = 0;
	MY_ALLOC(UInt32, p->FolderStartPackStreamIndex, p->db.NumFolders);
	for (i = 0; i < p->db.NumFolders; i++) {
		p->FolderStartPackStreamIndex[i] = startPos;
		startPos += p->db.Folders[i].NumPackStreams;
	}
	
	MY_ALLOC(UInt64, p->PackStreamStartPositions, p->db.NumPackStreams);
	
	for (i = 0; i < p->db.NumPackStreams; i++) {
		p->PackStreamStartPositions[i] = startPosSize;
		startPosSize += p->db.PackSizes[i];
	}
	
	MY_ALLOC(UInt32, p->FolderStartFileIndex, p->db.NumFolders);
	MY_ALLOC(UInt32, p->FileIndexToFolderIndexMap, p->db.NumFiles);
	
	for (i = 0; i < p->db.NumFiles; i++) {
		CSzFileItem *file = p->db.Files + i;
		int emptyStream = !file->HasStream;
		if (emptyStream && indexInFolder == 0) {
			p->FileIndexToFolderIndexMap[i] = (UInt32)-1;
			continue;
		}
		if (indexInFolder == 0) {
			/*
			 v3.13 incorrectly worked with empty folders
			 v4.07: Loop for skipping empty folders
			 */
			for (;;) {
				if (folderIndex >= p->db.NumFolders)
					return SZ_ERROR_ARCHIVE;
				p->FolderStartFileIndex[folderIndex] = i;
				if (p->db.Folders[folderIndex].NumUnpackStreams != 0)
					break;
				folderIndex++;
			}
		}
		p->FileIndexToFolderIndexMap[i] = folderIndex;
		if (emptyStream)
			continue;
		indexInFolder++;
		if (indexInFolder >= p->db.Folders[folderIndex].NumUnpackStreams) {
			folderIndex++;
			indexInFolder = 0;
		}
	}
	return SZ_OK;
}


UInt64 SzArEx_GetFolderStreamPos(const CSzArEx *p, UInt32 folderIndex, UInt32 indexInFolder) {
	return p->dataPos +
    p->PackStreamStartPositions[p->FolderStartPackStreamIndex[folderIndex] + indexInFolder];
}



static int SzReadByte(CBuf *sd, Byte *b) {
	if (sd->size == 0)
		return SZ_ERROR_ARCHIVE;
	sd->size--;
	*b = *sd->data++;
	return SZ_OK;
}

static int SzReadBytes(CBuf *sd, Byte *data, size_t size) {
	size_t i;
	for (i = 0; i < size; i++) {
		RINOK(SzReadByte(sd, data + i));
	}
	return SZ_OK;
}

static int SzReadUInt32(CBuf *sd, UInt32 *value) {
	int i;
	*value = 0;
	for (i = 0; i < 4; i++) {
		Byte b;
		RINOK(SzReadByte(sd, &b));
		*value |= ((UInt32)(b) << (8 * i));
	}
	return SZ_OK;
}

static int SzReadNumber(CBuf *sd, UInt64 *value) {
	Byte firstByte;
	Byte mask = 0x80;
	int i;
	RINOK(SzReadByte(sd, &firstByte));
	*value = 0;
	for (i = 0; i < 8; i++) {
		Byte b;
		if ((firstByte & mask) == 0) {
			UInt64 highPart = firstByte & (mask - 1);
			*value += (highPart << (8 * i));
			return SZ_OK;
		}
		RINOK(SzReadByte(sd, &b));
		*value |= ((UInt64)b << (8 * i));
		mask >>= 1;
	}
	return SZ_OK;
}

static int SzReadNumber32(CBuf *sd, UInt32 *value) {
	UInt64 value64;
	RINOK(SzReadNumber(sd, &value64));
	if (value64 >= 0x80000000)
		return SZ_ERROR_UNSUPPORTED;
	if (value64 >= ((UInt64)(1) << ((sizeof(size_t) - 1) * 8 + 2)))
		return SZ_ERROR_UNSUPPORTED;
	*value = (UInt32)value64;
	return SZ_OK;
}

static int SzSkeepDataSize(CBuf *sd, UInt64 size) {
	if (size > sd->size)
		return SZ_ERROR_ARCHIVE;
	sd->size -= (size_t)size;
	sd->data += (size_t)size;
	return SZ_OK;
}

static int SzSkeepData(CBuf *sd) {
	UInt64 size;
	RINOK(SzReadNumber(sd, &size));
	return SzSkeepDataSize(sd, size);
}

static int SzReadArchiveProperties(CBuf *sd) {
	for (;;) {
		UInt64 type;
		RINOK(SzReadNumber(sd, &type));
		if (type == k7zIdEnd)
			break;
		SzSkeepData(sd);
	}
	return SZ_OK;
}

static int SzWaitAttribute(CBuf *sd, UInt64 attribute) {
	for (;;) {
		UInt64 type;
		RINOK(SzReadNumber(sd, &type));
		if (type == attribute) {
			return SZ_OK;
		}
		if (type == k7zIdEnd) {
			return SZ_ERROR_ARCHIVE;
		}
		RINOK(SzSkeepData(sd));
	}
}

static int SzReadBoolVector(CBuf *sd, size_t numItems, Byte **v) {
	Byte b = 0;
	Byte mask = 0;
	size_t i;
	MY_ALLOC(Byte, *v, numItems);
	for (i = 0; i < numItems; i++) {
		if (mask == 0) {
			RINOK(SzReadByte(sd, &b));
			mask = 0x80;
		}
		(*v)[i] = (Byte)(((b & mask) != 0) ? 1 : 0);
		mask >>= 1;
	}
	return SZ_OK;
}

static int SzReadBoolVector2(CBuf *sd, size_t numItems, Byte **v) {
	Byte allAreDefined;
	size_t i;
	RINOK(SzReadByte(sd, &allAreDefined));
	if (allAreDefined == 0)
		return SzReadBoolVector(sd, numItems, v);
	MY_ALLOC(Byte, *v, numItems);
	for (i = 0; i < numItems; i++)
		(*v)[i] = 1;
	return SZ_OK;
}

static int SzReadHashDigests(CBuf *sd,
							  size_t numItems,
							  Byte **digestsDefined,
							  UInt32 **digests) {
	size_t i;
	RINOK(SzReadBoolVector2(sd, numItems, digestsDefined));
	MY_ALLOC(UInt32, *digests, numItems);
	for (i = 0; i < numItems; i++) {
		if ((*digestsDefined)[i]) {
			RINOK(SzReadUInt32(sd, (*digests) + i));
		}
	}
	return SZ_OK;
}

static int SzReadPackInfo(CBuf *sd,
						   UInt64 *dataOffset,
						   UInt32 *numPackStreams,
						   UInt64 **packSizes,
						   Byte **packCRCsDefined,
						   UInt32 **packCRCs) {
	UInt32 i;
	RINOK(SzReadNumber(sd, dataOffset));
	RINOK(SzReadNumber32(sd, numPackStreams));
	
	RINOK(SzWaitAttribute(sd, k7zIdSize));
	
	MY_ALLOC(UInt64, *packSizes, (size_t)*numPackStreams);
	
	for (i = 0; i < *numPackStreams; i++) {
		RINOK(SzReadNumber(sd, (*packSizes) + i));
	}
	
	for (;;) {
		UInt64 type;
		RINOK(SzReadNumber(sd, &type));
		if (type == k7zIdEnd)
			break;
		if (type == k7zIdCRC) {
			RINOK(SzReadHashDigests(sd, (size_t)*numPackStreams, packCRCsDefined, packCRCs));
			continue;
		}
		RINOK(SzSkeepData(sd));
	}
	if (*packCRCsDefined == 0) {
		MY_ALLOC(Byte, *packCRCsDefined, (size_t)*numPackStreams);
		MY_ALLOC(UInt32, *packCRCs, (size_t)*numPackStreams);
		for (i = 0; i < *numPackStreams; i++) {
			(*packCRCsDefined)[i] = 0;
			(*packCRCs)[i] = 0;
		}
	}
	return SZ_OK;
}

static int SzReadSwitch(CBuf *sd) {
	Byte external;
	RINOK(SzReadByte(sd, &external));
	return (external == 0) ? SZ_OK: SZ_ERROR_UNSUPPORTED;
}

static int SzGetNextFolderItem(CBuf *sd, CSzFolder *folder) {
	UInt32 numCoders, numBindPairs, numPackStreams, i;
	UInt32 numInStreams = 0, numOutStreams = 0;
	
	RINOK(SzReadNumber32(sd, &numCoders));
	if (numCoders > NUM_FOLDER_CODERS_MAX) {
		return SZ_ERROR_UNSUPPORTED;
	}
	folder->NumCoders = numCoders;
	
	MY_ALLOC(CSzCoderInfo, folder->Coders, (size_t)numCoders);
	
	for (i = 0; i < numCoders; i++) {
		SzCoderInfo_Init(folder->Coders + i);
	}
	
	for (i = 0; i < numCoders; i++) {
		Byte mainByte;
		CSzCoderInfo *coder = folder->Coders + i;
		{
			unsigned idSize, j;
			Byte longID[15];
			RINOK(SzReadByte(sd, &mainByte));
			idSize = (unsigned)(mainByte & 0xF);
			RINOK(SzReadBytes(sd, longID, idSize));
			if (idSize > sizeof(coder->MethodID))
				return SZ_ERROR_UNSUPPORTED;
			coder->MethodID = 0;
			for (j = 0; j < idSize; j++)
				coder->MethodID |= (UInt64)longID[idSize - 1 - j] << (8 * j);
			
			if ((mainByte & 0x10) != 0) {
				RINOK(SzReadNumber32(sd, &coder->NumInStreams));
				RINOK(SzReadNumber32(sd, &coder->NumOutStreams));
				if (coder->NumInStreams > NUM_CODER_STREAMS_MAX ||
					coder->NumOutStreams > NUM_CODER_STREAMS_MAX)
					return SZ_ERROR_UNSUPPORTED;
			} else {
				coder->NumInStreams = 1;
				coder->NumOutStreams = 1;
			}
			if ((mainByte & 0x20) != 0) {
				UInt64 propertiesSize = 0;
				RINOK(SzReadNumber(sd, &propertiesSize));
				if (!Buf_Create(&coder->Props, (size_t)propertiesSize))
					return SZ_ERROR_MEM;
				RINOK(SzReadBytes(sd, coder->Props.data, (size_t)propertiesSize));
			}
		}
		while ((mainByte & 0x80) != 0) {
			RINOK(SzReadByte(sd, &mainByte));
			RINOK(SzSkeepDataSize(sd, (mainByte & 0xF)));
			if ((mainByte & 0x10) != 0) {
				UInt32 n;
				RINOK(SzReadNumber32(sd, &n));
				RINOK(SzReadNumber32(sd, &n));
			}
			if ((mainByte & 0x20) != 0) {
				UInt64 propertiesSize = 0;
				RINOK(SzReadNumber(sd, &propertiesSize));
				RINOK(SzSkeepDataSize(sd, propertiesSize));
			}
		}
		numInStreams += coder->NumInStreams;
		numOutStreams += coder->NumOutStreams;
	}
	
	if (numOutStreams == 0)
		return SZ_ERROR_UNSUPPORTED;
	
	folder->NumBindPairs = numBindPairs = numOutStreams - 1;
	MY_ALLOC(CBindPair, folder->BindPairs, (size_t)numBindPairs);
	
	for (i = 0; i < numBindPairs; i++) {
		CBindPair *bp = folder->BindPairs + i;
		RINOK(SzReadNumber32(sd, &bp->InIndex));
		RINOK(SzReadNumber32(sd, &bp->OutIndex));
	}
	
	if (numInStreams < numBindPairs)
		return SZ_ERROR_UNSUPPORTED;
	
	folder->NumPackStreams = numPackStreams = numInStreams - numBindPairs;
	MY_ALLOC(UInt32, folder->PackStreams, (size_t)numPackStreams);
	
	if (numPackStreams == 1) {
		for (i = 0; i < numInStreams ; i++)
			if (SzFolder_FindBindPairForInStream(folder, i) < 0)
				break;
		if (i == numInStreams)
			return SZ_ERROR_UNSUPPORTED;
		folder->PackStreams[0] = i;
	}
	else
		for (i = 0; i < numPackStreams; i++) {
			RINOK(SzReadNumber32(sd, folder->PackStreams + i));
		}
	return SZ_OK;
}

static int SzReadUnpackInfo(CBuf *sd,
							 UInt32 *numFolders,
							 CSzFolder **folders) {
	UInt32 i;
	RINOK(SzWaitAttribute(sd, k7zIdFolder));
	RINOK(SzReadNumber32(sd, numFolders));
	{
		RINOK(SzReadSwitch(sd));
		
		MY_ALLOC(CSzFolder, *folders, (size_t)*numFolders);
		
		for (i = 0; i < *numFolders; i++)
			SzFolder_Init((*folders) + i);
		
		for (i = 0; i < *numFolders; i++) {
			RINOK(SzGetNextFolderItem(sd, (*folders) + i));
		}
	}
	
	RINOK(SzWaitAttribute(sd, k7zIdCodersUnpackSize));
	
	for (i = 0; i < *numFolders; i++) {
		UInt32 j;
		CSzFolder *folder = (*folders) + i;
		UInt32 numOutStreams = SzFolder_GetNumOutStreams(folder);
		
		MY_ALLOC(UInt64, folder->UnpackSizes, (size_t)numOutStreams);
		
		for (j = 0; j < numOutStreams; j++) {
			RINOK(SzReadNumber(sd, folder->UnpackSizes + j));
		}
	}
	
	for (;;) {
		UInt64 type;
		RINOK(SzReadNumber(sd, &type));
		if (type == k7zIdEnd)
			return SZ_OK;
		if (type == k7zIdCRC) {
			int res;
			Byte *crcsDefined = 0;
			UInt32 *crcs = 0;
			res = SzReadHashDigests(sd, *numFolders, &crcsDefined, &crcs);
			if (res == SZ_OK) {
				for (i = 0; i < *numFolders; i++) {
					CSzFolder *folder = (*folders) + i;
					folder->UnpackCRCDefined = crcsDefined[i];
					folder->UnpackCRC = crcs[i];
				}
			}
			free(crcs);
			free(crcsDefined);
			RINOK(res);
			continue;
		}
		RINOK(SzSkeepData(sd));
	}
}

static int SzReadSubStreamsInfo(CBuf *sd,
								 UInt32 numFolders,
								 CSzFolder *folders,
								 UInt32 *numUnpackStreams,
								 UInt64 **unpackSizes,
								 Byte **digestsDefined,
								 UInt32 **digests) {
	UInt64 type = 0;
	UInt32 i;
	UInt32 si = 0;
	UInt32 numDigests = 0;
	
	for (i = 0; i < numFolders; i++) {
		folders[i].NumUnpackStreams = 1;
	}
	*numUnpackStreams = numFolders;
	
	for (;;) {
		RINOK(SzReadNumber(sd, &type));
		if (type == k7zIdNumUnpackStream) {
			*numUnpackStreams = 0;
			for (i = 0; i < numFolders; i++) {
				UInt32 numStreams;
				RINOK(SzReadNumber32(sd, &numStreams));
				folders[i].NumUnpackStreams = numStreams;
				*numUnpackStreams += numStreams;
			}
			continue;
		}
		if (type == k7zIdCRC || type == k7zIdSize) {
			break;
		}
		if (type == k7zIdEnd) {
			break;
		}
		RINOK(SzSkeepData(sd));
	}
	
	if (*numUnpackStreams == 0) {
		*unpackSizes = 0;
		*digestsDefined = 0;
		*digests = 0;
	} else {
		*unpackSizes = (UInt64 *)malloc((size_t)*numUnpackStreams * sizeof(UInt64));
		RINOM(*unpackSizes);
		*digestsDefined = (Byte *)malloc((size_t)*numUnpackStreams * sizeof(Byte));
		RINOM(*digestsDefined);
		*digests = (UInt32 *)malloc((size_t)*numUnpackStreams * sizeof(UInt32));
		RINOM(*digests);
	}
	
	for (i = 0; i < numFolders; i++) {
		/*
		 v3.13 incorrectly worked with empty folders
		 v4.07: we check that folder is empty
		 */
		UInt64 sum = 0;
		UInt32 j;
		UInt32 numSubstreams = folders[i].NumUnpackStreams;
		if (numSubstreams == 0) {
			continue;
		}
		if (type == k7zIdSize) {
			for (j = 1; j < numSubstreams; j++) {
				UInt64 size;
				RINOK(SzReadNumber(sd, &size));
				(*unpackSizes)[si++] = size;
				sum += size;
			}
		}
		(*unpackSizes)[si++] = SzFolder_GetUnpackSize(folders + i) - sum;
	}
	if (type == k7zIdSize) {
		RINOK(SzReadNumber(sd, &type));
	}
	
	for (i = 0; i < *numUnpackStreams; i++) {
		(*digestsDefined)[i] = 0;
		(*digests)[i] = 0;
	}
	
	
	for (i = 0; i < numFolders; i++) {
		UInt32 numSubstreams = folders[i].NumUnpackStreams;
		if (numSubstreams != 1 || !folders[i].UnpackCRCDefined) {
			numDigests += numSubstreams;
		}
	}
	
	
	si = 0;
	for (;;) {
		if (type == k7zIdCRC) {
			int digestIndex = 0;
			Byte *digestsDefined2 = 0;
			UInt32 *digests2 = 0;
			int res = SzReadHashDigests(sd, numDigests, &digestsDefined2, &digests2);
			if (res == SZ_OK) {
				for (i = 0; i < numFolders; i++) {
					CSzFolder *folder = folders + i;
					UInt32 numSubstreams = folder->NumUnpackStreams;
					if (numSubstreams == 1 && folder->UnpackCRCDefined) {
						(*digestsDefined)[si] = 1;
						(*digests)[si] = folder->UnpackCRC;
						si++;
					} else {
						UInt32 j;
						for (j = 0; j < numSubstreams; j++, digestIndex++) {
							(*digestsDefined)[si] = digestsDefined2[digestIndex];
							(*digests)[si] = digests2[digestIndex];
							si++;
						}
					}
				}
			}
			free(digestsDefined2);
			free(digests2);
			RINOK(res);
		} else if (type == k7zIdEnd) {
			return SZ_OK;
		} else {
			RINOK(SzSkeepData(sd));
		}
		RINOK(SzReadNumber(sd, &type));
	}
}


static int SzReadStreamsInfo(CBuf *sd,
							  UInt64 *dataOffset,
							  CSzAr *p,
							  UInt32 *numUnpackStreams,
							  UInt64 **unpackSizes,
							  Byte **digestsDefined,
							  UInt32 **digests) {
	for (;;) {
		UInt64 type;
		RINOK(SzReadNumber(sd, &type));
		if ((UInt64)(int)type != type) {
			return SZ_ERROR_UNSUPPORTED;
		}
		switch((int)type) {
			case k7zIdEnd:
				return SZ_OK;
			case k7zIdPackInfo: {
				RINOK(SzReadPackInfo(sd, dataOffset, &p->NumPackStreams,
									 &p->PackSizes, &p->PackCRCsDefined, &p->PackCRCs));
				break;
			}
			case k7zIdUnpackInfo: {
				RINOK(SzReadUnpackInfo(sd, &p->NumFolders, &p->Folders));
				break;
			}
			case k7zIdSubStreamsInfo: {
				RINOK(SzReadSubStreamsInfo(sd, p->NumFolders, p->Folders,
										   numUnpackStreams, unpackSizes, digestsDefined, digests));
				break;
			}
			default:
				return SZ_ERROR_UNSUPPORTED;
		}
	}
}

Byte kUtf8Limits[5] = { 0xC0, 0xE0, 0xF0, 0xF8, 0xFC };

static int SzReadFileNames(CBuf *sd, UInt32 numFiles, CSzFileItem *files) {
	UInt32 i;
	for (i = 0; i < numFiles; i++) {
		UInt32 len = 0;
		UInt32 pos = 0;
		CSzFileItem *file = files + i;
		while (pos + 2 <= sd->size) {
			int numAdds;
			UInt32 value = (UInt32)(sd->data[pos] | (((UInt32)sd->data[pos + 1]) << 8));
			pos += 2;
			len++;
			if (value == 0) {
				break;
			}
			if (value < 0x80) {
				continue;
			}
			if (value >= 0xD800 && value < 0xE000) {
				UInt32 c2;
				if (value >= 0xDC00) {
					return SZ_ERROR_ARCHIVE;
				}
				if (pos + 2 > sd->size) {
					return SZ_ERROR_ARCHIVE;
				}
				c2 = (UInt32)(sd->data[pos] | (((UInt32)sd->data[pos + 1]) << 8));
				pos += 2;
				if (c2 < 0xDC00 || c2 >= 0xE000) {
					return SZ_ERROR_ARCHIVE;
				}
				value = ((value - 0xD800) << 10) | (c2 - 0xDC00);
			}
			for (numAdds = 1; numAdds < 5; numAdds++) {
				if (value < (((UInt32)1) << (numAdds * 5 + 6))) {
					break;
				}
			}
			len += numAdds;
		}
		
		MY_ALLOC(char, file->Name, (size_t)len);
		
		len = 0;
		while (2 <= sd->size) {
			int numAdds;
			UInt32 value = (UInt32)(sd->data[0] | (((UInt32)sd->data[1]) << 8));
			SzSkeepDataSize(sd, 2);
			if (value < 0x80) {
				file->Name[len++] = (char)value;
				if (value == 0) {
					break;
				}
				continue;
			}
			if (value >= 0xD800 && value < 0xE000) {
				UInt32 c2 = (UInt32)(sd->data[0] | (((UInt32)sd->data[1]) << 8));
				SzSkeepDataSize(sd, 2);
				value = ((value - 0xD800) << 10) | (c2 - 0xDC00);
			}
			for (numAdds = 1; numAdds < 5; numAdds++) {
				if (value < (((UInt32)1) << (numAdds * 5 + 6))) {
					break;
				}
			}
			file->Name[len++] = (char)(kUtf8Limits[numAdds - 1] + (value >> (6 * numAdds)));
			do {
				numAdds--;
				file->Name[len++] = (char)(0x80 + ((value >> (6 * numAdds)) & 0x3F));
			} while (numAdds > 0);
			
			len += numAdds;
		}
	}
	return SZ_OK;
}

static int SzReadHeader2(CSzArEx *p,
						  CBuf *sd,
						  UInt64 **unpackSizes,
						  Byte **digestsDefined,
						  UInt32 **digests,
						  Byte **emptyStreamVector,
						  Byte **emptyFileVector,
						  Byte **lwtVector) {
	UInt64 type;
	UInt32 numUnpackStreams = 0;
	UInt32 numFiles = 0;
	CSzFileItem *files = 0;
	UInt32 numEmptyStreams = 0;
	UInt32 i;
	
	RINOK(SzReadNumber(sd, &type));
	
	if (type == k7zIdArchiveProperties) {
		RINOK(SzReadArchiveProperties(sd));
		RINOK(SzReadNumber(sd, &type));
	}
	
	
	if (type == k7zIdMainStreamsInfo) {
		RINOK(SzReadStreamsInfo(sd,
								&p->dataPos,
								&p->db,
								&numUnpackStreams,
								unpackSizes,
								digestsDefined,
								digests));
		p->dataPos += p->startPosAfterHeader;
		RINOK(SzReadNumber(sd, &type));
	}
	
	if (type == k7zIdEnd) {
		return SZ_OK;
	}
	if (type != k7zIdFilesInfo) {
		return SZ_ERROR_ARCHIVE;
	}
	
	RINOK(SzReadNumber32(sd, &numFiles));
	p->db.NumFiles = numFiles;
	
	MY_ALLOC(CSzFileItem, files, (size_t)numFiles);
	
	p->db.Files = files;
	for (i = 0; i < numFiles; i++) {
		SzFile_Init(files + i);
	}
	
	for (;;) {
		UInt64 type;
		UInt64 size;
		RINOK(SzReadNumber(sd, &type));
		if (type == k7zIdEnd) {
			break;
		}
		RINOK(SzReadNumber(sd, &size));
		
		if ((UInt64)(int)type != type) {
			RINOK(SzSkeepDataSize(sd, size));
		} else {
			switch((int)type) {
				case k7zIdName: {
					RINOK(SzReadSwitch(sd));
					RINOK(SzReadFileNames(sd, numFiles, files))
					break;
				}
				case k7zIdEmptyStream: {
					RINOK(SzReadBoolVector(sd, numFiles, emptyStreamVector));
					numEmptyStreams = 0;
					for (i = 0; i < numFiles; i++)
						if ((*emptyStreamVector)[i])
							numEmptyStreams++;
					break;
				}
				case k7zIdEmptyFile: {
					RINOK(SzReadBoolVector(sd, numEmptyStreams, emptyFileVector));
					break;
				}
				case k7zIdMTime: {
					RINOK(SzReadBoolVector2(sd, numFiles, lwtVector));
					RINOK(SzReadSwitch(sd));
					for (i = 0; i < numFiles; i++) {
						CSzFileItem *f = &files[i];
						Byte defined = (*lwtVector)[i];
						f->MTimeDefined = defined;
						f->MTime.Low = f->MTime.High = 0;
						if (defined) {
							RINOK(SzReadUInt32(sd, &f->MTime.Low));
							RINOK(SzReadUInt32(sd, &f->MTime.High));
						}
					}
					break;
				}
				case k7zIdWinAttributes: {
					Byte AllAreDefined;
					RINOK(SzReadByte(sd, &AllAreDefined));
					if (AllAreDefined == 0) {
						//TODO
						return SZ_ERROR_UNSUPPORTED;
					}
					RINOK(SzReadSwitch(sd));
					UInt32 value;
					for (i = 0; i < numFiles; i++) {
						RINOK(SzReadUInt32(sd, &value));
						CSzFileItem *f = &files[i];
						f->AttribDefined = 1;
						f->Attrib = value;
					}
					break;
				}
				default: {
					RINOK(SzSkeepDataSize(sd, size));
					break;
				}
			}
		}
	}
	
	{
		UInt32 emptyFileIndex = 0;
		UInt32 sizeIndex = 0;
		for (i = 0; i < numFiles; i++) {
			CSzFileItem *file = files + i;
			file->IsAnti = 0;
			if (*emptyStreamVector == 0) {
				file->HasStream = 1;
			} else {
				file->HasStream = (Byte)((*emptyStreamVector)[i] ? 0 : 1);
			}
			if (file->HasStream) {
				file->IsDir = 0;
				file->Size = (*unpackSizes)[sizeIndex];
				file->FileCRC = (*digests)[sizeIndex];
				file->FileCRCDefined = (Byte)(*digestsDefined)[sizeIndex];
				sizeIndex++;
			} else {
				if (*emptyFileVector == 0) {
					file->IsDir = 1;
				} else {
					file->IsDir = (Byte)((*emptyFileVector)[emptyFileIndex] ? 0 : 1);
				}
				emptyFileIndex++;
				file->Size = 0;
				file->FileCRCDefined = 0;
			}
		}
	}
	return SzArEx_Fill(p);
}

static int SzReadHeader(CSzArEx *p, CBuf *sd) {
	UInt64 *unpackSizes = 0;
	Byte *digestsDefined = 0;
	UInt32 *digests = 0;
	Byte *emptyStreamVector = 0;
	Byte *emptyFileVector = 0;
	Byte *lwtVector = 0;
	int res = SzReadHeader2(p, sd, &unpackSizes, &digestsDefined, &digests,
							 &emptyStreamVector, &emptyFileVector, &lwtVector);
	free(unpackSizes);
	free(digestsDefined);
	free(digests);
	free(emptyStreamVector);
	free(emptyFileVector);
	free(lwtVector);
	return res;
}

static int SzReadAndDecodePackedStreams2(CLookToRead *inStream,
										  CBuf *sd,
										  CBuf *outBuffer,
										  UInt64 baseOffset,
										  CSzAr *p,
										  UInt64 **unpackSizes,
										  Byte **digestsDefined,
										  UInt32 **digests) {
	
	UInt32 numUnpackStreams = 0;
	UInt64 dataStartPos;
	CSzFolder *folder;
	UInt64 unpackSize;
	
	RINOK(SzReadStreamsInfo(sd, &dataStartPos, p,
							&numUnpackStreams,  unpackSizes, digestsDefined, digests));
	
	dataStartPos += baseOffset;
	if (p->NumFolders != 1) {
		return SZ_ERROR_ARCHIVE;
	}
		
	folder = p->Folders;
	unpackSize = SzFolder_GetUnpackSize(folder);
	
	RINOK(LookInStream_SeekTo(inStream, dataStartPos));
	
	if (!Buf_Create(outBuffer, (size_t)unpackSize)) {
		return SZ_ERROR_MEM;
	}
	
	RINOK(SzDecode(p->PackSizes, folder,
				   inStream, dataStartPos,
				   outBuffer->data, (size_t)unpackSize));
	
	if (folder->UnpackCRCDefined && CrcCalc(outBuffer->data, (size_t)unpackSize) != folder->UnpackCRC) {
		return SZ_ERROR_CRC;
	}
	return SZ_OK;
}

static int SzReadAndDecodePackedStreams(CLookToRead *inStream,
										 CBuf *sd,
										 CBuf *outBuffer,
										 UInt64 baseOffset) {
	CSzAr p;
	UInt64 *unpackSizes = 0;
	Byte *digestsDefined = 0;
	UInt32 *digests = 0;
	int res;
	SzAr_Init(&p);
	res = SzReadAndDecodePackedStreams2(inStream, sd, outBuffer, baseOffset,
										&p, &unpackSizes, &digestsDefined, &digests);
	SzAr_Free(&p);
	free(unpackSizes);
	free(digestsDefined);
	free(digests);
	return res;
}

int SzArEx_Open(CSzArEx *p, CLookToRead *inStream) {
	Byte header[k7zStartHeaderSize];
	UInt64 nextHeaderOffset, nextHeaderSize;
	size_t nextHeaderSizeT;
	UInt32 nextHeaderCRC;
	CBuf buffer;
	int res;
	
	RINOK(LookInStream_Read2(inStream, header, k7zStartHeaderSize, SZ_ERROR_NO_ARCHIVE));
	
	
	if (memcmp(header, k7zSignature, k7zSignatureSize) != 0) {
		return SZ_ERROR_NO_ARCHIVE;
	}
	if (header[6] != k7zMajorVersion) {
		return SZ_ERROR_UNSUPPORTED;
	}
	
	nextHeaderOffset = *(UInt64*)(header + 12);
	nextHeaderSize = *(UInt64*)(header + 20);
	nextHeaderCRC = *(UInt32*)(header + 28);
	
	p->startPosAfterHeader = k7zStartHeaderSize;
	
	if (CrcCalc(header + 12, 20) != *(UInt32*)(header + 8)) {
		return SZ_ERROR_CRC;
	}
	
	nextHeaderSizeT = (size_t)nextHeaderSize;
	if (nextHeaderSizeT == 0) {
		return SZ_OK;
	}
	
	Int64 pos = 0;
	RINOK(LookToRead_Seek(inStream, &pos, SEEK_END));
	if (pos < nextHeaderOffset) {
		return SZ_ERROR_INPUT_EOF;
	}
	
	RINOK(LookInStream_SeekTo(inStream, k7zStartHeaderSize + nextHeaderOffset));
	
	if (!Buf_Create(&buffer, nextHeaderSizeT)) {
		return SZ_ERROR_MEM;
	}
	
	res = LookInStream_Read(inStream, buffer.data, nextHeaderSizeT);
	if (res == SZ_OK) {
		res = SZ_ERROR_ARCHIVE;
		if (CrcCalc(buffer.data, nextHeaderSizeT) == nextHeaderCRC) {
			CBuf sd;
			UInt64 type;
			
			sd = buffer;
			res = SzReadNumber(&sd, &type);
			if (res == SZ_OK && type == k7zIdEncodedHeader) {
				CBuf outBuffer;
				Buf_Init(&outBuffer);
				res = SzReadAndDecodePackedStreams(inStream, &sd, &outBuffer, p->startPosAfterHeader);
				if (res != SZ_OK) {
					Buf_Free(&outBuffer);
				} else {
					Buf_Free(&buffer);
					buffer = outBuffer;
					sd = buffer;
					res = SzReadNumber(&sd, &type);
				}
			}
			if (res == SZ_OK) {
				if (type == k7zIdHeader) {
					res = SzReadHeader(p, &sd);
				} else {
					res = SZ_ERROR_UNSUPPORTED;
				}
			}
		}
	}
	Buf_Free(&buffer);
	return res;
}



int SzAr_Extract(const CSzArEx *p,
				 CLookToRead *inStream,
				 UInt32 fileIndex,
				 UInt32 *blockIndex,
				 Byte **outBuffer,
				 size_t *outBufferSize,
				 size_t *offset,
				 size_t *outSizeProcessed) {
	UInt32 folderIndex = p->FileIndexToFolderIndexMap[fileIndex];
	int res = SZ_OK;
	*offset = 0;
	*outSizeProcessed = 0;
	if (folderIndex == (UInt32)-1) {
		free(*outBuffer);
		*blockIndex = folderIndex;
		*outBuffer = 0;
		*outBufferSize = 0;
		return SZ_OK;
	}
	
	if (*outBuffer == 0 || *blockIndex != folderIndex) {
		CSzFolder *folder = p->db.Folders + folderIndex;
		UInt64 unpackSizeSpec = SzFolder_GetUnpackSize(folder);
		size_t unpackSize = (size_t)unpackSizeSpec;
		UInt64 startOffset = SzArEx_GetFolderStreamPos(p, folderIndex, 0);
		
		if (unpackSize != unpackSizeSpec) {
			return SZ_ERROR_MEM;
		}
		*blockIndex = folderIndex;
		free(*outBuffer);
		*outBuffer = 0;
		
		RINOK(LookInStream_SeekTo(inStream, startOffset));
		
		if (res == SZ_OK) {
			*outBufferSize = unpackSize;
			if (unpackSize != 0) {
				*outBuffer = (Byte *)malloc(unpackSize);
				if (*outBuffer == 0) {
					res = SZ_ERROR_MEM;
				}
			}
			if (res == SZ_OK) {
				res = SzDecode(p->db.PackSizes + p->FolderStartPackStreamIndex[folderIndex], folder,
							   inStream, startOffset, *outBuffer, unpackSize);
				if (res == SZ_OK) {
					if (folder->UnpackCRCDefined) {
						if (CrcCalc(*outBuffer, unpackSize) != folder->UnpackCRC)
							res = SZ_ERROR_CRC;
					}
				}
			}
		}
	}
	if (res == SZ_OK) {
		UInt32 i;
		CSzFileItem *fileItem = p->db.Files + fileIndex;
		*offset = 0;
		for (i = p->FolderStartFileIndex[folderIndex]; i < fileIndex; i++)
			*offset += (UInt32)p->db.Files[i].Size;
		*outSizeProcessed = (size_t)fileItem->Size;
		if (*offset + *outSizeProcessed > *outBufferSize)
			return SZ_ERROR_FAIL;
		{
			if (fileItem->FileCRCDefined) {
				if (CrcCalc(*outBuffer + *offset, *outSizeProcessed) != fileItem->FileCRC)
					res = SZ_ERROR_CRC;
			}
		}
	}
	return res;
}

