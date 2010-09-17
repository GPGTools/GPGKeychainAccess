//
//  GPGKeySignature.h
//  MacGPGME
//
//  Created by davelopper at users.sourceforge.net on Thu Dec 26 2002.
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

#ifndef GPGKEYSIGNATURE_H
#define GPGKEYSIGNATURE_H

#include <MacGPGME/GPGSignature.h>

#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif


@class GPGUserID;


/*!
 *  @class      GPGKeySignature
 *  @abstract   <p><i>Key signatures</i> are one component of a 
 *              <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code> object,
 *              and validate user IDs on the key.</p>
 *  @discussion <p><i>Key signatures</i> are one component of a
 *              <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code> object,
 *              and validate user IDs on the key.
 *
 *              The signatures on a key are only available if the key was 
 *              retrieved via a listing operation with the <code>@link //macgpg/c/econst/GPGKeyListModeSignatures GPGKeyListModeSignatures@/link</code>
 *              mode enabled, because it is expensive to retrieve all signatures
 *              of a key.
 *
 *              The signature notations on a key signature are only available if
 *              the key was retrieved via a listing operation with the
 *              <code>@link //macgpg/c/econst/GPGKeyListModeSignatureNotations GPGKeyListModeSignatureNotations@/link</code>
 *              mode enabled, because it can be expensive to retrieve all
 *              signature notations.
 *
 *              GPGKeySignature objects are returned by 
 *              <code>@link //macgpg/occ/instm/GPGUserID/signatures signatures@/link</code>
 *              (GPGUserID); you should never need to instantiate yourself
 *              objects of that class. It is guaranteed that the owning 
 *              <code>@link //macgpg/occ/cl/GPGUserID GPGUserID@/link</code>
 *              object will never be deallocated before the GPGKeySignature
 *              object has been deallocated, without creating non-breakable
 *              retain-cycles.
 *
 *              An object represents a signature on a <i>user ID</i> of a 
 *              <i>key</i>.
 *
 *              Key signatures raise a <code>@link //apple_ref/c/data/NSInternalInconsistencyException NSInternalInconsistencyException@/link</code>
 *              when methods <code>@link //macgpg/occ/instm/GPGSignature/fingerprint fingerprint@/link</code>,
 *              <code>@link //macgpg/occ/instm/GPGSignature/summary summary@/link</code>,
 *              <code>@link //macgpg/occ/instm/GPGSignature/validity validity@/link</code>,
 *              <code>@link //macgpg/occ/instm/GPGSignature/validityError validityError@/link</code>, 
 *              <code>@link //macgpg/occ/instm/GPGSignature/wrongKeyUsage wrongKeyUsage@/link</code>,
 *              <code>@link //macgpg/occ/instm/GPGSignature/validityDescription validityDescription@/link</code>,
 *              <code>@link //macgpg/occ/instm/GPGSignature/hashAlgorithm hashAlgorithm@/link</code>,
 *              <code>@link //macgpg/occ/instm/GPGSignature/hashAlgorithmDescription hashAlgorithmDescription@/link</code>
 *              are invoked.</p>
 */
@interface GPGKeySignature : GPGSignature
{
    BOOL		_isRevocationSignature;
    BOOL		_hasSignatureExpired;
    BOOL		_isSignatureInvalid;
    BOOL		_isExportable;
    NSString	*_signerKeyID;
    NSString	*_userID;
    NSString	*_name;
    NSString	*_email;
    NSString	*_comment;
    GPGUserID	*_signedUserID; // Signed userID; not retained
    int			_refCount;
}

/*!
 *  @method     signerKeyID
 *  @abstract   Returns the <i>key ID</i> of the signer's <i>key</i>.
 */
- (NSString *) signerKeyID;

/*!
 *  @method     userID
 *  @abstract   Returns the main <i>user ID</i> of the signer's <i>key</i>.
 */
- (NSString *) userID;

/*!
 *  @method     name
 *  @abstract   Returns the name on the signer's <i>key</i>.
 *  @discussion Returns the name on the signer's <i>key</i>, if available. Taken
 *              from the main <i>user ID</i> of the signer's <i>key</i>.
 */
- (NSString *) name;

/*!
 *  @method     email
 *  @abstract   Returns the email address on the signer's <i>key</i>.
 *  @discussion Returns the email address on the signer's <i>key</i>, if 
 *              available. Taken from the main <i>user ID</i> of the signer's
 *              <i>key</i>.
 */
- (NSString *) email;

/*!
 *  @method     comment
 *  @abstract   Returns the comment on the signer's <i>key</i>.
 *  @discussion Returns the comment on the signer's <i>key</i>, if available. 
 *              Taken from the main <i>user ID</i> of the signer's <i>key</i>.
 */
- (NSString *) comment;

/*!
 *  @method     creationDate
 *  @abstract   Returns <i>signature</i> creation date.
 *  @discussion Returns nil when not available or invalid.
 */
- (NSCalendarDate *) creationDate;

/*!
 *  @method     expirationDate
 *  @abstract   Returns <i>signature</i> expiration date.
 *  @discussion Returns nil when not available or invalid.
 */
- (NSCalendarDate *) expirationDate;

/*!
 *  @method     isRevocationSignature
 *  @abstract   Returns whether the signature is a revocation signature or not.
 */
- (BOOL) isRevocationSignature;

/*!
 *  @method     hasSignatureExpired
 *  @abstract   Returns whether <i>signature</i> has expired or not.
 */
- (BOOL) hasSignatureExpired;

/*!
 *  @method     isSignatureInvalid
 *  @abstract   Returns whether <i>signature</i> is invalid or not.
 */
- (BOOL) isSignatureInvalid;

/*!
 *  @method     isExportable
 *  @abstract   Returns whether <i>signature</i> is exportable or not (locally
 *              signed).
 */
- (BOOL) isExportable;

/*!
 *  @method     status
 *  @abstract   Returns <i>signature</i> status.
 *  @discussion In particular, the following status codes are of interest:<dl>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorNoError GPGErrorNoError@/link</code></dt>
 *              <dd>This status indicates that the signature is valid.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorSignatureExpired GPGErrorSignatureExpired@/link</code></dt>
 *              <dd>This status indicates that the signature is valid but
 *               expired.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorKeyExpired GPGErrorKeyExpired@/link</code></dt>
 *              <dd>This status indicates that the signature is valid but the
 *               key used to verify the signature has expired.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorBadSignature GPGErrorBadSignature@/link</code></dt>
 *              <dd>This status indicates that the signature is invalid.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorNoPublicKey GPGErrorNoPublicKey@/link</code></dt>
 *              <dd>This status indicates that the signature could not be
 *               verified due to a missing key.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorGeneralError GPGErrorGeneralError@/link</code></dt>
 *              <dd>This status indicates that there was some other error which
 *               prevented the signature verification.</dd></dl>
 */
- (GPGError) status;

/*!
 *  @method     signedUserID
 *  @abstract   Returns the <code>@link //macgpg/occ/cl/GPGUserID GPGUserID@/link</code>
 *              signed by this signature.
 */
- (GPGUserID *) signedUserID;

@end

#ifdef __cplusplus
}
#endif
#endif /* GPGKEYSIGNATURE_H */
