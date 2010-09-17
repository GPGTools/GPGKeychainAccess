//
//  GPGTrustItem.h
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

#ifndef GPGTRUSTITEM_H
#define GPGTRUSTITEM_H

#include <MacGPGME/GPGObject.h>
#include <MacGPGME/GPGKey.h>

#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif


@class NSString;


/*!
 *  @class      GPGTrustItem 
 *  @abstract   (brief description)
 *  @discussion GPGTrustItem objects are returned by GPGContext's 
 *              <code>@link //macgpg/occ/intfm/GPGContext(GPGKeyManagement)/trustItemEnumeratorForSearchPattern:maximumLevel: trustItemEnumeratorForSearchPattern:maximumLevel:@/link</code>;
 *              you should never need to instantiate objects of
 *              that class.
 *
 *              GPGTrustItem objects are immutable objects.
 *
 *              <strong>WARNING:</strong> the trust items interface is 
 *              experimental.
 */
@interface GPGTrustItem : GPGObject
{
}

/*!
 *  @method     keyID
 *  @abstract   Returns the <i>key ID</i> of the <i>key</i> referred by the
 *              trust item.
 */
- (NSString *) keyID;

/*!
 *  @method     ownerTrustDescription
 *  @abstract   Returns the owner trust.
 *  @discussion <strong>CAUTION:</strong> not yet working. Only if
 *              <code>@link type type@/link</code> returns 1.
 */
- (NSString *) ownerTrustDescription;

/*!
 *  @method     validityDescription
 *  @abstract   Returns the computed validity associated with the trust item.
 */
- (NSString *) validityDescription;

/*!
 *  @method     level
 *  @abstract   Returns the trust level of the trust item.
 */
- (int) level;

/*!
 *  @method     type
 *  @abstract   Returns the type of the trust item.
 *  @discussion A value of 1 refers to a key, a value of 2 refers to a user ID.
 *
 *              <strong>WARNING:</strong> not yet working.
 */
- (int) type;

/*!
 *  @method     name
 *  @abstract   Returns the <i>name</i> associated with the trust item. Only if 
 *              <code>@link type type@/link</code> returns 2.
 */
- (NSString *) name;

@end

#ifdef __cplusplus
}
#endif
#endif /* GPGTRUSTITEM_H */
