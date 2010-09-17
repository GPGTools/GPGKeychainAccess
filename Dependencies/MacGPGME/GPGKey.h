//
//  GPGKey.h
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

#ifndef GPGKEY_H
#define GPGKEY_H

#include <MacGPGME/GPGObject.h>
#include <MacGPGME/GPGEngine.h>
#include <MacGPGME/GPGContext.h>
#include <MacGPGME/GPGKeyDefines.h>

#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif


@class NSArray;
@class NSCalendarDate;
@class NSData;
@class NSDictionary;
@class NSEnumerator;
@class NSString;


/*!
 *  @class      GPGKey 
 *  @abstract   Represents a public or secret key.
 *  @discussion Some of the cryptographic operations require that
 *              <i>recipients</i> or <i>signers</i> are specified. This is
 *              always done by specifying the respective <i>keys</i> that
 *              should be used for the operation.
 *
 *              A GPGKey object represents a <i>public</i> or <i>secret key</i>,
 *              but NOT both!
 *
 *              A <i>key</i> can contain several <i>user IDs</i> and
 *              <i>subkeys</i>.
 *
 *              GPGKey objects are usually returned by
 *              <code>@link //macgpg/occ/instm/GPGContext(GPGKeyManagement)/keyEnumeratorForSearchPatterns:secretKeysOnly: keyEnumeratorForSearchPatterns:secretKeysOnly:@/link</code> (GPGContext),
 *              <code>@link //macgpg/occ/instm/GPGContext(GPGSynchronousOperations)/keyFromFingerprint:secretKey: keyFromFingerprint:secretKey:@/link</code> (GPGContext);
 *              you should never need to instantiate objects of that class.
 *
 *              Two GPGKey objects are considered equal (in MacGPGME) if they
 *              have the same <i>fingerprint</i>, and are both secret or public.
 *              GPGKey objects are (currently) immutable objects.
 */
@interface GPGKey : GPGObject <NSCopying>
{
    NSArray	*_subkeys; // Array containing GPGSubkey objects
    NSArray	*_userIDs; // Array containing GPGUserID objects
    NSData	*_photoData;
    BOOL	_checkedPhotoData;
}

/*!
 *  @method     hash
 *  @abstract   Returns hash value based on <i>fingerprint</i>.
 */
- (unsigned) hash;

/*!
 *  @method     isEqual:
 *  @abstract   Returns <code>YES</code> if both the receiver and <i>anObject</i>
 *              have the same <i>fingerprint</i>, are both subclasses of GPGKey,
 *              and are both public or secret keys.
 *  @param      anObject An object to compare to
 */
- (BOOL) isEqual:(id)anObject;

/*!
 *  @method     copyWithZone:
 *  @abstract   Returns the same object, retained.
 *  @discussion GPGKey objects are (currently) immutable.
 *  @param      zone Memory zone (unused).
 */
- (id) copyWithZone:(NSZone *)zone;

/*!
 *  @method     formattedFingerprint:
 *  @abstract   Returns fingerprint in hex digit form.
 *  @discussion Convenience method. Returns <i>fingerprint</i> in hex digit
 *              form, formatted like this:
 *
 *              <tt>XXXX XXXX XXXX XXXX XXXX  XXXX XXXX XXXX XXXX XXXX</tt>
 *
 *              or
 *
 *              <tt>XX XX XX XX XX XX XX XX  XX XX XX XX XX XX XX XX</tt>.
 *  @param      fingerprint A non-formatted fingerprint, as returned by 
 *              <code>@link //macgpg/occ/instm/GPGKey/fingerprint fingerprint@/link</code>.
 */
+ (NSString *) formattedFingerprint:(NSString *)fingerprint;


/*!
 *  @methodgroup Public and secret keys
 */

/*!
 *  @method     publicKey
 *  @abstract   If key is the public key, returns itself, else returns the 
 *              corresponding secret key if there is one, else nil.
 */
- (GPGKey *) publicKey;

/*!
 *  @method     secretKey
 *  @abstract   If key is the secret key, returns itself, else returns the
 *              corresponding public key if there is one, else nil.
 */
- (GPGKey *) secretKey;


/*!
 *  @methodgroup Description
 */

