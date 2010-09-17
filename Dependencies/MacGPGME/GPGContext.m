//
//  GPGContext.m
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

#include <MacGPGME/GPGContext.h>
#include <MacGPGME/GPGData.h>
#include <MacGPGME/GPGExceptions.h>
#include <MacGPGME/GPGInternals.h>
#include <MacGPGME/GPGRemoteKey.h>
#include <MacGPGME/GPGKeyGroup.h>
#include <MacGPGME/GPGOptions.h>
#include <MacGPGME/GPGSignature.h>
#include <MacGPGME/GPGTrustItem.h>
#include <Foundation/Foundation.h>
#include <time.h> /* Needed for GNUstep */
#include <gpgme.h>


#define _context	((gpgme_ctx_t)_internalRepresentation)


NSString	* const GPGKeyringChangedNotification = @"GPGKeyringChangedNotification";
NSString	* const GPGContextKey = @"GPGContextKey";
NSString	* const GPGChangesKey = @"GPGChangesKey";

NSString	* const GPGProgressNotification = @"GPGProgressNotification";

NSString	* const GPGAsynchronousOperationDidTerminateNotification = @"GPGAsynchronousOperationDidTerminateNotification";

NSString	* const GPGNextKeyNotification = @"GPGNextKeyNotification";
NSString	* const GPGNextKeyKey = @"GPGNextKeyKey";

NSString	* const GPGNextTrustItemNotification = @"GPGNextTrustItemNotification";
NSString	* const GPGNextTrustItemKey = @"GPGNextTrustItemKey";


static NSMapTable	*_helperPerContext = NULL;
static NSLock		*_helperPerContextLock = nil;


enum {
    EncryptOperation          = 1 <<  0,
    SignOperation             = 1 <<  1,
    VerifyOperation           = 1 <<  2,
    DecryptOperation          = 1 <<  3,
    ImportOperation           = 1 <<  4,
    KeyGenerationOperation    = 1 <<  5,
    KeyListingOperation       = 1 <<  6,
    SingleKeyListingOperation = 1 <<  7,
    ExportOperation           = 1 <<  8,
    TrustItemListingOperation = 1 <<  9,
    KeyDeletionOperation      = 1 << 10,
    RemoteKeyListingOperation = 1 << 11,
    KeyDownloadOperation      = 1 << 12,
    KeyUploadOperation        = 1 << 13
}; // Values for _operationMask


@interface GPGSignerKeyEnumerator : NSEnumerator
{
    GPGContext	*context;
    int			index;
}

- (id) initForContext:(GPGContext *)context;
// Designated initializer
// Can raise a GPGException; in this case, a release is sent to self

@end


@interface GPGKeyEnumerator : NSEnumerator
{
    GPGContext	*context;
}

- (id) initForContext:(GPGContext *)context searchPattern:(NSString *)searchPattern secretKeysOnly:(BOOL)secretKeysOnly;
- (id) initForContext:(GPGContext *)context searchPatterns:(NSArray *)searchPatterns secretKeysOnly:(BOOL)secretKeysOnly;
// Designated initializers
// Can raise a GPGException; in this case, a release is sent to self

@end


@interface GPGTrustItemEnumerator : NSEnumerator
{
    GPGContext	*context;
}

- (id) initForContext:(GPGContext *)context searchPattern:(NSString *)searchPattern maximumLevel:(int)maxLevel;
// Designated initializer
// Can raise a GPGException; in this case, a release is sent to self

@end


@interface GPGContext(Private)
- (NSDictionary *) _invalidKeysReasons:(gpgme_invalid_key_t)invalidKeys keys:(NSArray *)keys;
- (GPGKey *) _keyWithFpr:(const char *)fpr isSecret:(BOOL)isSecret;
- (GPGError) _importKeyDataFromServerOutput:(NSData *)result;
@end


@implementation GPGContext

static void progressCallback(void *object, const char *description, int type, int current, int total);
static NSLock   *_waitOperationLock = nil;

+ (void) initialize
{
    // Do not call super - see +initialize documentation
    if(_helperPerContextLock == nil){
        _helperPerContextLock = [[NSLock alloc] init];
        _helperPerContext = NSCreateMapTable(NSObjectMapKeyCallBacks, NSObjectMapValueCallBacks, 3);
        _waitOperationLock = [[NSLock alloc] init];
    }
}

- (void)_updateEnvironment
{
    // Agent-specific code:
    // Agent saves info in file ~/.gpg-agent-info.
    // If agent is restarted, then our environment is no longer up-to-date.
    // We need to re-read that file and update our environment.
    NSString    *agentEnvironment = [NSString stringWithContentsOfFile:[NSHomeDirectory() stringByAppendingPathComponent:@".gpg-agent-info"]]; // WARNING: we hardcode that path
    BOOL        resetEnvironment = YES;
    
    if([agentEnvironment length] > 0){
        NSArray         *lines = [agentEnvironment componentsSeparatedByString:@"\n"];
        NSEnumerator    *lineEnum = [lines objectEnumerator];
        NSString        *eachLine;
        
        while(eachLine = [lineEnum nextObject]){
            unsigned    lineLength = [eachLine length];
            
            if(lineLength > 0){ // Ignore empty lines
                unsigned    anIndex = [eachLine rangeOfString:@"="].location;
                
                if(anIndex != NSNotFound && anIndex < lineLength - 1){
                    NSString    *key = [eachLine substringToIndex:anIndex];
                    NSString    *value = [eachLine substringFromIndex:anIndex + 1];
                    NSString    *currentValue = [[[NSProcessInfo processInfo] environment] objectForKey:key];
                    
                    if(![currentValue isEqualToString:value]){
                        if(setenv([key cStringUsingEncoding:NSUTF8StringEncoding], [value cStringUsingEncoding:NSUTF8StringEncoding], 1) != 0)
                            perror([[NSString stringWithFormat:@"### Error: unable to change environment variable '%@' to '%@'", key, value] cStringUsingEncoding:NSUTF8StringEncoding]);
                        else{
                            resetEnvironment = NO;
                        }
                    }
                    else{
                        resetEnvironment = NO;
                    }
                }
                else
                    NSLog(@"### Error: invalid line in ~/.gpg-agent-info:\n%@", eachLine);
            }
        }
    }
    
    if(resetEnvironment){
        unsetenv("GPG_AGENT_INFO");
    }
}

- (id) init
{
    gpgme_ctx_t		aContext;
    gpgme_error_t	anError = gpgme_new(&aContext);

    if(anError != GPG_ERR_NO_ERROR){
        [self release];
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
    }
    
    [self _updateEnvironment];
    
    self = [self initWithInternalRepresentation:aContext];
    gpgme_set_progress_cb(aContext, progressCallback, self);
    _operationData = [[NSMutableDictionary allocWithZone:[self zone]] init];
    _signerKeys = [[NSMutableSet allocWithZone:[self zone]] init];

    return self;
}

- (void) dealloc
{
    gpgme_ctx_t	cachedContext = _context;

    if(_context != NULL){
        gpgme_set_passphrase_cb(_context, NULL, NULL);
        gpgme_set_progress_cb(_context, NULL, NULL);
    }
    [_operationData release];
    if(_userInfo != nil)
        [_userInfo release];
    [_signerKeys release];
    if(_engines != nil){
        NSEnumerator    *anEnum = [_engines objectEnumerator];
        GPGEngine       *anEngine;
        
        while((anEngine = [anEnum nextObject]))
            [anEngine invalidateContext];
        [_engines release];
    }

    [super dealloc];

    if(cachedContext != NULL)
        gpgme_release(cachedContext);
}

- (id) copyWithZone:(NSZone *)zone
{
    GPGContext      *contextCopy = [[[self class] alloc] init];
    NSEnumerator    *engineEnum = [[self engines] objectEnumerator];
    GPGEngine       *anEngine;
    
    [contextCopy setUsesArmor:[self usesArmor]];
    [contextCopy setUsesTextMode:[self usesTextMode]];
    [contextCopy setKeyListMode:[self keyListMode]];
    [contextCopy setProtocol:[self protocol]];
    [contextCopy setCertificatesInclusion:[self certificatesInclusion]];
    
    while(anEngine = [engineEnum nextObject]){
        NSEnumerator    *engineCopyEnum = [[contextCopy engines] objectEnumerator];
        GPGEngine       *anEngineCopy;
    
        while(anEngineCopy = [engineCopyEnum nextObject]){
            if([anEngineCopy engineProtocol] == [anEngine engineProtocol]){
                [anEngineCopy setExecutablePath:[anEngine executablePath]];
                [anEngineCopy setCustomHomeDirectory:[anEngine customHomeDirectory]];
                break;
            }
        }
    }
    
    return contextCopy;
}

- (void) setUsesArmor:(BOOL)armor
{
    gpgme_set_armor(_context, armor);
}

- (BOOL) usesArmor
{
    return gpgme_get_armor(_context) != 0;
}

- (void) setUsesTextMode:(BOOL)mode
{
    gpgme_set_textmode(_context, mode);
}

- (BOOL) usesTextMode
{
    return gpgme_get_textmode(_context) != 0;
}

- (void) setKeyListMode:(GPGKeyListMode)mask
{
    gpgme_error_t	anError = gpgme_set_keylist_mode(_context, mask);

    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
}

- (GPGKeyListMode) keyListMode
{
    gpgme_keylist_mode_t	mask = gpgme_get_keylist_mode(_context);

    NSAssert(mask != 0, @"_context is not a valid pointer");

    return mask;
}

- (void) setProtocol:(GPGProtocol)protocol
{
    gpgme_error_t	anError = gpgme_set_protocol(_context, protocol);
    
    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
}

- (GPGProtocol) protocol
{
    gpgme_protocol_t	protocol = gpgme_get_protocol(_context);

    return protocol;
}

static gpgme_error_t passphraseCallback(void *object, const char *uid_hint, const char *passphrase_info, int prev_was_bad, int fd)
{
    NSString		*aPassphrase = nil;
    NSArray			*keys = nil;
    gpgme_error_t	error = GPG_ERR_NO_ERROR;
    NSFileHandle	*resultFileHandle;

    // With a PGP key we have:
    // passphrase_info = "keyID (sub?)keyID algo 0"
    // uid_hint = "keyID userID"
    // Note that if keyID has been thrown away, we still have this info,
    // because gpg will try all secret keys.
    // For symmetric encryption and decryption we have:
    // passphrase_info = "3 3 2" = symmetricEncryptionAlgo ? ?
    // uid_hint = NULL

    if(uid_hint != NULL){
        // In case of symmetric encryption, no key is needed
        NSString	*aPattern = GPGStringFromChars(passphrase_info);
        GPGContext	*keySearchContext = nil;

		NS_DURING
			keySearchContext = [((GPGContext *)object) copy];
			// Do NOT use the whole uid_hint, because it causes problems with
			// uids that have ISOLatin1 data (instead of UTF8), and can also
			// lead to "ambiguous name" error. Use only the keyID, taken from
			// the passphrase_info.
			aPattern = [aPattern substringToIndex:[aPattern rangeOfString:@" "].location];
			keys = [[keySearchContext keyEnumeratorForSearchPattern:aPattern secretKeysOnly:YES] allObjects];
			[keySearchContext stopKeyEnumeration];
			[keySearchContext release];
		NS_HANDLER
			[keySearchContext release];
		NS_ENDHANDLER

        NSCAssert2([keys count] == 1, @"### No key or more than one key (%d) for search pattern '%@'", [keys count], aPattern);
    }

    NS_DURING
        aPassphrase = [((GPGContext *)object)->_passphraseDelegate context:((GPGContext *)object) passphraseForKey:[keys lastObject] again:!!prev_was_bad];
    NS_HANDLER
        if([[localException name] isEqualToString:GPGException]){
            error = [[[localException userInfo] objectForKey:GPGErrorKey] intValue];
            aPassphrase = @"";
        }
        else
            [localException raise];
    NS_ENDHANDLER

    if(aPassphrase == nil){
        // Cancel operation
        aPassphrase = @"";
        error = gpgme_err_make(GPG_MacGPGMEFrameworkErrorSource, GPG_ERR_CANCELED);
    }

    resultFileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd];
    [resultFileHandle writeData:[[aPassphrase stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [resultFileHandle release];

    return error;
}

- (void) postNotificationInMainThread:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] postNotification:notification];
}

static void progressCallback(void *object, const char *description, int type, int current, int total)
{
    // The <type> parameter is the letter printed during key generation 
    NSString			*aDescription;
    unichar				typeChar = type;
    NSNotification		*aNotification;
    GPGContext			*aContext = (GPGContext *)object;
    NSAutoreleasePool	*localAP = [[NSAutoreleasePool alloc] init];

    aDescription = GPGStringFromChars(description);
    aNotification = [NSNotification notificationWithName:GPGProgressNotification object:aContext userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithCharacters:&typeChar length:1], @"type", [NSNumber numberWithInt:current], @"current", [NSNumber numberWithInt:total], @"total", aDescription, @"description", nil]];
    // Note that if aDescription is nil, it will not be put into dictionary (ends argument list).
    [aContext performSelectorOnMainThread:@selector(postNotificationInMainThread:) withObject:aNotification waitUntilDone:NO];
    [localAP release];
}

