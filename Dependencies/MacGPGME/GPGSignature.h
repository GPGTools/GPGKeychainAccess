//
//  GPGSignature.h
//  MacGPGME
//
//  Created by davelopper at users.sourceforge.net on Sun Jul 14 2002.
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

#ifndef GPGSIGNATURE_H
#define GPGSIGNATURE_H

#include <MacGPGME/GPGObject.h>
#include <MacGPGME/GPGKey.h>

#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif


/*!
 *  @typedef    GPGSignatureSummaryMask
 *  @abstract   Mask values returned by <code>@link summary summary@/link</code> 
 *              (GPGSignature).
 *  @constant   GPGSignatureSummaryValidMask The signature is fully valid.
 *  @constant   GPGSignatureSummaryGreenMask The signature is good but one might
 *                                           want to display some extra
 *                                           information. Check the other bits.
 *  @constant   GPGSignatureSummaryRedMask The signature is bad. It might be
 *                                         useful to check other bits and
 *                                         display more information, i.e. a
 *                                         revoked certificate might not render
 *                                         a signature invalid when the message
 *                                         was received prior to the cause for
 *                                         the revocation.
 *  @constant   GPGSignatureSummaryKeyRevokedMask The key or at least one
 *                                                certificate has been revoked.
 *  @constant   GPGSignatureSummaryKeyExpiredMask The key or one of the
 *                                                certificates has expired. It
 *                                                is probably a good idea to
 *                                                display the date of the 
 *                                                expiration.
 *  @constant   GPGSignatureSummarySignatureExpiredMask The signature has 
 *                                                      expired.
 *  @constant   GPGSignatureSummaryKeyMissingMask Can't verify due to a missing
 *                                                key or certificate.
 *  @constant   GPGSignatureSummaryCRLMissingMask The CRL (or an equivalent
 *                                            mechanism) is not available.
 *  @constant   GPGSignatureSummaryCRLTooOldMask Available CRL is too old.
 *  @constant   GPGSignatureSummaryBadPolicyMask A policy requirement was not
 *                                               met.
 *  @constant   GPGSignatureSummarySystemErrorMask A system error occured.
 */
typedef enum {
    GPGSignatureSummaryValidMask            = 0x0001,
    GPGSignatureSummaryGreenMask            = 0x0002,
    GPGSignatureSummaryRedMask              = 0x0004,
    GPGSignatureSummaryKeyRevokedMask       = 0x0010,
    GPGSignatureSummaryKeyExpiredMask       = 0x0020,
    GPGSignatureSummarySignatureExpiredMask = 0x0040,
    GPGSignatureSummaryKeyMissingMask       = 0x0080,
    GPGSignatureSummaryCRLMissingMask       = 0x0100,
    GPGSignatureSummaryCRLTooOldMask        = 0x0200,
    GPGSignatureSummaryBadPolicyMask        = 0x0400,
    GPGSignatureSummarySystemErrorMask      = 0x0800
}GPGSignatureSummaryMask;


/*!
 *  @typedef    GPGPKATrust
 *  @abstract   Trust information gained by means of the PKA system.
 *  @discussion Depending on the configuration of the engine, this metric may
 *              also be reflected by the validity of the signature.
 *  @constant   GPGPKATrustUnavailable No PKA information available or 
 *                                     verification not possible.
 *  @constant   GPGPKATrustBad         PKA verification failed.
 *  @constant   GPGPKATrustOK          PKA verification succeeded.
 *  @constant   GPGPKATrustRFU         <i>Reserved for future use.</i>
 *  @seealso    GPGSignature
 */
typedef enum {
    GPGPKATrustUnavailable = 0,
    GPGPKATrustBad         = 1,
    GPGPKATrustOK          = 2,
    GPGPKATrustRFU         = 3,
}GPGPKATrust;


/*!
 *  @class      GPGSignature 
 *  @abstract   Represents a data signature (not a key signature - see 
 *              <code>@link //macgpg/occ/cl/GPGKeySignature GPGKeySignature@/link</code>
 *              for that).
 *  @discussion GPGSignature objects are returned by
 *              <code>@link //macgpg/occ/instm/GPGContext(GPGSynchronousOperations)/signatures signatures@/link</code>
 *              (GPGContext); you should never need to instantiate yourself
 *              objects of that class. Signatures are also returned after a 
 *              signing operation, but in this case, currently, not all
 *              attributes have significant values: you can count only on
 *              <code>@link //macgpg/occ/instm/GPGSignature/algorithm algorithm@/link</code>,
 *              <code>@link hashAlgorithm hashAlgorithm@/link</code>, 
 *              <code>@link signatureClass signatureClass@/link</code>,
 *              <code>@link //macgpg/occ/instm/GPGSignature/creationDate creationDate@/link</code>
 *              and <code>@link //macgpg/occ/instm/GPGSignature/fingerprint fingerprint@/link</code>.
 */
