/*
 Copyright © Roman Zechmeister, 2011
 
 Dieses Programm ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung dieses Programms erfolgt in der Hoffnung, daß es Ihnen 
 von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite 
 Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck. 
 Details finden Sie in der GNU General Public License.
 
 Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem 
 Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
*/

#import "ActionController.h"
#import "KeychainController.h"
#import "SheetController.h"


@implementation ActionController


//TODO: Fotos die auf mehrere Subpakete aufgeteilt sind.
//TODO: Fehlermeldungen wenn eine Aktion fehlschlägt.
//TODO: Geschätzte Sicherheit - Genauere Informationen.
//TODO: Algorithmus Preferänzen
//TODO: "…" zu manchen Französischen Menüeinträgen hinzufügen.



- (NSSet *)selectedKeyInfos {
	NSInteger clickedRow = [keyTable clickedRow];
	if (clickedRow != -1 && ![keyTable isRowSelected:clickedRow]) {
		return [NSSet setWithObject:[[keyTable itemAtRow:clickedRow] representedObject]];
	} else {
		return keyInfoSet([keysController selectedObjects]);
	}
}


- (BOOL)validateUserInterfaceItem:(id)anItem {
    SEL selector = [anItem action];
	
    if (selector == @selector(copy:)) {
		if ([[self selectedKeyInfos] count] >= 1) {
			return YES;
		}
		return NO;
    } else if (selector == @selector(paste:)) {
		NSPasteboard *pboard = [NSPasteboard generalPasteboard];
		if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]] != nil) {
			NSString *string = [pboard stringForType:NSStringPboardType];
			if (containsPGPKeyBlock(string)) {
				return YES;
			} else {
				return NO;
			}
		}
    } else if (selector == @selector(genRevokeCertificate:)) {
		NSSet *keyInfos = [self selectedKeyInfos];
		if ([keyInfos count] == 1 && ((GPGKey*)[keyInfos anyObject]).secret) {
			return YES;
		}
		return NO;
    } else if (selector == @selector(editAlgorithmPreferences:)) {
		NSSet *keyInfos = [self selectedKeyInfos];
		if ([keyInfos count] == 1) {
			return YES;
		}
		return NO;
	}
	return YES;
}


