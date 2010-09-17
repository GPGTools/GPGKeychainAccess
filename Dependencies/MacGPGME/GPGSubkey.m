//
//  GPGSubkey.m
//  MacGPGME
//
//  Created by davelopper at users.sourceforge.net on Jun 08 2003.
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

#include <MacGPGME/GPGSubkey.h>
#include <MacGPGME/GPGInternals.h>
#include <Foundation/Foundation.h>


#define _subkey	((gpgme_subkey_t)_internalRepresentation)


@implementation GPGSubkey

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
            NSLog(@"### GPGSubkey: _refCount < 0! (%d)", _refCount);
        [super release];
    }
}

- (GPGKey *) key
{
    return _key;
}

- (BOOL) isKeyRevoked
{
    return !!_subkey->revoked;
}

- (BOOL) isKeyInvalid
{
    return !!_subkey->invalid;
}

- (BOOL) hasKeyExpired
{
    // There is a bug in gpg/gpgme: the hasKeyExpired status is wrong!
    // We need to check the expiration date.
    BOOL	hasKeyExpired = !!_subkey->expired;
    
    if(!hasKeyExpired){
        NSCalendarDate	*expirationDate = [self expirationDate];

        if(expirationDate != nil)
            hasKeyExpired = ([expirationDate compare:[NSCalendarDate calendarDate]] == NSOrderedAscending);
    }

    return hasKeyExpired;
}

- (BOOL) isKeyDisabled
{
    return !!_subkey->disabled;
}

- (BOOL) canEncrypt
{
    return !!_subkey->can_encrypt;
}

- (BOOL) canSign
{
    return !!_subkey->can_sign;
}

- (BOOL) canCertify
{
    return !!_subkey->can_certify;
}

- (BOOL) canAuthenticate
{
    return !!_subkey->can_authenticate;
}

- (BOOL) isSecret
{
    return !!_subkey->secret;
}

- (GPGPublicKeyAlgorithm) algorithm
{
    return _subkey->pubkey_algo;
}

- (unsigned int) length
{
    return _subkey->length;
}

- (NSString *) keyID
{
    return GPGStringFromChars(_subkey->keyid);
}

- (NSString *) fingerprint
{
    return GPGStringFromChars(_subkey->fpr);
}

- (NSCalendarDate *) creationDate
{
    /* The creation timestamp, -1 if invalid, 0 if not available.  */
    long	timestamp = _subkey->timestamp;
    
    if(timestamp <= 0L)
        return nil;
    else
        return [NSCalendarDate dateWithTimeIntervalSince1970:timestamp];
}

- (NSCalendarDate *) expirationDate
{
    long	timestamp = _subkey->expires;

    if(timestamp == 0L)
        // Does not expire; shouldn't we return futureDate?
        return nil;
    else
        return [NSCalendarDate dateWithTimeIntervalSince1970:timestamp];
}

- (NSArray *) subkeys
{
    [NSException raise:NSInternalInconsistencyException format:@"### Subkeys do not respond to %@", NSStringFromSelector(_cmd)];
    return nil;
}

- (GPGValidity) ownerTrust
{
    [NSException raise:NSInternalInconsistencyException format:@"### Subkeys do not respond to %@", NSStringFromSelector(_cmd)];
    return -1;
}

- (NSString *) ownerTrustDescription
{
    [NSException raise:NSInternalInconsistencyException format:@"### Subkeys do not respond to %@", NSStringFromSelector(_cmd)];
    return nil;
}

- (GPGUserID *) primaryUserID
{
    [NSException raise:NSInternalInconsistencyException format:@"### Subkeys do not respond to %@", NSStringFromSelector(_cmd)];
    return nil;
}

- (NSString *) issuerSerial
{
    [NSException raise:NSInternalInconsistencyException format:@"### Subkeys do not respond to %@", NSStringFromSelector(_cmd)];
    return nil;
}

- (NSString *) issuerName
{
    [NSException raise:NSInternalInconsistencyException format:@"### Subkeys do not respond to %@", NSStringFromSelector(_cmd)];
    return nil;
}

- (NSString *) chainID
{
    [NSException raise:NSInternalInconsistencyException format:@"### Subkeys do not respond to %@", NSStringFromSelector(_cmd)];
    return nil;
}