@interface GPGSignature : NSObject <NSCopying>
{
    NSString				*_fingerprint;
    NSCalendarDate			*_creationDate;
    NSCalendarDate			*_expirationDate;
    GPGValidity				_validity;
    GPGError				_status;
    GPGSignatureSummaryMask	_summary;
    NSDictionary			*_notations;
    NSArray					*_policyURLs;
    GPGError				_validityError;
    BOOL					_wrongKeyUsage;
    GPGPublicKeyAlgorithm	_algorithm;
    GPGHashAlgorithm		_hashAlgorithm;
    unsigned int			_signatureClass;
    NSArray                 *_signatureNotations;
    GPGPKATrust             _pkaTrust;
    NSString                *_pkaAddress;
}

/*!
 *  @method     copyWithZone:
 *  @abstract   Implementation of <code>@link //apple_ref/occ/intf/NSCopying NSCopying@/link</code> 
 *              protocol. Returns itself, retained.
 *  @discussion GPGSignature objects are (currently) immutable.
 *  @param      zone Memory zone (unused).
 */
- (id) copyWithZone:(NSZone *)zone;


/*!
 *  @methodgroup Attributes
 */

/*!
 *  @method     fingerprint
 *  @abstract   Returns signer's key <i>fingerprint</i> or <i>key ID</i>.
 *  @discussion Never returns nil.
 */
- (NSString *) fingerprint;

/*!
 *  @method     creationDate
 *  @abstract   Returns <i>signature</i> creation date.
 *  @discussion Returns nil when not available or invalid.
 */
- (NSCalendarDate *) creationDate;

/*!
 *  @method     expirationDate
 *  @abstract   Returns <i>signature</i> expiration date.
 *  @discussion Returns nil if signature does not expire.
 *
 *              Not used for new signatures.
 */
- (NSCalendarDate *) expirationDate;

/*!
 *  @method     validity
 *  @abstract   Returns <i>signature</i>'s validity.
 *  @discussion Not used for new signatures.
 *
 *              Note that a signature's validity is never <code>@link //macgpg/c/econst/GPGValidityUltimate GPGValidityUltimate@/link</code>,
 *              because <code>@link //macgpg/c/econst/GPGValidityUltimate GPGValidityUltimate@/link</code>
 *              is reserved for key certification, not for signatures.
 */
- (GPGValidity) validity;

/*!
 *  @method     status
 *  @abstract   Returns <i>signature</i> status.
 *  @discussion In particular, the following status codes are of interest:<dl>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorNoError GPGErrorNoError@/link</code></dt>
 *              <dd>This status indicates that the signature is valid. For the
 *               combined result this status means that all signatures are
 *               valid.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorSignatureExpired GPGErrorSignatureExpired@/link</code></dt>
 *              <dd>This status indicates that the signature is valid but
 *               expired. For the combined result this status means that all
 *               signatures are valid and expired.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorKeyExpired GPGErrorKeyExpired@/link</code></dt>
 *              <dd>This status indicates that the signature is valid but the
 *               key used to verify the signature has expired. For the combined
 *               result this status means that all signatures are valid and all
 *               keys are expired.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorCertificateRevoked GPGErrorCertificateRevoked@/link</code></dt>
 *              <dd>This status indicates that the signature is valid but the
 *               key used  to verify the signature has been revoked. For the
 *               combined result this status means that all signatures are valid
 *               and all keys are revoked.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorBadSignature GPGErrorBadSignature@/link</code></dt>
 *              <dd>This status indicates that the signature is invalid. For the
 *               combined result this status means that all signatures are
 *               invalid.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorNoPublicKey GPGErrorNoPublicKey@/link</code></dt>
 *              <dd>This status indicates that the signature could not be
 *               verified due to a missing key. For the combined result this
 *               status means that all signatures could not be checked due to
 *               missing keys.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorGeneralError GPGErrorGeneralError@/link</code></dt>
 *              <dd>This status indicates that there was some other error which
 *               prevented the signature verification.</dd></dl>
 *              Not used for new signatures.
 */
- (GPGError) status;

/*!
 *  @method     summary
 *  @abstract   Returns a mask giving a summary of the signature status.
 *  @discussion Not used for new signatures.
 */
- (GPGSignatureSummaryMask) summary;

/*!
 *  @method     algorithm
 *  @abstract   Returns the public key algorithm used to create the signature.
 */
- (GPGPublicKeyAlgorithm) algorithm;

/*!
 *  @method     hashAlgorithm
 *  @abstract   Returns the hash algorithm used for the signature.
 */
