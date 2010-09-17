//
//  GPGSubkey.h
//  MacGPGME
//
//  Created by davelopper at users.sourceforge.net on Sun Jun 08 2003.
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

#ifndef GPGSUBKEY_H
#define GPGSUBKEY_H

#include <MacGPGME/GPGKey.h>

#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif


/*!
 *  @class      GPGSubkey
 *  @abstract   <p><i>Subkeys</i> are one component of a key.</p>
 *  @discussion <p><i>Subkeys</i> are one component of a key. In fact, subkeys are
 *              those parts that contains the real information about the 
 *              individual cryptographic keys that belong to the same key
 *              object. One <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code>
 *              can contain several <i>subkeys</i>. The first <i>subkey</i> in  
 *              the list returned by <code>@link subkeys subkeys@/link</code> is
 *              also called the <i>primary key</i>. It is guaranteed that the
 *              owning <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code>
 *              object will never be deallocated before the GPGSubkey has been
 *              deallocated, without creating non-breakable retain-cycles.
 *
 *              GPGSubkey objects do not support all methods from
 *              <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code>; 
 *              use only the listed ones, else a <code>@link //apple_ref/c/data/NSInternalInconsistencyException NSInternalInconsistencyException@/link</code>
 *              exception will be raised.
 *
 *              The following convenience methods, though not listed, are 
 *              supported: 
 *              <code>@link //macgpg/occ/instm/GPGKey/algorithmDescription algorithmDescription@/link</code> (GPGKey),
 *              <code>@link //macgpg/occ/instm/GPGKey/shortKeyID shortKeyID@/link</code> (GPGKey),
 *              <code>@link //macgpg/occ/instm/GPGKey/formattedFingerprint formattedFingerprint@/link</code> (GPGKey).
 *
 *              GPGSubkey objects are immutable objects.</p>
 */
@interface GPGSubkey : GPGKey
{
    GPGKey	*_key; // Key owning the subkey; not retained
    int		_refCount;
}

/*!
 *  @method     key
 *  @abstract   Returns parent key.
 *  @discussion Never returns nil.
 */
- (GPGKey *) key;

/*!
 *  @method     isKeyRevoked
 *  @abstract   Returns whether <i>subkey</i> is revoked.
 */
- (BOOL) isKeyRevoked;

/*!
 *  @method     isKeyInvalid
 *  @abstract   Returns whether <i>subkey</i> is invalid.
 */
- (BOOL) isKeyInvalid;

/*!
 *  @method     hasKeyExpired
 *  @abstract   Returns whether <i>subkey</i> is expired.
 *  @discussion It doesn't compare to current date. Information is computed only
 *              once when key is retrieved.
 */
- (BOOL) hasKeyExpired;

/*!
 *  @method     isKeyDisabled
 *  @abstract   Returns whether <i>subkey</i> is disabled.
 */
- (BOOL) isKeyDisabled;

/*!
 *  @method     isSecret
 *  @abstract   Returns whether the <i>subkey</i> is secret. Note that it will
 *              return <code>NO</code> if the key is actually a <i>stub key</i>;
 *              i.e. a secret key operation is currently not possible
 *              (offline-key).
 */
- (BOOL) isSecret;

/*!
 *  @method     algorithm
 *  @abstract   Returns <i>subkey algorithm</i>.
 *  @discussion The algorithm is the crypto algorithm for which the
 *              <i>subkey</i> can be used. The value corresponds to the 
 *              <code>@link //macgpg/c/tdef/GPGPublicKeyAlgorithm GPGPublicKeyAlgorithm@/link</code> 
 *              enum values.
 */
- (GPGPublicKeyAlgorithm) algorithm;

/*!
 *  @method     length
 *  @abstract   Returns <i>subkey</i> length, in bits.
 *  @seealso    //macgpg/occ/instm/GPGKey/algorithmDescription algorithmDescription (GPGKey)
 */
- (unsigned int) length;

/*!
 *  @method     keyID
 *  @abstract   Returns <i>subkey key ID</i> in hexadecimal digits.
 *  @discussion Always returns 16 hexadecimal digits, e.g. <code>8CED0ABE0A124C58</code>.
 *  @seealso    //macgpg/occ/instm/GPGKey/shortKeyID shortKeyID (GPGKey)
 */
- (NSString *) keyID;

/*!
 *  @method     fingerprint
 *  @abstract   Returns <i>subkey fingerprint</i> in hexadecimal digits, if 
 *              available.
 *  @discussion String can be made of 32 or 40 hexadecimal digits, e.g.
 *              <code>87B0AAC7A09B57D98CED0ABE0A124C58</code>.
 *  @seealso    //macgpg/occ/instm/GPGKey/formattedFingerprint formattedFingerprint (GPGKey)
 */
- (NSString *) fingerprint;

/*!
 *  @method     creationDate
 *  @abstract   Returns <i>subkey</i> creation date.
 *  @discussion Returns nil when creation date is not available or invalid.
 */
- (NSCalendarDate *) creationDate;

/*!
 *  @method     expirationDate
 *  @abstract   Returns <i>subkey</i> expiration date.
 *  @discussion Returns nil when there is no expiration date set or date is not
 *              available or is invalid.
 */
- (NSCalendarDate *) expirationDate;


/*!
 * @methodgroup Global <i>subkey</i> capabilities
 */

/*!
 *  @method     canEncrypt
 *  @abstract   Returns whether the <i>subkey</i> can be used for encryption.
 */
- (BOOL) canEncrypt;

/*!
 *  @method     canSign
 *  @abstract   Returns whether the <i>subkey</i> can be used to create data 
 *              signatures.
 */
- (BOOL) canSign;

/*!
 *  @method     canCertify
 *  @abstract   Returns whether the <i>subkey</i> can be used to create key 
 *              certificates.
 */
- (BOOL) canCertify;

/*!
 *  @method     canAuthenticate
 *  @abstract   Returns whether the <i>subkey</i> can be used for 
 *              authentication.
 */
- (BOOL) canAuthenticate;

@end

#ifdef __cplusplus
}
#endif
#endif /* GPGSUBKEY_H */