/*!
 *  @method     dictionaryRepresentation
 *  @abstract   Returns a dictionary containing key properties.
 *  @discussion Returns a dictionary that looks something like this:
 *              <pre>@textblock {
&nbsp; &nbsp; algo = 17; 
&nbsp; &nbsp; created = "2000-07-13 08:35:05 -0400"; 
&nbsp; &nbsp; expire = "2010-07-13 08:35:05 -0400"; 
&nbsp; &nbsp; disabled = 0; 
&nbsp; &nbsp; expired = 0; 
&nbsp; &nbsp; fpr = C462FA84B8113501901020D26EF377F7BBD3B003; 
&nbsp; &nbsp; invalid = 0; 
&nbsp; &nbsp; keyid = 6EF377F7BBD3B003; 
&nbsp; &nbsp; shortkeyid = BBD3B003; 
&nbsp; &nbsp; len = 1024; 
&nbsp; &nbsp; revoked = 0; 
&nbsp; &nbsp; secret = 1;
&nbsp; &nbsp; issuerSerial = XX;
&nbsp; &nbsp; issuerName = XX;
&nbsp; &nbsp; chainID = XX;
&nbsp; &nbsp; ownertrust = 1;
&nbsp; &nbsp; subkeys = (
&nbsp; &nbsp; &nbsp; &nbsp; {
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; algo = 16; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; created = "2000-07-13 08:35:06 -0400"; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; expire = "2010-07-13 08:35:06 -0400"; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; disabled = 0; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; expired = 0; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; fpr = ""; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; invalid = 0; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; keyid = 5745314F70E767A9;
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; shortkeyid = 70E767A9; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; len = 2048; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; revoked = 0; 
&nbsp; &nbsp; &nbsp; &nbsp; }
&nbsp; &nbsp; ); 
&nbsp; &nbsp; userids = (
&nbsp; &nbsp; &nbsp; &nbsp; {
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; comment = "Gordon Worley <redbird@mac.com>"; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; email = "Gordon Worley <redbird@mac.com>"; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; invalid = 0; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; name = "Gordon Worley <redbird@mac.com>"; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; raw = "Gordon Worley <redbird@mac.com>"; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; revoked = 0;
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; validity = 0; 
&nbsp; &nbsp; &nbsp; &nbsp; }, 
&nbsp; &nbsp; &nbsp; &nbsp; {
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; comment = ""; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; email = ""; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; invalid = 0; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; name = "[image of size 2493]"; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; raw = "[image of size 2493]"; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; revoked = 0;
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; validity = 0; 
&nbsp; &nbsp; &nbsp; &nbsp; }, 
&nbsp; &nbsp; &nbsp; &nbsp; {
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; comment = ""; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; email = "redbird@rbisland.cx"; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; invalid = 0; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; name = "Gordon Worley"; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; raw = "Gordon Worley <redbird@rbisland.cx>"; 
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; revoked = 0;
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; validity = 0; 
&nbsp; &nbsp; &nbsp; &nbsp; }
&nbsp; &nbsp; );
}@/textblock </pre>
 */
- (NSDictionary *) dictionaryRepresentation;


/*!
 *  @methodgroup Global key capabilities
 */

/*!
 *  @method     canEncrypt
 *  @abstract   Returns whether the <i>key</i> (actually one of its subkeys) can
 *              be used for encryption.
 */
- (BOOL) canEncrypt;

/*!
 *  @method     canSign
 *  @abstract   Returns whether the <i>key</i> (actually one of its subkeys) can
 *              be used to create data signatures.
 */
- (BOOL) canSign;

/*!
 *  @method     canCertify
 *  @abstract   Returns whether the <i>key</i> (actually one of its subkeys) can
 *              be used to create key certificates.
 */
- (BOOL) canCertify;

/*!
 *  @method     canAuthenticate
 *  @abstract   Returns whether the <i>key</i> (actually one of its subkeys) can
 *              be used for authentication.
 */
- (BOOL) canAuthenticate;


/*!
 * @methodgroup Main key
 */

/*!
 *  @method     shortKeyID
 *  @abstract   Returns <i>main key short</i> (32 bit) <i>key ID</i>.
 *  @discussion Convenience method. Always returns 8 hexadecimal digits, e.g.
 *              <code>0A124C58</code>.
 *  @seealso    //macgpg/occ/instm/GPGKey/keyID keyID
 */
- (NSString *) shortKeyID;

