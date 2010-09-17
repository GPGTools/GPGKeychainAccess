//
//  GPGKey.m
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

#include <MacGPGME/GPGKey.h>
#include <MacGPGME/GPGPrettyInfo.h>
#include <MacGPGME/GPGInternals.h>
#include <Foundation/Foundation.h>
#include <gpgme.h>


#define _key	((gpgme_key_t)_internalRepresentation)


NSString *GPGStringFromChars(const char * chars)
{
    // Normally, all string attributes should be UTF-8 encoded,
    // But some keys have userIDs which have been registered
    // using wrong string encoding, and cannot be decoded.
    if(chars != NULL){
        NSString	*result = [NSString stringWithUTF8String:chars];

        // We consider that if we cannot decode string as UTF-8 encoded,
        // then we use ISOLatin1 encoding.
        if(result == nil){
            NSData	*someData = [NSData dataWithBytes:chars length:strlen(chars) + 1];

            result = [[NSString alloc] initWithData:someData encoding:NSISOLatin1StringEncoding];
            if(result == nil)
                result = @"###"; // Let's avoid returning nil - this should not happen
            else
                [result autorelease];
        }

        return result;
    }
    else
        return nil;
}


// Retain/release strategy
// A GPGKey owns GPGUserID instances, as well as GPGSubkey instances, and
// a GPGUserID instance owns GPGKeySignature instances. How to make sure
// that an owned object having a backwards relationship to its owner always
// has a valid owner, without creating non-breakable retain-cycles (i.e. owner
// retains objects which retain the owner)? We have here a tree of objects,
// so the problem can be solved.
// Each time an owned object is retained or released, its owner is also
// retained or released.
// The first retain on an owned object, performed by the +alloc, is not
// redirected to the owner, because method -retain is not invoked. The owned
// object is retained by the owner (in an array) and the owned object has a
// non-retained backwards pointer to the owner. When all retains on the owned
// object except one have been released, then owner might be deallocated, if
// its retain count is 0, and it will release, finally, the owned object, and
// both will be deallocated at the same time. We use internal ref counts,
// because it's faster than using retain/release/retainCount which use external
// ref counts.


@implementation GPGKey
// BUG: with gpg <= 1.2.x, secret keys have wrong attributes
// The following attributes are in fact always 0 for secret keys, because gpg
// doesn't return the information!
// -isKeyDisabled, ...
// Problem has been fixed in gpg 1.4

+ (BOOL) needsPointerUniquing
{
    return YES;
}

- (void) dealloc
{
    gpgme_key_t	cachedKey = _key;
    BOOL		usesReferencesCount = [[self class] usesReferencesCount];

    if(_userIDs != nil)
        [_userIDs release];
    if(_subkeys != nil)
        [_subkeys release];
    if(_photoData != nil)
        [_photoData release];
    
    [super dealloc];

    if(cachedKey != NULL && usesReferencesCount)
        gpgme_key_unref(cachedKey);
}

- (unsigned) hash
{
    NSString	*fingerprint = [self fingerprint];
    
    if(fingerprint != nil)
        return [fingerprint hash];
    // We do not take in account if key is secret or not, and if it is a subkey or not.
    return [super hash];
}

- (BOOL) isEqual:(id)anObject
{
  if(anObject != nil && [anObject isKindOfClass:[GPGKey class]] && [self isSecret] == [anObject isSecret])
	return [[self fingerprint] isEqualToString:[anObject fingerprint]];
    return NO;
}

- (id) copyWithZone:(NSZone *)zone
{
    // Implementation is useful to allow use of GPGKey instances as keys in NSMutableDictionary instances.
    return [self retain];
}

- (NSString *) debugDescription
{
    return [NSString stringWithFormat:@"<%@: %p> keyID = 0x%@", NSStringFromClass([self class]), self, [self keyID]];
}

- (GPGKey *) publicKey
{
    if(![self isSecret])
        return self;
    else{
        // TODO: Cache result
        GPGContext	*aContext = [[GPGContext alloc] init];
        GPGKey		*aKey = nil;

		NS_DURING
			aKey = [[aContext keyEnumeratorForSearchPattern:[@"0x" stringByAppendingString:[self fingerprint]] secretKeysOnly:NO] nextObject]; // We assume that there is only one key returned (with the same fingerprint)
			[aKey retain];
			[aContext stopKeyEnumeration];
			[aContext release];
		NS_HANDLER
			[aContext stopKeyEnumeration];
			[aContext release];
			[localException raise];
		NS_ENDHANDLER

        return [aKey autorelease];
    }
}

