#include <string.h>
#include <stdlib.h>

#include "7zDecode.h"


#ifdef _LZMA_PROB32
#define CProb UInt32
#else
#define CProb UInt16
#endif

#define IsJcc(b0, b1) ((b0) == 0x0F && ((b1) & 0xF0) == 0x80)
#define IsJ(b0, b1) ((b1 & 0xFE) == 0xE8 || IsJcc(b0, b1))

#define kNumTopBits 24
#define kTopValue ((UInt32)1 << kNumTopBits)

#define kNumBitModelTotalBits 11
#define kBitModelTotal (1 << kNumBitModelTotalBits)
#define kNumMoveBits 5

#define RC_READ_BYTE (*buffer++)
#define RC_TEST { if (buffer == bufferLim) return SZ_ERROR_DATA; }

#define NORMALIZE1 if (range < kTopValue) { RC_TEST; range <<= 8; code = (code << 8) | RC_READ_BYTE; }


int Bcj2_Decode(const Byte *buf0, size_t size0,
				const Byte *buf1, size_t size1,
				const Byte *buf2, size_t size2,
				const Byte *buf3, size_t size3,
				Byte *outBuf, size_t outSize) {
	CProb p[256 + 2];
	size_t inPos = 0, outPos = 0;
	
	const Byte *buffer, *bufferLim;
	UInt32 range, code;
	Byte prevByte = 0;
	
	unsigned int i;
	for (i = 0; i < sizeof(p) / sizeof(p[0]); i++)
		p[i] = kBitModelTotal >> 1;
	
	buffer = buf3;
	bufferLim = buffer + size3;
	
	code = 0;
	range = 0xFFFFFFFF;
	for (int i = 0; i < 5; i++) {
		RC_TEST;
		code = (code << 8) | RC_READ_BYTE; 
	}
	
	
	if (outSize == 0) {
		return SZ_OK;
	}
	
	for (;;) {
		Byte b;
		CProb *prob;
		UInt32 bound;
		UInt32 ttt;
		
		size_t limit = size0 - inPos;
		if (outSize - outPos < limit) {
			limit = outSize - outPos;
		}
		while (limit != 0) {
			Byte b = buf0[inPos];
			outBuf[outPos++] = b;
			if (IsJ(prevByte, b)) {
				break;
			}
			inPos++;
			prevByte = b;
			limit--;
		}
		
		if (limit == 0 || outPos == outSize) {
			break;
		}
		
		b = buf0[inPos++];
		
		if (b == 0xE8) {
			prob = p + prevByte;
		} else if (b == 0xE9) {
			prob = p + 256;
		} else {
			prob = p + 257;
		}
		
		ttt = *(prob);
		bound = (range >> kNumBitModelTotalBits) * ttt;
		if (code < bound) {
			range = bound;
			*(prob) = (CProb)(ttt + ((kBitModelTotal - ttt) >> kNumMoveBits));
			NORMALIZE1;
			prevByte = b;
		} else {
			UInt32 dest;
			const Byte *v;
			range -= bound;
			code -= bound;
			*(prob) = (CProb)(ttt - (ttt >> kNumMoveBits));
			NORMALIZE1;
			if (b == 0xE8) {
				v = buf1;
				if (size1 < 4) {
					return SZ_ERROR_DATA;
				}
				buf1 += 4;
				size1 -= 4;
			} else {
				v = buf2;
				if (size2 < 4) {
					return SZ_ERROR_DATA;
				}
				buf2 += 4;
				size2 -= 4;
			}
			dest = (((UInt32)v[0] << 24) | ((UInt32)v[1] << 16) |
					((UInt32)v[2] << 8) | ((UInt32)v[3])) - ((UInt32)outPos + 4);
			outBuf[outPos++] = (Byte)dest;
			if (outPos == outSize) {
				break;
			}
			outBuf[outPos++] = (Byte)(dest >> 8);
			if (outPos == outSize) {
				break;
			}
			outBuf[outPos++] = (Byte)(dest >> 16);
			if (outPos == outSize) {
				break;
			}
			outBuf[outPos++] = prevByte = (Byte)(dest >> 24);
		}
	}
	return (outPos == outSize) ? SZ_OK : SZ_ERROR_DATA;
}


#define Test86MSByte(b) ((b) == 0 || (b) == 0xFF)

const Byte kMaskToAllowedStatus[8] = {1, 1, 1, 0, 1, 0, 0, 0};
const Byte kMaskToBitNumber[8] = {0, 1, 2, 2, 3, 3, 3, 3};

size_t x86_Convert(Byte *data, size_t size, UInt32 *state) {
	if (size < 5) {
		return 0;
	}
	size_t bufferPos = 0, prevPosT;
	UInt32 prevMask = *state & 0x7;
	prevPosT = (size_t)0 - 1;
	
	for (;;) {
		Byte *p = data + bufferPos;
		Byte *limit = data + size - 4;
		for (; p < limit; p++) {
			if ((*p & 0xFE) == 0xE8) {
				break;
			}
		}
		bufferPos = (size_t)(p - data);
		if (p >= limit) {
			break;
		}
		prevPosT = bufferPos - prevPosT;
		if (prevPosT > 3) {
			prevMask = 0;
		} else {
			prevMask = (prevMask << ((int)prevPosT - 1)) & 0x7;
			if (prevMask != 0) {
				Byte b = p[4 - kMaskToBitNumber[prevMask]];
				if (!kMaskToAllowedStatus[prevMask] || Test86MSByte(b)) {
					prevPosT = bufferPos;
					prevMask = ((prevMask << 1) & 0x7) | 1;
					bufferPos++;
					continue;
				}
			}
		}
		prevPosT = bufferPos;
		
		if (Test86MSByte(p[4])) {
			UInt32 src = ((UInt32)p[4] << 24) | ((UInt32)p[3] << 16) | ((UInt32)p[2] << 8) | ((UInt32)p[1]);
			UInt32 dest;
			for (;;) {
				Byte b;
				int index;
				dest = src - (5 + (UInt32)bufferPos);
				if (prevMask == 0) {
					break;
				}
				index = kMaskToBitNumber[prevMask] * 8;
				b = (Byte)(dest >> (24 - index));
				if (!Test86MSByte(b)) {
					break;
				}
				src = dest ^ ((1 << (32 - index)) - 1);
			}
			p[4] = (Byte)(~(((dest >> 24) & 1) - 1));
			p[3] = (Byte)(dest >> 16);
			p[2] = (Byte)(dest >> 8);
			p[1] = (Byte)dest;
			bufferPos += 5;
		} else {
			prevMask = ((prevMask << 1) & 0x7) | 1;
			bufferPos++;
		}
	}
	prevPosT = bufferPos - prevPosT;
	*state = ((prevPosT > 3) ? 0 : ((prevMask << ((int)prevPosT - 1)) & 0x7));
	return bufferPos;
}




