//
//  GPGUserID.h
//  MacGPGME
//
//  Created by davelopper at users.sourceforge.net on Fri Dec 27 2002.
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

#ifndef GPGUSERID_H
#define GPGUSERID_H

#include <MacGPGME/GPGObject.h>
#include <MacGPGME/GPGKey.h>

#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif


@class GPGKeySignature;


/*!
 *  @class      GPGUserID
 *  @abstract   A <i>user ID</i> is a component of a <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code>
 *              object.
 *  @discussion A <i>user ID</i> is a component of a <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code>
 *              object. One key can have many <i>user IDs</i>. The first one in
 *              the list is the <i>main</i> (or <i>primary</i>) user ID. It is 
 *              guaranteed that the owning <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code>
 *              objects will never be deallocated before the GPGUserID has
 *              been deallocated, without creating non-breakable
 *              retain-cycles.
 *
 *              A <i>user ID</i> represents an identity associated with a key.
 *              This identity is generally composed of a name and an email
 *              adress, and can have a comment associated.
 *
 *              The signatures on a key (actually on a <i>user ID</i>) are only
 *              available if the key was retrieved via a listing operation with
 *              the <code>@link //macgpg/c/econst/GPGKeyListModeSignatures GPGKeyListModeSignatures@/link</code>
 *              mode enabled, because it is expensive to retrieve all signatures
 *              of a key.
 */
@interface GPGUserID : GPGObject <NSCopying>
{     
    GPGKey	*_key; // Key owning the user ID; not retained
    NSArray	*_signatures; // Signatures on the user ID
    int		_refCount;
}

/*!
 *  @method     copyWithZone:
 *  @abstract   Implementation of <code>@link //apple_ref/occ/intf/NSCopying NSCopying@/link</code> 
 *              protocol. Returns itself, retained.
 *  @discussion GPGUserID objects are (currently) immutable.
 *  @param      zone Memory zone (unused)
 */
- (id) copyWithZone:(NSZone *)zone;

/*!
 *  @method     description
 *  @abstract   Returns <code>@link //macgpg/occ/instm/GPGUserID/userID userID@/link</code>.
 *  @seealso    userID
 */
- (NSString *) description;

/*!
 *  @method     userID
 *  @abstract   Returns a user-presentable description using format
 *              "Name (Comment) &lt;Email&gt;".
 *  @discussion Elements which are nil are not used for output.
 */
- (NSString *) userID;

/*!
 *  @method     key
 *  @abstract   Returns the key owning the <i>user ID</i>.
 *  @discussion Never returns nil, as a GPGUserID is always owned by a
 *              <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code>.
 */
- (GPGKey *) key;


/*!
 *  @methodgroup Attributes
 */

/*!
 *  @method     name
 *  @abstract   Returns the <i>user ID</i> name.
 *  @discussion May return nil when there is no name.
 */
- (NSString *) name;

/*!
 *  @method     comment
 *  @abstract   Returns the <i>user ID</i> comment.
 *  @discussion May return nil when there is no comment.
 */
- (NSString *) comment;

/*!
 *  @method     email
 *  @abstract   Returns the <i>user ID</i> email address.
 *  @discussion May return nil when there is no email.
 */
- (NSString *) email;

/*!
 *  @method     validity
 *  @abstract   Returns the <i>user ID</i> validity.
 *  @discussion Note that for secret keys, validity is currently meaningless and
 *              always set to <code>@link //macgpg/c/econst/GPGValidityUnknown GPGValidityUnknown@/link</code>.
 *              This will be fixed with <code>gpg</code> &gt;= 1.9.
 */
- (GPGValidity) validity;

/*!
 *  @method     hasBeenRevoked
 *  @abstract   Returns whether the <i>user ID</i> has been revoked or not.
 */
- (BOOL) hasBeenRevoked;

/*!
 *  @method     isInvalid
 *  @abstract   Returns whether the <i>user ID</i> is invalid or not.
 */
- (BOOL) isInvalid;


/*!
 *  @methodgroup Convenience methods
 */

/*!
 *  @method     validityDescription
 *  @abstract   Returns a localized string describing the <i>user ID</i> 
 *              validity.
 */
- (NSString *) validityDescription;


/*!
 *  @methodgroup Signatures
 */

/*!
 *  @method     signatures
 *  @abstract   Returns the signatures on the <i>user ID</i>.
 *  @discussion Returns the signatures on the <i>user ID</i>, <strong>if</strong>
 *              they have been fetched. Array contains <code>@link //macgpg/occ/cl/GPGKeySignature GPGKeySignature@/link</code> objects.
 *
 *              Returns nil if signatures have not been fetched.
 *  @seealso    //macgpg/c/econst/GPGKeyListModeSignatures GPGKeyListModeSignatures
 */
- (NSArray *) signatures;

@end

#ifdef __cplusplus
}
#endif
#endif /* GPGUSERID_H */
