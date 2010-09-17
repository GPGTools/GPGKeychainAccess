//
//  GPGUserID.m
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

#include <MacGPGME/GPGUserID.h>
#include <MacGPGME/GPGKeySignature.h>
#include <MacGPGME/GPGPrettyInfo.h>
#include <MacGPGME/GPGInternals.h>

#include <Foundation/Foundation.h>


#define _userID	((gpgme_user_id_t)_internalRepresentation)


@implementation GPGUserID

- (id) retain
{
    // See GPGKey.m for more information
    [_key retain];
    _refCount++;

    return self;
}

- (oneway void) release
{
    // See GPGKey.m for more information
    if(_refCount > 0){
        _refCount--;
        [_key release];
    }
    else{
        if(_refCount < 0)
            NSLog(@"### GPGUserID: _refCount < 0! (%d)", _refCount);
        [super release];
    }
}

- (void) dealloc
{
    if(_signatures != nil)
        [_signatures release];

    [super dealloc];
}

- (id) copyWithZone:(NSZone *)zone
{
    // Implementation is useful to allow use of GPGUserID instances as keys in NSMutableDictionary instances.
    return [self retain];
}

- (NSString *) description
{
    return [self userID];
}

- (NSString *) userID
{
    return GPGStringFromChars(_userID->uid);
}

- (NSString *) name
{
    return GPGStringFromChars(_userID->name);
}

- (NSString *) email
{
    return GPGStringFromChars(_userID->email);
}

- (NSString *) comment
{
    return GPGStringFromChars(_userID->comment);
}

- (GPGValidity) validity
{
    return _userID->validity;
}

- (NSString *) validityDescription
{
    return GPGValidityDescription([self validity]);
}

- (BOOL) hasBeenRevoked
{
    return !!_userID->revoked;
}

- (BOOL) isInvalid
{
    return !!_userID->invalid;
}

- (NSArray *) signatures
{
    // We cannot force fetch of signatures because when using -refreshKey:
    // we need to return a new GPGKey instance, because userIDs could have changed,
    // thus self (GPGUserID) could even disappear.
    if(_signatures == nil && _userID->signatures != NULL){
        // Check that there is a signature; keyID is mandatory, AFAIK
        gpgme_key_sig_t	aSignature = _userID->signatures;

        _signatures = [[NSMutableArray allocWithZone:[self zone]] init];
        while(aSignature != NULL){
            GPGKeySignature	*newSignature = [[GPGKeySignature allocWithZone:[self zone]] initWithKeySignature:aSignature userID:self];

            [(NSMutableArray *)_signatures addObject:newSignature];
            [newSignature release];
            aSignature = aSignature->next;
        }
    }

    return _signatures;
}

- (GPGKey *) key
{
    return _key;
}

@end

@implementation GPGUserID(GPGInternals)

- (id) initWithInternalRepresentation:(void *)aPtr key:(GPGKey *)key
{
    if(self = [self initWithInternalRepresentation:aPtr])
        ((GPGUserID *)self)->_key = key; // Not retained

    return self;
}

- (NSDictionary *) dictionaryRepresentation
/*
 * Returns a dictionary that looks something like this:
 *
 * {
 *     comment = "Gordon Worley <redbird@mac.com>";
 *     email = "Gordon Worley <redbird@mac.com>";
 *     invalid = 0;
 *     name = "Gordon Worley <redbird@mac.com>";
 *     raw = "Gordon Worley <redbird@mac.com>";
 *     revoked = 0;
 *     validity = 1;
 * }
 *
 * or
 *
 * {
 *     comment = "";
 *     email = "";
 *     invalid = 0;
 *     name = "[image of size 2493]";
 *     raw = "[image of size 2493]";
 *     revoked = 0;
 *     validity = 1;
 * }
 */
{
    NSMutableDictionary *aDictionary = [NSMutableDictionary dictionaryWithCapacity:7];
    NSString			*aString;

    [aDictionary setObject:[NSNumber numberWithBool:[self isInvalid]] forKey:@"invalid"];
    [aDictionary setObject:[NSNumber numberWithBool:[self hasBeenRevoked]] forKey:@"revoked"];
    [aDictionary setObject:[self userID] forKey:@"raw"];
    aString = [self name];
    if(aString != nil)
        [aDictionary setObject:aString forKey:@"name"];
    aString = [self email];
    if(aString != nil)
        [aDictionary setObject:aString forKey:@"email"];
    aString = [self comment];
    if(aString != nil)
        [aDictionary setObject:aString forKey:@"comment"];
    [aDictionary setObject:[NSNumber numberWithInt:[self validity]] forKey:@"validity"];

    return aDictionary;
}

@end