#define kNumTopBits 24
#define kTopValue ((UInt32)1 << kNumTopBits)

#define kNumBitModelTotalBits 11
#define kBitModelTotal (1 << kNumBitModelTotalBits)
#define kNumMoveBits 5

#define RC_INIT_SIZE 5

#define NORMALIZE if (range < kTopValue) { range <<= 8; code = (code << 8) | (*buf++); }

#define IF_BIT_0(p) ttt = *(p); NORMALIZE; bound = (range >> kNumBitModelTotalBits) * ttt; if (code < bound)
#define UPDATE_0(p) range = bound; *(p) = (CLzmaProb)(ttt + ((kBitModelTotal - ttt) >> kNumMoveBits));
#define UPDATE_1(p) range -= bound; code -= bound; *(p) = (CLzmaProb)(ttt - (ttt >> kNumMoveBits));
#define GET_BIT2(p, i, A0, A1) IF_BIT_0(p) \
{ UPDATE_0(p); i = (i + i); A0; } else \
{ UPDATE_1(p); i = (i + i) + 1; A1; }
#define GET_BIT(p, i) GET_BIT2(p, i, ; , ;)

#define TREE_GET_BIT(probs, i) { GET_BIT((probs + i), i); }
#define TREE_DECODE(probs, limit, i) \
{ i = 1; do { TREE_GET_BIT(probs, i); } while (i < limit); i -= limit; }

/* #define _LZMA_SIZE_OPT */

#ifdef _LZMA_SIZE_OPT
#define TREE_6_DECODE(probs, i) TREE_DECODE(probs, (1 << 6), i)
#else
#define TREE_6_DECODE(probs, i) \
{ i = 1; \
TREE_GET_BIT(probs, i); \
TREE_GET_BIT(probs, i); \
TREE_GET_BIT(probs, i); \
TREE_GET_BIT(probs, i); \
TREE_GET_BIT(probs, i); \
TREE_GET_BIT(probs, i); \
i -= 0x40; }
#endif

#define NORMALIZE_CHECK if (range < kTopValue) { if (buf >= bufLimit) return DUMMY_ERROR; range <<= 8; code = (code << 8) | (*buf++); }

#define IF_BIT_0_CHECK(p) ttt = *(p); NORMALIZE_CHECK; bound = (range >> kNumBitModelTotalBits) * ttt; if (code < bound)
#define UPDATE_0_CHECK range = bound;
#define UPDATE_1_CHECK range -= bound; code -= bound;
#define GET_BIT2_CHECK(p, i, A0, A1) IF_BIT_0_CHECK(p) \
{ UPDATE_0_CHECK; i = (i + i); A0; } else \
{ UPDATE_1_CHECK; i = (i + i) + 1; A1; }
#define GET_BIT_CHECK(p, i) GET_BIT2_CHECK(p, i, ; , ;)
#define TREE_DECODE_CHECK(probs, limit, i) \
{ i = 1; do { GET_BIT_CHECK(probs + i, i) } while (i < limit); i -= limit; }


#define kNumPosBitsMax 4
#define kNumPosStatesMax (1 << kNumPosBitsMax)

#define kLenNumLowBits 3
#define kLenNumLowSymbols (1 << kLenNumLowBits)
#define kLenNumMidBits 3
#define kLenNumMidSymbols (1 << kLenNumMidBits)
#define kLenNumHighBits 8
#define kLenNumHighSymbols (1 << kLenNumHighBits)

#define LenChoice 0
#define LenChoice2 (LenChoice + 1)
#define LenLow (LenChoice2 + 1)
#define LenMid (LenLow + (kNumPosStatesMax << kLenNumLowBits))
#define LenHigh (LenMid + (kNumPosStatesMax << kLenNumMidBits))
#define kNumLenProbs (LenHigh + kLenNumHighSymbols)


#define kNumStates 12
#define kNumLitStates 7

#define kStartPosModelIndex 4
#define kEndPosModelIndex 14
#define kNumFullDistances (1 << (kEndPosModelIndex >> 1))

#define kNumPosSlotBits 6
#define kNumLenToPosStates 4

#define kNumAlignBits 4
#define kAlignTableSize (1 << kNumAlignBits)

#define kMatchMinLen 2
#define kMatchSpecLenStart (kMatchMinLen + kLenNumLowSymbols + kLenNumMidSymbols + kLenNumHighSymbols)

#define IsMatch 0
#define IsRep (IsMatch + (kNumStates << kNumPosBitsMax))
#define IsRepG0 (IsRep + kNumStates)
#define IsRepG1 (IsRepG0 + kNumStates)
#define IsRepG2 (IsRepG1 + kNumStates)
#define IsRep0Long (IsRepG2 + kNumStates)
#define PosSlot (IsRep0Long + (kNumStates << kNumPosBitsMax))
#define SpecPos (PosSlot + (kNumLenToPosStates << kNumPosSlotBits))
#define Align (SpecPos + kNumFullDistances - kEndPosModelIndex)
#define LenCoder (Align + kAlignTableSize)
#define RepLenCoder (LenCoder + kNumLenProbs)
#define Literal (RepLenCoder + kNumLenProbs)