- (IBAction)copy:(id)sender {
	NSSet *keyInfos = [self selectedKeyInfos];
	if ([keyInfos count] > 0) {
		NSString *exportedKeys = dataToString([self exportKeys:keyInfos armored:YES allowSecret:NO fullExport:NO]);
		if ([exportedKeys length] > 0) {
			NSPasteboard *pboard = [NSPasteboard generalPasteboard];
			[pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
			[pboard setString:exportedKeys forType:NSStringPboardType];
		}
	}
}
- (IBAction)paste:(id)sender {
	NSPasteboard *pboard = [NSPasteboard generalPasteboard];
	NSData *data = [pboard dataForType:NSStringPboardType];
	
	if (data) {
		[self importFromData:data];
	}
}



- (IBAction)editAlgorithmPreferences:(id)sender {
	NSSet *keyInfos = [self selectedKeyInfos];
	if ([keyInfos count] == 1) {
		GPGKey *keyInfo = [keyInfos anyObject];
		SheetController *sheetController = [SheetController sharedInstance];
		[sheetController algorithmPreferences:keyInfo editable:[keyInfo secret]];
	}	
}
- (void)editAlgorithmPreferencesForKey:(GPGKey *)keyInfo preferences:(NSArray *)preferencesList {
	[self registerUndoForKey:keyInfo withName:@"Undo_AlgorithmPreferences"];

	for (NSDictionary *preferences in preferencesList) {
		GPGUserID *userID = [preferences objectForKey:@"userID"];
		NSString *cipherPreferences = [[preferences objectForKey:@"cipherPreferences"] componentsJoinedByString:@" "];
		NSString *digestPreferences = [[preferences objectForKey:@"digestPreferences"] componentsJoinedByString:@" "];
		NSString *compressPreferences = [[preferences objectForKey:@"compressPreferences"] componentsJoinedByString:@" "];
		
		[gpgc setAlgorithmPreferences:[NSString stringWithFormat:@"%@ %@ %@", cipherPreferences, digestPreferences, compressPreferences] forUserID:[userID hashID] ofKey:keyInfo];
	}
	
	[keychainController asyncUpdateKeyInfo:keyInfo];
}



- (NSString *)importResultWithStatusText:(NSString *)statusText {
	NSMutableString *retString = [NSMutableString string];
	NSScanner *scanner = [NSScanner scannerWithString:statusText];
	NSCharacterSet *hexCharSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"];
	NSUInteger length = [statusText length];
	
	NSInteger flags;
	NSString *fingerprint;
	NSString *userID;
	NSString *keyID;
	
	NSRange range = {0, length};
	
	
	while ((range = [statusText rangeOfString:@"[GNUPG:] IMPORT_OK " options:NSLiteralSearch range:range]).length > 0) {
		[scanner setScanLocation:range.location + 19];
		[scanner scanInteger:&flags];
		
		if (flags > 0) {
			[scanner scanCharactersFromSet:hexCharSet intoString:&fingerprint];
			userID = [[[keychainController keychain] objectForKey:fingerprint] userID];
			keyID = getShortKeyID(fingerprint);

			if (flags & 1) {
				if (flags & 16) {
					[retString appendFormat:localized(@"key %@: secret key imported\n"), keyID];
				} else {
					[retString appendFormat:localized(@"key %@: public key \"%@\" imported\n"), keyID, userID];
				}
			}
			if (flags & 2) {
				[retString appendFormat:localized(@"key %@: \"%@\" new user ID(s)\n"), keyID, userID];
			}
			if (flags & 4) {
				[retString appendFormat:localized(@"key %@: \"%@\" new signature(s)\n"), keyID, userID];
			}
			if (flags & 8) {
				[retString appendFormat:localized(@"key %@: \"%@\" new subkey(s)\n"), keyID, userID];
			}
		}
		
		range.location += range.length;
		range.length = length - range.location;
	}
		
	if ([retString length] == 0) {
		[retString setString:localized(@"Nothing imported!")];
	}
	
	return retString;
}



- (IBAction)cleanKey:(id)sender {
	NSSet *keyInfos = [self selectedKeyInfos];
	if ([keyInfos count] > 0) {
		[self registerUndoForKeys:keyInfos withName:@"Undo_Clean"];
		
		for (GPGKey *keyInfo in keyInfos) {
			[gpgc cleanKey:keyInfo];
		}
		[keychainController asyncUpdateKeyInfos:keyInfos];
	}
}
- (IBAction)minimizeKey:(id)sender {
	NSSet *keyInfos = [self selectedKeyInfos];
	if ([keyInfos count] > 0) {
		[self registerUndoForKeys:keyInfos withName:@"Undo_Minimize"];

		for (GPGKey *keyInfo in keyInfos) {
			[gpgc minimizeKey:keyInfo];
		}
		[keychainController asyncUpdateKeyInfos:keyInfos];
	}
}


- (IBAction)addPhoto:(NSButton *)sender {
	NSSet *keyInfos = [self selectedKeyInfos];
	if ([keyInfos count] == 1) {
		GPGKey *keyInfo = [[keyInfos anyObject] primaryKey];
		SheetController *sheetController = [SheetController sharedInstance];
		
		[sheetController addPhoto:keyInfo];
	}
}
- (void)addPhotoForKeyInfo:(GPGKey *)keyInfo photoPath:(NSString *)path {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self registerUndoForKey:keyInfo withName:@"Undo_AddPhoto"];
	
	[gpgc addPhotoFromPath:path toKey:keyInfo];
	
	[keychainController updateKeyInfos:[NSArray arrayWithObject:keyInfo]];
	[pool drain];
}

- (IBAction)removePhoto:(NSButton *)sender {
	if ([photosController selectionIndex] != NSNotFound) {
		NSSet *keyInfos = [self selectedKeyInfos];		
		GPGKey *keyInfo = [[keyInfos anyObject] primaryKey];
		[self registerUndoForKey:keyInfo withName:@"Undo_RemovePhoto"];
		
		[gpgc removeUserID:[[[photosController selectedObjects] objectAtIndex:0] hashID] fromKey:keyInfo];

		[keychainController asyncUpdateKeyInfos:keyInfos];
	}
}
- (IBAction)revokePhoto:(NSButton *)sender {
	if ([photosController selectionIndex] != NSNotFound) {
		NSSet *keyInfos = [self selectedKeyInfos];		
		GPGKey *keyInfo = [[keyInfos anyObject] primaryKey];
		[self registerUndoForKey:keyInfo withName:@"Undo_RevokePhoto"];

		[gpgc revokeUserID:[[[photosController selectedObjects] objectAtIndex:0] hashID] fromKey:keyInfo reason:0 description:nil];
		
		[keychainController asyncUpdateKeyInfos:keyInfos];
	}
}

