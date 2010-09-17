//
//  GPGRemoteUserID.h
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

#ifndef GPGREMOTEUSERID_H
#define GPGREMOTEUSERID_H

#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif

/*!
 *  @class      GPGRemoteUserID
 *  @abstract   A <i>remote user ID</i> is a component of a <code>@link //macgpg/occ/cl/GPGRemoteKey GPGRemoteKey@/link</code>
 *              object.
 *  @discussion A <i>remote user ID</i> is a component of a <code>@link //macgpg/occ/cl/GPGRemoteKey GPGRemoteKey@/link</code>
 *              object. One key can have many user IDs. 
 *
 *              A <i>remote user ID</i> represents an identity associated with a
 *              remote key. This identity is generally composed of a name and an
 *              email adress, and can have a comment associated.
 *
 *              GPGRemoteUserID objects are immutable and should never be
 *              created manually.
 */
@interface GPGRemoteUserID : GPGObject
{
    GPGRemoteKey    *_key; // Key owning the user ID; not retained
    int             _index;
}

/*!
 *  @method     description
 *  @abstract   Returns <code>@link //macgpg/occ/instm/GPGRemoteUserID/userID userID@/link</code>.
 *  @seealso    //macgpg/occ/instm/GPGRemoteUserID/userID userID
 */
- (NSString *) description;

    /*!
 *  @method     userID
 *  @abstract   Returns a user-presentable description using format
 *              "Name (Comment) &lt;Email&gt;".
 */
- (NSString *) userID;

/*!
 *  @method     key
 *  @abstract   Returns the key owning that user ID.
 */
- (GPGRemoteKey *) key;

@end

#ifdef __cplusplus
}
#endif
#endif /* GPGREMOTEUSERID_H */