#define LZMA_BASE_SIZE 1846
#define LZMA_LIT_SIZE 768

#define LzmaProps_GetNumProbs(p) ((UInt32)LZMA_BASE_SIZE + (LZMA_LIT_SIZE << ((p)->lc + (p)->lp)))

#if Literal != LZMA_BASE_SIZE
StopCompilingDueBUG
#endif

static const Byte kLiteralNextStates[kNumStates * 2] =
{
	0, 0, 0, 0, 1, 2, 3,  4,  5,  6,  4,  5,
	7, 7, 7, 7, 7, 7, 7, 10, 10, 10, 10, 10
};

#define LZMA_DIC_MIN (1 << 12)

/* First LZMA-symbol is always decoded.
 And it decodes new LZMA-symbols while (buf < bufLimit), but "buf" is without last normalization
 Out:
 Result:
 SZ_OK - OK
 SZ_ERROR_DATA - Error
 p->remainLen:
 < kMatchSpecLenStart : normal remain
 = kMatchSpecLenStart : finished
 = kMatchSpecLenStart + 1 : Flush marker
 = kMatchSpecLenStart + 2 : State Init Marker
 */

static int LzmaDec_DecodeReal(CLzmaDec *p, size_t limit, const Byte *bufLimit) {
	CLzmaProb *probs = p->probs;
	
	unsigned state = p->state;
	UInt32 rep0 = p->reps[0], rep1 = p->reps[1], rep2 = p->reps[2], rep3 = p->reps[3];
	unsigned pbMask = ((unsigned)1 << (p->prop.pb)) - 1;
	unsigned lpMask = ((unsigned)1 << (p->prop.lp)) - 1;
	unsigned lc = p->prop.lc;
	
	Byte *dic = p->dic;
	size_t dicBufSize = p->dicBufSize;
	size_t dicPos = p->dicPos;
	
	UInt32 processedPos = p->processedPos;
	UInt32 checkDicSize = p->checkDicSize;
	unsigned len = 0;
	
	const Byte *buf = p->buf;
	UInt32 range = p->range;
	UInt32 code = p->code;
	
	do
	{
		CLzmaProb *prob;
		UInt32 bound;
		unsigned ttt;
		unsigned posState = processedPos & pbMask;
		
		prob = probs + IsMatch + (state << kNumPosBitsMax) + posState;
		IF_BIT_0(prob) {
			unsigned symbol;
			UPDATE_0(prob);
			prob = probs + Literal;
			if (checkDicSize != 0 || processedPos != 0)
				prob += (LZMA_LIT_SIZE * (((processedPos & lpMask) << lc) +
										  (dic[(dicPos == 0 ? dicBufSize : dicPos) - 1] >> (8 - lc))));
			
			if (state < kNumLitStates)
			{
				symbol = 1;
				do { GET_BIT(prob + symbol, symbol) } while (symbol < 0x100);
			}
			else
			{
				unsigned matchByte = p->dic[(dicPos - rep0) + ((dicPos < rep0) ? dicBufSize : 0)];
				unsigned offs = 0x100;
				symbol = 1;
				do
				{
					unsigned bit;
					CLzmaProb *probLit;
					matchByte <<= 1;
					bit = (matchByte & offs);
					probLit = prob + offs + bit + symbol;
					GET_BIT2(probLit, symbol, offs &= ~bit, offs &= bit)
				}
				while (symbol < 0x100);
			}
			dic[dicPos++] = (Byte)symbol;
			processedPos++;
			
			state = kLiteralNextStates[state];
			/* if (state < 4) state = 0; else if (state < 10) state -= 3; else state -= 6; */
			continue;
		}
		else
		{
			UPDATE_1(prob);
			prob = probs + IsRep + state;
			IF_BIT_0(prob)
			{
				UPDATE_0(prob);
				state += kNumStates;
				prob = probs + LenCoder;
			}
			else
			{
				UPDATE_1(prob);
				if (checkDicSize == 0 && processedPos == 0)
					return SZ_ERROR_DATA;
				prob = probs + IsRepG0 + state;
				IF_BIT_0(prob) {
					UPDATE_0(prob);
					prob = probs + IsRep0Long + (state << kNumPosBitsMax) + posState;
					IF_BIT_0(prob) {
						UPDATE_0(prob);
						dic[dicPos] = dic[(dicPos - rep0) + ((dicPos < rep0) ? dicBufSize : 0)];
						dicPos++;
						processedPos++;
						state = state < kNumLitStates ? 9 : 11;
						continue;
					}
					UPDATE_1(prob);
				}
				else
				{
					UInt32 distance;
					UPDATE_1(prob);
					prob = probs + IsRepG1 + state;
					IF_BIT_0(prob) {
						UPDATE_0(prob);
						distance = rep1;
					}
					else
					{
						UPDATE_1(prob);
						prob = probs + IsRepG2 + state;
						IF_BIT_0(prob) {
							UPDATE_0(prob);
							distance = rep2;
						}
						else
						{
							UPDATE_1(prob);
							distance = rep3;
							rep3 = rep2;
						}
						rep2 = rep1;
					}
					rep1 = rep0;
					rep0 = distance;
				}
				state = state < kNumLitStates ? 8 : 11;
				prob = probs + RepLenCoder;
			}
			{
				unsigned limit, offset;
				CLzmaProb *probLen = prob + LenChoice;
				IF_BIT_0(probLen) {
					UPDATE_0(probLen);
					probLen = prob + LenLow + (posState << kLenNumLowBits);
					offset = 0;
					limit = (1 << kLenNumLowBits);
				}
				else
				{
					UPDATE_1(probLen);
					probLen = prob + LenChoice2;
					IF_BIT_0(probLen) {
						UPDATE_0(probLen);
						probLen = prob + LenMid + (posState << kLenNumMidBits);
						offset = kLenNumLowSymbols;
						limit = (1 << kLenNumMidBits);
					}
					else
					{
						UPDATE_1(probLen);
						probLen = prob + LenHigh;
						offset = kLenNumLowSymbols + kLenNumMidSymbols;
						limit = (1 << kLenNumHighBits);
					}
				}
				TREE_DECODE(probLen, limit, len);
				len += offset;
			}
			
			if (state >= kNumStates)
			{
				UInt32 distance;
				prob = probs + PosSlot +
				((len < kNumLenToPosStates ? len : kNumLenToPosStates - 1) << kNumPosSlotBits);
				TREE_6_DECODE(prob, distance);
				if (distance >= kStartPosModelIndex) {
					unsigned posSlot = (unsigned)distance;
					int numDirectBits = (int)(((distance >> 1) - 1));
					distance = (2 | (distance & 1));
					if (posSlot < kEndPosModelIndex) {
						distance <<= numDirectBits;
						prob = probs + SpecPos + distance - posSlot - 1;
						{
							UInt32 mask = 1;
							unsigned i = 1;
							do
							{
								GET_BIT2(prob + i, i, ; , distance |= mask);
								mask <<= 1;
							}
							while (--numDirectBits != 0);
						}
					}
					else
					{
						numDirectBits -= kNumAlignBits;
						do
						{
							NORMALIZE
							range >>= 1;
							
							{
								UInt32 t;
								code -= range;
								t = (0 - ((UInt32)code >> 31)); /* (UInt32)((Int32)code >> 31) */
								distance = (distance << 1) + (t + 1);
								code += range & t;
							}
							/*
							 distance <<= 1;
							 if (code >= range)
							 {
							 code -= range;
							 distance |= 1;
							 }
							 */
						}
						while (--numDirectBits != 0);
						prob = probs + Align;
						distance <<= kNumAlignBits;
						{
							unsigned i = 1;
							GET_BIT2(prob + i, i, ; , distance |= 1);
							GET_BIT2(prob + i, i, ; , distance |= 2);
							GET_BIT2(prob + i, i, ; , distance |= 4);
							GET_BIT2(prob + i, i, ; , distance |= 8);
						}
						if (distance == (UInt32)0xFFFFFFFF) {
							len += kMatchSpecLenStart;
							state -= kNumStates;
							break;
						}
					}
				}
				rep3 = rep2;
				rep2 = rep1;
				rep1 = rep0;
				rep0 = distance + 1;
				if (checkDicSize == 0) {
					if (distance >= processedPos)
						return SZ_ERROR_DATA;
				}
				else if (distance >= checkDicSize)
					return SZ_ERROR_DATA;
				state = (state < kNumStates + kNumLitStates) ? kNumLitStates : kNumLitStates + 3;
				/* state = kLiteralNextStates[state]; */
			}
			
			len += kMatchMinLen;
			
			if (limit == dicPos)
				return SZ_ERROR_DATA;
			{
				size_t rem = limit - dicPos;
				unsigned curLen = ((rem < len) ? (unsigned)rem : len);
				size_t pos = (dicPos - rep0) + ((dicPos < rep0) ? dicBufSize : 0);
				
				processedPos += curLen;
				
				len -= curLen;
				if (pos + curLen <= dicBufSize) {
					Byte *dest = dic + dicPos;
					ptrdiff_t src = (ptrdiff_t)pos - (ptrdiff_t)dicPos;
					const Byte *lim = dest + curLen;
					dicPos += curLen;
					do
						*(dest) = (Byte)*(dest + src);
					while (++dest != lim);
				}
				else
				{
					do
					{
						dic[dicPos++] = dic[pos];
						if (++pos == dicBufSize)
							pos = 0;
					}
					while (--curLen != 0);
				}
			}
		}
	}
	while (dicPos < limit && buf < bufLimit);
	NORMALIZE;
	p->buf = buf;
	p->range = range;
	p->code = code;
	p->remainLen = len;
	p->dicPos = dicPos;
	p->processedPos = processedPos;
	p->reps[0] = rep0;
	p->reps[1] = rep1;
	p->reps[2] = rep2;
	p->reps[3] = rep3;
	p->state = state;
	
	return SZ_OK;
}

