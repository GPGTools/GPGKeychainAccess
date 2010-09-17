//
//  GPGExceptions.h
//  MacGPGME
//
//  Created by davelopper at users.sourceforge.net on Tue Aug 14 2001.
//
//
//  Copyright (C) 2001-2006 Mac GPG Project.
//  
//  This code is free software; you can redistribute it and/or modify it under
//  the terms of the GNU Lesser General Public License as published by the Free
//  Software Foundation; either version 2.1 of the License, or (at your option)
//  any later version.
//  
//  This code is distributed in the hope that it will be useful, but WITHOUT ANY
//  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
//  FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
//  details.
//  
//  You should have received a copy of the GNU Lesser General Public License
//  along with this program; if not, visit <http://www.gnu.org/> or write to the
//  Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, 
//  MA 02111-1307, USA.
//  
//  More info at <http://macgpg.sourceforge.net/>
//

#ifndef GPGEXCEPTIONS_H
#define GPGEXCEPTIONS_H

#include <Foundation/Foundation.h>
#include <MacGPGME/GPGDefines.h>

#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif


@class NSString;


/*!
 *  @typedef    GPGErrorCode
 *  @abstract   Indicates the code of a <code>@link GPGError GPGError@/link</code>.
 *  @discussion The GPGErrorCode type indicates the type of an error, or the
 *              reason why an operation failed. The most important ones are
 *              described here.
 *  @constant   GPGErrorEOF                  This value indicates the end of a
 *                                           list, buffer or file.
 *  @constant   GPGErrorNoError              This value indicates success. The
 *                                           value of this error code is 0.
 *                                           Also, it is guaranteed that an
 *                                           error value made from the error
 *                                           code 0 will be 0 itself (as a
 *                                           whole). This means that the error
 *                                           source information is lost for this
 *                                           error code, however, as this error
 *                                           code indicates that no error
 *                                           occured, this is generally not a
 *                                           problem. No <code>@link GPGException GPGException@/link</code>
 *                                           exception is raised with this
 *                                           value.
 *  @constant   GPGErrorGeneralError         This value means that something
 *                                           went wrong, but either there is not
 *                                           enough information about the
 *                                           problem to return a more useful
 *                                           error value, or there is no 
 *                                           separate error value for this type
 *                                           of problem.
 *  @constant   GPGError_ENOMEM              This value means that an
 *                                           out-of-memory condition occurred.
 *  @constant   GPGError_EBUSY               This value means that the
 *                                           underlying process is already busy
 *                                           performing another operation.
 *  @constant   GPGError_E*                  System errors are mapped to
 *                                           <code>GPGError_<i>EFOO</i></code> 
 *                                           where <i>EFOO</i> is the symbol
 *                                           for the system error, e.g. 
 *                                           <code>@link GPGError_ENOMEM GPGError_ENOMEM@/link</code>
 *                                           corresponds to system error
 *                                           <code>ENOMEM</code>.
 *  @constant   GPGErrorInvalidValue         This value means that some user
 *                                           provided data was out of range.
 *                                           This can also refer to objects. For
 *                                           example, if an empty <code>@link //macgpg/occ/cl/GPGData GPGData@/link</code>
 *                                           object was expected, but one
 *                                           containing data was provided, this
 *                                           error value is returned.
 *  @constant   GPGErrorUnusablePublicKey    This value means that some
 *                                           recipients for a message were
 *                                           invalid.
 *  @constant   GPGErrorUnusableSecretKey    This value means that some signers
 *                                           were invalid.
 *  @constant   GPGErrorNoData               This value means that a <code>@link //macgpg/occ/cl/GPGData GPGData@/link</code>
 *                                           object which was expected to have
 *                                           content was found empty.
 *  @constant   GPGErrorConflict             This value means that a conflict of
 *                                           some sort occurred.
 *  @constant   GPGErrorNotImplemented       This value indicates that the
 *                                           specific function (or operation) is
 *                                           not implemented. This error should
 *                                           never happen. It can only occur if
 *                                           you use certain values or
 *                                           configuration options which do not
 *                                           work, but for which we think that
 *                                           they should work at some later
 *                                           time.
 *  @constant   GPGErrorDecryptionFailed     This value indicates that a
 *                                           decryption operation was
 *                                           unsuccessful.
 *  @constant   GPGErrorBadPassphrase        This value means that the user did
 *                                           not provide a correct passphrase
 *                                           when requested.
 *  @constant   GPGErrorCancelled            This value means that the operation
 *                                           was cancelled by user.
 *  @constant   GPGErrorInvalidEngine        This value means that the engine
 *                                           that implements the desired
 *                                           protocol is currently not
 *                                           available. This can either be 
 *                                           because the sources were configured 
 *                                           to exclude support for this engine,
 *                                           or because the engine is not
 *                                           installed properly.
 *  @constant   GPGErrorAmbiguousName        This value indicates that a user ID
 *                                           or other specifier did not specify
 *                                           a unique key.
 *  @constant   GPGErrorWrongKeyUsage        This value indicates that a key is
 *                                           not used appropriately.
 *  @constant   GPGErrorCertificateRevoked   This value indicates that a key
 *                                           signature was revoked.
 *  @constant   GPGErrorCertificateExpired   This value indicates that a key
 *                                           signature expired.
 *  @constant   GPGErrorNoCRLKnown           This value indicates that no
 *                                           certificate revocation list is
 *                                           known for the certificate.
 *  @constant   GPGErrorNoPolicyMatch        This value indicates that a policy
 *                                           issue occured.
 *  @constant   GPGErrorNoSecretKey          This value indicates that no secret
 *                                           key for the user ID is available.
 *  @constant   GPGErrorInvalidPassphrase    The passphrase is invalid, for
 *                                           example if it is in ISOLatin1
 *                                           although UTF-8 is expected.
 *  @constant   GPGErrorMissingCertificate   This value indicates that a key
 *                                           could not be imported because the
 *                                           issuer certificate is missing.
 *  @constant   GPGErrorBadCertificateChain  This value indicates that a key
 *                                           could not be imported because its
 *                                           certificate chain is not good, for
 *                                           example it could be too long.
 *  @constant   GPGErrorUnsupportedAlgorithm This value means a verification
 *                                           failed because the cryptographic
 *                                           algorithm is not supported by the
 *                                           crypto back-end.
 *  @constant   GPGErrorBadSignature         This value means a verification
 *                                           failed because the signature is
 *                                           bad.
 *  @constant   GPGErrorNoPublicKey          This value means a verification
 *                                           failed because the public key is
 *                                           not available.
 *  @constant   GPGErrorKeyServerError       This value means a problem occured
 *                                           when trying to discuss or
 *                                           discussing with a key server.
 *  @constant   GPGErrorTruncatedKeyListing  This value means the crypto 
 *                                           back-end had to truncate the result
 *                                           of a key listing operation. Result 
 *                                           is incomplete.
 *  @constant   GPGErrorNotSupported         This value means that the operation
 *                                           is not supported.
 *  @constant   GPGErrorUser2&nbsp;-&nbsp;GPGErrorUser16
 *                                           These error codes are not used by
 *                                           any GnuPG component and can be
 *                                           freely used by other software.
 *                                           Applications using MacGPGME might
 *                                           use them to mark specific errors
 *                                           returned by callback handlers if no
 *                                           suitable error codes (including the
 *                                           system errors) for these errors
 *                                           exist already.
 */