- (void) setPassphraseDelegate:(id)delegate
{
    NSParameterAssert(delegate == nil || [delegate respondsToSelector:@selector(context:passphraseForKey:again:)]);
    _passphraseDelegate = delegate; // We don't retain delegate
    if(delegate == nil)
        gpgme_set_passphrase_cb(_context, NULL, NULL);
    else
        gpgme_set_passphrase_cb(_context, passphraseCallback, self);
}

- (id) passphraseDelegate
{
    return _passphraseDelegate;
}

- (void) clearSignerKeys
{
    gpgme_signers_clear(_context);
    // Note that it also releases references to keys.
    [_signerKeys removeAllObjects];
}

- (void) addSignerKey:(GPGKey *)key
{
    gpgme_error_t	anError;

    NSParameterAssert(key != nil);

    anError = gpgme_signers_add(_context, [key gpgmeKey]);
    // It also acquires a reference to the key
    // => no need to retain the key
    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
    else
        // Now we also retain keys to have a more consistent ObjC API.
        [_signerKeys addObject:key];
}

- (NSEnumerator *) signerKeyEnumerator
{
    return [[[GPGSignerKeyEnumerator alloc] initForContext:self] autorelease];
}

- (NSArray *) signerKeys
{
    return [[self signerKeyEnumerator] allObjects];
}

- (void) setCertificatesInclusion:(int)includedCertificatesNumber
{
    gpgme_set_include_certs(_context, includedCertificatesNumber);
}

- (int) certificatesInclusion
{
    return gpgme_get_include_certs(_context);
}

- (NSDictionary *) operationResults
{
    NSMutableDictionary	*operationResults = [NSMutableDictionary dictionary];
    NSObject			*anObject;

    anObject = [_operationData objectForKey:GPGErrorKey];
    if(anObject == nil)
        anObject = [NSNumber numberWithUnsignedInt:GPGErrorNoError];
    [operationResults setObject:anObject forKey:GPGErrorKey];
    
    if(_operationMask & EncryptOperation){
        gpgme_encrypt_result_t	aResult = gpgme_op_encrypt_result(_context);

        if(aResult != NULL){
            NSDictionary	*aDict = [self _invalidKeysReasons:aResult->invalid_recipients keys:[_operationData objectForKey:@"keys"]];

            if(aDict != nil)
                [operationResults setObject:aDict forKey:@"keyErrors"];
        }

        if(gpgme_err_code([[_operationData objectForKey:GPGErrorKey] unsignedIntValue]) == GPG_ERR_UNUSABLE_PUBKEY){
            [operationResults setObject:[_operationData objectForKey:@"cipher"] forKey:@"cipher"];
        }
    }
    
    if(_operationMask & SignOperation){
        gpgme_sign_result_t	signResult = gpgme_op_sign_result(_context);

        if(gpgme_err_code([[_operationData objectForKey:GPGErrorKey] unsignedIntValue]) == GPG_ERR_UNUSABLE_SECKEY){
            [operationResults setObject:[_operationData objectForKey:@"signedData"] forKey:@"signedData"];
        }
        
        if(signResult != NULL){
            gpgme_new_signature_t	aSignature = signResult->signatures;
            NSMutableArray			*newSignatures = [NSMutableArray array];
            NSDictionary			*aDict;

            while(aSignature != NULL){
                GPGSignature	*newSignature = [[GPGSignature alloc] initWithNewSignature:aSignature];

                [newSignatures addObject:newSignature];
                [newSignature release];
                aSignature = aSignature->next;
            }
            if([newSignatures count] > 0)
                [operationResults setObject:newSignatures forKey:@"newSignatures"];

            aDict = [self _invalidKeysReasons:signResult->invalid_signers keys:[self signerKeys]];

            if(aDict != nil){
                NSDictionary	*oldDict = [operationResults objectForKey:@"keyErrors"];

                if(oldDict == nil)
                    [operationResults setObject:aDict forKey:@"keyErrors"];
                else{
                    // WARNING: we cannot have an error for the same key coming
                    // from encryption and signing. Shouldn't be a problem though.
                    if([[NSSet setWithArray:[oldDict allKeys]] intersectsSet:[NSSet setWithArray:[aDict allKeys]]])
                        NSLog(@"### Does not support having more than one error for the same key; ignoring some errors.");
                    oldDict = [NSMutableDictionary dictionaryWithDictionary:oldDict];
                    [(NSMutableDictionary *)oldDict addEntriesFromDictionary:aDict];
                    [operationResults setObject:oldDict forKey:@"keyErrors"];
                }
            }
        }
    }
    
    if(_operationMask & VerifyOperation){
        gpgme_verify_result_t	aResult = gpgme_op_verify_result(_context);
        
        if(aResult != NULL){
            NSArray	*signatures = [self signatures];
            
            if(signatures != nil)
                [operationResults setObject:signatures forKey:@"signatures"];
            if(aResult->file_name != NULL)
                [operationResults setObject:GPGStringFromChars(aResult->file_name) forKey:@"filename"];
        }
    }
    
    if(_operationMask & DecryptOperation){
        gpgme_decrypt_result_t	aResult = gpgme_op_decrypt_result(_context);

        if(aResult != NULL){
            gpgme_recipient_t   recipients = aResult->recipients;
            NSMutableDictionary *keyErrors = [[NSMutableDictionary alloc] init];
            GPGContext          *aContext = [self copy];
            
            if(aResult->unsupported_algorithm != NULL)
                [operationResults setObject:GPGStringFromChars(aResult->unsupported_algorithm) forKey:@"unsupportedAlgorithm"];
            if(!!aResult->wrong_key_usage)
                [operationResults setObject:[NSNumber numberWithBool:!!aResult->wrong_key_usage] forKey:@"wrongKeyUsage"];
            if(aResult->file_name != NULL)
                [operationResults setObject:GPGStringFromChars(aResult->file_name) forKey:@"filename"];
            
            while(recipients != NULL){
                // Try to get secret then public GPGKey for that keyID.
                // If none, create GPGRemoteKey
                NSString        *aKeyID = [[NSString alloc] initWithFormat:@"%s", recipients->keyid];
                id              aKey;
                
                if(recipients->status == GPGErrorNoError){
                    aKey = [aContext keyFromFingerprint:aKeyID secretKey:YES];
                    NSAssert1(aKey != nil, @"### Unable to find decryption secret key %s?!", recipients->keyid); // FIXME: It may happen that assertion fails! See with Martin B. - due to agent and NFS?
                }
                else{
                    aKey = [aContext keyFromFingerprint:aKeyID secretKey:NO];
                    if(aKey == nil)
                        aKey = [[[GPGRemoteKey alloc] initWithRecipient:recipients] autorelease];
                }
                [keyErrors setObject:[NSNumber numberWithUnsignedInt:recipients->status] forKey:aKey];
                recipients = recipients->next;
                [aKeyID release];
            }
            [aContext release];
            [operationResults setObject:keyErrors forKey:@"keyErrors"];
            [keyErrors release];
        }
    }
    
    if(_operationMask & ImportOperation){
        gpgme_import_result_t	result = gpgme_op_import_result(_context);

        if(result != NULL){
            NSMutableDictionary		*keys = [NSMutableDictionary dictionary];
            gpgme_import_status_t	importStatus = result->imports;

            [operationResults setObject:[NSNumber numberWithInt:result->considered] forKey:@"consideredKeyCount"];
            [operationResults setObject:[NSNumber numberWithInt:result->no_user_id] forKey:@"keysWithoutUserIDCount"];
            [operationResults setObject:[NSNumber numberWithInt:result->imported] forKey:@"importedKeyCount"];
            [operationResults setObject:[NSNumber numberWithInt:result->imported_rsa] forKey:@"importedRSAKeyCount"];
            [operationResults setObject:[NSNumber numberWithInt:result->unchanged] forKey:@"unchangedKeyCount"];
            [operationResults setObject:[NSNumber numberWithInt:result->new_user_ids] forKey:@"newUserIDCount"];
            [operationResults setObject:[NSNumber numberWithInt:result->new_sub_keys] forKey:@"newSubkeyCount"];
            [operationResults setObject:[NSNumber numberWithInt:result->new_signatures] forKey:@"newSignatureCount"];
            [operationResults setObject:[NSNumber numberWithInt:result->new_revocations] forKey:@"newRevocationCount"];
            [operationResults setObject:[NSNumber numberWithInt:result->secret_read] forKey:@"readSecretKeyCount"];
            [operationResults setObject:[NSNumber numberWithInt:result->secret_imported] forKey:@"importedSecretKeyCount"];
            [operationResults setObject:[NSNumber numberWithInt:result->secret_unchanged] forKey:@"unchangedSecretKeyCount"];
            [operationResults setObject:[NSNumber numberWithInt:result->skipped_new_keys] forKey:@"skippedNewKeyCount"];
            [operationResults setObject:[NSNumber numberWithInt:result->not_imported] forKey:@"notImportedKeyCount"];

            while(importStatus != NULL){
                BOOL			isSecret = (importStatus->status & GPGME_IMPORT_SECRET) != 0;
                GPGKey			*aKey = [self _keyWithFpr:importStatus->fpr isSecret:isSecret];
                NSDictionary	*statusDict;

                if(importStatus->result == GPG_ERR_NO_ERROR)
                    statusDict = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:importStatus->status] forKey:@"status"];
                else
                    statusDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:importStatus->status], @"status", [NSNumber numberWithUnsignedInt:importStatus->result], @"error", nil];
                NSAssert1(aKey != nil, @"### Unable to retrieve key matching fpr %s", importStatus->fpr);
                [keys setObject:statusDict forKey:aKey];
                importStatus = importStatus->next;
            }
            [operationResults setObject:keys forKey:GPGChangesKey];
        }
    }
    
    if(_operationMask & KeyGenerationOperation){
        gpgme_genkey_result_t	result = gpgme_op_genkey_result(_context);
        
        if(result != NULL && result->fpr != NULL){ // fpr is NULL for CMS
            GPGKey			*publicKey, *secretKey;
            NSDictionary	*keyChangesDict;

            secretKey = [self _keyWithFpr:result->fpr isSecret:YES];
            NSAssert1(secretKey != nil, @"### Unable to retrieve key matching fpr %s", result->fpr);
            publicKey = [self _keyWithFpr:result->fpr isSecret:NO];
            NSAssert1(publicKey != nil, @"### Unable to retrieve key matching fpr %s", result->fpr);
            keyChangesDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:(GPGImportNewKeyMask | GPGImportSecretKeyMask)] forKey:@"status"], secretKey, [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:GPGImportNewKeyMask] forKey:@"status"], publicKey, nil];
            [operationResults setObject:keyChangesDict forKey:GPGChangesKey];
        }
    }

    if(_operationMask & KeyDeletionOperation){
        NSArray *deletedKeyFingerprints = [_operationData objectForKey:@"deletedKeyFingerprints"];
        
        if(deletedKeyFingerprints)
            [operationResults setObject:deletedKeyFingerprints forKey:@"deletedKeyFingerprints"];
    }
    
    if(_operationMask & KeyListingOperation){
        gpgme_keylist_result_t	result = gpgme_op_keylist_result(_context);

        if(result != NULL){
            [operationResults setObject:[NSNumber numberWithBool:!!result->truncated] forKey:@"truncated"];
        }
    }

    if(_operationMask & RemoteKeyListingOperation){
        id	anObject;

        [operationResults setObject:[_operationData objectForKey:@"hostName"] forKey:@"hostName"];
        [operationResults setObject:[_operationData objectForKey:@"protocol"] forKey:@"protocol"];
        [operationResults setObject:[_operationData objectForKey:@"options"] forKey:@"options"];
        anObject = [_operationData objectForKey:@"port"] ;
        if(anObject != nil)
            [operationResults setObject:anObject forKey:@"port"];
        anObject = [_operationData objectForKey:@"keys"] ;
        if(anObject != nil)
            [operationResults setObject:anObject forKey:@"keys"];
    }

    if(_operationMask & KeyDownloadOperation){
        id	anObject;
        
        [operationResults setObject:[_operationData objectForKey:@"hostName"] forKey:@"hostName"];
        [operationResults setObject:[_operationData objectForKey:@"protocol"] forKey:@"protocol"];
        [operationResults setObject:[_operationData objectForKey:@"options"] forKey:@"options"];
        anObject = [_operationData objectForKey:@"port"] ;
        if(anObject != nil)
            [operationResults setObject:anObject forKey:@"port"];
    }

    if(_operationMask & KeyUploadOperation){
        id	anObject;
        
        [operationResults setObject:[_operationData objectForKey:@"hostName"] forKey:@"hostName"];
        [operationResults setObject:[_operationData objectForKey:@"protocol"] forKey:@"protocol"];
        [operationResults setObject:[_operationData objectForKey:@"options"] forKey:@"options"];
        anObject = [_operationData objectForKey:@"port"] ;
        if(anObject != nil)
            [operationResults setObject:anObject forKey:@"port"];
    }
    
    return operationResults;
}