static void LzmaDec_WriteRem(CLzmaDec *p, size_t limit) {
	if (p->remainLen != 0 && p->remainLen < kMatchSpecLenStart) {
		Byte *dic = p->dic;
		size_t dicPos = p->dicPos;
		size_t dicBufSize = p->dicBufSize;
		unsigned len = p->remainLen;
		UInt32 rep0 = p->reps[0];
		if (limit - dicPos < len)
			len = (unsigned)(limit - dicPos);
		
		if (p->checkDicSize == 0 && p->prop.dicSize - p->processedPos <= len)
			p->checkDicSize = p->prop.dicSize;
		
		p->processedPos += len;
		p->remainLen -= len;
		while (len-- != 0) {
			dic[dicPos] = dic[(dicPos - rep0) + ((dicPos < rep0) ? dicBufSize : 0)];
			dicPos++;
		}
		p->dicPos = dicPos;
	}
}

static int LzmaDec_DecodeReal2(CLzmaDec *p, size_t limit, const Byte *bufLimit) {
	do
	{
		size_t limit2 = limit;
		if (p->checkDicSize == 0) {
			UInt32 rem = p->prop.dicSize - p->processedPos;
			if (limit - p->dicPos > rem)
				limit2 = p->dicPos + rem;
		}
		RINOK(LzmaDec_DecodeReal(p, limit2, bufLimit));
		if (p->processedPos >= p->prop.dicSize)
			p->checkDicSize = p->prop.dicSize;
		LzmaDec_WriteRem(p, limit);
	}
	while (p->dicPos < limit && p->buf < bufLimit && p->remainLen < kMatchSpecLenStart);
	
	if (p->remainLen > kMatchSpecLenStart) {
		p->remainLen = kMatchSpecLenStart;
	}
	return 0;
}

typedef enum
{
	DUMMY_ERROR, /* unexpected end of input stream */
	DUMMY_LIT,
	DUMMY_MATCH,
	DUMMY_REP
} ELzmaDummy;

