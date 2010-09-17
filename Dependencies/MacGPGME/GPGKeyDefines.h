//
//  GPGKeyDefines.h
//  MacGPGME
//
//  Created by Robert Goldsmith (r.s.goldsmith@far-blue.co.uk) on Sat July 9 2005.
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

#ifndef GPGKEYDEFINES_H
#define GPGKEYDEFINES_H
 
#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif


/*!
 *  @typedef    GPGValidity
 *  @abstract   The GPGValidity type is used to specify the validity of a
 *              <i>user ID</i> in a key, or for a
 *              <code>@link //macgpg/occ/cl/GPGTrustItem GPGTrustItem@/link</code>
 *              object.
 *  @discussion Don't assume that higher value means higher validity; this might
 *              change in the future.
 *  @constant   GPGValidityUnknown    The <i>user ID</i> is of unknown validity
 *                                    [?].
 *  @constant   GPGValidityUndefined  No value assigned. The validity of the
 *                                    <i>user ID</i> is undefined [q].
 *  @constant   GPGValidityNever      The <i>user ID</i> is never valid [n].
 *  @constant   GPGValidityMarginal   The <i>user ID</i> is marginally valid
 *                                    [m].
 *  @constant   GPGValidityFull       The <i>user ID</i> is fully valid [f].
 *  @constant   GPGValidityUltimate   The <i>user ID</i> is ultimately valid
 *                                    [u]. 
 *                                    Only used for keys for which the secret
 *                                    key is also available.
 */
typedef enum {
    GPGValidityUnknown   = 0,
    GPGValidityUndefined = 1,
    GPGValidityNever     = 2,
    GPGValidityMarginal  = 3,
    GPGValidityFull      = 4,
    GPGValidityUltimate  = 5
} GPGValidity;


/*!
 *  @group      Algorithm numerical values (taken from OpenPGP, RFC2440)
 */

/*!
 *  @typedef    GPGPublicKeyAlgorithm
 *  @abstract   Public key algorithms.
 *  @discussion Public key algorithms are used for encryption, decryption, 
 *              signing and verification of signatures. You can convert the 
 *              numerical values to strings with <code>@link //macgpg/c/func/GPGPublicKeyAlgorithmDescription GPGPublicKeyAlgorithmDescription@/link</code>
 *              and <code>@link //macgpg/c/func/GPGLocalizedPublicKeyAlgorithmDescription GPGLocalizedPublicKeyAlgorithmDescription@/link</code>
 *              for printing.
 *  @constant   GPG_RSAAlgorithm                RSA (Rivest, Shamir, Adleman) 
 *                                              algorithm.
 *  @constant   GPG_RSAEncryptOnlyAlgorithm     Deprecated. RSA (Rivest, Shamir,
 *                                              Adleman) algorithm for
 *                                              encryption and decryption only
 *                                              (aka RSA-E).
 *  @constant   GPG_RSASignOnlyAlgorithm        Deprecated. RSA (Rivest, Shamir,
 *                                              Adleman) algorithm for signing
 *                                              and verification only (aka 
 *                                              RSA-S).
 *  @constant   GPG_ElgamalEncryptOnlyAlgorithm Elgamal (aka Elgamal-E); used
 *                                              specifically in GnuPG.
 *  @constant   GPG_DSAAlgorithm                Digital Signature Algorithm.
 *  @constant   GPG_EllipticCurveAlgorithm      Elliptic Curve Algorithm.
 *  @constant   GPG_ECDSAAlgorithm              ECDSA Algorithm.
 *  @constant   GPG_ElgamalAlgorithm            Elgamal.
 *  @constant   GPG_DiffieHellmanAlgorithm      Encrypt or Sign.
 */
typedef enum {
    GPG_RSAAlgorithm                =  1,
    GPG_RSAEncryptOnlyAlgorithm     =  2,
    GPG_RSASignOnlyAlgorithm        =  3,
    GPG_ElgamalEncryptOnlyAlgorithm = 16,
    GPG_DSAAlgorithm                = 17,
    GPG_EllipticCurveAlgorithm      = 18,
    GPG_ECDSAAlgorithm              = 19,
    GPG_ElgamalAlgorithm            = 20,
    GPG_DiffieHellmanAlgorithm      = 21
}GPGPublicKeyAlgorithm;