typedef enum {
    GPGErrorNoError                      =     0,
    GPGErrorGeneralError                 =     1,
    GPGErrorUnknownPacket                =     2,
    GPGErrorUnknownVersion               =     3,
    GPGErrorInvalidPublicKeyAlgorithm    =     4,
    GPGErrorInvalidDigestAlgorithm       =     5,
    GPGErrorBadPublicKey                 =     6,
    GPGErrorBadSecretKey                 =     7,
    GPGErrorBadSignature                 =     8,
    GPGErrorNoPublicKey                  =     9,
    GPGErrorChecksumError                =    10,
    GPGErrorBadPassphrase                =    11,
    GPGErrorInvalidCipherAlgorithm       =    12,
    GPGErrorOpenKeyring                  =    13,
    GPGErrorInvalidPacket                =    14,
    GPGErrorInvalidArmor                 =    15,
    GPGErrorNoUserID                     =    16,
    GPGErrorNoSecretKey                  =    17,
    GPGErrorWrongSecretKey               =    18,
    GPGErrorBadSessionKey                =    19,
    GPGErrorUnknownCompressionAlgorithm  =    20,
    GPGErrorNoPrime                      =    21,
    GPGErrorNoEncodingMethod             =    22,
    GPGErrorNoEncryptionScheme           =    23,
    GPGErrorNoSignatureScheme            =    24,
    GPGErrorInvalidAttribute             =    25,
    GPGErrorNoValue                      =    26,
    GPGErrorNotFound                     =    27,
    GPGErrorValueNotFound                =    28,
    GPGErrorSyntax                       =    29,
    GPGErrorBadMPI                       =    30,
    GPGErrorInvalidPassphrase            =    31,
    GPGErrorSignatureClass               =    32,
    GPGErrorResourceLimit                =    33,
    GPGErrorInvalidKeyring               =    34,
    GPGErrorTrustDBError                 =    35,
    GPGErrorBadCertificate               =    36,
    GPGErrorInvalidUserID                =    37,
    GPGErrorUnexpected                   =    38,
    GPGErrorTimeConflict                 =    39,
    GPGErrorKeyServerError               =    40,
    GPGErrorWrongPublicKeyAlgorithm      =    41,
    GPGErrorTributeToDA                  =    42,
    GPGErrorWeakKey                      =    43,
    GPGErrorInvalidKeyLength             =    44,
    GPGErrorInvalidArgument              =    45,
    GPGErrorBadURI                       =    46,
    GPGErrorInvalidURI                   =    47,
    GPGErrorNetworkError                 =    48,
    GPGErrorUnknownHost                  =    49,
    GPGErrorSelfTestFailed               =    50,
    GPGErrorNotEncrypted                 =    51,
    GPGErrorNotProcessed                 =    52,
    GPGErrorUnusablePublicKey            =    53,
    GPGErrorUnusableSecretKey            =    54,
    GPGErrorInvalidValue                 =    55,
    GPGErrorBadCertificateChain          =    56,
    GPGErrorMissingCertificate           =    57,
    GPGErrorNoData                       =    58,
    GPGErrorBug                          =    59,
    GPGErrorNotSupported                 =    60,
    GPGErrorInvalidOperationCode         =    61,
    GPGErrorTimeout                      =    62,
    GPGErrorInternalError                =    63,
    GPGErrorEOFInGCrypt                  =    64,
    GPGErrorInvalidObject                =    65,
    GPGErrorObjectTooShort               =    66,
    GPGErrorObjectTooLarge               =    67,
    GPGErrorNoObject                     =    68,
    GPGErrorNotImplemented               =    69,
    GPGErrorConflict                     =    70,
    GPGErrorInvalidCipherMode            =    71,
    GPGErrorInvalidFlag                  =    72,
    GPGErrorInvalidHandle                =    73,
    GPGErrorTruncatedResult              =    74,
    GPGErrorIncompleteLine               =    75,
    GPGErrorInvalidResponse              =    76,
    GPGErrorNoAgent                      =    77,
    GPGErrorAgentError                   =    78,
    GPGErrorInvalidData                  =    79,
    GPGErrorAssuanServerFault            =    80,
    GPGErrorAssuanError                  =    81,
    GPGErrorInvalidSessionKey            =    82,
    GPGErrorInvalidSEXP                  =    83,
    GPGErrorUnsupportedAlgorithm         =    84,
    GPGErrorNoPINEntry                   =    85,
    GPGErrorPINEntryError                =    86,
    GPGErrorBadPIN                       =    87,
    GPGErrorInvalidName                  =    88,
    GPGErrorBadData                      =    89,
    GPGErrorInvalidParameter             =    90,
    GPGErrorWrongCard                    =    91, 
    GPGErrorNoDirManager                 =    92,
    GPGErrorDirManagerError              =    93,
    GPGErrorCertificateRevoked           =    94,
    GPGErrorNoCRLKnown                   =    95,
    GPGErrorCRLTooOld                    =    96,
    GPGErrorLineTooLong                  =    97,
    GPGErrorNotTrusted                   =    98,    
    GPGErrorCancelled                    =    99,
    GPGErrorBadCACertificate             =   100,
    GPGErrorCertificateExpired           =   101,
    GPGErrorCertificateTooYoung          =   102,
    GPGErrorUnsupportedCertificate       =   103,
    GPGErrorUnknownSEXP                  =   104,
    GPGErrorUnsupportedProtection        =   105,
    GPGErrorCorruptedProtection          =   106,
    GPGErrorAmbiguousName                =   107,
    GPGErrorCardError                    =   108,
    GPGErrorCardReset                    =   109,
    GPGErrorCardRemoved                  =   110,
    GPGErrorInvalidCard                  =   111,
    GPGErrorCardNotPresent               =   112,
    GPGErrorNoPKCS15Application          =   113,
    GPGErrorNotConfirmed                 =   114,
    GPGErrorConfigurationError           =   115,
    GPGErrorNoPolicyMatch                =   116,
    GPGErrorInvalidIndex                 =   117,
    GPGErrorInvalidID                    =   118,
    GPGErrorNoSCDaemon                   =   119,
    GPGErrorSCDaemonError                =   120,
    GPGErrorUnsupportedProtocol          =   121,
    GPGErrorBadPINMethod                 =   122,
    GPGErrorCardNotInitialized           =   123,
    GPGErrorUnsupportedOperation         =   124,
    GPGErrorWrongKeyUsage                =   125,
    GPGErrorNothingFound                 =   126,
    GPGErrorWrongBLOBType                =   127,
    GPGErrorMissingValue                 =   128,
    GPGErrorHardware                     =   129,
    GPGErrorPINBlocked                   =   130,
    GPGErrorUseConditions                =   131,
    GPGErrorPINNotSynced                 =   132,
    GPGErrorInvalidCRL                   =   133,
    GPGErrorBadBER                       =   134,
    GPGErrorInvalidBER                   =   135,
    GPGErrorElementNotFound              =   136,
    GPGErrorIdentifierNotFound           =   137,
    GPGErrorInvalidTag                   =   138,
    GPGErrorInvalidLength                =   139,
    GPGErrorInvalidKeyInfo               =   140,
    GPGErrorUnexpectedTag                =   141,
    GPGErrorNotDEREncoded                =   142,
    GPGErrorNoCMSObject                  =   143,
    GPGErrorInvalidCMSObject             =   144,
    GPGErrorUnknownCMSObject             =   145,
    GPGErrorUnsupportedCMSObject         =   146,
    GPGErrorUnsupportedEncoding          =   147,
    GPGErrorUnsupportedCMSVersion        =   148,
    GPGErrorUnknownAlgorithm             =   149,    
    GPGErrorInvalidEngine                =   150,
    GPGErrorPublicKeyNotTrusted          =   151,
    GPGErrorDecryptionFailed             =   152,
    GPGErrorKeyExpired                   =   153,
    GPGErrorSignatureExpired             =   154,
    GPGErrorEncodingProblem              =   155,
    GPGErrorInvalidState                 =   156,
    GPGErrorDuplicateValue               =   157,
    GPGErrorMissingAction                =   158,
    GPGErrorModuleNotFound               =   159,
    GPGErrorInvalidOIDString             =   160,
    GPGErrorInvalidTime                  =   161,
    GPGErrorInvalidCRLObject             =   162,
    GPGErrorUnsupportedCRLVersion        =   163,
    GPGErrorInvalidCertObject            =   164,
    GPGErrorUnknownName                  =   165,
    GPGErrorLocaleProblem                =   166,
    GPGErrorNotLocked                    =   167,
    GPGErrorProtocolViolation            =   168,
    GPGErrorInvalidMac                   =   169,
    GPGErrorInvalidRequest               =   170,

    GPGErrorBufferTooShort               =   200,
    GPGErrorSEXPInvalidLengthSpec        =   201,
    GPGErrorSEXPStringTooLong            =   202,
    GPGErrorSEXPUnmatchedParenthese      =   203,
    GPGErrorSEXPNotCanonical             =   204,
    GPGErrorSEXPBadCharacter             =   205,
    GPGErrorSEXPBadQuotation             =   206,
    GPGErrorSEXPZeroPrefix               =   207,
    GPGErrorSEXPNestedDisplayHint        =   208,
    GPGErrorSEXPUnmatchedDisplayHint     =   209,
    GPGErrorSEXPUnexpectedPunctuation    =   210,
    GPGErrorSEXPBadHexCharacter          =   211,
    GPGErrorSEXPOddHexNumbers            =   212,
    GPGErrorSEXPBadOctalCharacter        =   213,

    GPGErrorTruncatedKeyListing          =  1024,
    GPGErrorUser2                        =  1025,
    GPGErrorUser3                        =  1026,
    GPGErrorUser4                        =  1027,
    GPGErrorUser5                        =  1028,
    GPGErrorUser6                        =  1029,
    GPGErrorUser7                        =  1030,
    GPGErrorUser8                        =  1031,
    GPGErrorUser9                        =  1032,
    GPGErrorUser10                       =  1033,
    GPGErrorUser11                       =  1034,
    GPGErrorUser12                       =  1035,
    GPGErrorUser13                       =  1036,
    GPGErrorUser14                       =  1037,
    GPGErrorUser15                       =  1038,
    GPGErrorUser16                       =  1039,

    GPGErrorMissingErrno                 = 16381,
    GPGErrorUnknownErrno                 = 16382,
    GPGErrorEOF                          = 16383,

    /* The following error codes are used to map system errors.  */
    GPGError_E2BIG                       = 16384,
    GPGError_EACCES                      = 16385,
    GPGError_EADDRINUSE                  = 16386,
    GPGError_EADDRNOTAVAIL               = 16387,
    GPGError_EADV                        = 16388,
    GPGError_EAFNOSUPPORT                = 16389,
    GPGError_EAGAIN                      = 16390,
    GPGError_EALREADY                    = 16391,
    GPGError_EAUTH                       = 16392,
    GPGError_EBACKGROUND                 = 16393,
    GPGError_EBADE                       = 16394,
    GPGError_EBADF                       = 16395,
    GPGError_EBADFD                      = 16396,
    GPGError_EBADMSG                     = 16397,
    GPGError_EBADR                       = 16398,
    GPGError_EBADRPC                     = 16399,
    GPGError_EBADRQC                     = 16400,
    GPGError_EBADSLT                     = 16401,
    GPGError_EBFONT                      = 16402,
    GPGError_EBUSY                       = 16403,
    GPGError_ECANCELLED                  = 16404,
    GPGError_ECHILD                      = 16405,
    GPGError_ECHRNG                      = 16406,
    GPGError_ECOMM                       = 16407,
    GPGError_ECONNABORTED                = 16408,
    GPGError_ECONNREFUSED                = 16409,
    GPGError_ECONNRESET                  = 16410,
    GPGError_ED                          = 16411,
    GPGError_EDEADLK                     = 16412,
    GPGError_EDEADLOCK                   = 16413,
    GPGError_EDESTADDRREQ                = 16414,
    GPGError_EDIED                       = 16415,
    GPGError_EDOM                        = 16416,
    GPGError_EDOTDOT                     = 16417,
    GPGError_EDQUOT                      = 16418,
    GPGError_EEXIST                      = 16419,
    GPGError_EFAULT                      = 16420,
    GPGError_EFBIG                       = 16421,
    GPGError_EFTYPE                      = 16422,
    GPGError_EGRATUITOUS                 = 16423,
    GPGError_EGREGIOUS                   = 16424,
    GPGError_EHOSTDOWN                   = 16425,
    GPGError_EHOSTUNREACH                = 16426,
    GPGError_EIDRM                       = 16427,
    GPGError_EIEIO                       = 16428,
    GPGError_EILSEQ                      = 16429,
    GPGError_EINPROGRESS                 = 16430,
    GPGError_EINTR                       = 16431,
    GPGError_EINVAL                      = 16432,
    GPGError_EIO                         = 16433,
    GPGError_EISCONN                     = 16434,
    GPGError_EISDIR                      = 16435,
    GPGError_EISNAM                      = 16436,
    GPGError_EL2HLT                      = 16437,
    GPGError_EL2NSYNC                    = 16438,
    GPGError_EL3HLT                      = 16439,
    GPGError_EL3RST                      = 16440,
    GPGError_ELIBACC                     = 16441,
    GPGError_ELIBBAD                     = 16442,
    GPGError_ELIBEXEC                    = 16443,
    GPGError_ELIBMAX                     = 16444,
    GPGError_ELIBSCN                     = 16445,
    GPGError_ELNRNG                      = 16446,
    GPGError_ELOOP                       = 16447,
    GPGError_EMEDIUMTYPE                 = 16448,
    GPGError_EMFILE                      = 16449,
    GPGError_EMLINK                      = 16450,
    GPGError_EMSGSIZE                    = 16451,
    GPGError_EMULTIHOP                   = 16452,
    GPGError_ENAMETOOLONG                = 16453,
    GPGError_ENAVAIL                     = 16454,
    GPGError_ENEEDAUTH                   = 16455,
    GPGError_ENETDOWN                    = 16456,
    GPGError_ENETRESET                   = 16457,
    GPGError_ENETUNREACH                 = 16458,
    GPGError_ENFILE                      = 16459,
    GPGError_ENOANO                      = 16460,
    GPGError_ENOBUFS                     = 16461,
    GPGError_ENOCSI                      = 16462,
    GPGError_ENODATA                     = 16463,
    GPGError_ENODEV                      = 16464,
    GPGError_ENOENT                      = 16465,
    GPGError_ENOEXEC                     = 16466,
    GPGError_ENOLCK                      = 16467,
    GPGError_ENOLINK                     = 16468,
    GPGError_ENOMEDIUM                   = 16469,
    GPGError_ENOMEM                      = 16470,
    GPGError_ENOMSG                      = 16471,
    GPGError_ENONET                      = 16472,
    GPGError_ENOPKG                      = 16473,
    GPGError_ENOPROTOOPT                 = 16474,
    GPGError_ENOSPC                      = 16475,
    GPGError_ENOSR                       = 16476,
    GPGError_ENOSTR                      = 16477,
    GPGError_ENOSYS                      = 16478,
    GPGError_ENOTBLK                     = 16479,
    GPGError_ENOTCONN                    = 16480,
    GPGError_ENOTDIR                     = 16481,
    GPGError_ENOTEMPTY                   = 16482,
    GPGError_ENOTNAM                     = 16483,
    GPGError_ENOTSOCK                    = 16484,
    GPGError_ENOTSUP                     = 16485,
    GPGError_ENOTTY                      = 16486,
    GPGError_ENOTUNIQ                    = 16487,
    GPGError_ENXIO                       = 16488,
    GPGError_EOPNOTSUPP                  = 16489,
    GPGError_EOVERFLOW                   = 16490,
    GPGError_EPERM                       = 16491,
    GPGError_EPFNOSUPPORT                = 16492,
    GPGError_EPIPE                       = 16493,
    GPGError_EPROCLIM                    = 16494,
    GPGError_EPROCUNAVAIL                = 16495,
    GPGError_EPROGMISMATCH               = 16496,
    GPGError_EPROGUNAVAIL                = 16497,
    GPGError_EPROTO                      = 16498,
    GPGError_EPROTONOSUPPORT             = 16499,
    GPGError_EPROTOTYPE                  = 16500,
    GPGError_ERANGE                      = 16501,
    GPGError_EREMCHG                     = 16502,
    GPGError_EREMOTE                     = 16503,
    GPGError_EREMOTEIO                   = 16504,
    GPGError_ERESTART                    = 16505,
    GPGError_EROFS                       = 16506,
    GPGError_ERPCMISMATCH                = 16507,
    GPGError_ESHUTDOWN                   = 16508,
    GPGError_ESOCKTNOSUPPORT             = 16509,
    GPGError_ESPIPE                      = 16510,
    GPGError_ESRCH                       = 16511,
    GPGError_ESRMNT                      = 16512,
    GPGError_ESTALE                      = 16513,
    GPGError_ESTRPIPE                    = 16514,
    GPGError_ETIME                       = 16515,
    GPGError_ETIMEDOUT                   = 16516,
    GPGError_ETOOMANYREFS                = 16517,
    GPGError_ETXTBSY                     = 16518,
    GPGError_EUCLEAN                     = 16519,
    GPGError_EUNATCH                     = 16520,
    GPGError_EUSERS                      = 16521,
    GPGError_EWOULDBLOCK                 = 16522,
    GPGError_EXDEV                       = 16523,
    GPGError_EXFULL                      = 16524,

    /* This is one more than the largest allowed entry.  */
    GPGError_CODE_DIM                    = 65536
} GPGErrorCode;