/*!
 *  @method     keyID
 *  @abstract   Returns <i>main key ID</i> in hexadecimal digits.
 *  @discussion Convenience method. Always returns 16 hexadecimal digits, e.g.
 *              <code>8CED0ABE0A124C58</code>.
 *  @seealso    //macgpg/occ/instm/GPGKey/shortKeyID shortKeyID
 */
- (NSString *) keyID;

/*!
 *  @method     fingerprint
 *  @abstract   Returns <i>main key fingerprint</i> in hex digit form.
 *  @discussion Convenience method.
 *
 *              String can be made of 32 or 40 hexadecimal digits, e.g.
 *              <code>87B0AAC7A09B57D98CED0ABE0A124C58</code>.
 *  @seealso    //macgpg/occ/instm/GPGKey/formattedFingerprint formattedFingerprint
 *  @seealso    //macgpg/occ/instm/GPGContext/init init (GPGContext)
 */
- (NSString *) fingerprint;

/*!
 *  @method     formattedFingerprint
 *  @abstract   Returns <i>main key fingerprint</i> in hex digit formatted form.
 *  @discussion Convenience method. Returns <i>main key fingerprint</i> in hex 
 *              digit form, formatted like this:
 *
 *              <tt>XXXX XXXX XXXX XXXX XXXX  XXXX XXXX XXXX XXXX XXXX</tt>
 *
 *              or
 *
 *              <tt>XX XX XX XX XX XX XX XX  XX XX XX XX XX XX XX XX</tt>.
 */
- (NSString *) formattedFingerprint;

/*!
 *  @method     algorithm
 *  @abstract   Returns <i>main key algorithm</i>.
 *  @discussion Convenience method. The algorithm is the crypto algorithm for 
 *              which the key can be used. The value corresponds to the
 *              <code>@link //macgpg/c/tdef/GPGPublicKeyAlgorithm GPGPublicKeyAlgorithm@/link</code>
 *              enum values.
 */
- (GPGPublicKeyAlgorithm) algorithm;

/*!
 *  @method     algorithmDescription
 *  @abstract   Returns a non-localized description of the <i>main key</i>
 *              algorithm.
 *  @discussion Convenience method.
 */
- (NSString *) algorithmDescription;

/*!
 *  @method     length
 *  @abstract   Returns <i>main key</i> length, in bits.
 *  @discussion Convenience method.
 */
- (unsigned int) length;

/*!
 *  @method     creationDate
 *  @abstract   Returns <i>main key</i> creation date. Returns nil when not
 *              available or invalid.
 *  @discussion Convenience method.
 */
- (NSCalendarDate *) creationDate;

/*!
 *  @method     expirationDate
 *  @abstract   Returns <i>main key</i> expiration date. Returns nil when there
 *              is none or is not available or is invalid.
 *  @discussion Convenience method.
 */
- (NSCalendarDate *) expirationDate;

/*!
 *  @method     isKeyRevoked
 *  @abstract   Returns whether key is revoked.
 */
- (BOOL) isKeyRevoked;

/*!
 *  @method     isKeyInvalid
 *  @abstract   Returns whether key is invalid.
 *  @discussion Returns whether key is invalid (e.g. due to a missing
 *              self-signature). This might have several reasons, for a example
 *              for the S/MIME back-end, it will be set in during key listing if
 *              the key could not be validated due to missing certificates or
 *              unmatched policies.
 */
- (BOOL) isKeyInvalid;

/*!
 *  @method     hasKeyExpired
 *  @abstract   Returns whether key is expired.
 */
- (BOOL) hasKeyExpired;

/*!
 *  @method     isKeyDisabled
 *  @abstract   Returns whether key is disabled.
 */
- (BOOL) isKeyDisabled;

/*!
 *  @method     isSecret
 *  @abstract   Returns whether key is a secret key.
 *  @discussion If a key is secret, then all <i>subkeys</i> are 
 *              password-protected (i.e. are secret too), but password can be
 *              different for each <i>subkey</i>. A <i>subkey</i> cannot be
 *              secret if the key is not. Note, that it will always return
 *              <code>YES</code> even if the corresponding subkey may return
 *              <code>NO</code> (offline/stubkeys).
 */
- (BOOL) isSecret;

/*!
 *  @method     isQualified
 *  @abstract   Returns whether key can be used for qualified signatures 
 *              according to local government regulations.
 */
- (BOOL) isQualified;

/*!
 *  @method     ownerTrust
 *  @abstract   Returns <i>owner trust</i> (only for OpenPGP).
 */