- (GPGKey *) secretKey
{
    if([self isSecret])
        return self;
    else{
        GPGContext	*aContext = [[GPGContext alloc] init];
        GPGKey		*aKey = nil;

		NS_DURING
			aKey = [[aContext keyEnumeratorForSearchPattern:[@"0x" stringByAppendingString:[self fingerprint]] secretKeysOnly:YES] nextObject]; // We assume that there is only one key returned (with the same fingerprint)
			[aKey retain];
			[aContext stopKeyEnumeration];
			[aContext release];
		NS_HANDLER
			[aContext stopKeyEnumeration];
			[aContext release];
			[localException raise];
		NS_ENDHANDLER

        return [aKey autorelease];
    }
}

- (NSDictionary *) dictionaryRepresentation
{
    NSMutableDictionary	*key_dict = [NSMutableDictionary dictionary];
    NSArray 			*objects;
    
    [key_dict setObject: [NSNumber numberWithBool:[self isSecret]] forKey:@"secret"];
    [key_dict setObject: [NSNumber numberWithBool:[self isKeyInvalid]] forKey:@"invalid"];
    [key_dict setObject: [NSNumber numberWithBool:[self isKeyRevoked]] forKey:@"revoked"];
    [key_dict setObject: [NSNumber numberWithBool:[self hasKeyExpired]] forKey:@"expired"];
    [key_dict setObject: [NSNumber numberWithBool:[self isKeyDisabled]] forKey:@"disabled"];
    [key_dict setObject: [self shortKeyID] forKey: @"shortkeyid"];
    [key_dict setObject: [self keyID] forKey: @"keyid"];
    [key_dict setObject: [self fingerprint] forKey:@"fpr"];
    [key_dict setObject: [NSNumber numberWithInt:[self algorithm]] forKey:@"algo"];
    [key_dict setObject: [NSNumber numberWithInt:[self length]] forKey:@"len"];
    if ([self creationDate])
        [key_dict setObject: [self creationDate] forKey:@"created"];
    if ([self expirationDate])
        [key_dict setObject: [self expirationDate] forKey:@"expire"];
    if ([self issuerSerial])
        [key_dict setObject: [self issuerSerial] forKey:@"issuerSerial"];
    if ([self issuerName])
        [key_dict setObject: [self issuerName] forKey:@"issuerName"];
    if ([self chainID])
        [key_dict setObject: [self chainID] forKey:@"chainID"];
    [key_dict setObject: [NSNumber numberWithInt:[self ownerTrust]] forKey:@"ownertrust"];

    objects = [self userIDs];
    if(objects != nil){
#if 0
        [key_dict setObject: [objects valueForKey:@"dictionaryRepresentation"] forKey:@"userids"];
#else
        NSEnumerator	*anEnum = [objects objectEnumerator];
        GPGUserID		*aUserID;
        NSMutableArray	*anArray = [NSMutableArray array];

        while(aUserID = [anEnum nextObject])
            [anArray addObject:[aUserID dictionaryRepresentation]];
        [key_dict setObject:anArray forKey:@"userids"];
#endif
    }
    objects = [self subkeys];
    if(objects != nil){
#if 0
        [key_dict setObject: [objects valueForKey:@"dictionaryRepresentation"] forKey:@"subkeys"];
#else
        NSEnumerator	*anEnum = [objects objectEnumerator];
        GPGSubkey		*aSubkey;
        NSMutableArray	*anArray = [NSMutableArray array];

        while(aSubkey = [anEnum nextObject])
            [anArray addObject:[aSubkey dictionaryRepresentation]];
        [key_dict setObject:anArray forKey:@"subkeys"];
#endif
    }
    
    return key_dict;
}

- (NSString *) shortKeyID
{
    NSString *keyIDString = [self keyID];
    
    return [keyIDString substringFromIndex:[keyIDString length] - 8];
}

- (NSString *) keyID
{
    return [[[self subkeys] objectAtIndex:0] keyID];
}

- (NSArray *) subkeys
{
    if(_subkeys == nil){
        gpgme_subkey_t	aSubkey = _key->subkeys;
        NSZone			*aZone = [self zone];

        _subkeys = [[NSMutableArray allocWithZone:aZone] init];

        while(aSubkey != NULL){
            GPGSubkey	*newSubkey = [[GPGSubkey allocWithZone:aZone] initWithInternalRepresentation:aSubkey key:self];

            [(NSMutableArray *)_subkeys addObject:newSubkey];
            [newSubkey release];
            aSubkey = aSubkey->next;
        }
    }

    return _subkeys;
}