/*!
 *  @typedef    GPGErrorSource
 *  @abstract   Defines the source of an error/exception.
 *  @discussion The GPGErrorSource type defines the different sources of 
 *              errors/exceptions used in MacGPGME. The error source has not a
 *              precisely defined meaning. Sometimes it is the place where the
 *              error happened, sometimes it is the place where an error was
 *              encoded into an error value. Usually the error source will give
 *              an indication to where to look for the problem. This is not
 *              always true, but it is attempted to achieve this goal.
 *
 *              Any other value smaller than 256 can be used for your own 
 *              purpose.
 *  @constant   GPG_UnknownErrorSource           Unknown error source.
 *  @constant   GPG_GCryptErrorSource            Error comes from C library 
 *                                               <i>gcrypt</i>, which is used by
 *                                               crypto engines to perform
 *                                               cryptographic operations.
 *  @constant   GPG_GPGErrorSource               Error comes from <i>GnuPG</i>,
 *                                               which is the crypto engine used
 *                                               for the OpenPGP protocol.
 *  @constant   GPG_GPGSMErrorSource             Error comes from <i>GPGSM</i>,
 *                                               which is the crypto engine used
 *                                               for the CMS protocol.
 *  @constant   GPG_GPGAgentErrorSource          Error comes from
 *                                               <i>gpg-agent</i>, which is used
 *                                               by crypto engines to perform 
 *                                               operations with the secret key.
 *  @constant   GPG_PINEntryErrorSource          Error comes from
 *                                               <i>pinentry</i>, which is used
 *                                               by <i>gpg-agent</i> to query
 *                                               the passphrase to unlock a
 *                                               secret key.
 *  @constant   GPG_SCDErrorSource               Error comes from the 
 *                                               <i>SmartCard Daemon</i>, which
 *                                               is used by <i>gpg-agent</i> to
 *                                               delegate operations with the
 *                                               secret key to a
 *                                               <i>SmartCard</i>.
 *  @constant   GPG_GPGMELibErrorSource          Error comes from C library
 *                                               <i>gpgme</i>.
 *  @constant   GPG_KeyBoxErrorSource            Error comes from <i>libkbx</i>,
 *                                               a library used by the crypto
 *                                               engines to manage local
 *                                               <i>key rings</i>.
 *  @constant   GPG_KSBAErrorSource              Error comes from C library
 *                                               <i>libksba</i>.
 *  @constant   GPG_DirMngrErrorSource           Error comes from
 *                                               <i>DirMngr</i>.
 *  @constant   GPG_GSTIErrorSource              Error comes from <i>GSTI</i>.
 *  @constant   GPG_MacGPGMEFrameworkErrorSource Error comes from 
 *                                               <i>MacGPGME</i> framework.
 *  @constant   GPG_User2ErrorSource             (reserved)
 *  @constant   GPG_User3ErrorSource             (reserved)
 *  @constant   GPG_User4ErrorSource             (reserved)
 */