- (void) setUserInfo:(id)newUserInfo
{
    id	oldUserInfo = _userInfo;
    
    if(newUserInfo != nil)
        _userInfo = [newUserInfo retain];
    else
        _userInfo = nil;
    if(oldUserInfo != nil)
        [oldUserInfo release];
}

- (id) userInfo
{
    return _userInfo;
}

/* Key-Value Coding compliance */
- (void) setNilValueForKey:(NSString *)key
{
    if([key isEqualToString:@"certificatesInclusion"])
        [self setCertificatesInclusion:NO];
    else if([key isEqualToString:@"usesArmor"])
        [self setUsesArmor:NO];
    else if([key isEqualToString:@"usesTextMode"])
        [self setUsesTextMode:NO];
    else if([key isEqualToString:@"protocol"])
        [self setProtocol:GPGOpenPGPProtocol];
    else
        [super setNilValueForKey:key];
}

- (void) clearSignatureNotations
{
    gpgme_sig_notation_clear(_context);
}

- (void) addSignatureNotationWithName:(NSString *)name value:(id)value flags:(GPGSignatureNotationFlags)flags
{
    static NSCharacterSet   *notPrintableNorSpaceCharset = nil;
    const char              *aCStringName;
    const char              *aCStringValue;
    gpgme_error_t           anError;

    if(notPrintableNorSpaceCharset == nil){            
        notPrintableNorSpaceCharset = [NSCharacterSet characterSetWithRange:NSMakeRange(040, 0176 - 040 + 1)]; // Octal values - see isgraph()
        notPrintableNorSpaceCharset = [[notPrintableNorSpaceCharset invertedSet] retain];
    }
    
    // We need to duplicate work done in gpg (g10/g10.c: add_notation_data()) because
    // gpg/gpgme doesn't report any error, and operation would fail silently.
    if(name != nil){
        NSRange     atRange;
        unsigned    nameLength = [name length];
        
        if(nameLength == 0)
            [NSException raise:NSInvalidArgumentException format:@"a notation name cannot be empty"];
        if([name rangeOfCharacterFromSet:notPrintableNorSpaceCharset].location != NSNotFound)
            [NSException raise:NSInvalidArgumentException format:@"a notation name must have only printable characters or spaces"];
        
        atRange = [name rangeOfString:@"@"];
        if(atRange.location == NSNotFound)
            [NSException raise:NSInvalidArgumentException format:@"a user notation name must contain the '@' character"];
        if(atRange.location + 1 < nameLength){
            atRange = [name rangeOfString:@"@" options:0 range:NSMakeRange(atRange.location + 1, nameLength - (atRange.location + 1))];
            if(atRange.location != NSNotFound)
                [NSException raise:NSInvalidArgumentException format:@"a notation name must not contain more than one '@' character"];
        }
    }
    
    if(![value isKindOfClass:[NSString class]])
        [[NSException exceptionWithGPGError:gpgme_err_make(GPG_MacGPGMEFrameworkErrorSource, GPGErrorNotImplemented) userInfo:nil] raise];
    
    aCStringName = (name != nil ? [name UTF8String] : NULL);
    
    if(value != nil && [(NSString *)value length] > 0){
        static NSMutableCharacterSet    *controlCharset = nil;
        
        if(controlCharset == nil){
            controlCharset = (NSMutableCharacterSet *)[NSMutableCharacterSet characterSetWithRange:NSMakeRange(0, 037 + 1)]; // Octal values - see iscntrl()
            [controlCharset addCharactersInRange:NSMakeRange(0177, 1)];
            [controlCharset retain];
        }
        
        if(name == nil){
            if([value rangeOfCharacterFromSet:notPrintableNorSpaceCharset].location != NSNotFound)
                [NSException raise:NSInvalidArgumentException format:@"the policy URL is invalid"];
        }
        else{
            if([value rangeOfCharacterFromSet:controlCharset].location != NSNotFound)
                [NSException raise:NSInvalidArgumentException format:@"a notation value must not use any control characters"];
        }
    }
    
    aCStringValue = (value == nil ? "":[value UTF8String]);
    anError = gpgme_sig_notation_add(_context, aCStringName, aCStringValue, flags);
    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
}

- (NSArray *) signatureNotations
{
    NSMutableArray          *signatureNotations = [NSMutableArray array];
    gpgme_sig_notation_t    eachNotation = gpgme_sig_notation_get(_context);
    
    while(eachNotation != NULL){
        GPGSignatureNotation    *anObject = [[GPGSignatureNotation alloc] initWithInternalRepresentation:eachNotation];
        
        [signatureNotations addObject:anObject];
        eachNotation = eachNotation->next;
        [anObject release];
    }
    
    return signatureNotations;
}

- (NSArray *) engines
{
    if(_engines == nil){
        gpgme_engine_info_t engineInfo = gpgme_ctx_get_engine_info(_context);
        
        _engines = [[GPGEngine enginesFromEngineInfo:engineInfo context:self] retain];
    }
    
    return _engines;
}

- (GPGEngine *) engine
{
    NSEnumerator    *engineEnum = [[self engines] objectEnumerator];
    GPGEngine       *anEngine;
    
    while((anEngine = [engineEnum nextObject]))
        if([anEngine engineProtocol] == [self protocol])
            return anEngine;
    
    return nil;
}

- (GPGOptions *) options
{
    return [[[GPGOptions alloc] initWithPath:[[self engine] optionsFilename]] autorelease];
}

@end


@implementation GPGContext(GPGAsynchronousOperations)

+ (GPGContext *) waitOnAnyRequest:(BOOL)hang
{
    gpgme_error_t	anError = GPG_ERR_NO_ERROR;
    gpgme_ctx_t		returnedCtx;
    GPGContext		*newContext;

    // Only one thread at a time can call gpgme_wait => protect usage with mutex!
    [_waitOperationLock lock];
    returnedCtx = gpgme_wait(NULL, &anError, hang);
    [_waitOperationLock unlock];
    
    if(anError != GPG_ERR_NO_ERROR){
        // Returns an existing context
        if(returnedCtx != NULL){
            newContext = [[GPGContext alloc] initWithInternalRepresentation:returnedCtx];
            [[NSException exceptionWithGPGError:anError userInfo:[NSDictionary dictionaryWithObject:[newContext autorelease] forKey:GPGContextKey]] raise];
        }
        else
            [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
    }

    if(returnedCtx != NULL){
        // Returns an existing context
        newContext = [[GPGContext alloc] initWithInternalRepresentation:returnedCtx];

        return [newContext autorelease];
    }
    else
        return nil;
}

- (BOOL) wait:(BOOL)hang
{
    /*
     @code{gpgme_wait} can be used only in conjunction with any context
    that has a pending operation initiated with one of the
    @code{gpgme_op_*_start} functions except @code{gpgme_op_keylist_start}
    and @code{gpgme_op_trustlist_start} (for which you should use the
                                         corresponding @code{gpgme_op_*_next} functions).  If @var{ctx} is
    @code{NULL}, all of such contexts are waited upon and possibly
    returned.  Synchronous operations running in parallel, as well as key
    and trust item list operations, do not affect @code{gpgme_wait}.

    In a multi-threaded environment, only one thread should ever call
    @code{gpgme_wait} at any time, irregardless if @var{ctx} is specified
    or not.  This means that all calls to this function should be fully
    synchronized by locking primitives.
    */
    gpgme_error_t	anError = GPG_ERR_NO_ERROR;
    gpgme_ctx_t		returnedCtx;

    // Only one thread at a time can call gpgme_wait => protect usage with mutex!
    [_waitOperationLock lock];
    returnedCtx = gpgme_wait(_context, &anError, hang);
    [_waitOperationLock unlock];

    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
    
    if(returnedCtx == _context)
        return YES;
    else
        return (returnedCtx != NULL);
}

- (void) cancel
{

    /*
     *
     * If you use the global event loop, you must not call -wait: nor
     * +waitOnAnyRequest: during cancellation. After successful cancellation, you
     * can call +waitOnAnyRequest: or -wait:, and the context will appear as if it
     * had finished with the error code #GPGErrorCancelled.
     *
     * If you use your an external event loop, you must ensure that no I/O
     * callbacks are invoked for this context (for example by halting the event
                                               * loop). On successful cancellation, all registered I/O callbacks for this
     * context will be unregistered, and a GPGME_EVENT_DONE event with the error
     * code #GPGErrorCancelled will be signaled.
     */
    gpgme_error_t	anError = gpgme_cancel(_context);

    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
}

@end


@implementation GPGContext(GPGSynchronousOperations)

- (GPGData *) _decryptedData:(gpgme_data_t)gpgme_data
{
    GPGData                 *returnedData;
    gpgme_decrypt_result_t	aResult;
    
    returnedData = [[[GPGData alloc] initWithInternalRepresentation:gpgme_data] autorelease];
    aResult = gpgme_op_decrypt_result(_context);
    NSAssert(aResult != NULL, @"### No decryption result after successful decryption!?");
    if(aResult->file_name != NULL)
        [returnedData setFilename:GPGStringFromChars(aResult->file_name)];
    
    return returnedData;
}

- (GPGData *) decryptedData:(GPGData *)inputData
{
    gpgme_data_t    outputData;
    gpgme_error_t   anError;
    
    anError = gpgme_data_new(&outputData);
    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];

    anError = gpgme_op_decrypt(_context, [inputData gpgmeData], outputData);
    [self setOperationMask:DecryptOperation];
    [_operationData setObject:[NSNumber numberWithUnsignedInt:anError] forKey:GPGErrorKey];
    if(anError != GPG_ERR_NO_ERROR){
        NSDictionary	*aUserInfo = [NSDictionary dictionaryWithObject:self forKey:GPGContextKey];
        
        gpgme_data_release(outputData);
        [[NSException exceptionWithGPGError:anError userInfo:aUserInfo] raise];
    }

    return [self _decryptedData:outputData];
}

- (NSArray *) verifySignatureData:(GPGData *)signatureData againstData:(GPGData *)inputData
{
    gpgme_error_t	anError = gpgme_op_verify(_context, [signatureData gpgmeData], [inputData gpgmeData], NULL);

    [self setOperationMask:VerifyOperation | ImportOperation];
    [_operationData setObject:[NSNumber numberWithUnsignedInt:anError] forKey:GPGErrorKey];
    if(anError != GPG_ERR_NO_ERROR){
        NSDictionary	*aUserInfo = [NSDictionary dictionaryWithObject:self forKey:GPGContextKey];
        
        [[NSException exceptionWithGPGError:anError userInfo:aUserInfo] raise];
    }
    
    return [self signatures];
}

- (NSArray *) verifySignedData:(GPGData *)signedData
{
    return [self verifySignedData:signedData originalData:NULL];
}

- (NSArray *) verifySignedData:(GPGData *)signedData originalData:(GPGData **)originalDataPtr
{
    gpgme_data_t	uninitializedData;
    gpgme_error_t	anError;
    
    anError = gpgme_data_new(&uninitializedData);
    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
    anError = gpgme_op_verify(_context, [signedData gpgmeData], NULL, uninitializedData);
    [self setOperationMask:VerifyOperation | ImportOperation];
    [_operationData setObject:[NSNumber numberWithUnsignedInt:anError] forKey:GPGErrorKey];
    if(anError != GPG_ERR_NO_ERROR){
        NSDictionary	*aUserInfo = [NSDictionary dictionaryWithObject:self forKey:GPGContextKey];

        gpgme_data_release(uninitializedData);
        [[NSException exceptionWithGPGError:anError userInfo:aUserInfo] raise];
    }

    if(originalDataPtr == NULL)
        gpgme_data_release(uninitializedData);
    else{
        gpgme_verify_result_t	aResult;
        
        *originalDataPtr = [[[GPGData alloc] initWithInternalRepresentation:uninitializedData] autorelease];
        aResult = gpgme_op_verify_result(_context);
        NSAssert(aResult != NULL, @"### No verification result after successful verification!?");
        if(aResult->file_name != NULL)
            [*originalDataPtr setFilename:GPGStringFromChars(aResult->file_name)];
    }

    return [self signatures];
}

- (NSArray *) signatures
{
    gpgme_verify_result_t	aResult;
    NSMutableArray			*signatures;
    gpgme_signature_t		aSignature;

    aResult = gpgme_op_verify_result(_context);
    if(aResult == NULL)
        return nil;
    
    signatures = [NSMutableArray array];
    aSignature = aResult->signatures;
    while(aSignature != NULL){
        GPGSignature	*newSignature = [[GPGSignature alloc] initWithSignature:aSignature];

        [signatures addObject:newSignature];
        [newSignature release];
        aSignature = aSignature->next;
    }

    return signatures;
}

- (GPGData *) decryptedData:(GPGData *)inputData signatures:(NSArray **)signaturesPtr
{
    gpgme_data_t    outputData;
    gpgme_error_t   anError;

    anError = gpgme_data_new(&outputData);
    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];

    anError = gpgme_op_decrypt_verify(_context, [inputData gpgmeData], outputData);
    [self setOperationMask:DecryptOperation | VerifyOperation];
    [_operationData setObject:[NSNumber numberWithUnsignedInt:anError] forKey:GPGErrorKey];
    if(anError != GPG_ERR_NO_ERROR){
        NSDictionary	*aUserInfo = [NSDictionary dictionaryWithObject:self forKey:GPGContextKey];

        gpgme_data_release(outputData);
        [[NSException exceptionWithGPGError:anError userInfo:aUserInfo] raise];
    }

    if(signaturesPtr != NULL)
        *signaturesPtr = [self signatures];

    return [self _decryptedData:outputData];
}