- (IBAction)setPrimaryPhoto:(NSButton *)sender {
	if ([photosController selectionIndex] != NSNotFound) {
		NSSet *keyInfos = [self selectedKeyInfos];		
		GPGKey *keyInfo = [[keyInfos anyObject] primaryKey];
		[self registerUndoForKey:keyInfo withName:@"Undo_PrimaryPhoto"];
		
		[gpgc setPrimaryUserID:[[[photosController selectedObjects] objectAtIndex:0] hashID] ofKey:keyInfo];

		[keychainController asyncUpdateKeyInfos:keyInfos];
	}
}



- (IBAction)importKey:(id)sender {
	SheetController *sheetController = [SheetController sharedInstance];
	[sheetController importKey];
}
- (void)importFromURLs:(NSArray *)urls {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSMutableData *dataToImport = [NSMutableData dataWithCapacity:100000];

	for (NSObject *url in urls) {
		if ([url isKindOfClass:[NSURL class]]) {
			[dataToImport appendData:[NSData dataWithContentsOfURL:(NSURL*)url]];
		} else if ([url isKindOfClass:[NSString class]]) {
			[dataToImport appendData:[NSData dataWithContentsOfFile:(NSString*)url]];
		}
	}
	[self importFromData:dataToImport];
	[pool drain];
}
- (void)importFromData:(NSData *)data {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSSet *keys = [self keysInExportedData:data];
	
	[self registerUndoForKeys:keys withName:@"Undo_Import"];
	
	NSString *statusText = [gpgc importFromData:data fullImport:NO];
	
	[keychainController updateKeyInfos:keys];
	
	SheetController *sheetController = [SheetController sharedInstance];
	[sheetController showResult:[self importResultWithStatusText:statusText]];
	
	[pool drain];
}


- (void)restoreKeys:(NSObject <EnumerationList> *)keys withData:(NSData *)data { //Löscht die übergebenen Schlüssel und importiert data.
	//TODO: Auswahl der Schlüsselliste wiederherstellen.
	[self registerUndoForKeys:keys withName:nil];
	[undoManager disableUndoRegistration];
	[gpgc deleteKeys:keys withMode:GPGDeletePublicAndSecretKey];
	
	if (data && [data length] > 0) {
		[gpgc importFromData:data fullImport:YES];
	}
	
	[keychainController updateKeyInfos:keys];
	[undoManager enableUndoRegistration];
}
- (void)registerUndoForKeys:(NSObject <EnumerationList> *)keys withName:(NSString *)actionName {
	if (useUndo && [undoManager isUndoRegistrationEnabled]) {
		[[undoManager prepareWithInvocationTarget:self] restoreKeys:keys withData:[self exportKeys:keys armored:NO allowSecret:YES fullExport:YES]];
		if (actionName && ![undoManager isUndoing] && ![undoManager isRedoing]) {
			[undoManager setActionName:localized(actionName)];
		}
	}
}
- (void)registerUndoForKey:(NSObject <KeyFingerprint> *)key withName:(NSString *)actionName {
	[self registerUndoForKeys:[NSSet setWithObject:key] withName:actionName];
}


- (IBAction)exportKey:(id)sender {
	NSSet *keyInfos = [self selectedKeyInfos];
	SheetController *sheetController = [SheetController sharedInstance];
	
	[sheetController exportKeys:keyInfos];
}
- (NSData *)exportKeys:(NSObject <EnumerationList> *)keys armored:(BOOL)armored allowSecret:(BOOL)allowSec fullExport:(BOOL)fullExport {
	gpgc.useArmor = armored;
	return [gpgc exportKeys:keys allowSecret:allowSec fullExport:fullExport];
}

