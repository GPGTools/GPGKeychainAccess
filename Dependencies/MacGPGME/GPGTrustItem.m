//
//  GPGTrustItem.m
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

#include <MacGPGME/GPGTrustItem.h>
#include <MacGPGME/GPGPrettyInfo.h>
#include <MacGPGME/GPGInternals.h>
#include <Foundation/Foundation.h>
#include <gpgme.h>


#define _trustItem	((gpgme_trust_item_t)_internalRepresentation)


@implementation GPGTrustItem

+ (BOOL) needsPointerUniquing
{
    return YES;
}

- (void) dealloc
{
    gpgme_trust_item_t	cachedTrustItem = _trustItem;
    
    [super dealloc];

    gpgme_trust_item_unref(cachedTrustItem);
}

- (NSString *) keyID
{
    return GPGStringFromChars(_trustItem->keyid);
}

- (NSString *) ownerTrustDescription
{
    return GPGStringFromChars(_trustItem->owner_trust);
}

- (NSString *) name
{
    return GPGStringFromChars(_trustItem->name);
}

- (NSString *) validityDescription
{
    return GPGStringFromChars(_trustItem->validity);
}

- (int) level
{
    return _trustItem->level;
}

- (int) type
{
    return _trustItem->type;
}

/*
    TODO: We could also implement -key
    - (GPGKey *) key
    (we need to create a local context to get the named key; key should be cached)
*/

@end