- (GPGKey *) _keyWithFpr:(const char *)fpr fromKeys:(NSArray *)keys
{
    // fpr can be either a fingerprint OR a keyID
    NSString		*aFingerprint = GPGStringFromChars(fpr);
    NSEnumerator	*anEnum = [keys objectEnumerator];
    GPGKey			*aKey;

    while(aKey = [anEnum nextObject])
        // Maybe we'd better compare keyID to key's ID/fingerprint or one of its _subkeys_ ID
        if([[aKey fingerprint] isEqualToString:aFingerprint] || [[aKey keyID] isEqualToString:aFingerprint])
            return aKey;

#warning FIXME: Workaround for bug in gpgme
//    [NSException raise:NSInternalInconsistencyException format:@"### Unable to find key matching %s among %@", fpr, keys];

    return nil;
}

- (NSDictionary *) _invalidKeysReasons:(gpgme_invalid_key_t)invalidKeys keys:(NSArray *)keys
{
    if(invalidKeys != NULL){
        NSMutableDictionary	*keyErrors = [NSMutableDictionary dictionary];

        // WARNING: Does not support having more than one problem per key!
        // This could theoretically happen, but does not currently
        while(invalidKeys != NULL){
            GPGKey	*aKey = [self _keyWithFpr:invalidKeys->fpr fromKeys:keys]; // fpr or keyID!

#warning FIXME: Workaround for bug in <= gpgme 1.1.4 - invalidKeys might contains recipient keys, not signer keys => invalidKeys not in keys
            if(aKey != nil){
                if([keyErrors objectForKey:aKey] != nil)
                    NSLog(@"### Does not support having more than one error per key. Ignoring error %u (%@) for key %@", invalidKeys->reason, GPGErrorDescription(invalidKeys->reason), aKey);
                else
                    [keyErrors setObject:[NSNumber numberWithUnsignedInt:invalidKeys->reason] forKey:aKey];
            }
            invalidKeys = invalidKeys->next;
        }
        if([keyErrors count] > 0)
            return keyErrors;
    }
    return nil;
}

- (GPGData *) signedData:(GPGData *)inputData signatureMode:(GPGSignatureMode)mode
{
    gpgme_data_t	outputData;
    gpgme_error_t	anError;
    GPGData			*signedData;

    anError = gpgme_data_new(&outputData);
    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
    signedData = [[GPGData alloc] initWithInternalRepresentation:outputData];

    anError = gpgme_op_sign(_context, [inputData gpgmeData], outputData, mode);
    [self setOperationMask:SignOperation];
    [_operationData setObject:signedData forKey:@"signedData"];
    [_operationData setObject:[NSNumber numberWithUnsignedInt:anError] forKey:GPGErrorKey];
    if(anError != GPG_ERR_NO_ERROR){
        NSDictionary	*userInfo = [NSDictionary dictionaryWithObject:self forKey:GPGContextKey];
        
        [signedData release];
        [[NSException exceptionWithGPGError:anError userInfo:userInfo] raise];
    }

    return [signedData autorelease];
}

- (NSArray *) _flattenedKeys:(NSArray *)keysAndKeyGroups
{
    int             itemCount = [keysAndKeyGroups count];
    NSMutableArray  *keys = [NSMutableArray arrayWithCapacity:itemCount];
    int             i;
    
    for(i = 0; i < itemCount; i++){
        id  aKeyOrGroup = [keysAndKeyGroups objectAtIndex:i];
        
        if([aKeyOrGroup isKindOfClass:[GPGKeyGroup class]])
            [keys addObjectsFromArray:[aKeyOrGroup keys]];
        else
            [keys addObject:aKeyOrGroup];
    }
    
    return keys;
}

- (GPGData *) encryptedData:(GPGData *)inputData withKeys:(NSArray *)keys trustAllKeys:(BOOL)trustAllKeys
{
    gpgme_data_t	outputData;
    gpgme_error_t	anError;
    gpgme_key_t		*encryptionKeys;
    int				i = 0, keyCount;
    GPGData			*cipher;

    NSParameterAssert(keys != nil); // Would mean symmetric encryption
    
    keys = [self _flattenedKeys:keys];
    keyCount = [keys count];
    NSAssert(keyCount > 0, @"### No keys or group(s) expand to no keys!"); // Would mean symmetric encryption

    anError = gpgme_data_new(&outputData);
    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
    cipher = [[GPGData alloc] initWithInternalRepresentation:outputData];
    
    encryptionKeys = NSZoneMalloc(NSDefaultMallocZone(), sizeof(gpgme_key_t) * (keyCount + 1));
    for(i = 0; i < keyCount; i++)
        encryptionKeys[i] = [[keys objectAtIndex:i] gpgmeKey];
    encryptionKeys[i] = NULL;

    anError = gpgme_op_encrypt(_context, encryptionKeys, (trustAllKeys ? GPGME_ENCRYPT_ALWAYS_TRUST:0), [inputData gpgmeData], outputData);
    [self setOperationMask:EncryptOperation];
    NSZoneFree(NSDefaultMallocZone(), encryptionKeys);

    [_operationData setObject:[NSNumber numberWithUnsignedInt:anError] forKey:GPGErrorKey];
    [_operationData setObject:cipher forKey:@"cipher"];

    if(anError != GPG_ERR_NO_ERROR){
        [_operationData setObject:keys forKey:@"keys"];
        [cipher release];
        
        [[NSException exceptionWithGPGError:anError userInfo:[NSDictionary dictionaryWithObject:self forKey:GPGContextKey]] raise];
    }

    return [cipher autorelease];
}

- (GPGData *) encryptedData:(GPGData *)inputData
{
    gpgme_data_t	outputData;
    gpgme_error_t	anError;
    GPGData			*cipher;

    NSAssert([self passphraseDelegate] != nil, @"### No passphrase delegate set for symmetric encryption"); // This is to workaround a bug in gpgme 1.0.2 which doesn't return an error in that case!
    anError = gpgme_data_new(&outputData);
    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
    cipher = [[GPGData alloc] initWithInternalRepresentation:outputData];

    anError = gpgme_op_encrypt(_context, NULL, 0, [inputData gpgmeData], outputData);
    [self setOperationMask:EncryptOperation];
    [_operationData setObject:[NSNumber numberWithUnsignedInt:anError] forKey:GPGErrorKey];
    [_operationData setObject:cipher forKey:@"cipher"];
    if(anError != GPG_ERR_NO_ERROR){
        [cipher release];
        [[NSException exceptionWithGPGError:anError userInfo:[NSDictionary dictionaryWithObject:self forKey:GPGContextKey]] raise];
    }

    return [cipher autorelease];
}

- (GPGData *) encryptedSignedData:(GPGData *)inputData withKeys:(NSArray *)keys trustAllKeys:(BOOL)trustAllKeys
{
    gpgme_data_t	outputData;
    gpgme_error_t	anError;
    gpgme_key_t		*encryptionKeys;
    int				i = 0, keyCount = [keys count];
    GPGData			*cipher;

    NSParameterAssert(keys != nil); // Would mean symmetric encryption
    
    keys = [self _flattenedKeys:keys];
    keyCount = [keys count];
    NSAssert(keyCount > 0, @"### No keys or group(s) expand to no keys!"); // Would mean symmetric encryption
    
    anError = gpgme_data_new(&outputData);
    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
    cipher = [[GPGData alloc] initWithInternalRepresentation:outputData];

    encryptionKeys = NSZoneMalloc(NSDefaultMallocZone(), sizeof(gpgme_key_t) * (keyCount + 1));
    for(i = 0; i < keyCount; i++)
        encryptionKeys[i] = [[keys objectAtIndex:i] gpgmeKey];
    encryptionKeys[i] = NULL;

    anError = gpgme_op_encrypt_sign(_context, encryptionKeys, (trustAllKeys ? GPGME_ENCRYPT_ALWAYS_TRUST:0), [inputData gpgmeData], outputData);
    [self setOperationMask:EncryptOperation | SignOperation];
    NSZoneFree(NSDefaultMallocZone(), encryptionKeys);
    [_operationData setObject:[NSNumber numberWithUnsignedInt:anError] forKey:GPGErrorKey];
    [_operationData setObject:cipher forKey:@"cipher"];

    if(anError != GPG_ERR_NO_ERROR){
        NSDictionary	*userInfo;

        [_operationData setObject:keys forKey:@"keys"];
        userInfo = [NSDictionary dictionaryWithObject:self forKey:GPGContextKey];

        [cipher release];
        [[NSException exceptionWithGPGError:anError userInfo:userInfo] raise];
    }

    return [cipher autorelease];
}

- (GPGData *) exportedKeys:(NSArray *)keys
{
    gpgme_data_t	outputData;
    gpgme_error_t	anError;
    const char		**patterns;

    anError = gpgme_data_new(&outputData);
    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];

    if(keys != nil){
        int	patternCount = [keys count];
        int	i;
        
        patterns = NSZoneMalloc(NSDefaultMallocZone(), (patternCount + 1) * sizeof(char *));
        for(i = 0; i < patternCount; i++)
            patterns[i] = [[[keys objectAtIndex:i] fingerprint] UTF8String];
        patterns[i] = NULL;
    }
    else
        patterns = NULL;
    
    anError = gpgme_op_export_ext(_context, patterns, 0, outputData);
    [self setOperationMask:ExportOperation];
    NSZoneFree(NSDefaultMallocZone(), patterns);
    [_operationData setObject:[NSNumber numberWithUnsignedInt:anError] forKey:GPGErrorKey];

    if(anError != GPG_ERR_NO_ERROR){
        gpgme_data_release(outputData);
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
    }

    return [[[GPGData alloc] initWithInternalRepresentation:outputData] autorelease];
}

- (GPGKey *) _keyWithFpr:(const char *)fpr isSecret:(BOOL)isSecret
{
    // WARNING: we need to call this method in a context other than self,
    // because we start a new operation, thus changing operation results.
    GPGContext	*localContext = [self copy];
    GPGKey      *aKey = nil;
    
    NS_DURING
        aKey = [localContext keyFromFingerprint:GPGStringFromChars(fpr) secretKey:isSecret];
    NS_HANDLER
        [localContext release];
        [localException raise];
    NS_ENDHANDLER
    
    [localContext release];
    
    return aKey;
}

- (NSDictionary *) convertedChangesDictionaryForDistributedNotification:(NSDictionary *)dictionary
{
    // We replace all GPGKey instances (which are the keys in the dictionary)
    // by key fingerprints as NSString instances
    NSMutableDictionary *convertedDictionary = [NSMutableDictionary dictionaryWithCapacity:[dictionary count]];
    NSEnumerator        *keyEnum = [dictionary keyEnumerator];
    GPGKey              *aKey;
    
    while((aKey = [keyEnum nextObject]))
        // FIXME: No difference between secret and public keys
        [convertedDictionary setObject:[dictionary objectForKey:aKey] forKey:[aKey fingerprint]];
    
    return convertedDictionary;
}


- (NSDictionary *) importKeyData:(GPGData *)keyData
{
    gpgme_error_t			anError = gpgme_op_import(_context, [keyData gpgmeData]);
    gpgme_import_result_t	result;
    NSMutableDictionary		*changedKeys;
    gpgme_import_status_t	importStatus;

    [self setOperationMask:ImportOperation];
    [_operationData setObject:[NSNumber numberWithUnsignedInt:anError] forKey:GPGErrorKey];
    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:[NSDictionary dictionaryWithObject:self forKey:GPGContextKey]] raise];

    changedKeys = [NSMutableDictionary dictionary];
    result = gpgme_op_import_result(_context);
    importStatus = result->imports;
    while(importStatus != NULL){
        if(importStatus->status != 0){
            BOOL			isSecret = (importStatus->status & GPGME_IMPORT_SECRET) != 0;
            GPGKey			*aKey = [self _keyWithFpr:importStatus->fpr isSecret:isSecret];
            NSDictionary	*statusDict;

            NSAssert1(aKey != nil, @"### Unable to retrieve key matching fpr %s", importStatus->fpr);
            if(importStatus->result == GPG_ERR_NO_ERROR)
                statusDict = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:importStatus->status] forKey:@"status"];
            else
                statusDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:importStatus->status], @"status", [NSNumber numberWithUnsignedInt:importStatus->result], @"error", nil];
            
            [changedKeys setObject:statusDict forKey:aKey];
        }
        importStatus = importStatus->next;
    }

    // Posts notif only if key ring changed
    if([changedKeys count] > 0){
        [[NSNotificationCenter defaultCenter] postNotificationName:GPGKeyringChangedNotification object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:self, GPGContextKey, changedKeys, GPGChangesKey, nil]];
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:GPGKeyringChangedNotification object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self convertedChangesDictionaryForDistributedNotification:changedKeys], GPGChangesKey, nil]];
    }

    return [self operationResults];
}