typedef enum {
    GPG_UnknownErrorSource            =  0,
    GPG_GCryptErrorSource             =  1,
    GPG_GPGErrorSource                =  2,
    GPG_GPGSMErrorSource              =  3,
    GPG_GPGAgentErrorSource           =  4,
    GPG_PINEntryErrorSource           =  5,
    GPG_SCDErrorSource                =  6,
    GPG_GPGMELibErrorSource           =  7,
    GPG_KeyBoxErrorSource             =  8,
    GPG_KSBAErrorSource               =  9,
    GPG_DirMngrErrorSource            = 10,
    GPG_GSTIErrorSource               = 11,
    GPG_MacGPGMEFrameworkErrorSource  = 32,
    GPG_User2ErrorSource              = 33,
    GPG_User3ErrorSource              = 34,
    GPG_User4ErrorSource              = 35
}GPGErrorSource;


/*!
 *  @typedef    GPGError
 *  @abstract   Indicates the type of an error or of a
 *              <code>@link GPGException GPGException@/link</code> exception. 
 *              Composed of an error code and an error source.
 *  @discussion An error value like this has always two components, an error 
 *              code and an error source. Both together form the error value.
 *
 *              Thus, the error value can not be directly compared against an 
 *              error code, but the accessor functions <code>@link GPGErrorSourceFromError GPGErrorSourceFromError@/link</code>
 *              and <code>@link GPGErrorCodeFromError GPGErrorCodeFromError@/link</code>
 *              must be used. However, it is guaranteed that only 0 is used to
 *              indicate success (<code>@link GPGErrorNoError GPGErrorNoError@/link</code>),
 *              and that in this case all other parts of the error value are set
 *              to 0, too.
 *
 *              Note that in MacGPGME, the error source is used purely for
 *              diagnostical purposes. Only the error code should be checked to
 *              test for a certain outcome of a function. The manual only
 *              documents the error code part of an error value. The error
 *              source is left unspecified and might be anything.
 */
