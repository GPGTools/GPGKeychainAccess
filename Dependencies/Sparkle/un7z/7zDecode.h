#ifndef __7Z_DECODE_H
#define __7Z_DECODE_H

#include "7zIn.h"

int Bcj2_Decode(const Byte *buf0, size_t size0,
				const Byte *buf1, size_t size1,
				const Byte *buf2, size_t size2,
				const Byte *buf3, size_t size3,
				Byte *outBuf, size_t outSize);


#define x86_Convert_Init(state) { state = 0; }
size_t x86_Convert(Byte *data, size_t size, UInt32 *state);



/* #define _LZMA_PROB32 */
/* _LZMA_PROB32 can increase the speed on some CPUs,
 but memory usage for CLzmaDec::probs will be doubled in that case */

#ifdef _LZMA_PROB32
#define CLzmaProb UInt32
#else
#define CLzmaProb UInt16
#endif



#define LZMA_PROPS_SIZE 5

typedef struct _CLzmaProps
{
	unsigned lc, lp, pb;
	UInt32 dicSize;
} CLzmaProps;

int LzmaProps_Decode(CLzmaProps *p, const Byte *data, unsigned size);


#define LZMA_REQUIRED_INPUT_MAX 20

typedef struct {
	CLzmaProps prop;
	CLzmaProb *probs;
	Byte *dic;
	const Byte *buf;
	UInt32 range, code;
	size_t dicPos;
	size_t dicBufSize;
	UInt32 processedPos;
	UInt32 checkDicSize;
	unsigned state;
	UInt32 reps[4];
	unsigned remainLen;
	int needFlush;
	int needInitState;
	UInt32 numProbs;
	unsigned tempBufSize;
	Byte tempBuf[LZMA_REQUIRED_INPUT_MAX];
} CLzmaDec;

#define LzmaDec_Construct(p) { (p)->dic = 0; (p)->probs = 0; }

void LzmaDec_Init(CLzmaDec *p);

typedef enum {
	LZMA_FINISH_ANY,
	LZMA_FINISH_END
} ELzmaFinishMode;


typedef enum {
	LZMA_STATUS_NOT_SPECIFIED,
	LZMA_STATUS_FINISHED_WITH_MARK,
	LZMA_STATUS_NOT_FINISHED,
	LZMA_STATUS_NEEDS_MORE_INPUT,
	LZMA_STATUS_MAYBE_FINISHED_WITHOUT_MARK
} ELzmaStatus;

int LzmaDec_AllocateProbs(CLzmaDec *p, const Byte *props, unsigned propsSize);
void LzmaDec_FreeProbs(CLzmaDec *p);

int LzmaDec_Allocate(CLzmaDec *state, const Byte *prop, unsigned propsSize);
void LzmaDec_Free(CLzmaDec *state);


int LzmaDec_DecodeToDic(CLzmaDec *p, size_t dicLimit,
						const Byte *src, size_t *srcLen, ELzmaFinishMode finishMode, ELzmaStatus *status);

int SzDecode(const UInt64 *packSizes, const CSzFolder *folder,
			  CLookToRead *inStream, UInt64 startPos,
			  Byte *outBuffer, size_t outSize);

#endif
