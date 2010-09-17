//
//  GPGKeySignature.m
//  MacGPGME
//
//  Created by davelopper at users.sourceforge.net on Thu Dec 26 2002.
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

#include <MacGPGME/GPGKeySignature.h>
#include <MacGPGME/GPGInternals.h>
#include <Foundation/Foundation.h>
#include <gpgme.h>


@implementation GPGKeySignature

- (id) retain
{
    // See GPGKey.m for more information
    [_signedUserID retain];
    _refCount++;

    return self;
}

- (oneway void) release
{
    // See GPGKey.m for more information
    if(_refCount > 0){
        _refCount--;
        [_signedUserID release];
    }
    else{
        if(_refCount < 0)
            NSLog(@"### GPGKeySignature: _refCount < 0! (%d)", _refCount);
        [super release];
    }
}

- (void) dealloc
{
	[_signerKeyID release];
    [_userID release];
    [_name release];
    [_email release];
    [_comment release];
    
	[super dealloc];
}

- (NSString *) fingerprint
{
    [NSException raise:NSInternalInconsistencyException format:@"GPGKeySignature instances don't have fingerprint."];
    
    return nil;
}

- (GPGSignatureSummaryMask) summary
{
    [NSException raise:NSInternalInconsistencyException format:@"GPGKeySignature instances don't have summary."];
    
    return 0;
}

- (GPGValidity) validity
{
#warning Ask Werner whether it is not _yet_ available
    [NSException raise:NSInternalInconsistencyException format:@"GPGKeySignature instances don't have validity."];
    
    return 0;
}

- (NSString *) validityDescription
{
    [NSException raise:NSInternalInconsistencyException format:@"GPGKeySignature instances don't have validityDescription."];
    
    return nil;
}

- (GPGError) validityError
{
    [NSException raise:NSInternalInconsistencyException format:@"GPGKeySignature instances don't have validityError."];

    return -1;
}

- (BOOL) wrongKeyUsage
{
    [NSException raise:NSInternalInconsistencyException format:@"GPGKeySignature instances don't have wrongKeyUsage."];

    return NO;
}

- (GPGHashAlgorithm) hashAlgorithm
{
    [NSException raise:NSInternalInconsistencyException format:@"GPGKeySignature instances don't have hashAlgorithm."];

    return 0;
}

- (NSString *) hashAlgorithmDescription
{
    [NSException raise:NSInternalInconsistencyException format:@"GPGKeySignature instances don't have hashAlgorithmDescription."];

    return nil;
}

- (NSString *) signerKeyID
{
    return _signerKeyID;
}

- (NSString *) userID
{
    return _userID;
}

- (NSString *) name
{
    return _name;
}

- (NSString *) email
{
    return _email;
}

- (NSString *) comment
{
    return _comment;
}

- (NSCalendarDate *) creationDate
{
    return _creationDate;
}

- (NSCalendarDate *) expirationDate
{
    return _expirationDate;
}

- (BOOL) isRevocationSignature
{
    return _isRevocationSignature;
}

- (BOOL) hasSignatureExpired
{
    return _hasSignatureExpired;
}

- (BOOL) isSignatureInvalid
{
    return _isSignatureInvalid;
}

- (BOOL) isExportable
{
    return _isExportable;
}

- (GPGError) status
{
    return _status;
}

- (GPGUserID *) signedUserID
{
    return _signedUserID;
}

@end

@implementation GPGKeySignature(GPGInternals)

- (id) initWithKeySignature:(gpgme_key_sig_t)keySignature userID:(GPGUserID *)userID
{
    if(self = [self init]){
        gpgme_sig_notation_t	aNotation;
        long                    aValue;

        _signerKeyID = [GPGStringFromChars(keySignature->keyid) retain];
        _algorithm = keySignature->pubkey_algo;
        _userID = [GPGStringFromChars(keySignature->uid) retain];
        _name = [GPGStringFromChars(keySignature->name) retain];
        _email = [GPGStringFromChars(keySignature->email) retain];
        _comment = [GPGStringFromChars(keySignature->comment) retain];
        aValue = keySignature->timestamp;
        if(aValue > 0)
            _creationDate = [[NSCalendarDate dateWithTimeIntervalSince1970:aValue] retain];
        aValue = keySignature->expires;
        if(aValue > 0)
            _expirationDate = [[NSCalendarDate dateWithTimeIntervalSince1970:aValue] retain];
        _isRevocationSignature = !!keySignature->revoked;
        _hasSignatureExpired = !!keySignature->expired;
        _isSignatureInvalid = !!keySignature->invalid;
        _isExportable = !!keySignature->exportable;
        _signatureClass = keySignature->sig_class;
        _status = keySignature->status;
        _signedUserID = userID; // Not retained; backpointer
        _hashAlgorithm = 0; // Unsignificant value (GPG_NoHashAlgorithm)
        aNotation = keySignature->notations;
        _notations = [[NSMutableDictionary alloc] init];
        _policyURLs = [[NSMutableArray alloc] init];
        _signatureNotations = [[NSMutableArray alloc] init];
        while(aNotation != NULL){
            char                    *name = aNotation->name;
            GPGSignatureNotation    *anObject;
            
            if(name != NULL){
                // WARNING: theoretically there could be more than one notation
                // data for the same name.
                NSString	*aName = GPGStringFromChars(name);
                NSString	*aValue = GPGStringFromChars(aNotation->value);
                
                if([_notations objectForKey:aName] != nil)
                    NSLog(@"### We don't support more than one notation per name!! Ignoring notation '%@' with value '%@'", aName, aValue);
                else
                    [(NSMutableDictionary *)_notations setObject:aValue forKey:aName];
            }
            else
                [(NSMutableArray *)_policyURLs addObject:GPGStringFromChars(aNotation->value)];
            
            anObject = [[GPGSignatureNotation alloc] initWithInternalRepresentation:aNotation];
            [(NSMutableArray *)_signatureNotations addObject:anObject];
            [anObject release];
            
            aNotation = aNotation->next;
        }
    }
    
    return self;
}

@end