- (NSString *) xmlStringForString:(NSString *)string
{
    int				i;
    NSMutableString	*xmlString = [NSMutableString stringWithString:string];
    
    for(i = [string length] - 1; i >= 0; i--){
        unichar	aChar = [string characterAtIndex:i];

        switch(aChar){
            case '\n':
                [xmlString replaceCharactersInRange:NSMakeRange(i, 1) withString:@" "]; break;
            case '<':
                [xmlString replaceCharactersInRange:NSMakeRange(i, 1) withString:@"&lt;"]; break;
            case '>':
                [xmlString replaceCharactersInRange:NSMakeRange(i, 1) withString:@"&gt;"]; break;
            case ':':
                [xmlString replaceCharactersInRange:NSMakeRange(i, 1) withString:@"\\x3a"]; break;
            case '&':
                [xmlString replaceCharactersInRange:NSMakeRange(i, 1) withString:@"&amp;"];
        }
    }
    
    return xmlString;
}

- (NSDictionary *) generateKeyFromDictionary:(NSDictionary *)params secretKey:(GPGData *)secretKeyData publicKey:(GPGData *)publicKeyData
{
    NSMutableString	*xmlString = [[NSMutableString alloc] init];
    id				aValue;
    gpgme_error_t	anError;
    NSDictionary	*keyChangesDict;
    NSDictionary	*operationResults;
    
    [xmlString appendString:@"<GnupgKeyParms format=\"internal\">\n"];
    [xmlString appendFormat:@"Key-Type: %@\n", [params objectForKey:@"type"]]; // number or string
    [xmlString appendFormat:@"Key-Length: %@\n", [params objectForKey:@"length"]]; // number or string
    aValue = [params objectForKey:@"subkeyType"]; // number or string; optional
    if(aValue != nil){
        [xmlString appendFormat:@"Subkey-Type: %@\n", aValue];
        [xmlString appendFormat:@"Subkey-Length: %@\n", [params objectForKey:@"subkeyLength"]]; // number or string
    }
    aValue = [params objectForKey:@"name"];
    if(aValue != nil){
        if([self protocol] == GPGOpenPGPProtocol)
            [xmlString appendFormat:@"Name-Real: %@\n", [self xmlStringForString:aValue]];
        else
            [xmlString appendFormat:@"Name-DN: %@\n", [self xmlStringForString:aValue]];
    }
    aValue = [params objectForKey:@"comment"];
    if(aValue != nil)
        [xmlString appendFormat:@"Name-Comment: %@\n", [self xmlStringForString:aValue]];
    aValue = [params objectForKey:@"email"];
    if(aValue != nil)
        [xmlString appendFormat:@"Name-Email: %@\n", [self xmlStringForString:aValue]];
    aValue = [params objectForKey:@"expirationDate"];
    if(aValue != nil)
        [xmlString appendFormat:@"Expire-Date: %@\n", [aValue descriptionWithCalendarFormat:@"%Y-%m-%d"]];
    else
        [xmlString appendString:@"Expire-Date: 0\n"];
    aValue = [params objectForKey:@"passphrase"];
    if(aValue != nil)
        [xmlString appendFormat:@"Passphrase: %@\n", [self xmlStringForString:aValue]];
    [xmlString appendString:@"</GnupgKeyParms>\n"];
    
    anError = gpgme_op_genkey(_context, [xmlString UTF8String], [publicKeyData gpgmeData], [secretKeyData gpgmeData]);
    [self setOperationMask:KeyGenerationOperation];
    [_operationData setObject:[NSNumber numberWithUnsignedInt:anError] forKey:GPGErrorKey];
    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:[NSDictionary dictionaryWithObject:[xmlString autorelease] forKey:@"XML"]] raise];
    [xmlString release];

    operationResults = [self operationResults];
    keyChangesDict = [operationResults objectForKey:GPGChangesKey];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:GPGKeyringChangedNotification object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:self, GPGContextKey, keyChangesDict, GPGChangesKey, nil]];
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:GPGKeyringChangedNotification object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self convertedChangesDictionaryForDistributedNotification:keyChangesDict], GPGChangesKey, nil]];

    return keyChangesDict;
}

- (void) deleteKey:(GPGKey *)key evenIfSecretKey:(BOOL)allowSecret
{
    gpgme_error_t	anError;
    NSString        *aFingerprint;
    NSArray         *deletedKeyFingerprints;

    NSParameterAssert(key != nil);
    aFingerprint = [[key fingerprint] retain];
    anError = gpgme_op_delete(_context, [key gpgmeKey], allowSecret);
    [self setOperationMask:KeyDeletionOperation];
    [_operationData setObject:[NSNumber numberWithUnsignedInt:anError] forKey:GPGErrorKey];
    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
    deletedKeyFingerprints = [NSArray arrayWithObject:aFingerprint];
    [_operationData setObject:deletedKeyFingerprints forKey:@"deletedKeyFingerprints"];
    // TODO: We should mark GPGKey as deleted, and it would raise an exception on any method invocation
    [[NSNotificationCenter defaultCenter] postNotificationName:GPGKeyringChangedNotification object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:self, GPGContextKey, deletedKeyFingerprints, @"deletedKeyFingerprints", nil]];
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:GPGKeyringChangedNotification object:nil userInfo:[NSDictionary dictionaryWithObject:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:GPGImportDeletedKeyMask] forKey:aFingerprint] forKey:GPGChangesKey]]; // FIXME: No difference between secret and public keys
    [aFingerprint release];
}

