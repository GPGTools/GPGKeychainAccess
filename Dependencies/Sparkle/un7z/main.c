#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

#include "7zDiv.h"
#include "7zIn.h"


int main(int numargs, char *args[]) {
	FILE *archiveFile;
	CLookToRead archiveStream;
	CSzArEx db;
	int res;
	
	
	if (numargs != 3) {
		return 1;
	}
	if ((archiveFile = fopen(args[1], "r")) == NULL) {
		return 2;
	}
	if (!directoryExists(args[2])) {
		return 4;		
	}
	
	int outPathLen = strlen(args[2]);
	int maxPathLen = 5;
	int pathLen;
	char *outputPath;
	
	outputPath = malloc(outPathLen + maxPathLen + 1);
	memcpy(outputPath, args[2], outPathLen);
	if (outputPath[outPathLen - 1] != '/') {
		outputPath[outPathLen] = '/';
		outPathLen++;
		maxPathLen--; 
	}
	
	
	archiveStream.file = &archiveFile;
	LookToRead_Init(&archiveStream);
	
	CrcGenerateTable();
	
	SzArEx_Init(&db);
	res = SzArEx_Open(&db, &archiveStream);
	if (res == SZ_OK) {
		UInt32 i;
		
		UInt32 blockIndex;
		Byte *outBuffer = 0;
		size_t outBufferSize;
		
		for (i = 0; i < db.db.NumFiles; i++) {
			size_t offset;
			size_t outSizeProcessed;
			CSzFileItem *f = db.db.Files + i;
			
			pathLen = strlen(f->Name);
			if (pathLen > maxPathLen) {
				maxPathLen = pathLen * 2;
				outputPath = realloc(outputPath, outPathLen + maxPathLen + 1);
			}
			memcpy(outputPath + outPathLen, f->Name, pathLen + 1);
			
			mode_t fileMode;
			if (f->AttribDefined && f->Attrib & 0x8000) {
				fileMode = f->Attrib >> 16;
			} else {
				fileMode = 0;
			}
			
			if (f->IsDir) {
				createPathForFile(outputPath, outPathLen, 1);
				if (fileMode) {
					chmod(outputPath, fileMode);
				}
			} else {
				res = SzAr_Extract(&db, &archiveStream, i,
								   &blockIndex, &outBuffer, &outBufferSize,
								   &offset, &outSizeProcessed);
				if (res != SZ_OK) {
					break;
				}

				FILE *outFile;
				
				if (createPathForFile(outputPath, outPathLen, 0) != 0) {
					res = SZ_ERROR_FAIL;
					break;					
				}
				
				char isSpecial = 0;
				
				if (fileMode) {
					if (S_ISLNK(fileMode)) {
						isSpecial = 1;
						char lnikDest[outSizeProcessed + 1];
						memcpy(lnikDest, (char*)outBuffer + offset, outSizeProcessed);
						lnikDest[outSizeProcessed] = 0;
						if (symlink(lnikDest, outputPath) != 0) {
							res = SZ_ERROR_FAIL;
							break;
						}
						fileMode = 0;
					} else if (S_ISFIFO(fileMode)) {
						isSpecial = 1;
						if (mkfifo(outputPath, fileMode) != 0) {
							res = SZ_ERROR_FAIL;
							break;
						}						
					}
				}
				if (!isSpecial) {
					if ((outFile = fopen(outputPath, "w+")) == NULL) {
						res = SZ_ERROR_FAIL;
						break;
					}				
					if (fwrite(outBuffer + offset, 1, outSizeProcessed, outFile) != outSizeProcessed) {
						res = SZ_ERROR_FAIL;
						break;
					}
					if (fclose(outFile)) {
						res = SZ_ERROR_FAIL;
						break;
					}
				}
				if (fileMode) {
					chmod(outputPath, fileMode);
				}
			}
		}
		free(outBuffer);
	}
	SzArEx_Free(&db);
	free(outputPath);
	fclose(archiveFile);
	
	if (res == SZ_OK) {
		return 0;
	}
	return 3;
}