static ELzmaDummy LzmaDec_TryDummy(const CLzmaDec *p, const Byte *buf, size_t inSize) {
	UInt32 range = p->range;
	UInt32 code = p->code;
	const Byte *bufLimit = buf + inSize;
	CLzmaProb *probs = p->probs;
	unsigned state = p->state;
	ELzmaDummy res;
	
	{
		CLzmaProb *prob;
		UInt32 bound;
		unsigned ttt;
		unsigned posState = (p->processedPos) & ((1 << p->prop.pb) - 1);
		
		prob = probs + IsMatch + (state << kNumPosBitsMax) + posState;
		IF_BIT_0_CHECK(prob) {
			UPDATE_0_CHECK
			
			/* if (bufLimit - buf >= 7) return DUMMY_LIT; */
			
			prob = probs + Literal;
			if (p->checkDicSize != 0 || p->processedPos != 0)
				prob += (LZMA_LIT_SIZE *
						 ((((p->processedPos) & ((1 << (p->prop.lp)) - 1)) << p->prop.lc) +
						  (p->dic[(p->dicPos == 0 ? p->dicBufSize : p->dicPos) - 1] >> (8 - p->prop.lc))));
			
			if (state < kNumLitStates)
			{
				unsigned symbol = 1;
				do { GET_BIT_CHECK(prob + symbol, symbol) } while (symbol < 0x100);
			}
			else
			{
				unsigned matchByte = p->dic[p->dicPos - p->reps[0] +
											((p->dicPos < p->reps[0]) ? p->dicBufSize : 0)];
				unsigned offs = 0x100;
				unsigned symbol = 1;
				do
				{
					unsigned bit;
					CLzmaProb *probLit;
					matchByte <<= 1;
					bit = (matchByte & offs);
					probLit = prob + offs + bit + symbol;
					GET_BIT2_CHECK(probLit, symbol, offs &= ~bit, offs &= bit)
				}
				while (symbol < 0x100);
			}
			res = DUMMY_LIT;
		}
		else
		{
			unsigned len;
			UPDATE_1_CHECK;
			
			prob = probs + IsRep + state;
			IF_BIT_0_CHECK(prob)
			{
				UPDATE_0_CHECK;
				state = 0;
				prob = probs + LenCoder;
				res = DUMMY_MATCH;
			}
			else
			{
				UPDATE_1_CHECK;
				res = DUMMY_REP;
				prob = probs + IsRepG0 + state;
				IF_BIT_0_CHECK(prob) {
					UPDATE_0_CHECK;
					prob = probs + IsRep0Long + (state << kNumPosBitsMax) + posState;
					IF_BIT_0_CHECK(prob) {
						UPDATE_0_CHECK;
						NORMALIZE_CHECK;
						return DUMMY_REP;
					}
					else
					{
						UPDATE_1_CHECK;
					}
				}
				else
				{
					UPDATE_1_CHECK;
					prob = probs + IsRepG1 + state;
					IF_BIT_0_CHECK(prob) {
						UPDATE_0_CHECK;
					}
					else
					{
						UPDATE_1_CHECK;
						prob = probs + IsRepG2 + state;
						IF_BIT_0_CHECK(prob) {
							UPDATE_0_CHECK;
						}
						else
						{
							UPDATE_1_CHECK;
						}
					}
				}
				state = kNumStates;
				prob = probs + RepLenCoder;
			}
			{
				unsigned limit, offset;
				CLzmaProb *probLen = prob + LenChoice;
				IF_BIT_0_CHECK(probLen) {
					UPDATE_0_CHECK;
					probLen = prob + LenLow + (posState << kLenNumLowBits);
					offset = 0;
					limit = 1 << kLenNumLowBits;
				}
				else
				{
					UPDATE_1_CHECK;
					probLen = prob + LenChoice2;
					IF_BIT_0_CHECK(probLen) {
						UPDATE_0_CHECK;
						probLen = prob + LenMid + (posState << kLenNumMidBits);
						offset = kLenNumLowSymbols;
						limit = 1 << kLenNumMidBits;
					}
					else
					{
						UPDATE_1_CHECK;
						probLen = prob + LenHigh;
						offset = kLenNumLowSymbols + kLenNumMidSymbols;
						limit = 1 << kLenNumHighBits;
					}
				}
				TREE_DECODE_CHECK(probLen, limit, len);
				len += offset;
			}
			
			if (state < 4)
			{
				unsigned posSlot;
				prob = probs + PosSlot +
				((len < kNumLenToPosStates ? len : kNumLenToPosStates - 1) <<
				 kNumPosSlotBits);
				TREE_DECODE_CHECK(prob, 1 << kNumPosSlotBits, posSlot);
				if (posSlot >= kStartPosModelIndex) {
					int numDirectBits = ((posSlot >> 1) - 1);
					
					/* if (bufLimit - buf >= 8) return DUMMY_MATCH; */
					
					if (posSlot < kEndPosModelIndex) {
						prob = probs + SpecPos + ((2 | (posSlot & 1)) << numDirectBits) - posSlot - 1;
					}
					else
					{
						numDirectBits -= kNumAlignBits;
						do
						{
							NORMALIZE_CHECK
							range >>= 1;
							code -= range & (((code - range) >> 31) - 1);
							/* if (code >= range) code -= range; */
						}
						while (--numDirectBits != 0);
						prob = probs + Align;
						numDirectBits = kNumAlignBits;
					}
					{
						unsigned i = 1;
						do
						{
							GET_BIT_CHECK(prob + i, i);
						}
						while (--numDirectBits != 0);
					}
				}
			}
		}
	}
	NORMALIZE_CHECK;
	return res;
}


static void LzmaDec_InitRc(CLzmaDec *p, const Byte *data) {
	p->code = ((UInt32)data[1] << 24) | ((UInt32)data[2] << 16) | ((UInt32)data[3] << 8) | ((UInt32)data[4]);
	p->range = 0xFFFFFFFF;
	p->needFlush = 0;
}