- (NSString *) userID
{
    [NSException raise:NSInternalInconsistencyException format:@"### Subkeys do not respond to %@", NSStringFromSelector(_cmd)];
    return nil;
}

- (NSArray *) userIDs
{
    [NSException raise:NSInternalInconsistencyException format:@"### Subkeys do not respond to %@", NSStringFromSelector(_cmd)];
    return nil;
}

- (NSString *) name
{
    [NSException raise:NSInternalInconsistencyException format:@"### Subkeys do not respond to %@", NSStringFromSelector(_cmd)];
    return nil;
}

- (NSString *) email
{
    [NSException raise:NSInternalInconsistencyException format:@"### Subkeys do not respond to %@", NSStringFromSelector(_cmd)];
    return nil;
}

- (NSString *) comment
{
    [NSException raise:NSInternalInconsistencyException format:@"### Subkeys do not respond to %@", NSStringFromSelector(_cmd)];
    return nil;
}

- (GPGValidity) validity
{
    [NSException raise:NSInternalInconsistencyException format:@"### Subkeys do not respond to %@", NSStringFromSelector(_cmd)];
    return -1;
}

- (NSString *) validityDescription
{
    [NSException raise:NSInternalInconsistencyException format:@"### Subkeys do not respond to %@", NSStringFromSelector(_cmd)];
    return nil;
}

- (GPGProtocol) supportedProtocol
{
    [NSException raise:NSInternalInconsistencyException format:@"### Subkeys do not respond to %@", NSStringFromSelector(_cmd)];
    return -1;
}

- (NSString *) supportedProtocolDescription
{
    [NSException raise:NSInternalInconsistencyException format:@"### Subkeys do not respond to %@", NSStringFromSelector(_cmd)];
    return nil;
}

- (GPGKey *) publicKey
{
    [NSException raise:NSInternalInconsistencyException format:@"### Subkeys do not respond to %@", NSStringFromSelector(_cmd)];
    return nil;
}

- (GPGKey *) secretKey
{
    [NSException raise:NSInternalInconsistencyException format:@"### Subkeys do not respond to %@", NSStringFromSelector(_cmd)];
    return nil;
}

@end


@implementation GPGSubkey(GPGInternals)

+ (BOOL) usesReferencesCount
{
    return NO;
}

- (id) initWithInternalRepresentation:(void *)aPtr key:(GPGKey *)key
{
    if(self = [self initWithInternalRepresentation:aPtr])
        ((GPGSubkey *)self)->_key = key; // Not retained

    return self;
}

- (gpgme_key_t) gpgmeKey
{
    [NSException raise:NSInternalInconsistencyException format:@"### Subkeys do not respond to %@", NSStringFromSelector(_cmd)];
    return NULL;
}

- (NSDictionary *) dictionaryRepresentation
{
    NSMutableDictionary	*dictionaryRepresentation = [NSMutableDictionary dictionaryWithCapacity:11];
    NSCalendarDate		*aDate;
    NSString			*aString;

    [dictionaryRepresentation setObject:[NSNumber numberWithInt:[self algorithm]] forKey:@"algo"];
    aDate = [self creationDate];
    if(aDate != nil)
        [dictionaryRepresentation setObject:aDate forKey:@"created"];
    aDate = [self expirationDate];
    if(aDate != nil)
        [dictionaryRepresentation setObject:aDate forKey:@"expire"];
    [dictionaryRepresentation setObject:[NSNumber numberWithBool:[self isKeyDisabled]] forKey:@"disabled"];
    [dictionaryRepresentation setObject:[NSNumber numberWithBool:[self hasKeyExpired]] forKey:@"expired"];
    aString = [self fingerprint];
    if(aString != nil)
        [dictionaryRepresentation setObject:aString forKey:@"fpr"];
    [dictionaryRepresentation setObject:[NSNumber numberWithBool:[self isKeyInvalid]] forKey:@"invalid"];
    [dictionaryRepresentation setObject:[self keyID] forKey:@"keyid"];
    [dictionaryRepresentation setObject:[self shortKeyID] forKey:@"shortkeyid"];
    [dictionaryRepresentation setObject:[NSNumber numberWithUnsignedInt:[self length]] forKey:@"len"];
    [dictionaryRepresentation setObject:[NSNumber numberWithBool:[self isKeyRevoked]] forKey:@"revoked"];
    
    return dictionaryRepresentation;
}

@end