- (NSString *) fingerprint
{
    return [[[self subkeys] objectAtIndex:0] fingerprint];
}

+ (NSString *) formattedFingerprint:(NSString *)fingerprint
{
    if(fingerprint != nil && [fingerprint length] == 40){
        return [NSString stringWithFormat:@"%@ %@ %@ %@ %@  %@ %@ %@ %@ %@", [fingerprint substringWithRange:NSMakeRange(0, 4)], [fingerprint substringWithRange:NSMakeRange(4, 4)], [fingerprint substringWithRange:NSMakeRange(8, 4)], [fingerprint substringWithRange:NSMakeRange(12, 4)], [fingerprint substringWithRange:NSMakeRange(16, 4)], [fingerprint substringWithRange:NSMakeRange(20, 4)], [fingerprint substringWithRange:NSMakeRange(24, 4)], [fingerprint substringWithRange:NSMakeRange(28, 4)], [fingerprint substringWithRange:NSMakeRange(32, 4)], [fingerprint substringWithRange:NSMakeRange(36, 4)]];
    }
    else if(fingerprint != nil && [fingerprint length] == 32){
        return [NSString stringWithFormat:@"%@ %@ %@ %@ %@ %@ %@ %@  %@ %@ %@ %@ %@ %@ %@ %@", [fingerprint substringWithRange:NSMakeRange(0, 2)], [fingerprint substringWithRange:NSMakeRange(2, 2)], [fingerprint substringWithRange:NSMakeRange(4, 2)], [fingerprint substringWithRange:NSMakeRange(6, 2)], [fingerprint substringWithRange:NSMakeRange(8, 2)], [fingerprint substringWithRange:NSMakeRange(10, 2)], [fingerprint substringWithRange:NSMakeRange(12, 2)], [fingerprint substringWithRange:NSMakeRange(14, 2)], [fingerprint substringWithRange:NSMakeRange(16, 2)], [fingerprint substringWithRange:NSMakeRange(18, 2)], [fingerprint substringWithRange:NSMakeRange(20, 2)], [fingerprint substringWithRange:NSMakeRange(22, 2)], [fingerprint substringWithRange:NSMakeRange(24, 2)], [fingerprint substringWithRange:NSMakeRange(26, 2)], [fingerprint substringWithRange:NSMakeRange(28, 2)], [fingerprint substringWithRange:NSMakeRange(30, 2)]];
    }
    else
        return fingerprint;
}

- (NSString *) formattedFingerprint
{
    return [[self class] formattedFingerprint:[self fingerprint]];
}

- (GPGPublicKeyAlgorithm) algorithm
{
    return [[[self subkeys] objectAtIndex:0] algorithm];
}

- (NSString *) algorithmDescription
{
    return GPGPublicKeyAlgorithmDescription([self algorithm]);
}

- (unsigned int) length
{
    return [(GPGSubkey *)[[self subkeys] objectAtIndex:0] length];
}

- (NSCalendarDate *) creationDate
{
    return [[[self subkeys] objectAtIndex:0] creationDate];
}

- (NSCalendarDate *) expirationDate
{
    return [[[self subkeys] objectAtIndex:0] expirationDate];
}

- (GPGValidity) ownerTrust
{
    return _key->owner_trust;
}

- (NSString *) ownerTrustDescription
{
    return GPGValidityDescription([self ownerTrust]);
}

- (GPGUserID *) primaryUserID
{
    // It MIGHT happen that a key has NO userID!
    NSArray	*userIDs = [self userIDs];

    if([userIDs lastObject] != nil)
        return [userIDs objectAtIndex:0];
    else
        return nil;
}

- (NSString *) userID
{
    return [[self primaryUserID] userID];
}

- (NSArray *) userIDs
{
    if(_userIDs == nil){
        gpgme_user_id_t	aUserID = _key->uids;
        NSZone			*aZone = [self zone];

        _userIDs = [[NSMutableArray allocWithZone:aZone] init];

        while(aUserID != NULL){
            GPGUserID	*newUserID = [[GPGUserID allocWithZone:aZone] initWithInternalRepresentation:aUserID key:self];
            
            [(NSMutableArray *)_userIDs addObject:newUserID];
            [newUserID release];
            aUserID = aUserID->next;
        }
    }

    return _userIDs;
}

- (NSString *) name
{
    return [[self primaryUserID] name];
}

- (NSString *) email
{
    return [[self primaryUserID] email];
}

- (NSString *) comment
{
    return [[self primaryUserID] comment];
}