typedef unsigned int	GPGError;

/*!
 *  @function   GPGErrorDescription
 *  @abstract   Returns the localized description of an error.
 *  @discussion This string can be used to output a diagnostic message to the 
 *              user.
 *  @param      error The error
 */
GPG_EXPORT NSString	*GPGErrorDescription(GPGError error);


/*!
 *  @function   GPGErrorSourceDescription
 *  @abstract   Returns the localized name of an error source.
 *  @discussion This string can be used to output a diagnostic message to the 
 *              user.
 *  @param      errorSource The error source
 */
GPG_EXPORT NSString *GPGErrorSourceDescription(GPGErrorSource errorSource);

/*!
 *  @function   GPGErrorCodeFromError
 *  @abstract   Returns the code component of an error.
 *  @discussion This function must be used to extract the error code of
 *              <i>err</i> in order to compare it with the
 *              <code>GPGError*</code> error code values.
 *  @param      err The error
 */
GPG_EXPORT GPGErrorCode GPGErrorCodeFromError(GPGError err);

/*!
 *  @function   GPGErrorSourceFromError
 *  @abstract   Returns the source component of an error.
 *  @discussion This function must be used to extract the error source of
 *              <i>err</i> in order to compare it with the
 *              <code>GPG_*Source</code> error source values.
 *  @param      err The error
 */