- (GPGHashAlgorithm) hashAlgorithm;

/*!
 *  @method     signatureClass
 *  @abstract   Returns the signature class of a <i>key signature</i> or a new 
 *              signature.
 *  @discussion The meaning is specific to the crypto engine.
 *
 *              This attribute is not (yet?) available for signatures returned
 *              after a verification operation.
 */
- (unsigned int) signatureClass;

/*!
 *  @method     pkaTrust
 *  @abstract   Returns the PKA status.
 */
- (GPGPKATrust) pkaTrust;

/*!
 *  @method     pkaAddress
 *  @abstract   Returns the mailbox from the PKA information, or 
 *              <code>nil</code>.
 */
- (NSString *) pkaAddress;

/*!
 *  @methodgroup Notations
 */

/*!
 *  @method     signatureNotations
 *  @abstract   Returns all signature notations (notation data and policy URLs).
 *  @discussion Never returns nil.
 */
- (NSArray *) signatureNotations;


/*!
 *  @methodgroup Misc
 */

/*!
 *  @method     validityError
 *  @abstract   Returns error explaining why a signature is invalid.
 *  @discussion If a signature is not valid, this provides a reason why.
 *
 *              Not used for new signatures.
 */
- (GPGError) validityError;

/*!
 *  @method     wrongKeyUsage
 *  @abstract   Returns <code>YES</code> if the key was not used according to
 *              its policy.
 *  @discussion Not used for new signatures.
 */
- (BOOL) wrongKeyUsage;


/*!
 *  @methodgroup Convenience methods
 */

/*!
 *  @method     validityDescription
 *  @abstract   Returns <i>signature</i>'s validity in localized human readable
 *              form.
 *  @discussion Not used for new signatures.
 */
- (NSString *) validityDescription;

/*!
 *  @method     algorithmDescription
 *  @abstract   Returns the localized description of the public key algorithm 
 *              used to create the signature.
 */
- (NSString *) algorithmDescription;

/*!
 *  @method     hashAlgorithmDescription
 *  @abstract   Returns the localized description of the hash algorithm used for
 *              the signature.
 */
- (NSString *) hashAlgorithmDescription;

/*!
 *  @method     formattedFingerprint
 *  @abstract   Returns signer's key formatted fingerprint or key ID.
 *  @discussion If <code>@link //macgpg/occ/instm/GPGSignature/fingerprint fingerprint@/link</code> returns a 
 *              <i>fingerprint</i>, returns <i>fingerprint</i> in hex digit
 *              form, formatted like this:
 *
 *              <tt>XXXX XXXX XXXX XXXX XXXX  XXXX XXXX XXXX XXXX XXXX</tt>
 *
 *              or
 *
 *              <tt>XX XX XX XX XX XX XX XX  XX XX XX XX XX XX XX XX</tt>.
 *
 *              If <code>@link //macgpg/occ/instm/GPGSignature/fingerprint fingerprint@/link</code> returns a 
 *              <i>key ID</i>, returns <i>key ID</i> with 32 or 40 hexadecimal 
 *              digits, prefixed by <code>0x</code>.
 */
- (NSString *) formattedFingerprint;

@end

/*!
 *  @category   GPGSignature(GPGSignatureDeprecated)
 *  @abstract   Deprecated methods
 */
@interface GPGSignature(GPGSignatureDeprecated)

/*!
 *  @method     notations
 *  @abstract   Returns a dictionary of <i>notation data</i> key-value pairs.
 *  @discussion Returns a dictionary of <i>notation data</i> key-value pairs. A 
 *              notation is a key/value pair that is added to the content, it 
 *              can be anything. Value is returned as an 
 *              <code>@link //apple_ref/occ/cl/NSString NSString@/link</code>
 *              object.
 *
 *              Not used for new signatures.
 *  @deprecated in version 1.1
 *  @see        //macgpg/occ/instm/GPGSignature/signatureNotations signatureNotations
 */
- (NSDictionary *) notations; 

/*!
 *  @method     policyURLs
 *  @abstract   Returns an array of <i>policy URLs</i> as 
 *              <code>@link //apple_ref/occ/cl/NSString NSString@/link</code>
 *              objects.
 *  @discussion Returns an array of <i>policy URLs</i> as
 *              <code>@link //apple_ref/occ/cl/NSString NSString@/link</code> 
 *              objects. A policy URL is an URL to a document that documents 
 *              the persons policy in signing other people's keys.
 *
 *              Not used for new signatures.
 *  @deprecated in version 1.1
 *  @see        //macgpg/occ/instm/GPGSignature/signatureNotations signatureNotations
 */
- (NSArray *) policyURLs;

@end

#ifdef __cplusplus
}
#endif
#endif /* GPGSIGNATURE_H */
