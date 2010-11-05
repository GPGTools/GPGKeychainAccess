#ifndef __7Z_DIV_H
#define __7Z_DIV_H

#include <stddef.h>
#include <stdio.h>


#define SZ_OK 0
#define SZ_ERROR_DATA 1
#define SZ_ERROR_MEM 2
#define SZ_ERROR_CRC 3
#define SZ_ERROR_UNSUPPORTED 4
#define SZ_ERROR_PARAM 5
#define SZ_ERROR_INPUT_EOF 6
#define SZ_ERROR_OUTPUT_EOF 7
#define SZ_ERROR_READ 8
#define SZ_ERROR_WRITE 9
#define SZ_ERROR_PROGRESS 10
#define SZ_ERROR_FAIL 11
#define SZ_ERROR_THREAD 12
#define SZ_ERROR_ARCHIVE 16
#define SZ_ERROR_NO_ARCHIVE 17


#ifndef RINOK
#define RINOK(x) { int __result__ = (x); if (__result__ != 0) return __result__; }
#endif

typedef unsigned char Byte;
typedef short Int16;
typedef unsigned short UInt16;
typedef int Int32;
typedef unsigned int UInt32;
typedef long long int Int64;
typedef unsigned long long int UInt64;



#define LookToRead_BUF_SIZE (1 << 14)

typedef struct {
	FILE **file;
	size_t pos;
	size_t size;
	Byte buf[LookToRead_BUF_SIZE];
} CLookToRead;

int LookInStream_SeekTo(CLookToRead *stream, UInt64 offset);

int LookInStream_Read2(CLookToRead *stream, void *buf, size_t size, int errorType);
int LookInStream_Read(CLookToRead *stream, void *buf, size_t size);


void LookToRead_Init(CLookToRead *stream);


int LookToRead_Look_Exact(CLookToRead *stream, void **buf, size_t *size);
int LookToRead_Skip(CLookToRead *stream, size_t offset);
int LookToRead_Read(CLookToRead *stream, void *buf, size_t *size);
int LookToRead_Seek(CLookToRead *stream, Int64 *pos, int whence);



typedef struct {
	Byte *data;
	size_t size;
} CBuf;

void Buf_Init(CBuf *p);
int Buf_Create(CBuf *p, size_t size);
void Buf_Free(CBuf *p);


extern UInt32 g_CrcTable[];

void CrcGenerateTable(void);

#define CRC_INIT_VAL 0xFFFFFFFF
#define CRC_GET_DIGEST(crc) ((crc) ^ 0xFFFFFFFF)
#define CRC_UPDATE_BYTE(crc, b) (g_CrcTable[((crc) ^ (b)) & 0xFF] ^ ((crc) >> 8))

UInt32 CrcUpdate(UInt32 crc, const void *data, size_t size);
UInt32 CrcCalc(const void *data, size_t size);



#define k7zSignatureSize 6
extern Byte k7zSignature[k7zSignatureSize];

#define k7zMajorVersion 0

#define k7zStartHeaderSize 0x20

enum EIdEnum {
	k7zIdEnd,
    
	k7zIdHeader,
    
	k7zIdArchiveProperties,
    
	k7zIdAdditionalStreamsInfo,
	k7zIdMainStreamsInfo,
	k7zIdFilesInfo,
	
	k7zIdPackInfo,
	k7zIdUnpackInfo,
	k7zIdSubStreamsInfo,
	
	k7zIdSize,
	k7zIdCRC,
	
	k7zIdFolder,
	
	k7zIdCodersUnpackSize,
	k7zIdNumUnpackStream,
	
	k7zIdEmptyStream,
	k7zIdEmptyFile,
	k7zIdAnti,
	
	k7zIdName,
	k7zIdCTime,
	k7zIdATime,
	k7zIdMTime,
	k7zIdWinAttributes,
	k7zIdComment,
	
	k7zIdEncodedHeader,
	
	k7zIdStartPos,
	k7zIdDummy
};

int createPathForFile(const char *filePath, int relativePathLen, Byte isDir);
int directoryExists(const char *path);

int FileInStream_Read(FILE *pp, void *buf, size_t *size);
int FileInStream_Seek(FILE *pp, Int64 *pos, int whence);





#endif