- (GPGKey *) keyFromFingerprint:(NSString *)fingerprint secretKey:(BOOL)secretKey
{
    gpgme_error_t	anError;
    gpgme_key_t		aKey = NULL;

    NSParameterAssert(fingerprint != nil);
    anError = gpgme_get_key(_context, [fingerprint UTF8String], &aKey, secretKey); // Returned key has one reference
    [self setOperationMask:SingleKeyListingOperation];
    [_operationData setObject:[NSNumber numberWithUnsignedInt:anError] forKey:GPGErrorKey];
    if(anError != GPG_ERR_NO_ERROR){
        if(gpgme_err_code(anError) == GPG_ERR_EOF)
            aKey = NULL;
        else
            [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
    }

    if(aKey != NULL){
        GPGKey  *returnedKey = [[[GPGKey alloc] initWithInternalRepresentation:aKey] autorelease];
        
        gpgme_key_unref(aKey);
        
        return returnedKey;
    }
    else
        return nil;
}

- (GPGKey *) refreshKey:(GPGKey *)key
{
    NSString	*aString;
    
    NSParameterAssert(key != nil);

    aString = [key fingerprint];
    if(aString == nil)
        aString = [key keyID];
    
    return [self keyFromFingerprint:aString secretKey:[key isSecret]];
}

@end


@implementation GPGContext(GPGKeyManagement)

- (NSEnumerator *) keyEnumeratorForSearchPattern:(NSString *)searchPattern secretKeysOnly:(BOOL)secretKeysOnly
{
    return [[[GPGKeyEnumerator alloc] initForContext:self searchPattern:searchPattern secretKeysOnly:secretKeysOnly] autorelease];
}

- (NSEnumerator *) keyEnumeratorForSearchPatterns:(NSArray *)searchPatterns secretKeysOnly:(BOOL)secretKeysOnly
{
    return [[[GPGKeyEnumerator alloc] initForContext:self searchPatterns:searchPatterns secretKeysOnly:secretKeysOnly] autorelease];
}

- (void) stopKeyEnumeration
{
    gpgme_error_t	anError = gpgme_op_keylist_end(_context);

    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
}

- (NSEnumerator *) trustItemEnumeratorForSearchPattern:(NSString *)searchPattern maximumLevel:(int)maxLevel
{
    return [[[GPGTrustItemEnumerator alloc] initForContext:self searchPattern:searchPattern maximumLevel:maxLevel] autorelease];
}

- (void) stopTrustItemEnumeration
{
    gpgme_error_t	anError = gpgme_op_trustlist_end(_context);

    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
}

@end


enum {
    _GPGContextHelperSearchCommand,
    _GPGContextHelperGetCommand,
    _GPGContextHelperUploadCommand
};

@interface _GPGContextHelper : NSObject
{
    GPGContext      *context;
    NSTask          *task;
    NSPipe          *outputPipe;
    NSPipe          *errorPipe;
    id              argument;
    NSString        *hostName;
    NSString        *hostPort;
    NSString        *protocolName;
    NSArray         *serverOptions;
    NSDictionary	*passedOptions;
    BOOL            importOutputData;
    int             command;
    NSMutableArray  *resultKeys;
    BOOL			interrupted;
    int				version;
    NSData          *errorData;
    NSData          *outputData;
    NSConditionLock *taskHandlerLock;
}

+ (void) helpContext:(GPGContext *)theContext searchingForKeysMatchingPatterns:(NSArray *)theSearchPatterns serverOptions:(NSDictionary *)options;
+ (void) helpContext:(GPGContext *)theContext downloadingKeys:(NSArray *)theKeys serverOptions:(NSDictionary *)options;
+ (void) helpContext:(GPGContext *)theContext uploadingKeys:(NSArray *)theKeys serverOptions:(NSDictionary *)options;
- (void) interrupt;

@end

@implementation _GPGContextHelper

+ (void) performCommand:(int)theCommand forContext:(GPGContext *)theContext argument:(id)theArgument serverOptions:(NSDictionary *)thePassedOptions needsLocking:(BOOL)needsLocking
{
	static NSMutableDictionary	*executableVersions = nil;
	
    _GPGContextHelper	*helper;
    NSTask				*aTask = nil;
    NSMutableString		*commandString = nil;
    NSString			*aHostName;
    NSString			*port = nil;
    NSString			*aString;
    NSString			*aProtocol = nil;
    GPGOptions			*gpgOptions;
    NSRange				aRange;
    NSPipe				*inputPipe, *anOutputPipe, *anErrorPipe;
    NSString			*launchPath = nil;
    NSArray             *options;
    NSArray             *defaultOptions;
    NSArray             *customOptions;
    NSEnumerator		*anEnum;
    int					formatVersion = 0;
    NSNumber			*formatVersionNumber = nil;
    int                 urlSchemeSeparatorLength = 3; // Length of ://
    BOOL                passHostArgument = YES;
    int                 engineMajorVersion;

	if(executableVersions == nil)
		executableVersions = [[NSMutableDictionary alloc] initWithCapacity:5];
	
    gpgOptions = [[theContext options] retain];
    aHostName = [thePassedOptions objectForKey:@"keyserver"];
    if(aHostName == nil){
        NSArray	*optionValues = [gpgOptions activeOptionValuesForName:@"keyserver"];

        if([optionValues count] == 0){
            [gpgOptions release];
            [[NSException exceptionWithGPGError:gpgme_err_make(GPG_MacGPGMEFrameworkErrorSource, GPGErrorKeyServerError) userInfo:[NSDictionary dictionaryWithObject:@"No keyserver set" forKey:GPGAdditionalReasonKey]] raise];
        }
        else
            aHostName = [optionValues objectAtIndex:0];
    }

    aRange = [aHostName rangeOfString:@"://"];
    if(aRange.length <= 0){
        if([aHostName hasPrefix:@"finger:"]){
            // Special case
            // Format is finger:user@domain - finger://relay/user scheme is not yet supported
            aRange = [aHostName rangeOfString:@":"];
            urlSchemeSeparatorLength = 1;
            passHostArgument = NO;
        }
        else{
            aHostName = [@"x-hkp://" stringByAppendingString:aHostName];
            aRange = [aHostName rangeOfString:@"://"];
        }
    }
    engineMajorVersion = [[[theContext engine] version] characterAtIndex:0] - '0';
    aString = [aHostName lowercaseString];
    if([aString hasPrefix:@"ldap://"]){
        launchPath = (engineMajorVersion == 2 ? @"gpg2keys_ldap" : @"gpgkeys_ldap"); // Hardcoded
        aProtocol = @"ldap";
    }
    else if([aString hasPrefix:@"x-hkp://"]){
        launchPath = (engineMajorVersion == 2 ? @"gpg2keys_hkp" : @"gpgkeys_hkp"); // Hardcoded
        aProtocol = @"x-hkp";
    }
    else if([aString hasPrefix:@"hkp://"]){
        launchPath = (engineMajorVersion == 2 ? @"gpg2keys_hkp" : @"gpgkeys_hkp"); // Hardcoded
        aProtocol = @"hkp";
    }
    else if([aString hasPrefix:@"http://"]){
        launchPath = (engineMajorVersion == 2 ? @"gpg2keys_curl" : @"gpgkeys_curl"); // Hardcoded
        aProtocol = @"http";
    }
    else if([aString hasPrefix:@"https://"]){
        launchPath = (engineMajorVersion == 2 ? @"gpg2keys_curl" : @"gpgkeys_curl"); // Hardcoded
        aProtocol = @"https";
    }
    else if([aString hasPrefix:@"ftp://"]){
        launchPath = (engineMajorVersion == 2 ? @"gpg2keys_curl" : @"gpgkeys_curl"); // Hardcoded
        aProtocol = @"ftp";
    }
    else if([aString hasPrefix:@"ftps://"]){
        launchPath = (engineMajorVersion == 2 ? @"gpg2keys_curl" : @"gpgkeys_curl"); // Hardcoded
        aProtocol = @"ftps";
    }
    else if([aString hasPrefix:@"finger:"]){
        launchPath = (engineMajorVersion == 2 ? @"gpg2keys_finger" : @"gpgkeys_finger"); // Hardcoded
        aProtocol = @"finger";
    }
    else{
        [gpgOptions release];
        [[NSException exceptionWithGPGError:gpgme_err_make(GPG_MacGPGMEFrameworkErrorSource, GPGErrorKeyServerError) userInfo:[NSDictionary dictionaryWithObject:@"Unsupported keyserver type" forKey:GPGAdditionalReasonKey]] raise];
    }
    aHostName = [aHostName substringFromIndex:aRange.location + urlSchemeSeparatorLength];

    if(engineMajorVersion == 1)
        aString = [[[[[theContext engine] executablePath] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"libexec/gnupg"]; // E.g. from /usr/local/bin/gpg to /usr/local/libexec/gnupg
    else{
        aString = [[[[[theContext engine] executablePath] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"libexec"]; // E.g. from /usr/local/bin/gpg2 to /usr/local/libexec
    }
    aString = [aString stringByAppendingPathComponent:launchPath];
    if(![[NSFileManager defaultManager] fileExistsAtPath:aString]){
        aString = [[[[[theContext engine] executablePath] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"lib/gnupg"]; // E.g. from /sw/bin/gpg to /sw/lib/gnupg (needed for Fink installations!)
        aString = [aString stringByAppendingPathComponent:launchPath];
        if(![[NSFileManager defaultManager] fileExistsAtPath:aString]){
            BOOL	tryEmbeddedOnes = YES;
            
            if([aProtocol isEqualToString:@"http"]){
                launchPath = (engineMajorVersion == 2 ? @"gpg2keys_http" : @"gpgkeys_http"); // Hardcoded
                aString = [[aString stringByDeletingLastPathComponent] stringByAppendingPathComponent:launchPath];
                tryEmbeddedOnes = ![[NSFileManager defaultManager] fileExistsAtPath:aString];
            }
            
            if(tryEmbeddedOnes){
#if 0
                // Try to use embedded version - we should embed only gpg 1.2 version of these executables, as for gpg 1.4 all binaries are installed
#warning FIXME: Embed gpgkeys_* 1.2 binaries (backwards compatible)
                launchPath = [[NSBundle bundleForClass:self] pathForResource:[launchPath stringByDeletingPathExtension] ofType:[launchPath pathExtension]]; // -pathForAuxiliaryExecutable: does not work for frameworks?!
                if(!launchPath || ![[NSFileManager defaultManager] fileExistsAtPath:launchPath]){
                    [gpgOptions release];
                    [[NSException exceptionWithGPGError:gpgme_err_make(GPG_MacGPGMEFrameworkErrorSource, GPGErrorKeyServerError) userInfo:[NSDictionary dictionaryWithObject:@"Unsupported keyserver type" forKey:GPGAdditionalReasonKey]] raise];
                }
#else
                // We no longer embed executables - everyone now uses gpg >= 1.4
                [gpgOptions release];
                [[NSException exceptionWithGPGError:gpgme_err_make(GPG_MacGPGMEFrameworkErrorSource, GPGErrorKeyServerError) userInfo:[NSDictionary dictionaryWithObject:@"Unsupported keyserver type" forKey:GPGAdditionalReasonKey]] raise];
#endif
            }
            else
                launchPath = aString;
        }
        else
            launchPath = aString;
	}
    else
        launchPath = aString;

    // TODO: verify that it works too with gpg2
	formatVersionNumber = [executableVersions objectForKey:launchPath];
	if(!formatVersionNumber){
		// We need to test the format version used by the executable
		// We do it only once per executable and cache result,
		// to spare use of system resources (when launching task).
		NS_DURING
			NSData	*data;
			
			aTask = [[NSTask alloc] init];
			[aTask setLaunchPath:launchPath];
			[aTask setArguments:[NSArray arrayWithObject:@"-V"]]; // Get version
			anOutputPipe = [NSPipe pipe];
			[aTask setStandardOutput:anOutputPipe];
			[aTask launch]; // FIXME: Shouldn't we do that asynchronously too?
			// Output is on 2 lines: first contains format version,
			// second contains executable version; we are interested only in format version,
			// and reading first 2 bytes should be enough. If we use -readDataToEndOfFile
			// we need to write more complex code, to avoid being blocked.
			data = [[anOutputPipe fileHandleForReading] readDataOfLength:2];
			[aTask waitUntilExit];
			aString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			formatVersionNumber = [NSNumber numberWithInt:[aString intValue]];
			[executableVersions setObject:formatVersionNumber forKey:launchPath];
			[aString release];
			[aTask release];
		NS_HANDLER
			[aTask release];
			[gpgOptions release];
			[localException raise];
		NS_ENDHANDLER
	}

	formatVersion = [formatVersionNumber intValue];    
    aRange = [aHostName rangeOfString:@":"];
    if(aRange.length > 0){
        port = [aHostName substringFromIndex:aRange.location + 1];
        aHostName = [aHostName substringToIndex:aRange.location];
    }

    commandString = [[NSMutableString alloc] init];
    if(formatVersion > 0){
        [commandString appendFormat:@"VERSION %d\n", formatVersion]; // For gpg >= 1.3.x, optional
        [commandString appendFormat:@"PROGRAM %@\n", [[theContext engine] version]]; // For gpg >= 1.3.x, optional(?)
        [commandString appendFormat:@"SCHEME %@\n", aProtocol]; // For gpg >= 1.3.x, optional(?)
        [commandString appendFormat:@"OPAQUE %@\n", aHostName]; // For gpg >= 1.3.x, optional(?)
    }
    
    switch(theCommand){
        case _GPGContextHelperSearchCommand:
            [commandString appendString:@"COMMAND search\n"]; break;
        case _GPGContextHelperGetCommand:
            [commandString appendString:@"COMMAND get\n"]; break;
        case _GPGContextHelperUploadCommand:
            [commandString appendString:@"COMMAND send\n"]; break;
    }
    if(passHostArgument){
        [commandString appendFormat:@"HOST %@\n", aHostName];
        if(port != nil)
            [commandString appendFormat:@"PORT %@\n", port];
    }
    
    // We pass all default options and custom options, but custom ones are passed after default
    // ones, so they have higher priority.
    customOptions = [thePassedOptions objectForKey:@"keyserver-options"];
    defaultOptions = ([gpgOptions optionStateForName:@"keyserver-options"] ? [gpgOptions _subOptionsForName:@"keyserver-options"] : nil);
    if(customOptions == nil){
        if(defaultOptions == nil)
            options = [NSArray array];
        else
            options = defaultOptions;
    }
    else{
        if(defaultOptions == nil)
            options = customOptions;
        else
            options = [defaultOptions arrayByAddingObjectsFromArray:customOptions];
    }
    anEnum = [options objectEnumerator];
    while(aString = [anEnum nextObject]){
        [commandString appendFormat:@"OPTION %@\n", aString];
    }

    [commandString appendString:@"\n"]; // An empty line as separator
    switch(theCommand){
        case _GPGContextHelperGetCommand:
            [commandString appendString:[theArgument componentsJoinedByString:@"\n"]]; break;
        case _GPGContextHelperSearchCommand:
            // We cannot do a search with multiple patterns; we need to do multiple searches.
            // We start with the first pattern.
            [commandString appendString:[theArgument objectAtIndex:0]]; break;
        case _GPGContextHelperUploadCommand:{
            // We cannot upload multiple keys; we need to do multiple uploads.
            // We start with the first key.
            GPGKey		*aKey = [theArgument objectAtIndex:0];
            NSString	*aKeyID = [aKey keyID];
            GPGContext	*tempContext = [theContext copy]; // We cannot use current context, to avoid changing its state
            NSString	*asciiExport = nil;

            [tempContext setUsesArmor:YES];
            NS_DURING
                asciiExport = [[tempContext exportedKeys:[NSArray arrayWithObject:[aKey publicKey]]] string]; // NEVER send private key!!!
            NS_HANDLER
                [tempContext release];
                [commandString release];
                [gpgOptions release];
                [localException raise];
            NS_ENDHANDLER
            [commandString appendFormat:@"KEY %@ BEGIN\n%@\nKEY %@ END", aKeyID, asciiExport, aKeyID];
            [tempContext release];
            break;
        }
    }
    [commandString appendString:@"\n"]; // Terminate last line
    
    helper = [[self alloc] init];
    aTask = [[NSTask alloc] init];
    [aTask setLaunchPath:launchPath];

    inputPipe = [NSPipe pipe];
    anOutputPipe = [NSPipe pipe];
    anErrorPipe = [NSPipe pipe];
    [aTask setStandardInput:inputPipe];
    [aTask setStandardOutput:anOutputPipe];
    [aTask setStandardError:anErrorPipe];
    [[NSNotificationCenter defaultCenter] addObserver:helper selector:@selector(gotOutputResults:) name:NSFileHandleReadToEndOfFileCompletionNotification object:[anOutputPipe fileHandleForReading]];
    [[NSNotificationCenter defaultCenter] addObserver:helper selector:@selector(gotErrorResults:) name:NSFileHandleReadToEndOfFileCompletionNotification object:[anErrorPipe fileHandleForReading]];
    [[NSNotificationCenter defaultCenter] addObserver:helper selector:@selector(taskEnded:) name:NSTaskDidTerminateNotification object:aTask];
    [[anOutputPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
    [[anErrorPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];

    helper->task = aTask;
    helper->context = [theContext retain];
    helper->argument = [theArgument copy];
    helper->outputPipe = [anOutputPipe retain];
    helper->errorPipe = [anErrorPipe retain];
    helper->hostName = [aHostName retain];
    helper->hostPort = [port retain];
    helper->protocolName = [aProtocol retain];
    helper->serverOptions = [options copy];
    helper->command = theCommand;
    helper->passedOptions = [thePassedOptions copy];
    helper->resultKeys = [[thePassedOptions objectForKey:@"_keys"] retain];
    if(helper->resultKeys == nil)
        helper->resultKeys = [[NSMutableArray alloc] init];
    helper->version = formatVersion;
    helper->taskHandlerLock = [[NSConditionLock alloc] initWithCondition:2]; // 2 pipes to read

    if(needsLocking)
        [_helperPerContextLock lock];
    NS_DURING
        NSMapInsertKnownAbsent(_helperPerContext, theContext, helper);
        switch(theCommand){
            case _GPGContextHelperGetCommand:
                [theContext setOperationMask:KeyDownloadOperation]; break;
            case _GPGContextHelperSearchCommand:
                [theContext setOperationMask:RemoteKeyListingOperation]; break;
            case _GPGContextHelperUploadCommand:
                [theContext setOperationMask:KeyUploadOperation]; break;
        }
        [[theContext operationData] setObject:commandString forKey:@"_command"]; // Useful for debugging

        [aTask launch];
        [[inputPipe fileHandleForWriting] writeData:[commandString dataUsingEncoding:NSUTF8StringEncoding]];
    NS_HANDLER
        gpgme_error_t	anError = gpgme_err_make(GPG_MacGPGMEFrameworkErrorSource, GPGErrorGeneralError);

        [[inputPipe fileHandleForWriting] closeFile];
        [gpgOptions release];
        [commandString release];
        [helper release];
        [[theContext operationData] setObject:[NSNumber numberWithUnsignedInt:anError] forKey:GPGErrorKey];
        NSMapRemove(_helperPerContext, theContext);
        if(needsLocking)
            [_helperPerContextLock unlock];
        [[NSException exceptionWithGPGError:anError userInfo:[NSDictionary dictionaryWithObject:[localException reason] forKey:GPGAdditionalReasonKey]] raise];
    NS_ENDHANDLER

    [[inputPipe fileHandleForWriting] closeFile];
    [gpgOptions release];
    [commandString release];
    if(needsLocking)
        [_helperPerContextLock unlock];
    // helper will release itself after task terminates
}

+ (void) helpContext:(GPGContext *)theContext searchingForKeysMatchingPatterns:(NSArray *)theSearchPatterns serverOptions:(NSDictionary *)thePassedOptions
{
    [self performCommand:_GPGContextHelperSearchCommand forContext:theContext argument:theSearchPatterns serverOptions:thePassedOptions needsLocking:YES];
}

+ (void) helpContext:(GPGContext *)theContext downloadingKeys:(NSArray *)theKeys serverOptions:(NSDictionary *)options
{
    NSEnumerator	*anEnum = [theKeys objectEnumerator];
    GPGKey			*aKey;
    NSMutableArray	*patterns = [NSMutableArray array];

    while(aKey = [anEnum nextObject])
        [patterns addObject:[aKey keyID]];
    [self performCommand:_GPGContextHelperGetCommand forContext:theContext argument:patterns serverOptions:options needsLocking:YES];
}

+ (void) helpContext:(GPGContext *)theContext uploadingKeys:(NSArray *)theKeys serverOptions:(NSDictionary *)options
{
    [self performCommand:_GPGContextHelperUploadCommand forContext:theContext argument:theKeys serverOptions:options needsLocking:YES];
}

- (void) interrupt
{
    interrupted = YES;
    [task interrupt];
}

- (void) handleResults
{
    // WARNING: might be executed in a secondary thread
    NSNotification	*aNotification = nil;
    
    [_helperPerContextLock lock];
    NS_DURING
        int	terminationStatus = [task terminationStatus];
        
        if(!interrupted){
            if(terminationStatus != 0){
                // In case of multiple search patterns, we stop after first error
                gpgme_error_t	anError = gpgme_err_make(GPG_MacGPGMEFrameworkErrorSource, GPGErrorKeyServerError);
                NSString        *aString = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
                
                if([aString hasPrefix:@"gpgkeys: "])
                    aString = [[[aString autorelease] substringFromIndex:9] copy];
                
                aNotification = [NSNotification notificationWithName:GPGAsynchronousOperationDidTerminateNotification object:context userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:anError], GPGErrorKey, aString, GPGAdditionalReasonKey, nil]];
                [aString release];
            }
            else{
                NSMutableDictionary	*passedData = [NSMutableDictionary dictionaryWithObject:outputData forKey:@"readData"];
                unsigned            aCount = [argument count];
                
                [self performSelectorOnMainThread:@selector(passResultsBackFromData:) withObject:passedData waitUntilDone:YES];
                
                if(command == _GPGContextHelperSearchCommand && aCount > 1)
                    [self performSelectorOnMainThread:@selector(startSearchForNextPattern:) withObject:[passedData objectForKey:@"_keys"] waitUntilDone:YES];
                else if(command == _GPGContextHelperUploadCommand && aCount > 1)
                    [self performSelectorOnMainThread:@selector(startUploadForNextKey:) withObject:[passedData objectForKey:@"_keys"] waitUntilDone:YES];
                else
                    aNotification = [NSNotification notificationWithName:GPGAsynchronousOperationDidTerminateNotification object:context userInfo:[NSDictionary dictionaryWithObject:[passedData objectForKey:GPGErrorKey] forKey:GPGErrorKey]];
            }
        }
        else{
            // When interrupted, when send notif anyway with error?
            gpgme_error_t	anError = gpgme_err_make(GPG_MacGPGMEFrameworkErrorSource, GPG_ERR_CANCELED);
            
            aNotification = [NSNotification notificationWithName:GPGAsynchronousOperationDidTerminateNotification object:context userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:anError] forKey:GPGErrorKey]];
        }
    NS_HANDLER
        NSMapRemove(_helperPerContext, context);
        [self autorelease];
        [_helperPerContextLock unlock];
        // taskHandlerLock is not locked at that time
        [localException raise];
    NS_ENDHANDLER
    
    // taskHandlerLock is not locked at that time
    if(aNotification != nil){
        NSMapRemove(_helperPerContext, context);
        [_helperPerContextLock unlock];
        [self performSelectorOnMainThread:@selector(postNotificationInMainThread:) withObject:aNotification waitUntilDone:YES];
    }
    else
        [_helperPerContextLock unlock];
    
    [self release];
}

- (void) taskEnded:(NSNotification *)notification
{
    [[outputPipe fileHandleForWriting] closeFile]; // Needed, else is blocking on read()!
    [[errorPipe fileHandleForWriting] closeFile]; // Needed, else is blocking on read()!
    [[NSNotificationCenter defaultCenter] removeObserver:self name:[notification name] object:[notification object]];
}

- (NSArray *) keysFromOutputString:(NSString *)outputString
{
    NSEnumerator		*anEnum = [[outputString componentsSeparatedByString:@"\n"] objectEnumerator];
    NSString			*aLine;
    int					aCount = -1;
    NSMutableDictionary	*linesPerKeyID = [NSMutableDictionary dictionary];
    int					aVersion = 0;

    while(aLine = [anEnum nextObject]){
        if([aLine hasPrefix:@"VERSION "])
            aVersion = [[aLine substringFromIndex:8] intValue];
        else if([aLine hasPrefix:@"COUNT "]){
            // Used only for version 0, currently
            int	i = 0;

            NSAssert(aVersion == 0, @"### Unknown output format if not version 0 ###");
            aCount = [[aLine substringFromIndex:6] intValue];
            for(; i < aCount; i++){
                int				anIndex;
                NSString		*aKeyID;
                NSMutableArray	*anArray;

                aLine = [anEnum nextObject];
                anIndex = [aLine rangeOfString:@":"].location;
                aKeyID = [aLine substringToIndex:anIndex];
                anArray = [linesPerKeyID objectForKey:aKeyID];
                if(anArray == nil)
                    [linesPerKeyID setObject:[NSMutableArray arrayWithObject:aLine] forKey:aKeyID];
                else
                    [anArray addObject:aLine];
            }
            break;
        }
        else if([aLine hasPrefix:@"info:1:"]){
            // Followed by a number telling how many public keys are listed
            // Used only for version 1, currently, but optional!
            NSAssert(aVersion == 1, @"### Unknown output format if not version 1 ###");
            aCount = [[aLine substringFromIndex:7] intValue];
        }
        else if([aLine hasPrefix:@"pub:"]){
            // Used only for version 1, currently
            int	i = 0;
            BOOL	hadCount = (aCount > 0);

            NSAssert(aVersion == 1, @"### Unknown output format if not version 1 ###");
            if(!hadCount)
                aCount = 1;
            for(; i < aCount; i++){
                if([aLine hasPrefix:@"pub:"]){
                    int				anIndex;
                    unsigned		aLength = [aLine length];
                    NSString		*aKeyID;
                    NSMutableArray	*anArray;

                    anIndex = [aLine rangeOfString:@":" options:0 range:NSMakeRange(4, aLength - 4)].location;
                    aKeyID = [aLine substringWithRange:NSMakeRange(4, aLength - anIndex)];
                    anArray = [NSMutableArray arrayWithObject:aLine];
                    [linesPerKeyID setObject:anArray forKey:aKeyID];
                    while(aLine = [anEnum nextObject]){
                        if([aLine hasPrefix:@"uid:"])
                            [anArray addObject:aLine];
                        else if([aLine hasPrefix:@"pub:"]){
                            if(!hadCount)
                                aCount++;
                            break;
                        }
                        else if([aLine hasPrefix:@"SEARCH "] || [aLine length] == 0)
                            // SEARCH ... END
                            break;
                        else if(![aLine isEqualToString:@"\r"])
                            NSLog(@"### Unable to parse following line. Ignored.\n%@", aLine);
                    }
                }
                else
                    NSLog(@"### Expecting 'pub:' prefix in following line. Ignored.\n%@", aLine);

            }
            break;
        }
//        else if([aLine hasPrefix:@"SEARCH "] && [aLine rangeOfString:@" FAILED "].location != NSNotFound){
//        }
//        else if([aLine hasPrefix:@"KEY 0x"] && [aLine rangeOfString:@" FAILED "].location != NSNotFound){
//        }
    }
    if(aCount == -1)
        return nil;
    else{
        NSArray			*anArray;
        NSMutableArray	*keys = [NSMutableArray array];

        anEnum = [linesPerKeyID objectEnumerator]; // We loose the order; no cure.
        while(anArray = [anEnum nextObject]){
            GPGRemoteKey	*aKey = [[GPGRemoteKey alloc] initWithColonOutputStrings:anArray version:aVersion];
            
            [keys addObject:aKey];
            [aKey release];
        }
        return keys;
    }
}

- (void) postNotificationInMainThread:(NSNotification *)notification
{
    [[[notification object] operationData] setObject:[[notification userInfo] objectForKey:GPGErrorKey] forKey:GPGErrorKey];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
}

- (void) passResultsBackFromData:(NSMutableDictionary *)dict
{
    // Executed in main thread
    GPGError	anError = GPGErrorNoError;
    NSData		*readData = [dict objectForKey:@"readData"];

    switch(command){
        case _GPGContextHelperGetCommand:{
            anError = [context _importKeyDataFromServerOutput:readData];
            break;
        }
        case _GPGContextHelperSearchCommand:{
            // It happens that output data is a mix of correct UTF8 userIDs
            // and invalid ISOLatin1 userIDs! If we decode using UTF8, it will fail,
            // and all UTF8 userIDs will be displayed badly, because decoded as ISOLatin1.
            // We need to decode one line after the other.
            const unsigned char *bytes = [readData bytes];
            const unsigned char *readPtr = bytes;
            const unsigned char *endPtr = (bytes + [readData length]);
            NSMutableArray      *lines = [[NSMutableArray alloc] init];
            NSString            *rawResults;
            NSArray             *keys;

            while(readPtr < endPtr){
                // We consider that line endings contain \n (works also for \r\n)
                const unsigned char *aPtr = memchr(readPtr, '\n', endPtr - readPtr);
                NSString            *aLine;
                NSData				*lineData;
                
                if(aPtr == NULL)
                    aPtr = endPtr;

                lineData = [[NSData alloc] initWithBytes:readPtr length:(aPtr - readPtr)];
                aLine = [[NSString alloc] initWithData:lineData encoding:NSUTF8StringEncoding];
                
                if(aLine == nil)
                    // We consider that if we cannot decode string as UTF-8 encoded,
                    // then we use ISOLatin1 encoding.
                    aLine = [[NSString alloc] initWithData:lineData encoding:NSISOLatin1StringEncoding];
                [lines addObject:aLine];
                readPtr = aPtr + 1;
                [lineData release];
                [aLine release];
            }
            
            rawResults = [lines componentsJoinedByString:@"\n"];
            keys = [self keysFromOutputString:rawResults];

            if(keys != nil){
                // Support for multiple search patterns
                [resultKeys addObjectsFromArray:keys];
                [dict setObject:resultKeys forKey:@"_keys"];
                [[context operationData] setObject:resultKeys forKey:@"keys"];
            }
            [lines release];
        }
        case _GPGContextHelperUploadCommand:{
            // Parse output to find out if everything went fine
            // and add uploaded key to [dict setObject:resultKeys forKey:@"_keys"]
        }            
    }

    [[context operationData] setObject:hostName forKey:@"hostName"];
    [[context operationData] setObject:protocolName forKey:@"protocol"];
    [[context operationData] setObject:serverOptions forKey:@"options"];
    if(hostPort)
        [[context operationData] setObject:hostPort forKey:@"port"];
    [dict setObject:[NSNumber numberWithUnsignedInt:anError] forKey:GPGErrorKey];
}

- (void) startSearchForNextPattern:(NSArray *)fetchedKeys
{
    // Executed in main thread
    NSMutableDictionary *aDict = [NSMutableDictionary dictionaryWithDictionary:passedOptions];
    
	if(fetchedKeys != nil) //only set the remaining patterns if the array is not nil
		[aDict setObject:fetchedKeys forKey:@"_keys"];
    NSMapRemove(_helperPerContext, context);
    [[self class] performCommand:command forContext:context argument:[argument subarrayWithRange:NSMakeRange(1, [argument count] - 1)] serverOptions:aDict needsLocking:NO];
}

- (void) startUploadForNextKey:(NSArray *)uploadedKeys
{
    // Executed in main thread
    NSMutableDictionary *aDict = [NSMutableDictionary dictionaryWithDictionary:passedOptions];

    [aDict setObject:uploadedKeys forKey:@"_keys"];
    NSMapRemove(_helperPerContext, context);
    [[self class] performCommand:command forContext:context argument:[argument subarrayWithRange:NSMakeRange(1, [argument count] - 1)] serverOptions:aDict needsLocking:NO];
}

- (void) handleResultsIfPossible
{
    // WARNING: might be executed in a secondary thread
    BOOL    lockCondition;
    
    [taskHandlerLock lock];
    lockCondition = [taskHandlerLock condition];
    [taskHandlerLock unlockWithCondition:lockCondition - 1];
    if(lockCondition == 1)
        [self handleResults];
}

- (void) gotErrorResults:(NSNotification *)notification
{
    // WARNING: might be executed in a secondary thread
    errorData = [[[notification userInfo] objectForKey:NSFileHandleNotificationDataItem] copy];
    [self handleResultsIfPossible];
}

- (void) gotOutputResults:(NSNotification *)notification
{
    // WARNING: might be executed in a secondary thread
    outputData = [[[notification userInfo] objectForKey:NSFileHandleNotificationDataItem] copy];
    [self handleResultsIfPossible];
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [context release];
    [task release];
    [argument release];
    [outputPipe release];
    [errorPipe release];
    [hostName release];
    [hostPort release];
    [protocolName release];
    [serverOptions release];
    [passedOptions release];
    [resultKeys release];
    [errorData release];
    [outputData release];
    [taskHandlerLock release];

    [super dealloc];
}

@end


@implementation GPGContext(GPGExtendedKeyManagement)

- (void) asyncSearchForKeysMatchingPatterns:(NSArray *)searchPatterns serverOptions:(NSDictionary *)options
{
    // TODO: Add support for multiple keyservers: combine results, and stop when all tasks stopped
    NSParameterAssert(searchPatterns != nil && [searchPatterns count] > 0);

    if([self protocol] != GPGOpenPGPProtocol)
        [[NSException exceptionWithGPGError:gpgme_err_make(GPG_MacGPGMEFrameworkErrorSource, GPGErrorNotImplemented) userInfo:nil] raise];

    [_GPGContextHelper helpContext:self searchingForKeysMatchingPatterns:searchPatterns serverOptions:options];
}

- (void) asyncDownloadKeys:(NSArray *)keys serverOptions:(NSDictionary *)options
{
    NSParameterAssert(keys != nil && [keys count] > 0);

    if([self protocol] != GPGOpenPGPProtocol)
        [[NSException exceptionWithGPGError:gpgme_err_make(GPG_MacGPGMEFrameworkErrorSource, GPGErrorNotImplemented) userInfo:nil] raise];
    [_GPGContextHelper helpContext:self downloadingKeys:keys serverOptions:options];
}

- (GPGError) _importKeyDataFromServerOutput:(NSData *)result
{
    // We don't need to parse rawData: keys are ASCII-armored,
    // and gpg is able to recognize armors :-)
    GPGData				*keyData = [[GPGData alloc] initWithData:result];
    NSMutableDictionary	*savedOperationData = [_operationData mutableCopy];
    int					savedOperationMask = _operationMask;
    GPGError			resultError = GPGErrorNoError;
    
    [keyData setEncoding:GPGDataEncodingArmor];
    NS_DURING
        // WARNING: this changes operation mask & data!
        (void)[self importKeyData:keyData];
    NS_HANDLER
        // Should we pass error back to result?
        if([[localException name] isEqualToString:GPGException])
            resultError = [[[localException userInfo] objectForKey:GPGErrorKey] unsignedIntValue];
        else{
            [keyData release];
            [savedOperationData release];
            [localException raise];
        }
    NS_ENDHANDLER
    [keyData release];
    _operationMask |= savedOperationMask;
    [_operationData addEntriesFromDictionary:savedOperationData];
    [savedOperationData release];

    return resultError;
}

- (void) asyncUploadKeys:(NSArray *)keys serverOptions:(NSDictionary *)options
{
#warning TEST!
    NSParameterAssert(keys != nil && [keys count] > 0);

    if([self protocol] != GPGOpenPGPProtocol)
        [[NSException exceptionWithGPGError:gpgme_err_make(GPG_MacGPGMEFrameworkErrorSource, GPGErrorNotImplemented) userInfo:nil] raise];
    [_GPGContextHelper helpContext:self uploadingKeys:keys serverOptions:options];
}

- (void) interruptAsyncOperation
{
    _GPGContextHelper	*helper;
    
    [_helperPerContextLock lock];
    NS_DURING
        helper = NSMapGet(_helperPerContext, self);
        if(helper != nil)
            [helper interrupt];
    NS_HANDLER
        [_helperPerContextLock unlock];
        [localException raise];
    NS_ENDHANDLER
    [_helperPerContextLock unlock];
}


- (BOOL) isPerformingAsyncOperation
{
    return (NSMapGet(_helperPerContext, self) != nil);
}

@end


@implementation GPGContext(GPGKeyGroups)

- (NSArray *) keyGroups
{
    GPGOptions          *options = [self options];
    NSArray             *groupOptionValues = [options activeOptionValuesForName:@"group"];
    NSEnumerator        *groupDefEnum = [groupOptionValues objectEnumerator];
    NSMutableDictionary *groupsPerName = [NSMutableDictionary dictionaryWithCapacity:[groupOptionValues count]];
    NSString            *aGroupDefinition;
    
    while((aGroupDefinition = [groupDefEnum nextObject]) != nil){
        NSDictionary    *aDict = [[self class] parsedGroupDefinitionLine:aGroupDefinition];
        GPGKeyGroup     *newGroup;
        NSString        *aName;
        NSArray         *keys;
        NSArray         *additionalKeys = nil;
        
        if(aDict == nil)
            continue;
        
        aName = [aDict objectForKey:@"name"];
        newGroup = [groupsPerName objectForKey:aName];
        if(newGroup){
            // Multiple groups with the same name are automatically merged
            // into a single group.
            additionalKeys = [newGroup keys];
        }
                
        keys = [aDict objectForKey:@"keys"];
        if([keys count] > 0)
            keys = [[self keyEnumeratorForSearchPatterns:keys secretKeysOnly:NO] allObjects];

        newGroup = [[GPGKeyGroup alloc] initWithName:aName keys:(additionalKeys ? [additionalKeys arrayByAddingObjectsFromArray:keys] : keys)];
        
        [groupsPerName setObject:newGroup forKey:aName];
        [newGroup release];
    }
    
    return [groupsPerName allValues];
}

@end

@implementation GPGContext(GPGInternals)

- (gpgme_ctx_t) gpgmeContext
{
    return _context;
}

- (void) setOperationMask:(int)flags
{
    _operationMask = flags;
    [_operationData removeAllObjects];
}

- (NSMutableDictionary *) operationData
{
    return _operationData;
}

+ (NSDictionary *) parsedGroupDefinitionLine:(NSString *)groupDefLine
{
    int         anIndex = [groupDefLine rangeOfString:@"="].location;
    NSString    *aName;
    
    if(anIndex == NSNotFound){
        NSLog(@"### Invalid group definition:\n%@", groupDefLine);
        return nil; // This is an invalid group definition! Let's ignore it
    }
    
    aName = [groupDefLine substringToIndex:anIndex];
    aName = [aName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if([aName length] == 0){
        NSLog(@"### Invalid group definition - empty name:\n%@", groupDefLine);
        return nil; // This is an invalid group definition! Let's ignore it
    }
    
    if(anIndex < ([groupDefLine length] - 1)){
        // We accept only keyIDs or fingerprints, separated by a space or a tab
        NSMutableString *aString = [NSMutableString stringWithString:[[groupDefLine substringFromIndex:anIndex + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
        
        [aString replaceOccurrencesOfString:@"\t" withString:@" " options:0 range:NSMakeRange(0, [aString length])];
        while([aString replaceOccurrencesOfString:@"  " withString:@" " options:0 range:NSMakeRange(0, [aString length])] != 0)
            ;
        
        return [NSDictionary dictionaryWithObjectsAndKeys:[aString componentsSeparatedByString:@" "], @"keys", aName, @"name", nil];
    }
    else
        return [NSDictionary dictionaryWithObjectsAndKeys:[NSArray array], @"keys", aName, @"name", nil];
}

@end


@implementation GPGSignerKeyEnumerator

- (id) initForContext:(GPGContext *)newContext
{
    if(self = [self init]){
        // We retain newContext, to avoid it to be released before we are finished
        context = [newContext retain];
    }

    return self;
}

- (void) dealloc
{
    [context release];

    [super dealloc];
}

- (id) nextObject
{
    gpgme_key_t	aKey = gpgme_signers_enum([context gpgmeContext], index); // Acquires a reference to the signers key with the specified index
    GPGKey		*returnedKey;

    if(aKey == NULL)
        return nil;
    index++;
    // Returned signer has already been retained by call gpgme_signers_enum(),
    // and calling -[GPGKey initWithInternalRepresentation:] retains it
    // too => we need to release it once.
    returnedKey = [[GPGKey alloc] initWithInternalRepresentation:aKey];
    gpgme_key_unref(aKey);
    
    return [returnedKey autorelease];
}

@end


@implementation GPGKeyEnumerator

- (id) initForContext:(GPGContext *)newContext searchPattern:(NSString *)searchPattern secretKeysOnly:(BOOL)secretKeysOnly
{
    if(self = [self init]){
        gpgme_error_t	anError;
        const char		*aPattern = (searchPattern != nil ? [searchPattern UTF8String]:NULL);

        anError = gpgme_op_keylist_start([newContext gpgmeContext], aPattern, secretKeysOnly);
        [newContext setOperationMask:KeyListingOperation];
        [[newContext operationData] setObject:[NSNumber numberWithUnsignedInt:anError] forKey:GPGErrorKey];

        if(anError != GPG_ERR_NO_ERROR){
            [self release];
            [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
        }
        else
            // We retain newContext, to avoid it to be released before we have finished
            context = [newContext retain];
    }

    return self;
}

- (id) initForContext:(GPGContext *)newContext searchPatterns:(NSArray *)searchPatterns secretKeysOnly:(BOOL)secretKeysOnly
{
    NSParameterAssert(searchPatterns != nil);
    
    if(self = [self init]){
        gpgme_error_t	anError;
        int				i, patternCount = [searchPatterns count];
        const char		**patterns;

        patterns = NSZoneMalloc(NSDefaultMallocZone(), (patternCount + 1) * sizeof(char *));
        for(i = 0; i < patternCount; i++)
            patterns[i] = [[searchPatterns objectAtIndex:i] UTF8String];
        patterns[i] = NULL;

        anError = gpgme_op_keylist_ext_start([newContext gpgmeContext], patterns, secretKeysOnly, 0);
        [newContext setOperationMask:KeyListingOperation];
        [[newContext operationData] setObject:[NSNumber numberWithUnsignedInt:anError] forKey:GPGErrorKey];
        NSZoneFree(NSDefaultMallocZone(), patterns);

        if(anError != GPG_ERR_NO_ERROR){
            [self release];
            [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
        }
        else
            // We retain newContext, to avoid it to be released before we are finished
            context = [newContext retain];
    }

    return self;
}

- (void) dealloc
{
    gpgme_error_t	anError = GPG_ERR_NO_ERROR;
    
    if(context != nil){
        anError = gpgme_op_keylist_end([context gpgmeContext]);
        // We don't care about the key listing operation result
        [context autorelease]; // Do not release it, we might need it for exception
    }

    [super dealloc];

    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:[NSDictionary dictionaryWithObject:context forKey:GPGContextKey]] raise];
}

- (id) nextObject
{
    gpgme_key_t		aKey;
    gpgme_error_t	anError;
    GPGKey          *returnedKey;
    
    NSAssert(context != nil, @"### Enumerator is invalid now, because an exception was raised during enumeration.");
    anError = gpgme_op_keylist_next([context gpgmeContext], &aKey); // Returned key has one reference
    if(gpg_err_code(anError) == GPG_ERR_EOF){
        gpgme_keylist_result_t	result = gpgme_op_keylist_result([context gpgmeContext]);

        if(!!result->truncated)
            [[NSException exceptionWithGPGError:GPGMakeError(GPG_MacGPGMEFrameworkErrorSource, GPGErrorTruncatedKeyListing) userInfo:[NSDictionary dictionaryWithObject:context forKey:GPGContextKey]] raise];
        return nil;
    }
    
    if(anError != GPG_ERR_NO_ERROR){
        // We release and nullify context; we don't want another exception
        // being raised during -dealloc, as we call gpgme_op_keylist_end().
        GPGContext	*aContext = context;

        context = nil;
        [aContext autorelease]; // Do not release it: we need it for exception
        [[NSException exceptionWithGPGError:anError userInfo:[NSDictionary dictionaryWithObject:aContext forKey:GPGContextKey]] raise];
    }

    NSAssert(aKey != NULL, @"### Returned key is NULL, but no error?!");

    returnedKey = [[[GPGKey alloc] initWithInternalRepresentation:aKey] autorelease];
    gpgme_key_unref(aKey);
    
    return returnedKey;
}

@end


@implementation GPGTrustItemEnumerator

- (id) initForContext:(GPGContext *)newContext searchPattern:(NSString *)searchPattern maximumLevel:(int)maxLevel
{
    NSParameterAssert(searchPattern != nil && [searchPattern length] > 0);
    
    if(self = [self init]){
        gpgme_error_t	anError;
        const char		*aPattern = [searchPattern UTF8String];

        anError = gpgme_op_trustlist_start([newContext gpgmeContext], aPattern, maxLevel);
        [newContext setOperationMask:TrustItemListingOperation];
        [[newContext operationData] setObject:[NSNumber numberWithUnsignedInt:anError] forKey:GPGErrorKey];

        if(anError != GPG_ERR_NO_ERROR){
            [self release];
            [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
        }
        else
            // We retain newContext, to avoid it to be released before we are finished
            context = [newContext retain];
    }

    return self;
}

- (void) dealloc
{
    gpgme_error_t	anError;

    if(context != nil){
        anError = gpgme_op_trustlist_end([context gpgmeContext]);
        [context release];
    }
    else
        anError = GPG_ERR_NO_ERROR;

    [super dealloc];

    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
}

- (id) nextObject
{
    gpgme_trust_item_t	aTrustItem;
    gpgme_error_t		anError = gpgme_op_trustlist_next([context gpgmeContext], &aTrustItem);

    // Q: Does it really return a GPG_ERR_EOF?
    // Answer from Werner: "It should, but well I may have to change things. Don't spend too much time on it yet."
    if(gpg_err_code(anError) == GPG_ERR_EOF)
        return nil;

    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];

    NSAssert(aTrustItem != NULL, @"### Returned trustItem is NULL, but no error?!");

    // Always return a new trustItem, with 1 ref -> will be unref'd when dealloc'd
    return [[[GPGTrustItem alloc] initWithInternalRepresentation:aTrustItem] autorelease];
}

@end