/*!
 *  @typedef    GPGSymmetricKeyAlgorithm
 *  @abstract   Symmetric key algorithms
 *  @constant   GPG_NoAlgorithm          Unencrypted data.
 *  @constant   GPG_IDEAAlgorithm        [IDEA].
 *  @constant   GPG_TripleDESAlgorithm   [3DES] aka 3DES or DES-EDE - 168 bit 
 *                                       key derived from 192.
 *  @constant   GPG_CAST5Algorithm       [CAST5] 128 bit key.
 *  @constant   GPG_BlowfishAlgorithm    [BLOWFISH] 128 bit key, 16 rounds.
 *  @constant   GPG_SAFER_SK128Algorithm 13 rounds.
 *  @constant   GPG_DES_SKAlgorithm      (no description)
 *  @constant   GPG_AES128Algorithm      [AES] aka Rijndael.
 *  @constant   GPG_AES192Algorithm      aka Rijndael 192.
 *  @constant   GPG_AES256Algorithm      aka Rijndael 256.
 *  @constant   GPG_TwoFishAlgorithm     [TWOFISH] twofish 256 bit.
 *  @constant   GPG_SkipjackAlgorithm    Experimental: skipjack.
 *  @constant   GPG_TwoFish_OldAlgorithm Experimental: twofish 128 bit.
 *  @constant   GPG_DummyAlgorithm       No encryption at all.
 */
typedef enum {
    GPG_NoAlgorithm          =   0,
    GPG_IDEAAlgorithm        =   1,
    GPG_TripleDESAlgorithm   =   2,
    GPG_CAST5Algorithm       =   3,
    GPG_BlowfishAlgorithm    =   4,
    GPG_SAFER_SK128Algorithm =   5,
    GPG_DES_SKAlgorithm      =   6,
    GPG_AES128Algorithm      =   7,
    GPG_AES192Algorithm      =   8,
    GPG_AES256Algorithm      =   9,
    GPG_TwoFishAlgorithm     =  10,
    GPG_SkipjackAlgorithm    = 101,
    GPG_TwoFish_OldAlgorithm = 102,
    GPG_DummyAlgorithm       = 110
}GPGSymmetricKeyAlgorithm;


/*!
 *  @typedef    GPGHashAlgorithm
 *  @abstract   Hash algorithms 
 *  @constant   GPG_NoHashAlgorithm             No hash
 *  @constant   GPG_MD5HashAlgorithm            (no description)
 *  @constant   GPG_SHA_1HashAlgorithm          [SHA1].
 *  @constant   GPG_RIPE_MD160HashAlgorithm     [RIPEMD160]
 *  @constant   GPG_DoubleWidthSHAHashAlgorithm (no description)
 *  @constant   GPG_MD2HashAlgorithm            (no description)
 *  @constant   GPG_TIGER192HashAlgorithm       (no description)
 *  @constant   GPG_HAVALHashAlgorithm          5 pass, 160 bit.
 *  @constant   GPG_SHA256HashAlgorithm         (no description)
 *  @constant   GPG_SHA384HashAlgorithm         (no description)
 *  @constant   GPG_SHA512HashAlgorithm         (no description)
 *  @constant   GPG_MD4HashAlgorithm            (no description)
 *  @constant   GPG_CRC32HashAlgorithm          (no description)
 *  @constant   GPG_CRC32RFC1510HashAlgorithm   (no description)
 *  @constant   GPG_CRC24RFC2440HashAlgorithm   (no description)
 */
typedef enum {
    GPG_NoHashAlgorithm             =   0,
    GPG_MD5HashAlgorithm            =   1,
    GPG_SHA_1HashAlgorithm          =   2,
    GPG_RIPE_MD160HashAlgorithm     =   3,
    GPG_DoubleWidthSHAHashAlgorithm =   4,
    GPG_MD2HashAlgorithm            =   5,
    GPG_TIGER192HashAlgorithm       =   6,
    GPG_HAVALHashAlgorithm          =   7,
    GPG_SHA256HashAlgorithm         =   8,
    GPG_SHA384HashAlgorithm         =   9,
    GPG_SHA512HashAlgorithm         =  10,
    GPG_MD4HashAlgorithm            = 301,
    GPG_CRC32HashAlgorithm          = 302,
    GPG_CRC32RFC1510HashAlgorithm   = 303,
    GPG_CRC24RFC2440HashAlgorithm   = 304
}GPGHashAlgorithm;


/*!
 *  @typedef    GPGCompressionAlgorithm
 *  @abstract   Compression algorithms
 *  @constant   GPG_NoCompressionAlgorithm   No compression.
 *  @constant   GPG_ZIPCompressionAlgorithm  [ZIP] Old zlib version (RFC1951) 
 *                                           which is used by PGP&reg;.
 *  @constant   GPG_ZLIBCompressionAlgorithm [ZLIB] Default algorithm (RFC1950).
 */
typedef enum {
    GPG_NoCompressionAlgorithm   = 0,
    GPG_ZIPCompressionAlgorithm  = 1,
    GPG_ZLIBCompressionAlgorithm = 2
}GPGCompressionAlgorithm;



#ifdef __cplusplus
}
#endif
#endif /* GPGKEYDEFINES_H */