- (NSSet *)keysInExportedData:(NSData *)data {
	//TODO: Libmacgpg!
	/*NSData *outData;
	
	if (runGPGCommandWithArray(data, &outData, nil, nil, nil, [NSArray arrayWithObject:@"--with-fingerprint"]) != 0) {
		NSLog(@"keysInExportedData fehlgeschlagen.");
	}
	NSArray *lines = [dataToString(outData) componentsSeparatedByString:@"\n"];
	NSMutableSet *keys = [NSMutableSet setWithCapacity:[lines count] / 3];
	
	for (NSString *line in lines) {
		NSArray *splitedLine = [line componentsSeparatedByString:@":"];
		if ([[splitedLine objectAtIndex:0] isEqualToString:@"fpr"]) {
			[keys addObject:[splitedLine objectAtIndex:9]];
		}
	}
	return keys;*/
	return nil;
}


- (IBAction)genRevokeCertificate:(id)sender {
	NSSet *keyInfos = [self selectedKeyInfos];
	if ([keyInfos count] == 1) {
		SheetController *sheetController = [SheetController sharedInstance];
		[sheetController genRevokeCertificateForKey:[keyInfos anyObject]];
	}
}
- (NSData *)genRevokeCertificateForKey:(GPGKey *)keyInfo {
	return [gpgc generateRevokeCertificateForKey:keyInfo reason:0 description:nil];
}



- (IBAction)addSignature:(id)sender {
	if ([sender tag] != 1 || [userIDsController selectionIndex] != NSNotFound) {
		NSSet *keyInfos = [self selectedKeyInfos];		
		GPGKey *keyInfo = [[keyInfos anyObject] primaryKey];
		SheetController *sheetController = [SheetController sharedInstance];
		
		NSString *userID;
		if ([sender tag] == 1) {
			userID = [[[userIDsController selectedObjects] objectAtIndex:0] userID];
		} else {
			userID = nil;
		}
		
		[sheetController addSignature:keyInfo userID:userID];
	}
}
- (void)addSignatureForKeyInfo:(GPGKey *)keyInfo andUserID:(NSString *)userID signKey:(NSString *)signFingerprint type:(NSInteger)type local:(BOOL)local daysToExpire:(NSInteger)daysToExpire {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self registerUndoForKey:keyInfo withName:@"Undo_AddSignature"];
	
	[gpgc signUserID:userID ofKey:keyInfo signKey:signFingerprint type:type local:local daysToExpire:daysToExpire];
	
	[keychainController updateKeyInfos:[NSArray arrayWithObject:keyInfo]];
	[pool drain];
}

- (IBAction)addSubkey:(NSButton *)sender {
	NSSet *keyInfos = [self selectedKeyInfos];		
	if ([keyInfos count] == 1) {
		GPGKey *keyInfo = [[keyInfos anyObject] primaryKey];
		SheetController *sheetController = [SheetController sharedInstance];
		
		[sheetController addSubkey:keyInfo];
	}
}
- (void)addSubkeyForKeyInfo:(GPGKey *)keyInfo type:(NSInteger)type length:(NSInteger)length daysToExpire:(NSInteger)daysToExpire {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self registerUndoForKey:keyInfo withName:@"Undo_AddSubkey"];

	[gpgc addSubkeyToKey:keyInfo type:type length:length daysToExpire:daysToExpire];

	[keychainController updateKeyInfos:[NSArray arrayWithObject:keyInfo]];
	[pool drain];
}

- (IBAction)addUserID:(NSButton *)sender {
	NSSet *keyInfos = [self selectedKeyInfos];		
	if ([keyInfos count] == 1) {
		GPGKey *keyInfo = [[keyInfos anyObject] primaryKey];
		SheetController *sheetController = [SheetController sharedInstance];
		
		[sheetController addUserID:keyInfo];
	}
}
- (void)addUserIDForKeyInfo:(GPGKey *)keyInfo name:(NSString *)name email:(NSString *)email comment:(NSString *)comment{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self registerUndoForKey:keyInfo withName:@"Undo_AddUserID"];

	[gpgc addUserIDToKey:keyInfo name:name email:email comment:comment];
	
	[keychainController updateKeyInfos:[NSArray arrayWithObject:keyInfo]];
	[pool drain];
}