void LzmaDec_Init(CLzmaDec *p) {
	p->dicPos = 0;
	p->needFlush = 1;
	p->remainLen = 0;
	p->tempBufSize = 0;
	p->processedPos = 0;
	p->checkDicSize = 0;
	p->needInitState = 1;
	p->needInitState = 1;
}

static void LzmaDec_InitStateReal(CLzmaDec *p) {
	UInt32 numProbs = Literal + ((UInt32)LZMA_LIT_SIZE << (p->prop.lc + p->prop.lp));
	UInt32 i;
	CLzmaProb *probs = p->probs;
	for (i = 0; i < numProbs; i++)
		probs[i] = kBitModelTotal >> 1;
	p->reps[0] = p->reps[1] = p->reps[2] = p->reps[3] = 1;
	p->state = 0;
	p->needInitState = 0;
}

int LzmaDec_DecodeToDic(CLzmaDec *p, size_t dicLimit, const Byte *src, size_t *srcLen,
						ELzmaFinishMode finishMode, ELzmaStatus *status) {
	size_t inSize = *srcLen;
	(*srcLen) = 0;
	LzmaDec_WriteRem(p, dicLimit);
	
	*status = LZMA_STATUS_NOT_SPECIFIED;
	
	while (p->remainLen != kMatchSpecLenStart) {
		int checkEndMarkNow;
		
		if (p->needFlush != 0) {
			for (; inSize > 0 && p->tempBufSize < RC_INIT_SIZE; (*srcLen)++, inSize--)
				p->tempBuf[p->tempBufSize++] = *src++;
			if (p->tempBufSize < RC_INIT_SIZE)
			{
				*status = LZMA_STATUS_NEEDS_MORE_INPUT;
				return SZ_OK;
			}
			if (p->tempBuf[0] != 0)
				return SZ_ERROR_DATA;
			
			LzmaDec_InitRc(p, p->tempBuf);
			p->tempBufSize = 0;
		}
		
		checkEndMarkNow = 0;
		if (p->dicPos >= dicLimit) {
			if (p->remainLen == 0 && p->code == 0)
			{
				*status = LZMA_STATUS_MAYBE_FINISHED_WITHOUT_MARK;
				return SZ_OK;
			}
			if (finishMode == LZMA_FINISH_ANY)
			{
				*status = LZMA_STATUS_NOT_FINISHED;
				return SZ_OK;
			}
			if (p->remainLen != 0)
			{
				*status = LZMA_STATUS_NOT_FINISHED;
				return SZ_ERROR_DATA;
			}
			checkEndMarkNow = 1;
		}
		
		if (p->needInitState)
			LzmaDec_InitStateReal(p);
		
		if (p->tempBufSize == 0) {
			size_t processed;
			const Byte *bufLimit;
			if (inSize < LZMA_REQUIRED_INPUT_MAX || checkEndMarkNow)
			{
				int dummyRes = LzmaDec_TryDummy(p, src, inSize);
				if (dummyRes == DUMMY_ERROR) {
					memcpy(p->tempBuf, src, inSize);
					p->tempBufSize = (unsigned)inSize;
					(*srcLen) += inSize;
					*status = LZMA_STATUS_NEEDS_MORE_INPUT;
					return SZ_OK;
				}
				if (checkEndMarkNow && dummyRes != DUMMY_MATCH) {
					*status = LZMA_STATUS_NOT_FINISHED;
					return SZ_ERROR_DATA;
				}
				bufLimit = src;
			}
			else
				bufLimit = src + inSize - LZMA_REQUIRED_INPUT_MAX;
			p->buf = src;
			if (LzmaDec_DecodeReal2(p, dicLimit, bufLimit) != 0)
				return SZ_ERROR_DATA;
			processed = (size_t)(p->buf - src);
			(*srcLen) += processed;
			src += processed;
			inSize -= processed;
		}
		else
		{
			unsigned rem = p->tempBufSize, lookAhead = 0;
			while (rem < LZMA_REQUIRED_INPUT_MAX && lookAhead < inSize)
				p->tempBuf[rem++] = src[lookAhead++];
			p->tempBufSize = rem;
			if (rem < LZMA_REQUIRED_INPUT_MAX || checkEndMarkNow)
			{
				int dummyRes = LzmaDec_TryDummy(p, p->tempBuf, rem);
				if (dummyRes == DUMMY_ERROR) {
					(*srcLen) += lookAhead;
					*status = LZMA_STATUS_NEEDS_MORE_INPUT;
					return SZ_OK;
				}
				if (checkEndMarkNow && dummyRes != DUMMY_MATCH) {
					*status = LZMA_STATUS_NOT_FINISHED;
					return SZ_ERROR_DATA;
				}
			}
			p->buf = p->tempBuf;
			if (LzmaDec_DecodeReal2(p, dicLimit, p->buf) != 0)
				return SZ_ERROR_DATA;
			lookAhead -= (rem - (unsigned)(p->buf - p->tempBuf));
			(*srcLen) += lookAhead;
			src += lookAhead;
			inSize -= lookAhead;
			p->tempBufSize = 0;
		}
	}
	if (p->code == 0)
		*status = LZMA_STATUS_FINISHED_WITH_MARK;
	return (p->code == 0) ? SZ_OK : SZ_ERROR_DATA;
}


void LzmaDec_FreeProbs(CLzmaDec *p) {
	free(p->probs);
	p->probs = 0;
}

static void LzmaDec_FreeDict(CLzmaDec *p) {
	free(p->dic);
	p->dic = 0;
}

void LzmaDec_Free(CLzmaDec *p) {
	LzmaDec_FreeProbs(p);
	LzmaDec_FreeDict(p);
}