- (GPGValidity) ownerTrust;

/*!
 *  @method     ownerTrustDescription
 *  @abstract   Returns a localized description of the <i>owner trust</i>.
 */
- (NSString *) ownerTrustDescription;

/*!
 *  @method     issuerSerial
 *  @abstract   Returns the X.509 <i>issuer serial</i> attribute of the key.
 *  @discussion Only for S/MIME.
 */
- (NSString *) issuerSerial;

/*!
 *  @method     issuerName
 *  @abstract   Returns the X.509 <i>issuer name</i> attribute of the key.
 *  @discussion Only for S/MIME.
 */
- (NSString *) issuerName;

/*!
 *  @method     chainID
 *  @abstract   Returns the X.509 <i>chain ID</i> that can be used to build the
 *              certificate chain.
 *  @discussion Only for S/MIME.
 */
- (NSString *) chainID;


/*!
 *  @methodgroup All subkeys
 */

/*!
 *  @method     subkeys
 *  @abstract   Returns the <i>main key</i>, followed by other <i>subkeys</i>, 
 *              as <code>@link //macgpg/occ/cl/GPGSubkey GPGSubkey@/link</code>
 *              objects.
 */
- (NSArray *) subkeys;


/*!
 *  @methodgroup Primary user ID information
 */

/*!
 *  @method     userID
 *  @abstract   Returns the <i>primary user ID</i> in a user-presentable 
 *              description using format "Name (Comment) &lt;Email&gt;".
 *  @discussion Convenience method. Elements which are nil are not used for
 *              output.
 */
- (NSString *) userID;

/*!
 *  @method     name
 *  @abstract   Returns the <i>primary user ID</i> name.
 *  @discussion Convenience method.
 */
- (NSString *) name;

/*!
 *  @method     email
 *  @abstract   Returns the <i>primary user ID</i> email address.
 *  @discussion Convenience method.
 */
- (NSString *) email;

/*!
 *  @method     comment
 *  @abstract   Returns the <i>primary user ID</i> comment.
 *  @discussion Convenience method.
 */
- (NSString *) comment;

/*!
 *  @method     validity
 *  @abstract   Returns the <i>primary user ID</i> validity.
 *  @discussion Convenience method. Will return
 *              <code>@link //macgpg/c/econst/GPGValidityUnknown GPGValidityUnknown@/link</code>
 *              if there is no <i>primary user ID</i>.
 */
- (GPGValidity) validity;

/*!
 *  @method     validityDescription
 *  @abstract   Returns a localized description of the <i>primary user ID</i>
 *              validity.
 *  @discussion Convenience method.
 */
- (NSString *) validityDescription;


/*!
 *  @methodgroup All user IDs
 */

/*!
 *  @method     userIDs
 *  @abstract   Returns the <i>primary user ID</i>, followed by other 
 *              <i>user IDs</i>, as <code>@link //macgpg/occ/cl/GPGUserID GPGUserID@/link</code>
 *              objects.
 */
- (NSArray *) userIDs;


/*!
 *  @methodgroup Supported protocol
 */

/*!
 *  @method     supportedProtocol
 *  @abstract   Returns information about the protocol supported by the key.
 */
- (GPGProtocol) supportedProtocol;

/*!
 *  @method     supportedProtocolDescription
 *  @abstract   Returns a localized description of the 
 *              <i>supported protocol</i>.
 */
- (NSString *) supportedProtocolDescription;


/*!
 *  @methodgroup Other key attributes
 */

/*!
 *  @method     photoData
 *  @abstract   Returns data for the photo <i>user ID</i>, if there is one.
 *  @discussion You can get an <code>@link //apple_ref/occ/cl/NSImage NSImage@/link</code>
 *              object out of it using <code>@link //apple_ref/occ/instm/NSImage/initWithData: initWithData:@/link</code>
 *              (NSImage) method.
 *
 *              Returns nil when there is no photo user ID. Note that photo data
 *              is cached. Implemented only for OpenPGP keys.
 */
- (NSData *) photoData;

/*!
 *  @method     keyListMode
 *  @abstract   Returns the keylist mode that was active when the key was 
 *              retrieved.
 */
- (GPGKeyListMode) keyListMode;

@end

#ifdef __cplusplus
}
#endif
#endif /* GPGKEY_H */