- (IBAction)changeExpirationDate:(NSButton *)sender {
	BOOL aKeyIsSelected = NO;
	GPGSubkey *subkey;
	
	NSSet *keyInfos = [self selectedKeyInfos];			
	if ([sender tag] == 1 && [[subkeysController selectedObjects] count] == 1) {
		subkey = [[subkeysController selectedObjects] objectAtIndex:0];
		aKeyIsSelected = YES;
	} else if ([sender tag] == 0 && [keyInfos count] == 1) {
		subkey = nil;
		aKeyIsSelected = YES;
	}
	
	if (aKeyIsSelected) {
		GPGKey *keyInfo = [[keyInfos anyObject] primaryKey];
		SheetController *sheetController = [SheetController sharedInstance];
		
		[sheetController changeExpirationDate:keyInfo subkey:subkey];
	}
	
}
- (void)changeExpirationDateForKeyInfo:(GPGKey *)keyInfo subkey:(GPGSubkey *)subkey daysToExpire:(NSInteger)daysToExpire {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self registerUndoForKey:keyInfo withName:@"Undo_ChangeExpirationDate"];
	
	[gpgc setExpirationDateForSubkey:subkey fromKey:keyInfo daysToExpire:daysToExpire];
	
	[keychainController updateKeyInfos:[NSArray arrayWithObject:keyInfo]];
	[pool drain];
}

- (IBAction)searchKeys:(id)sender {
	SheetController *sheetController = [SheetController sharedInstance];
	[sheetController searchKeys];
}
- (NSArray *)searchKeysWithPattern:(NSString *)pattern errorText:(NSString **)errText {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSArray *keys = [[gpgc searchKeysOnServer:pattern] retain];
	
	[pool drain];
	return [keys autorelease];
}




- (IBAction)receiveKeys:(id)sender {
	SheetController *sheetController = [SheetController sharedInstance];
	[sheetController receiveKeys];
}
- (NSString *)receiveKeysWithIDs:(NSSet *)keyIDs {
	NSString *statusText = [gpgc receiveKeysFromServer:keyIDs];
	return [self importResultWithStatusText:statusText];
}

- (IBAction)sendKeysToServer:(id)sender {
	NSSet *keyInfos = [self selectedKeyInfos];
	if ([keyInfos count] > 0) {
		[gpgc sendKeysToServer:keyInfos];
	}
}

- (IBAction)refreshKeysFromServer:(id)sender {
	NSSet *keyInfos = [self selectedKeyInfos];
	if ([keyInfos count] > 0) {
		[self registerUndoForKeys:keyInfos withName:@"Undo_Refresh"];
	
		[gpgc refreshKeysFromServer:keyInfos];

		[keychainController asyncUpdateKeyInfos:keyInfos];
	}
}

- (IBAction)changePassphrase:(NSButton *)sender {
	NSSet *keyInfos = [self selectedKeyInfos];	
	if ([keyInfos count] == 1) {
		GPGKey *keyInfo = [[keyInfos anyObject] primaryKey];
		[self registerUndoForKey:keyInfo withName:@"Undo_ChangePassphrase"];
		
		[gpgc changePassphraseForKey:keyInfo];
		
		[keychainController asyncUpdateKeyInfos:keyInfos];
	}
}

- (IBAction)removeSignature:(NSButton *)sender { //Diese Funktion ist äusserst ineffizient, mir ist allerdings kein besserer Weg bekannt.
	if ([signaturesController selectionIndex] != NSNotFound) {
		GPGKeySignature *gpgKeySignature = [[signaturesController selectedObjects] objectAtIndex:0];
		GPGUserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
		GPGKey *keyInfo = [userID primaryKey];
		[self registerUndoForKey:keyInfo withName:@"Undo_RemoveSignature"];

		[gpgc removeSignature:gpgKeySignature fromUserID:userID ofKey:keyInfo];

		[keychainController asyncUpdateKeyInfo:keyInfo];
	}
}

- (IBAction)removeSubkey:(NSButton *)sender {
	if ([[subkeysController selectedObjects] count] == 1) {
		GPGSubkey *subkey = [[subkeysController selectedObjects] objectAtIndex:0];
		GPGKey *keyInfo = [subkey primaryKey];
		[self registerUndoForKey:keyInfo withName:@"Undo_RemoveSubkey"];

		[gpgc removeSubkey:subkey fromKey:keyInfo];
			
		[keychainController asyncUpdateKeyInfo:keyInfo];
	}
}

- (IBAction)removeUserID:(NSButton *)sender {
	if ([userIDsController selectionIndex] != NSNotFound) {
		GPGUserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
		GPGKey *keyInfo = [userID primaryKey];
		[self registerUndoForKey:keyInfo withName:@"Undo_RemoveUserID"];
		
		[gpgc removeUserID:[userID hashID] fromKey:keyInfo];
		
		[keychainController asyncUpdateKeyInfo:keyInfo];
	}
}

