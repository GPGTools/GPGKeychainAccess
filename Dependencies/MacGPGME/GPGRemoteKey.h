//
//  GPGRemoteKey.h
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

#ifndef GPGREMOTEKEY_H
#define GPGREMOTEKEY_H

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


/*!
 *  @class      GPGRemoteKey 
 *  @abstract   Represents a key on a key server but not in the key ring.
 *  @discussion Rather than returning actual keys from a remote key match, a key
 *              server will reply with token representations of the keys, in the
 *              form of GPGRemoteKey objects. GPGRemoteKey objects are not real
 *              keys, and cannot be treated as such. However, they can be
 *              compared against actual keys by checking the <i>short key ID</i>
 *              of two keys.
 * 
 *              GPGRemoteKey objects are returned by
 *              <code>@link //macgpg/occ/instm/GPGContext(GPGExtendedKeyManagement)/asyncSearchForKeysMatchingPatterns:serverOptions: asyncSearchForKeysMatchingPatterns:serverOptions:@/link</code>
 *              (GPGContext), or <code>@link //macgpg/occ/instm/GPGContext/operationResults operationResults@/link</code>
 *              (GPGContext).
 *
 *              GPGRemoteKey objects can be passed (in any combination with
 *              normal keys) to
 *              <code>@link //macgpg/occ/instm/GPGContext(GPGExtendedKeyManagement)/asyncDownloadKeys:serverOptions asyncDownloadKeys:serverOptions@/link</code>
 *              (GPGContext).
 *
 *              GPGRemoteKey objects are immutable and should never be created
 *              manually.
 */
@interface GPGRemoteKey : GPGObject <NSCopying>
{
    NSArray *_userIDs; // Array containing GPGRemoteUserID objects
    NSArray	*_colonFormatStrings;
    int		_version;
}

/*!
 *  @method     copyWithZone:
 *  @abstract   Implementation of <code>@link //apple_ref/occ/intf/NSCopying NSCopying@/link</code> 
 *              protocol. Returns itself, retained.
 *  @discussion GPGRemoteKey objects are immutable.
 *  @param      zone Memory zone (unused)
 */
- (id) copyWithZone:(NSZone *)zone;

/*!
 *  @method     hash
 *  @abstract   Returns hash value based on <i>key ID</i>.
 */
- (unsigned) hash;

/*!
 *  @method     isEqual:
 *  @abstract   Returns <code>YES</code> if both the receiver and <i>anObject</i>
 *              have the same <i>key ID</i> and of the same class.
 */
- (BOOL) isEqual:(id)anObject;

/*!
 *  @method     dictionaryRepresentation
 *  @abstract   Returns a dictionary containing all key attributes.
 *  @discussion Returns a dictionary that looks something like this:
 *              <pre>@textblock {
&nbsp; &nbsp; algo = 17;
&nbsp; &nbsp; created = "2003-05-29 00:33:31 +0100";
&nbsp; &nbsp; expired = 0;
&nbsp; &nbsp; keyid = 2E92F423;
&nbsp; &nbsp; len = 1024;
&nbsp; &nbsp; revoked = 0;
&nbsp; &nbsp; userids = (
&nbsp; &nbsp; &nbsp; &nbsp; "Robert Scott Goldsmith <R.S.Goldsmith@cs.bham.ac.uk>",
&nbsp; &nbsp; &nbsp; &nbsp; "Robert Scott Goldsmith <R.S.Goldsmith@Far-Blue.co.uk>"
&nbsp; &nbsp; );
}@/textblock </pre>
 */
- (NSDictionary *) dictionaryRepresentation;

/*!
 *  @method     shortKeyID
 *  @abstract   Returns short (32 bit) <i>key ID</i> using hexadecimal digits.
 *  @discussion Convenience method. Always returns 8 hexadecimal digits, e.g.
 *              <code>0A124C58</code>.
 *  @seealso    //macgpg/occ/instm/GPGRemoteKey/keyID keyID
 */
- (NSString *) shortKeyID;

/*!
 *  @method     keyID
 *  @abstract   Returns the key ID in hexadecimal digits.
 *  @discussion Always returns 16 hexadecimal digits, e.g.
 *              <code>8CED0ABE0A124C58</code>.
 *  @seealso    //macgpg/occ/instm/GPGRemoteKey/shortKeyID shortKeyID
 */
- (NSString *) keyID;

/*!
 *  @method     algorithm
 *  @abstract   Returns <i>key algorithm</i>.
 *  @discussion The algorithm is the crypto algorithm for which the <i>key</i>
 *              (once downloaded) can be used. The value corresponds to the
 *              <code>@link //macgpg/c/tdef/GPGPublicKeyAlgorithm GPGPublicKeyAlgorithm@/link</code>
 *              enum values.
 */
- (GPGPublicKeyAlgorithm) algorithm;

/*!
 *  @method     algorithmDescription
 *  @abstract   Returns a non-localized description of the algorithm.
 *  @discussion Convenience method.
 *
 *              Not always available.
 */
- (NSString *) algorithmDescription;

/*!
 *  @method     length
 *  @abstract   Returns <i>key</i> length, in bits.
 */
- (unsigned int) length;

/*!
 *  @method     creationDate
 *  @abstract   Returns <i>key</i> creation date.
 *  @discussion Returns nil when not available or invalid.
 */
- (NSCalendarDate *) creationDate;

/*!
 *  @method     expirationDate
 *  @abstract   Returns <i>key</i> expiration date.
 *  @discussion Returns nil when there is none or is not available or is 
 *              invalid.
 */
- (NSCalendarDate *) expirationDate;

/*!
 *  @method     isKeyRevoked
 *  @abstract   Returns whether key is revoked.
 */
- (BOOL) isKeyRevoked;

/*!
 *  @method     hasKeyExpired
 *  @abstract   Returns whether key is expired.
 *  @discussion It doesn't compare to current date. Information is computed only
 *              once when key is retrieved.
 */
- (BOOL) hasKeyExpired;

/*!
 *  @method     userID
 *  @abstract   Returns the <i>primary user ID</i> in a user-presentable 
 *              description using format "Name (Comment) &lt;Email&gt;".
 *  @discussion Convenience method. Can return nil.
 */
- (NSString *) userID;

/*!
 *  @method     userIDs
 *  @abstract   Returns the <i>user IDs</i>, as <code>@link //macgpg/occ/cl/GPGRemoteUserID GPGRemoteUserID@/link</code> objects.
 *  @discussion Never returns nil, but can return an empty array.
 */
- (NSArray *) userIDs;

@end

#ifdef __cplusplus
}
#endif
#endif /* GPGREMOTEKEY_H */

