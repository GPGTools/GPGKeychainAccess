#ifndef __7Z_IN_H
#define __7Z_IN_H

#include "7zDiv.h"

typedef struct {
	UInt32 NumInStreams;
	UInt32 NumOutStreams;
	UInt64 MethodID;
	CBuf Props;
} CSzCoderInfo;

void SzCoderInfo_Init(CSzCoderInfo *p);
void SzCoderInfo_Free(CSzCoderInfo *p);

typedef struct {
	UInt32 InIndex;
	UInt32 OutIndex;
} CBindPair;

typedef struct {
	CSzCoderInfo *Coders;
	CBindPair *BindPairs;
	UInt32 *PackStreams;
	UInt64 *UnpackSizes;
	UInt32 NumCoders;
	UInt32 NumBindPairs;
	UInt32 NumPackStreams;
	int UnpackCRCDefined;
	UInt32 UnpackCRC;
	
	UInt32 NumUnpackStreams;
} CSzFolder;

void SzFolder_Init(CSzFolder *p);
UInt64 SzFolder_GetUnpackSize(CSzFolder *p);
int SzFolder_FindBindPairForInStream(CSzFolder *p, UInt32 inStreamIndex);
UInt32 SzFolder_GetNumOutStreams(CSzFolder *p);
UInt64 SzFolder_GetUnpackSize(CSzFolder *p);

typedef struct {
	UInt32 Low;
	UInt32 High;
} CNtfsFileTime;

typedef struct {
	CNtfsFileTime MTime;
	UInt64 Size;
	char *Name;
	UInt32 FileCRC;
	
	Byte HasStream;
	Byte IsDir;
	Byte IsAnti;
	Byte FileCRCDefined;
	Byte MTimeDefined;
	
	char AttribDefined;
	UInt32 Attrib;
} CSzFileItem;

void SzFile_Init(CSzFileItem *p);

typedef struct {
	UInt64 *PackSizes;
	Byte *PackCRCsDefined;
	UInt32 *PackCRCs;
	CSzFolder *Folders;
	CSzFileItem *Files;
	UInt32 NumPackStreams;
	UInt32 NumFolders;
	UInt32 NumFiles;
} CSzAr;

void SzAr_Init(CSzAr *p);
void SzAr_Free(CSzAr *p);



typedef struct {
	CSzAr db;
	
	UInt64 startPosAfterHeader;
	UInt64 dataPos;
	
	UInt32 *FolderStartPackStreamIndex;
	UInt64 *PackStreamStartPositions;
	UInt32 *FolderStartFileIndex;
	UInt32 *FileIndexToFolderIndexMap;
} CSzArEx;

void SzArEx_Init(CSzArEx *p);
void SzArEx_Free(CSzArEx *p);
UInt64 SzArEx_GetFolderStreamPos(const CSzArEx *p, UInt32 folderIndex, UInt32 indexInFolder);

int SzArEx_Open(CSzArEx *p, CLookToRead *inStream);

int SzAr_Extract(const CSzArEx *db,
				 CLookToRead *inStream,
				 UInt32 fileIndex,
				 UInt32 *blockIndex,
				 Byte **outBuffer,
				 size_t *outBufferSize,
				 size_t *offset,
				 size_t *outSizeProcessed);

#endif