- (GPGValidity) validity
{
    GPGUserID   *primaryUserID = [self primaryUserID];
    
    if(primaryUserID != nil)
        return [primaryUserID validity];
    else
        return GPGValidityUnknown;
}

- (NSString *) validityDescription
{
    GPGUserID   *primaryUserID = [self primaryUserID];
    
    if(primaryUserID != nil)
        return GPGValidityDescription([self validity]);
    else
        return nil;
}

- (BOOL) isKeyRevoked
{
    return !!_key->revoked;
}

- (BOOL) isKeyInvalid
{
    return !!_key->invalid;
}

- (BOOL) hasKeyExpired
{
    // There is a bug in gpg/gpgme: the hasKeyExpired status is wrong!
    // We need to check the expiration date.
    BOOL	hasKeyExpired = !!_key->expired;

    if(!hasKeyExpired){
        NSCalendarDate	*expirationDate = [self expirationDate];

        if(expirationDate != nil)
            hasKeyExpired = ([expirationDate compare:[NSCalendarDate calendarDate]] == NSOrderedAscending);
    }

    return hasKeyExpired;
}

- (BOOL) isKeyDisabled
{
    return !!_key->disabled;
}

- (BOOL) isSecret
{
    return !!_key->secret;
}

- (BOOL) isQualified
{
    return !!_key->is_qualified;
}

- (BOOL) canEncrypt
{
    return !!_key->can_encrypt;
}

- (BOOL) canSign
{
    return !!_key->can_sign;
}

- (BOOL) canCertify
{
    return !!_key->can_certify;
}

- (BOOL) canAuthenticate
{
    return !!_key->can_authenticate;
}

- (NSString *) issuerSerial
{
    return GPGStringFromChars(_key->issuer_serial);
}

- (NSString *) issuerName
{
    return GPGStringFromChars(_key->issuer_name);
}

- (NSString *) chainID
{
    return GPGStringFromChars(_key->chain_id);
}

- (GPGProtocol) supportedProtocol
{
    return _key->protocol;
}

- (NSString *) supportedProtocolDescription
{
    return GPGLocalizedProtocolDescription([self supportedProtocol]);
}

- (NSData *) photoData
{
    // This is a temporary implementation; libgpgme will return
    // corresponding data within an API, later.
    if([self supportedProtocol] != GPGOpenPGPProtocol)
        [[NSException exceptionWithGPGError:gpgme_err_make(GPG_MacGPGMEFrameworkErrorSource, GPGErrorNotImplemented) userInfo:nil] raise];
        
    if(!_checkedPhotoData){
        NSTask	*aTask = [[NSTask alloc] init];

        NS_DURING
            NSString	*temporaryFilename = [[NSProcessInfo processInfo] globallyUniqueString];
            NSString	*aPath = [NSTemporaryDirectory() stringByAppendingPathComponent:temporaryFilename];

            [aTask setLaunchPath:[[GPGEngine engineForProtocol:GPGOpenPGPProtocol] executablePath]];
            // Seems it is not possible to read only image data:
            // with some keys (e.g. 18AC60DD67191493), image data 
            // is mixed with userID data. gpg is though able to do
            // it correctly. We'll wait till gpgme does it too,
            // in the meantime we use a temporary file
            [aTask setArguments:[NSArray arrayWithObjects:@"--photo-viewer", [NSString stringWithFormat:@"tee %@", aPath], @"--show-photos", @"--list-keys", [self keyID], nil]];
            [aTask setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
            [aTask setStandardError:[NSFileHandle fileHandleWithNullDevice]];
            [aTask launch];
            [aTask waitUntilExit];
            _photoData = [[NSData alloc] initWithContentsOfFile:aPath];
            (void)[[NSFileManager defaultManager] removeFileAtPath:aPath handler:nil];
        NS_HANDLER
            NSLog(@"Something happened with the photo: %@", localException);
        NS_ENDHANDLER

        [aTask release];
        _checkedPhotoData = YES;
    }

    return _photoData;
}

- (GPGKeyListMode) keyListMode
{
    return _key->keylist_mode;
}

@end


@implementation GPGKey(GPGInternals)

+ (BOOL) usesReferencesCount
{
    // Note that we need to keep reference to the gpgme_key_t struct ptr,
    // because we need it for some context operations.
    return YES;
}

- (id) initWithInternalRepresentation:(void *)aPtr
{
    id	originalSelf = self;

    if(self = [super initWithInternalRepresentation:aPtr]){
        if(originalSelf == self && [[self class] usesReferencesCount])
            gpgme_key_ref(_key);
    }

    return self;
}

- (gpgme_key_t) gpgmeKey
{
    return _key;
}

@end