int LzmaProps_Decode(CLzmaProps *p, const Byte *data, unsigned size) {
	UInt32 dicSize;
	Byte d;
	
	if (size < LZMA_PROPS_SIZE)
		return SZ_ERROR_UNSUPPORTED;
	else
		dicSize = data[1] | ((UInt32)data[2] << 8) | ((UInt32)data[3] << 16) | ((UInt32)data[4] << 24);
	
	if (dicSize < LZMA_DIC_MIN)
		dicSize = LZMA_DIC_MIN;
	p->dicSize = dicSize;
	
	d = data[0];
	if (d >= (9 * 5 * 5))
		return SZ_ERROR_UNSUPPORTED;
	
	p->lc = d % 9;
	d /= 9;
	p->pb = d / 5;
	p->lp = d % 5;
	
	return SZ_OK;
}

static int LzmaDec_AllocateProbs2(CLzmaDec *p, const CLzmaProps *propNew) {
	UInt32 numProbs = LzmaProps_GetNumProbs(propNew);
	if (p->probs == 0 || numProbs != p->numProbs) {
		LzmaDec_FreeProbs(p);
		p->probs = (CLzmaProb *)malloc(numProbs * sizeof(CLzmaProb));
		p->numProbs = numProbs;
		if (p->probs == 0)
			return SZ_ERROR_MEM;
	}
	return SZ_OK;
}

int LzmaDec_AllocateProbs(CLzmaDec *p, const Byte *props, unsigned propsSize) {
	CLzmaProps propNew;
	RINOK(LzmaProps_Decode(&propNew, props, propsSize));
	RINOK(LzmaDec_AllocateProbs2(p, &propNew));
	p->prop = propNew;
	return SZ_OK;
}

int LzmaDec_Allocate(CLzmaDec *p, const Byte *props, unsigned propsSize) {
	CLzmaProps propNew;
	size_t dicBufSize;
	RINOK(LzmaProps_Decode(&propNew, props, propsSize));
	RINOK(LzmaDec_AllocateProbs2(p, &propNew));
	dicBufSize = propNew.dicSize;
	if (p->dic == 0 || dicBufSize != p->dicBufSize) {
		LzmaDec_FreeDict(p);
		p->dic = (Byte *)malloc(dicBufSize);
		if (p->dic == 0) {
			LzmaDec_FreeProbs(p);
			return SZ_ERROR_MEM;
		}
	}
	p->dicBufSize = dicBufSize;
	p->prop = propNew;
	return SZ_OK;
}





#define k_Copy 0
#define k_LZMA 0x30101
#define k_BCJ 0x03030103
#define k_BCJ2 0x0303011B

static int SzDecodeLzma(CSzCoderInfo *coder, UInt64 inSize, CLookToRead *inStream,
						 Byte *outBuffer, size_t outSize) {
	CLzmaDec state;
	int res;
	
	LzmaDec_Construct(&state);
	RINOK(LzmaDec_AllocateProbs(&state, coder->Props.data, (unsigned)coder->Props.size));
	state.dic = outBuffer;
	state.dicBufSize = outSize;
	LzmaDec_Init(&state);
	
	for (;;) {
		Byte *inBuf = NULL;
		size_t lookahead = (1 << 18);
		if (lookahead > inSize) {
			lookahead = (size_t)inSize;
		}
		res = LookToRead_Look_Exact((void *)inStream, (void **)&inBuf, &lookahead);
		if (res != SZ_OK) {
			break;
		}
		
		{
			size_t inProcessed = (size_t)lookahead;
			size_t dicPos = state.dicPos;
			ELzmaStatus status;
			res = LzmaDec_DecodeToDic(&state, outSize, inBuf, &inProcessed, LZMA_FINISH_END, &status);
			lookahead -= inProcessed;
			inSize -= inProcessed;
			
			printf("Processed: %li\n", inProcessed);
			fflush(stdout);
			
			if (res != SZ_OK)
				break;
			if (state.dicPos == state.dicBufSize || (inProcessed == 0 && dicPos == state.dicPos)) {
				if (state.dicBufSize != outSize || lookahead != 0 || (status != LZMA_STATUS_FINISHED_WITH_MARK && status != LZMA_STATUS_MAYBE_FINISHED_WITHOUT_MARK)) {
					res = SZ_ERROR_DATA;
				}
				break;
			}
			res = LookToRead_Skip((void *)inStream, inProcessed);
			if (res != SZ_OK)
				break;
		}
	}
	
	LzmaDec_FreeProbs(&state);
	return res;
}

static int SzDecodeCopy(UInt64 inSize, CLookToRead *inStream, Byte *outBuffer) {
	while (inSize > 0) {
		void *inBuf;
		size_t curSize = (1 << 18);
		if (curSize > inSize)
			curSize = (size_t)inSize;
		RINOK(LookToRead_Look_Exact((void *)inStream, (void **)&inBuf, &curSize));
		if (curSize == 0)
			return SZ_ERROR_INPUT_EOF;
		memcpy(outBuffer, inBuf, curSize);
		outBuffer += curSize;
		inSize -= curSize;
		RINOK(LookToRead_Skip((void *)inStream, curSize));
	}
	return SZ_OK;
}

#define IS_UNSUPPORTED_METHOD(m) ((m) != k_Copy && (m) != k_LZMA)
#define IS_UNSUPPORTED_CODER(c) (IS_UNSUPPORTED_METHOD(c.MethodID) || c.NumInStreams != 1 || c.NumOutStreams != 1)
#define IS_NO_BCJ(c) (c.MethodID != k_BCJ || c.NumInStreams != 1 || c.NumOutStreams != 1)
#define IS_NO_BCJ2(c) (c.MethodID != k_BCJ2 || c.NumInStreams != 4 || c.NumOutStreams != 1)

