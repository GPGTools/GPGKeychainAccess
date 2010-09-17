//
//  GPGKeyGroup.h
//  MacGPGME
//
//  Created by davelopper at users.sourceforge.net on Wed Oct 6 2004.
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

#ifndef GPGKEYGROUP_H
#define GPGKEYGROUP_H

#include <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif


/*!
 *  @class      GPGKeyGroup 
 *  @abstract   Key groups defined in <code>gpg</code> configuration file.
 *  @discussion Key groups can be defined in <code>gpg</code> configuration file 
 *              (<a href="file:///~/.gnupg/gpg.conf">gpg.conf</a>). 
 *              Those groups, identified by names (name could be an email 
 *              address for example, or anything else), contain only keys, and
 *              cannot contain other groups.
 *
 *              Groups can be used in place of keys only in encryption
 *              operations; they will be expanded to their contained keys.
 *
 *              Key groups are only for OpenPGP keys. To obtain key groups, invoke 
 *              <code>@link //macgpg/occ/instm/GPGContext(GPGKeyGroups)/keyGroups keyGroups@/link</code> (GPGContext).
 *              If you want to create a new key group, invoke
 *              <code>@link createKeyGroupNamed:withKeys: createKeyGroupNamed:withKeys:@/link</code>.
 */
@interface GPGKeyGroup : NSObject
{
    NSString    *_name;
    NSArray     *_keys;
}

/*!
 *  @method     createKeyGroupNamed:withKeys:
 *  @abstract   Creates a new key group in <code>gpg</code> configuration file 
 *              and returns it.
 *  @discussion Creates a new key group in <code>gpg</code> configuration file, 
 *              overwriting any existing group with the same name. Group names 
 *              can't be empty nor contain the equal sign (<code>=</code>) or an 
 *              end-of-line character (<code>\n</code>), and the starting and
 *              ending space characters are trimmed out; groups may have no key.
 *
 *              <strong>WARNING:</strong> this call will modify <code>gpg</code> 
 *              configuration file, but does not lock it; you need to be careful
 *              that no other call accesses that file at the same time.
 *  @param      name The new group name
 *  @param      keys The keys associated to the new group, as <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code> objects.
 */
+ (id) createKeyGroupNamed:(NSString *)name withKeys:(NSArray *)keys;

/*!
 *  @method     name
 *  @abstract   Returns the group name.
 */
- (NSString *) name;

/*!
 *  @method     keys
 *  @abstract   Returns the <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code>
 *              keys contained in the group.
 */
- (NSArray *) keys;

@end

#ifdef __cplusplus
}
#endif
#endif /* GPGKEYGROUP_H */
