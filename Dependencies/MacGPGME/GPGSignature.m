//
//  GPGSignature.m
//  MacGPGME
//
//  Created by davelopper at users.sourceforge.net on Sun Jul 14 2002.
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

#include <MacGPGME/GPGSignature.h>
#include <MacGPGME/GPGPrettyInfo.h>
#include <MacGPGME/GPGSignatureNotation.h>
#include <MacGPGME/GPGInternals.h>
#include <Foundation/Foundation.h>
#include <gpgme.h>


@implementation GPGSignature

+ (BOOL) accessInstanceVariablesDirectly
{
    return NO;
}

- (void) dealloc
{
    [_fingerprint release];
    [_creationDate release];
    [_expirationDate release];
    [_notations release];
    [_policyURLs release];
    [_signatureNotations release];
    [_pkaAddress release];

    [super dealloc];
}

- (id) copyWithZone:(NSZone *)zone
{
    // Implementation is useful to allow use of GPGSignature instances as keys in NSMutableDictionary instances.
    return [self retain];
}

- (NSString *) fingerprint
{
    return _fingerprint;
}

- (NSString *) formattedFingerprint
{
    NSString	*aString = [self fingerprint];

    if(aString == nil)
        return @"";
    else if([aString length] >= 32)
        return [GPGKey formattedFingerprint:aString];
    else
        return [@"0x" stringByAppendingString:aString];
}

- (GPGError) validityError
{
    return _validityError;
}

- (BOOL) wrongKeyUsage
{
    return _wrongKeyUsage;
}

- (NSCalendarDate *) creationDate
{
    return _creationDate;
}

- (NSCalendarDate *) expirationDate
{
    return _expirationDate;
}

- (GPGValidity) validity
{
    return _validity;
}

- (NSString *) validityDescription
{
    return GPGValidityDescription([self validity]);
}

- (GPGError) status
{
    return _status;
}

- (GPGSignatureSummaryMask) summary
{
    return _summary;
}

- (GPGPublicKeyAlgorithm) algorithm
{
    return _algorithm;
}

- (NSString *) algorithmDescription
{
    return GPGLocalizedPublicKeyAlgorithmDescription([self algorithm]);
}

- (GPGHashAlgorithm) hashAlgorithm
{
    return _hashAlgorithm;
}

- (NSString *) hashAlgorithmDescription
{
    return GPGLocalizedHashAlgorithmDescription([self hashAlgorithm]);
}

- (unsigned int) signatureClass
{
    return _signatureClass;
}

- (NSArray *) signatureNotations
{
    return _signatureNotations;
}

- (GPGPKATrust) pkaTrust
{
    return _pkaTrust;
}

- (NSString *) pkaAddress
{
    return _pkaAddress;
}

@end


@implementation GPGSignature(GPGSignatureDeprecated)

- (NSDictionary *) notations
{
    return _notations;
}

- (NSArray *) policyURLs
{
    return _policyURLs;
}

@end


@implementation GPGSignature(GPGInternals)

- (id) initWithSignature:(gpgme_signature_t)signature
{
    if(self = [self init]){
        unsigned long			aValue;
        gpgme_sig_notation_t	aNotation;

        _fingerprint = [GPGStringFromChars(signature->fpr) retain];
        _validityError = signature->validity_reason;
        _wrongKeyUsage = !!signature->wrong_key_usage;
        aValue = signature->timestamp;
        if(aValue != 0L)
            _creationDate = [[NSCalendarDate dateWithTimeIntervalSince1970:aValue] retain];
        aValue = signature->exp_timestamp;
        if(aValue != 0L)
            _expirationDate = [[NSCalendarDate dateWithTimeIntervalSince1970:aValue] retain];
        _validity = signature->validity;
        _status = signature->status;
        _summary = signature->summary;
        aNotation = signature->notations;
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
        _algorithm = signature->pubkey_algo;
        _hashAlgorithm = signature->hash_algo;
        _signatureClass = 0; // Unsignificant value
        _pkaTrust = signature->pka_trust;
        _pkaAddress = [GPGStringFromChars(signature->pka_address) retain];
    }

    return self;
}

- (id) initWithNewSignature:(gpgme_new_signature_t)signature
{
    if(self = [self init]){
        long	aValue;

        _fingerprint = [GPGStringFromChars(signature->fpr) retain];
        _validityError = GPGErrorNoError;
        _wrongKeyUsage = NO;
        aValue = signature->timestamp;
        if(aValue != 0L)
            _creationDate = [[NSCalendarDate dateWithTimeIntervalSince1970:aValue] retain];
        _validity = GPGValidityUltimate;
        _status = GPGErrorNoError;
        _summary = 0;
        _algorithm = signature->pubkey_algo;
        _hashAlgorithm = signature->hash_algo;
        _signatureClass = signature->sig_class;
        // We ignore gpgme_new_signature_t->type (GPGSignatureMode)
    }

    return self;
}

@end