- (IBAction)revokeSignature:(NSButton *)sender { //Diese Funktion ist äusserst ineffizient, mir ist allerdings kein besserer Weg bekannt.
	if ([signaturesController selectionIndex] != NSNotFound) {
		GPGKeySignature *gpgKeySignature = [[signaturesController selectedObjects] objectAtIndex:0];
		GPGUserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
		GPGKey *keyInfo = [userID primaryKey];
		[self registerUndoForKey:keyInfo withName:@"Undo_RevokeSignature"];
		
		[gpgc revokeSignature:gpgKeySignature fromUserID:userID ofKey:keyInfo reason:0 description:nil];
		
		[keychainController asyncUpdateKeyInfo:keyInfo];
	}
}

- (IBAction)revokeSubkey:(NSButton *)sender {
	if ([[subkeysController selectedObjects] count] == 1) {
		GPGSubkey *subkey = [[subkeysController selectedObjects] objectAtIndex:0];
		GPGKey *keyInfo = [subkey primaryKey];
		[self registerUndoForKey:keyInfo withName:@"Undo_RevokeSubkey"];

		[gpgc revokeSubkey:subkey fromKey:keyInfo reason:0 description:nil];		

		[keychainController asyncUpdateKeyInfo:keyInfo];
	}
}

- (IBAction)revokeUserID:(NSButton *)sender {
	if ([userIDsController selectionIndex] != NSNotFound) {
		GPGUserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
		GPGKey *keyInfo = [userID primaryKey];
		[self registerUndoForKey:keyInfo withName:@"Undo_RevokeUserID"];

		[gpgc revokeUserID:[userID hashID] fromKey:keyInfo reason:0 description:nil]; 

		[keychainController asyncUpdateKeyInfo:keyInfo];
	}
}

- (IBAction)setDisabled:(NSButton *)sender {
	NSSet *keyInfos = [self selectedKeyInfos];
	if ([keyInfos count] > 0) {
		[self setDisabled:[sender state] == NSOnState forKeyInfos:keyInfos];
	}
}
- (void)setDisabled:(BOOL)disabled forKeyInfos:(NSSet *)keys {
	if (useUndo && [undoManager isUndoRegistrationEnabled]) {
		NSMutableSet *editedKeys = [NSMutableSet setWithCapacity:[keys count]];
		for (GPGKey *keyInfo in keys) {
			if (keyInfo.disabled != disabled) {
				[editedKeys addObject:keyInfo];
			}
		}
		if ([editedKeys count] > 0) {
			[[undoManager prepareWithInvocationTarget:self] setDisabled:!disabled forKeyInfos:editedKeys];
			if (![undoManager isUndoing] && ![undoManager isRedoing]) {
				[undoManager setActionName:localized(disabled ? @"Undo_DisableKey" : @"Undo_EnableKey")];
			}
		}
	}

	for (GPGKey *keyInfo in keys) {
		[gpgc key:keyInfo setDisabled:disabled];
	}
	[keychainController updateKeyInfos:keys];	
}

- (IBAction)setPrimaryUserID:(NSButton *)sender {
	if ([userIDsController selectionIndex] != NSNotFound) {
		GPGUserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
		GPGKey *keyInfo = [userID primaryKey];
		[self registerUndoForKey:keyInfo withName:@"Undo_PrimaryUserID"];
	
		[gpgc setPrimaryUserID:[userID hashID] ofKey:keyInfo];

		[keychainController asyncUpdateKeyInfo:keyInfo];
	}
}

- (IBAction)setTrsut:(NSPopUpButton *)sender {
	NSSet *keyInfos = [self selectedKeyInfos];
	if ([keyInfos count] > 0) {
		[self registerUndoForKeys:keyInfos withName:@"Undo_SetTrust"];
		
		for (GPGKey *keyInfo in keyInfos) {
			[gpgc key:keyInfo setOwnerTrsut:[sender selectedTag]];
		}
		[keychainController asyncUpdateKeyInfos:keyInfos];
	}
}