GPG_EXPORT GPGErrorSource GPGErrorSourceFromError(GPGError err);

/*!
 *  @function   GPGMakeError
 *  @abstract   Returns the error value consisting of an error source and an 
 *              error code.
 *  @discussion This function can be used in callback methods to construct an 
 *              error value to return it to the framework.
 *  @param      src The error source
 *  @param      cde The error code
 */
GPG_EXPORT GPGError GPGMakeError(GPGErrorSource src, GPGErrorCode cde);

/*!
 *  @function   GPGMakeErrorFromErrno
 *  @abstract   Returns the error value consisting of an error source and a 
 *              system error.
 *  @discussion The function GPGMakeErrorFromErrno is like
 *              <code>@link GPGMakeError GPGMakeError@/link</code>, 
 *              but it takes a system error like <code>errno</code> instead of a
 *              <code>@link //macgpg/c/tdef/GPGErrorCode GPGErrorCode@/link</code>
 *              error code.
 *  @param      src The error source
 *  @param      cde The system error code
 */
GPG_EXPORT GPGError GPGMakeErrorFromErrno(GPGErrorSource src, int cde);

/*!
 *  @function   GPGMakeErrorFromSystemError
 *  @abstract   Returns the error value consisting of the default error source
 *              and the latest system error (<code>errno</code>).
 *  @discussion Retrieves the error code directly from the <code>errno</code>
 *              variable. This returns <code>GPGErrorUnknownErrno</code> as 
 *              error code if the system error is not mapped and 
 *              <code>GPGErrorMissingErrno</code> if <code>errno</code> has the
 *              value 0.
 */