int CheckSupportedFolder(const CSzFolder *f) {
	if (f->NumCoders < 1 || f->NumCoders > 4)
		return SZ_ERROR_UNSUPPORTED;
	if (IS_UNSUPPORTED_CODER(f->Coders[0]))
		return SZ_ERROR_UNSUPPORTED;
	if (f->NumCoders == 1) {
		if (f->NumPackStreams != 1 || f->PackStreams[0] != 0 || f->NumBindPairs != 0)
			return SZ_ERROR_UNSUPPORTED;
		return SZ_OK;
	}
	if (f->NumCoders == 2) {
		if (IS_NO_BCJ(f->Coders[1]) ||
			f->NumPackStreams != 1 || f->PackStreams[0] != 0 ||
			f->NumBindPairs != 1 ||
			f->BindPairs[0].InIndex != 1 || f->BindPairs[0].OutIndex != 0)
			return SZ_ERROR_UNSUPPORTED;
		return SZ_OK;
	}
	if (f->NumCoders == 4) {
		if (IS_UNSUPPORTED_CODER(f->Coders[1]) ||
			IS_UNSUPPORTED_CODER(f->Coders[2]) ||
			IS_NO_BCJ2(f->Coders[3]))
			return SZ_ERROR_UNSUPPORTED;
		if (f->NumPackStreams != 4 ||
			f->PackStreams[0] != 2 ||
			f->PackStreams[1] != 6 ||
			f->PackStreams[2] != 1 ||
			f->PackStreams[3] != 0 ||
			f->NumBindPairs != 3 ||
			f->BindPairs[0].InIndex != 5 || f->BindPairs[0].OutIndex != 0 ||
			f->BindPairs[1].InIndex != 4 || f->BindPairs[1].OutIndex != 1 ||
			f->BindPairs[2].InIndex != 3 || f->BindPairs[2].OutIndex != 2)
			return SZ_ERROR_UNSUPPORTED;
		return SZ_OK;
	}
	return SZ_ERROR_UNSUPPORTED;
}

UInt64 GetSum(const UInt64 *values, UInt32 index) {
	UInt64 sum = 0;
	UInt32 i;
	for (i = 0; i < index; i++)
		sum += values[i];
	return sum;
}

int SzDecode2(const UInt64 *packSizes, const CSzFolder *folder,
			   CLookToRead *inStream, UInt64 startPos,
			   Byte *outBuffer, size_t outSize, Byte *tempBuf[]) {
	UInt32 ci;
	size_t tempSizes[3] = { 0, 0, 0};
	size_t tempSize3 = 0;
	Byte *tempBuf3 = 0;
	
	RINOK(CheckSupportedFolder(folder));
	
	for (ci = 0; ci < folder->NumCoders; ci++) {
		CSzCoderInfo *coder = &folder->Coders[ci];
		
		if (coder->MethodID == k_Copy || coder->MethodID == k_LZMA) {
			UInt32 si = 0;
			UInt64 offset;
			UInt64 inSize;
			Byte *outBufCur = outBuffer;
			size_t outSizeCur = outSize;
			if (folder->NumCoders == 4) {
				UInt32 indices[] = { 3, 2, 0 };
				UInt64 unpackSize = folder->UnpackSizes[ci];
				si = indices[ci];
				if (ci < 2) {
					Byte *temp;
					outSizeCur = (size_t)unpackSize;
					if (outSizeCur != unpackSize) {
						return SZ_ERROR_MEM;
					}
					temp = (Byte *)malloc(outSizeCur);
					if (temp == 0 && outSizeCur != 0) {
						return SZ_ERROR_MEM;
					}
					outBufCur = tempBuf[1 - ci] = temp;
					tempSizes[1 - ci] = outSizeCur;
				} else if (ci == 2) {
					if (unpackSize > outSize) { /* check it */
						return SZ_ERROR_PARAM;
					}
					tempBuf3 = outBufCur = outBuffer + (outSize - (size_t)unpackSize);
					tempSize3 = outSizeCur = (size_t)unpackSize;
				} else {
					return SZ_ERROR_UNSUPPORTED;
				}
			}
			offset = GetSum(packSizes, si);
			inSize = packSizes[si];
			RINOK(LookInStream_SeekTo(inStream, startPos + offset));
			
			if (coder->MethodID == k_Copy) {
				if (inSize != outSizeCur) /* check it */
					return SZ_ERROR_DATA;
				RINOK(SzDecodeCopy(inSize, inStream, outBufCur));
			}
			else
			{
				RINOK(SzDecodeLzma(coder, inSize, inStream, outBufCur, outSizeCur));
			}
		}
		else if (coder->MethodID == k_BCJ) {
			UInt32 state;
			if (ci != 1) {
				return SZ_ERROR_UNSUPPORTED;
			}
			x86_Convert_Init(state);
			x86_Convert(outBuffer, outSize, &state);
		}
		else if (coder->MethodID == k_BCJ2) {
			UInt64 offset = GetSum(packSizes, 1);
			UInt64 s3Size = packSizes[1];
			int res;
			if (ci != 3) {
				return SZ_ERROR_UNSUPPORTED;
			}
			RINOK(LookInStream_SeekTo(inStream, startPos + offset));
			tempSizes[2] = (size_t)s3Size;
			if (tempSizes[2] != s3Size) {
				return SZ_ERROR_MEM;
			}
			tempBuf[2] = (Byte *)malloc(tempSizes[2]);
			if (tempBuf[2] == 0 && tempSizes[2] != 0) {
				return SZ_ERROR_MEM;
			}
			res = SzDecodeCopy(s3Size, inStream, tempBuf[2]);
			RINOK(res)
			
			res = Bcj2_Decode(tempBuf3, tempSize3,
							  tempBuf[0], tempSizes[0],
							  tempBuf[1], tempSizes[1],
							  tempBuf[2], tempSizes[2],
							  outBuffer, outSize);
			RINOK(res)
		}
		else
			return SZ_ERROR_UNSUPPORTED;
	}
	return SZ_OK;
}

int SzDecode(const UInt64 *packSizes, const CSzFolder *folder,
			  CLookToRead *inStream, UInt64 startPos,
			  Byte *outBuffer, size_t outSize) {
	Byte *tempBuf[3] = { 0, 0, 0};
	int i;
	int res = SzDecode2(packSizes, folder, inStream, startPos,
						 outBuffer, (size_t)outSize, tempBuf);
	for (i = 0; i < 3; i++)
		free(tempBuf[i]);
	return res;
}