- (IBAction)generateNewKey:(id)sender {
	SheetController *sheetController = [SheetController sharedInstance];
	[sheetController generateNewKey];
}
- (void)generateNewKeyWithName:(NSString *)name email:(NSString *)email comment:(NSString *)comment passphrase:(NSString *)passphrase type:(NSInteger)type length:(NSInteger)length daysToExpire:(NSInteger)daysToExpire {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	
	NSInteger keyType, subkeyType;
	
	switch (type) {
		default:
		case 1: //RSA und RSA
			keyType = GPG_RSAAlgorithm;
			subkeyType = GPG_RSAAlgorithm;
			break;
		case 2: //DSA und Elgamal
			keyType = GPG_DSAAlgorithm;
			subkeyType = GPG_ElgamalEncryptOnlyAlgorithm;
			break;
		case 3: //DSA
			keyType = GPG_DSAAlgorithm;
			subkeyType = 0;
			break;
		case 4: //RSA
			keyType = GPG_RSAAlgorithm;
			subkeyType = 0;
			break;
	}
	
	NSString *fingerprint = [gpgc generateNewKeyWithName:name email:email comment:comment keyType:keyType keyLength:length subkeyType:subkeyType subkeyLength:length daysToExpire:daysToExpire preferences:nil passphrase:nil];
	
	
	if (useUndo && fingerprint) {
		[[undoManager prepareWithInvocationTarget:self] deleteKeys:[NSSet setWithObject:fingerprint] withMode:GPGDeletePublicAndSecretKey];
		[undoManager setActionName:localized(@"Undo_NewKey")];
	}
	
	
	[keychainController updateKeyInfos:nil];
	[pool drain];
}

- (IBAction)refreshDisplayedKeys:(id)sender {
	[keychainController asyncUpdateKeyInfos:nil];
}

- (IBAction)deleteKey:(id)sender { 	
	//TODO: Bessere Dialoge mit der auswahl "Für alle".
	NSSet *keyInfos = [self selectedKeyInfos];
	if ([keyInfos count] > 0) {
		NSInteger retVal;
		SheetController *sheetController = [SheetController sharedInstance];
		
		if (useUndo) {
			[undoManager beginUndoGrouping];
		}
		
		for (GPGKey *keyInfo in keyInfos) {
			
			if (keyInfo.secret) {
				retVal = [sheetController alertSheetForWindow:mainWindow 
												  messageText:localized(@"DeleteSecretKey_Title") 
													 infoText:[NSString stringWithFormat:localized(@"DeleteSecretKey_Msg"), [keyInfo userID], [keyInfo shortKeyID]] 
												defaultButton:localized(@"Delete secret key only") 
											  alternateButton:localized(@"Cancel") 
												  otherButton:localized(@"Delete both")];
				switch (retVal) {
					case NSAlertFirstButtonReturn:
						[self deleteKeys:[NSSet setWithObject:keyInfo] withMode:GPGDeleteSecretKey];
						break;
					case NSAlertThirdButtonReturn:
						[self deleteKeys:[NSSet setWithObject:keyInfo] withMode:GPGDeletePublicAndSecretKey];
						break;
				}
			} else {
				retVal = [sheetController alertSheetForWindow:mainWindow 
												  messageText:localized(@"DeleteKey_Title") 
													 infoText:[NSString stringWithFormat:localized(@"DeleteKey_Msg"), [keyInfo userID], [keyInfo shortKeyID]] 
												defaultButton:localized(@"Delete key") 
											  alternateButton:localized(@"Cancel") 
												  otherButton:nil];
				if (retVal == NSAlertFirstButtonReturn) {
					[self deleteKeys:[NSSet setWithObject:keyInfo] withMode:GPGDeletePublicKey];
				}
			}
		}
		
		if (useUndo) {
			[undoManager endUndoGrouping];
			[undoManager setActionName:localized(@"Undo_Delete")];
		}
	}
}
- (void)deleteKeys:(NSObject <EnumerationList> *)keys withMode:(GPGDeleteKeyMode)mode {
	if ([keys count] == 0) {
		return;
	}
	[self registerUndoForKeys:keys withName:@"Undo_Delete"];
	
	[gpgc deleteKeys:keys withMode:mode];

	if ([undoManager isUndoRegistrationEnabled]) {
		[keychainController asyncUpdateKeyInfos:keys];
	}
}


- (IBAction)showInspector:(id)sender {
	[inspectorWindow makeKeyAndOrderFront:sender];
}


- (id)init {
	self = [super init];
	actionController = self;
	gpgc = [[GPGController gpgController] retain];
	return self;
}


@end