GPG_EXPORT GPGError GPGMakeErrorFromSystemError();

/*!
 *  @constant   GPGException
 *  @abstract   Name of exceptions specific to MacGPGME framework.
 *  @discussion A GPGException exception can be raised by nearly any MacGPGME
 *              call.
 *
 *              Its <i>reason</i> contains the localized description of
 *              <code>@link GPGError GPGError@/link</code>.
 *
 *              Its <i>userInfo</i> dictionary can contain the following keys:
 *              <dl>
 *              <dt><code>@link GPGErrorKey GPGErrorKey@/link</code></dt>
 *              <dd>A <code>@link //apple_ref/occ/cl/NSNumber NSNumber@/link</code>
 *              containing a <code>@link GPGError GPGError@/link</code> value.</dd>
 *              <dt><code>@link //macgpg/c/data/GPGContextKey GPGContextKey@/link</code></dt>
 *              <dd>The <code>@link //macgpg/occ/cl/GPGContext GPGContext@/link</code>
 *               object which terminated with an error; used by 
 *               <code>@link //macgpg/occ/clm/GPGContext(GPGAsynchronousOperations)/waitOnAnyRequest: waitOnAnyRequest:@/link</code>
 *               (GPGContext) and for errors on asynchronous operations.</dd>
 *              <dt><code>@link GPGAdditionalReasonKey GPGAdditionalReasonKey@/link</code></dt>
 *              <dd>An additional unlocalized error message; optional.</dd></dl>
 */
GPG_EXPORT NSString	* const GPGException;

/*!
 *  @constant   GPGErrorKey
 *  @abstract   Key of a <i>userInfo</i> entry in a <code>@link GPGException GPGException@/link</code>
 *              exception; value is a <code>@link //apple_ref/occ/cl/NSNumber NSNumber@/link</code>
 *              wrapping a <code>@link GPGError GPGError@/link</code>.
 */
GPG_EXPORT NSString	* const GPGErrorKey;

/*!
 *  @constant   GPGAdditionalReasonKey
 *  @abstract   Key of a <i>userInfo</i> entry in a <code>@link GPGException GPGException@/link</code>
 *              exception; value is a <code>@link //apple_ref/occ/cl/NSString NSString@/link</code>
 *              containing an additional unlocalized error message.
 */
GPG_EXPORT NSString * const	GPGAdditionalReasonKey;


/*!
 *  @category   NSException(GPGExceptions)
 *  @abstract   Additions by MacGPGME framework to <code>@link //apple_ref/occ/cl/NSException NSException@/link</code>.
 */
@interface NSException(GPGExceptions)
/*!
 *  @method     exceptionWithGPGError:userInfo:
 *  @abstract   Returns a new <code>@link GPGException GPGException@/link</code> exception.
 *  @discussion Returns a new <code>@link //apple_ref/occ/cl/NSException NSException@/link</code>
 *              object with <i>name</i> <code>@link GPGException GPGException@/link</code>,
 *              <i>reason</i> defined as <code>@link GPGErrorDescription GPGErrorDescription(error)@/link</code>,
 *              and <i>userInfo</i> dictionary filled with <code>@link GPGErrorKey GPGErrorKey@/link</code>
 *              = error and additional <i>userInfo</i>.
 *
 *              Used internally by the MacGPGME framework, and can be used by
 *              delegates.
 *  @param      error A <code>@link GPGError GPGError@/link</code> error
 *  @param      additionalUserInfo Additional <i>userInfo</i> entries, or nil
 */
+ (NSException *) exceptionWithGPGError:(GPGError)error userInfo:(NSDictionary *)additionalUserInfo;
@end

#ifdef __cplusplus
}
#endif
#endif /* GPGEXCEPTIONS_H */
