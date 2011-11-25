/*
 Copyright © Roman Zechmeister, 2011
 
 Diese Datei ist Teil von GPG Keychain Access.
 
 GPG Keychain Access ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung von GPG Keychain Access erfolgt in der Hoffnung, daß es Ihnen 
 von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite 
 Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck. 
 Details finden Sie in der GNU General Public License.
 
 Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem 
 Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
*/

#import "ActionController.h"
#import "ActionController_Private.h"
#import "KeychainController.h"
#import "SheetController.h"


@implementation ActionController
@synthesize progressText, errorText;


#pragma mark "Import and Export"
- (IBAction)exportKey:(id)sender {
	NSSet *keys = [self selectedKeys];
	if (keys.count == 0) {
		return;
	}
	
	sheetController.title = nil; //TODO
	sheetController.msgText = nil; //TODO
	
	if ([keys count] == 1) {
		sheetController.pattern = [[keys anyObject] shortKeyID];
	} else {
		sheetController.pattern = localized(@"untitled");
	}
	
	
	sheetController.sheetType = SheetTypeExportKey;
	if ([sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	self.progressText = localized(@"ExportKey_Progress");
	self.errorText = localized(@"ExportKey_Error");
	gpgc.useArmor = sheetController.exportFormat != 0;
	gpgc.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:SaveDataToURLAction], @"action", sheetController.URL, @"URL", nil];
	[gpgc exportKeys:keys allowSecret:sheetController.allowSecretKeyExport fullExport:NO];
}
- (IBAction)importKey:(id)sender {
	sheetController.title = nil; //TODO
	sheetController.msgText = nil; //TODO
	//sheetController.allowedFileTypes = [NSArray arrayWithObjects:@"asc", @"gpg", @"pgp", @"key", @"gpgkey", nil];
	
	sheetController.sheetType = SheetTypeOpenPanel;
	if ([sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	[self importFromURLs:sheetController.URLs];
}
- (void)importFromURLs:(NSArray *)urls {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSMutableData *dataToImport = [NSMutableData data];
	
	for (NSObject *url in urls) {
		if ([url isKindOfClass:[NSURL class]]) {
			[dataToImport appendData:[NSData dataWithContentsOfURL:(NSURL *)url]];
		} else if ([url isKindOfClass:[NSString class]]) {
			[dataToImport appendData:[NSData dataWithContentsOfFile:(NSString *)url]];
		}
	}
	[self importFromData:dataToImport];
	[pool drain];
}
- (void)importFromData:(NSData *)data {
	self.progressText = localized(@"ImportKey_Progress");
	self.errorText = localized(@"ImportKey_Error");
	gpgc.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:ShowResultAction], @"action", nil];
	[gpgc importFromData:data fullImport:NO];
}
- (IBAction)copy:(id)sender {
	NSSet *keys = [self selectedKeys];
	if ([keys count] > 0) {
		gpgc.async = NO;
		gpgc.useArmor = YES;
		NSString *exportedKeys = [[gpgc exportKeys:keys allowSecret:NO fullExport:NO] gpgString];
		gpgc.async = YES;
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

 
#pragma mark "Window and display"
- (IBAction)showInspector:(id)sender {
	if (![sender isKindOfClass:[NSTableView class]] || [sender clickedRow] > -1) {
		[inspectorWindow makeKeyAndOrderFront:sender];
	}
}
- (IBAction)refreshDisplayedKeys:(id)sender {
	[[KeychainController sharedInstance] asyncUpdateKeys:nil];
}

#pragma mark "Keys"
- (IBAction)generateNewKey:(id)sender {
	sheetController.sheetType = SheetTypeNewKey;
	if ([sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	NSInteger keyType, subkeyType;
	
	switch (sheetController.keyType) {
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
	self.progressText = localized(@"GenerateKey_Progress");
	self.errorText = localized(@"GenerateKey_Error");
	
	[gpgc generateNewKeyWithName:sheetController.name 
						   email:sheetController.email 
						 comment:sheetController.comment 
						 keyType:keyType 
					   keyLength:sheetController.length 
					  subkeyType:subkeyType 
					subkeyLength:sheetController.length 
					daysToExpire:sheetController.daysToExpire
					 preferences:nil 
					  passphrase:sheetController.passphrase];
}
- (IBAction)deleteKey:(id)sender { 	
	NSSet *keys = [self selectedKeys];
	if (keys.count == 0) {
		return;
	}
	
	NSInteger returnCode;
	BOOL applyToAll = NO;
	NSMutableSet *keysToDelete = [NSMutableSet setWithCapacity:keys.count];
	NSMutableSet *secretKeysToDelete = [NSMutableSet setWithCapacity:keys.count];
	
	[self.undoManager beginUndoGrouping];
	
	
	BOOL (^secretKeyTest)(id, BOOL*) = ^BOOL(id obj, BOOL *stop) {
		return ((GPGKey *)obj).secret;
	};
	
	
	
	NSSet *secretKeys = [keys objectsWithOptions:NSEnumerationConcurrent passingTest:secretKeyTest];
	NSMutableSet *publicKeys = [[keys mutableCopy] autorelease];
	[publicKeys minusSet:secretKeys];
	
	
	
	for (GPGKey *key in secretKeys) {
		if (!applyToAll) {
			returnCode = [sheetController alertSheetForWindow:mainWindow 
												  messageText:localized(@"DeleteSecretKey_Title") 
													 infoText:[NSString stringWithFormat:localized(@"DeleteSecretKey_Msg"), [key userID], [key shortKeyID]] 
												defaultButton:localized(@"Delete secret key only") 
											  alternateButton:localized(@"Cancel") 
												  otherButton:localized(@"Delete both")
											suppressionButton:localized(@"Apply to all")];
			
			applyToAll = !!(returnCode & SheetSuppressionButton);
			returnCode = returnCode & ~SheetSuppressionButton;
			if (applyToAll && returnCode == NSAlertSecondButtonReturn) {
				break;
			}
		}
		
		switch (returnCode) {
			case NSAlertFirstButtonReturn:
				[secretKeysToDelete addObject:key];
				break;
			case NSAlertThirdButtonReturn:
				[keysToDelete addObject:key];
				break;
		}
	}
	
	
	if (applyToAll && returnCode == NSAlertThirdButtonReturn) {
		returnCode = NSAlertFirstButtonReturn;
	} else {
		applyToAll = NO;
	}
	
	for (GPGKey *key in publicKeys) {
		if (!applyToAll) {
			returnCode = [sheetController alertSheetForWindow:mainWindow 
												  messageText:localized(@"DeleteKey_Title") 
													 infoText:[NSString stringWithFormat:localized(@"DeleteKey_Msg"), [key userID], [key shortKeyID]] 
												defaultButton:localized(@"Delete key") 
											  alternateButton:localized(@"Cancel") 
												  otherButton:nil
											suppressionButton:localized(@"Apply to all")];
			
			applyToAll = !!(returnCode & SheetSuppressionButton);
			returnCode = returnCode & ~SheetSuppressionButton;
			if (applyToAll && returnCode == NSAlertSecondButtonReturn) {
				break;
			}
		}
		
		if (returnCode == NSAlertFirstButtonReturn) {
			[keysToDelete addObject:key];
		}
	}
	

	if (secretKeysToDelete.count > 0) {
		self.progressText = localized(@"DeleteKeys_Progress");
		self.errorText = localized(@"DeleteKeys_Error");
		[gpgc deleteKeys:secretKeysToDelete withMode:GPGDeleteSecretKey];
	}
	
	if (keysToDelete.count > 0) {
		self.progressText = localized(@"DeleteKeys_Progress");
		self.errorText = localized(@"DeleteKeys_Error");
		[gpgc deleteKeys:keysToDelete withMode:GPGDeletePublicAndSecretKey];
	}
	
	
	[self.undoManager endUndoGrouping];
	[self.undoManager setActionName:localized(@"Undo_Delete")];
	
}

#pragma mark "Key attributes"
- (IBAction)changePassphrase:(NSButton *)sender {
	NSSet *keys = [self selectedKeys];	
	if ([keys count] == 1) {
		GPGKey *key = [[keys anyObject] primaryKey];
		
		self.progressText = localized(@"ChangePassphrase_Progress");
		self.errorText = localized(@"ChangePassphrase_Error");
		[gpgc changePassphraseForKey:key];
	}
}
- (IBAction)setDisabled:(NSButton *)sender {
	NSSet *keys = [self selectedKeys];
	if ([keys count] > 0) {
		BOOL disabled = [sender state] == NSOnState;
		[self.undoManager beginUndoGrouping];
		for (GPGKey *key in keys) {
			self.progressText = localized(@"SetDisabled_Progress");
			self.errorText = localized(@"SetDisabled_Error");
			[gpgc key:key setDisabled:disabled];
		}
		[self.undoManager endUndoGrouping];
		[self.undoManager setActionName:localized(disabled ? @"Undo_Disable" : @"Undo_Enable")];
	}
}
- (IBAction)setTrust:(NSPopUpButton *)sender {
	NSSet *keys = [self selectedKeys];
	if ([keys count] > 0) {
		for (GPGKey *key in keys) {
			self.progressText = localized(@"SetOwnerTrust_Progress");
			self.errorText = localized(@"SetOwnerTrust_Error");
			[gpgc key:key setOwnerTrsut:[sender selectedTag]];
		}
	}
}
- (IBAction)changeExpirationDate:(NSButton *)sender {
	NSSet *keys = [self selectedKeys];
	if ([keys count] != 1) {
		return;
	}
	GPGSubkey *subkey = nil;
	GPGKey *key = [[keys anyObject] primaryKey];
	
	if ([sender tag] == 1 && [[subkeysController selectedObjects] count] == 1) {
		subkey = [[subkeysController selectedObjects] objectAtIndex:0];
	}
	
	if (subkey) {
		sheetController.msgText = [NSString stringWithFormat:localized(@"ChangeSubkeyExpirationDate_Msg"), [subkey shortKeyID], [key userID], [key shortKeyID]];
		sheetController.expirationDate = [subkey expirationDate];
	} else {
		sheetController.msgText = [NSString stringWithFormat:localized(@"ChangeExpirationDate_Msg"), [key userID], [key shortKeyID]];
		sheetController.expirationDate = [key expirationDate];
	}
	
	sheetController.sheetType = SheetTypeExpirationDate;
	if ([sheetController runModalForWindow:mainWindow] == NSOKButton) {
		self.progressText = localized(@"ChangeExpirationDate_Progress");
		self.errorText = localized(@"ChangeExpirationDate_Error");
		[gpgc setExpirationDateForSubkey:subkey fromKey:key daysToExpire:sheetController.daysToExpire];
	}
}
- (IBAction)editAlgorithmPreferences:(id)sender {
	NSSet *keys = [self selectedKeys];		
	if ([keys count] != 1) {
		return;
	}
	GPGKey *key = [keys anyObject];
	
	NSMutableArray *algorithmPreferences = [NSMutableArray array];
	
	
	for (GPGUserID *userID in [key userIDs]) {
		[algorithmPreferences addObject:
		 [NSMutableDictionary dictionaryWithObjectsAndKeys:
		  userID, @"userID", 
		  [userID cipherPreferences], @"cipherPreferences", 
		  [userID digestPreferences], @"digestPreferences", 
		  [userID compressPreferences], @"compressPreferences", 
		  [userID otherPreferences], @"otherPreferences", nil]];
	}
	
	sheetController.allowEdit = key.secret;
	sheetController.algorithmPreferences = algorithmPreferences; 
	sheetController.sheetType = SheetTypeAlgorithmPreferences;
	if ([sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	
	for (NSDictionary *preferences in sheetController.algorithmPreferences) {
		GPGUserID *userID = [preferences objectForKey:@"userID"];
		NSString *cipherPreferences = [[preferences objectForKey:@"cipherPreferences"] componentsJoinedByString:@" "];
		NSString *digestPreferences = [[preferences objectForKey:@"digestPreferences"] componentsJoinedByString:@" "];
		NSString *compressPreferences = [[preferences objectForKey:@"compressPreferences"] componentsJoinedByString:@" "];
		
		self.progressText = localized(@"SetAlgorithmPreferences_Progress");
		self.errorText = localized(@"SetAlgorithmPreferences_Error");
		[gpgc setAlgorithmPreferences:[NSString stringWithFormat:@"%@ %@ %@", cipherPreferences, digestPreferences, compressPreferences] forUserID:[userID hashID] ofKey:key];
	}
	
	
}

#pragma mark "Keys (other)"
- (IBAction)cleanKey:(id)sender {
	NSSet *keys = [self selectedKeys];
	for (GPGKey *key in keys) {
		self.progressText = localized(@"CleanKey_Progress");
		self.errorText = localized(@"CleanKey_Error");
		[gpgc cleanKey:key];
	}
}
- (IBAction)minimizeKey:(id)sender {
	NSSet *keys = [self selectedKeys];
	for (GPGKey *key in keys) {
		self.progressText = localized(@"MinimizeKey_Progress");
		self.errorText = localized(@"MinimizeKey_Error");
		[gpgc minimizeKey:key];
	}
}
- (IBAction)genRevokeCertificate:(id)sender {
	NSSet *keys = [self selectedKeys];		
	if ([keys count] != 1) {
		return;
	}
	GPGKey *key = [[keys anyObject] primaryKey];
	
	
	sheetController.title = nil; //TODO
	sheetController.msgText = nil; //TODO
	sheetController.allowedFileTypes = [NSArray arrayWithObjects:@"asc", @"gpg", @"pgp", nil];
	sheetController.pattern = [NSString stringWithFormat:localized(@"%@ Revoke certificate"), [key shortKeyID]];
	
	sheetController.sheetType = SheetTypeSavePanel;
	if ([sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	self.progressText = localized(@"GenerateRevokeCertificateForKey_Progress");
	self.errorText = localized(@"GenerateRevokeCertificateForKey_Error");
	gpgc.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:SaveDataToURLAction], @"action", sheetController.URL, @"URL", nil];
	[gpgc generateRevokeCertificateForKey:key reason:0 description:nil];			   
}

#pragma mark "Keyserver"
- (IBAction)searchKeys:(id)sender {
	sheetController.sheetType = SheetTypeSearchKeys;
	if ([sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	gpgc.userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:ShowFoundKeysAction] forKey:@"action"];
	
	self.progressText = localized(@"SearchKeysOnServer_Progress");
	self.errorText = localized(@"SearchKeysOnServer_Error");
	[gpgc searchKeysOnServer:sheetController.pattern];
}
- (IBAction)receiveKeys:(id)sender {
	sheetController.sheetType = SheetTypeReceiveKeys;
	if ([sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	NSSet *keyIDs = [sheetController.pattern keyIDs];
	
	[self receiveKeysFromServer:keyIDs];
}
- (IBAction)sendKeysToServer:(id)sender {
	NSSet *keys = [self selectedKeys];
	if ([keys count] > 0) {
		self.progressText = localized(@"SendKeysToServer_Progress");
		self.errorText = localized(@"SendKeysToServer_Error");
		[gpgc sendKeysToServer:keys];
	}
}
- (IBAction)refreshKeysFromServer:(id)sender {
	NSSet *keys = [self selectedKeys];
	if ([keys count] > 0) {	
		self.progressText = localized(@"RefreshKeysFromServer_Progress");
		self.errorText = localized(@"RefreshKeysFromServer_Error");
		[gpgc refreshKeysFromServer:keys];
	}
}

#pragma mark "Subkeys"
- (IBAction)addSubkey:(NSButton *)sender {
	NSSet *keys = [self selectedKeys];		
	if ([keys count] != 1) {
		return;
	}
	GPGKey *key = [[keys anyObject] primaryKey];
	
	sheetController.msgText = [NSString stringWithFormat:localized(@"GenerateSubkey_Msg"), [key userID], [key shortKeyID]];
	
	sheetController.sheetType = SheetTypeAddSubkey;
	if ([sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	self.progressText = localized(@"AddSubkey_Progress");
	self.errorText = localized(@"AddSubkey_Error");
	[gpgc addSubkeyToKey:key type:sheetController.keyType length:sheetController.length daysToExpire:sheetController.daysToExpire];
}
- (IBAction)removeSubkey:(NSButton *)sender {
	if ([[subkeysController selectedObjects] count] == 1) {
		GPGSubkey *subkey = [[subkeysController selectedObjects] objectAtIndex:0];
		GPGKey *key = [subkey primaryKey];
		
		self.progressText = localized(@"RemoveSubkey_Progress");
		self.errorText = localized(@"RemoveSubkey_Error");
		[gpgc removeSubkey:subkey fromKey:key];
	}
}
- (IBAction)revokeSubkey:(NSButton *)sender {
	if ([[subkeysController selectedObjects] count] == 1) {
		GPGSubkey *subkey = [[subkeysController selectedObjects] objectAtIndex:0];
		GPGKey *key = [subkey primaryKey];
		
		self.progressText = localized(@"RevokeSubkey_Progress");
		self.errorText = localized(@"RevokeSubkey_Error");
		[gpgc revokeSubkey:subkey fromKey:key reason:0 description:nil];		
	}
}

#pragma mark "UserIDs"
- (IBAction)addUserID:(NSButton *)sender {
	NSSet *keys = [self selectedKeys];		
	if ([keys count] != 1) {
		return;
	}
	GPGKey *key = [[keys anyObject] primaryKey];
	
	sheetController.msgText = [NSString stringWithFormat:localized(@"GenerateUserID_Msg"), [key userID], [key shortKeyID]];
	
	sheetController.sheetType = SheetTypeAddUserID;
	if ([sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	self.progressText = localized(@"AddUserID_Progress");
	self.errorText = localized(@"AddUserID_Error");
	[gpgc addUserIDToKey:key name:sheetController.name email:sheetController.email comment:sheetController.comment];
}
- (IBAction)removeUserID:(NSButton *)sender {
	if ([userIDsController selectionIndex] != NSNotFound) {
		GPGUserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
		GPGKey *key = [userID primaryKey];
		
		self.progressText = localized(@"RemoveUserID_Progress");
		self.errorText = localized(@"RemoveUserID_Error");
		[gpgc removeUserID:[userID hashID] fromKey:key];
	}
}
- (IBAction)setPrimaryUserID:(NSButton *)sender {
	if ([userIDsController selectionIndex] != NSNotFound) {
		GPGUserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
		GPGKey *key = [userID primaryKey];
		
		self.progressText = localized(@"SetPrimaryUserID_Progress");
		self.errorText = localized(@"SetPrimaryUserID_Error");
		[gpgc setPrimaryUserID:[userID hashID] ofKey:key];
	}
}
- (IBAction)revokeUserID:(NSButton *)sender {
	if ([userIDsController selectionIndex] != NSNotFound) {
		GPGUserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
		GPGKey *key = [userID primaryKey];
		
		self.progressText = localized(@"RevokeUserID_Progress");
		self.errorText = localized(@"RevokeUserID_Error");
		[gpgc revokeUserID:[userID hashID] fromKey:key reason:0 description:nil]; 
	}
}

#pragma mark "Photos"
- (IBAction)addPhoto:(NSButton *)sender {
	NSSet *keys = [self selectedKeys];		
	if ([keys count] != 1) {
		return;
	}
	GPGKey *key = [[keys anyObject] primaryKey];
	
	sheetController.title = nil; //TODO
	sheetController.msgText = nil; //TODO
	sheetController.allowedFileTypes = [NSArray arrayWithObjects:@"jpg", @"jpeg", nil];;
	
	sheetController.sheetType = SheetTypeOpenPhotoPanel;
	if ([sheetController runModalForWindow:inspectorWindow] != NSOKButton) {
		return;
	}
	
	self.progressText = localized(@"AddPhoto_Progress");
	self.errorText = localized(@"AddPhoto_Error");
	[gpgc addPhotoFromPath:[sheetController.URL path] toKey:key];
}
- (IBAction)removePhoto:(NSButton *)sender {
	if ([photosController selectionIndex] != NSNotFound) {
		NSSet *keys = [self selectedKeys];		
		GPGKey *key = [[keys anyObject] primaryKey];
		
		self.progressText = localized(@"RemovePhoto_Progress");
		self.errorText = localized(@"RemovePhoto_Error");
		[gpgc removeUserID:[[[photosController selectedObjects] objectAtIndex:0] hashID] fromKey:key];
	}
}
- (IBAction)setPrimaryPhoto:(NSButton *)sender {
	if ([photosController selectionIndex] != NSNotFound) {
		GPGKey *key = [[[self selectedKeys] anyObject] primaryKey];		
		
		self.progressText = localized(@"SetPrimaryPhoto_Progress");
		self.errorText = localized(@"SetPrimaryPhoto_Error");
		[gpgc setPrimaryUserID:[[[photosController selectedObjects] objectAtIndex:0] hashID] ofKey:key];
	}
}
- (IBAction)revokePhoto:(NSButton *)sender {
	if ([photosController selectionIndex] != NSNotFound) {
		GPGKey *key = [[[self selectedKeys] anyObject] primaryKey];		
		
		self.progressText = localized(@"RevokePhoto_Progress");
		self.errorText = localized(@"RevokePhoto_Error");
		[gpgc revokeUserID:[[[photosController selectedObjects] objectAtIndex:0] hashID] fromKey:key reason:0 description:nil];
	}
}

#pragma mark "Signatures"
- (IBAction)addSignature:(id)sender {
	NSSet *keys = [self selectedKeys];		
	if ([keys count] != 1) {
		return;
	}
	
	GPGUserID *userID = nil;
	if ([sender tag] == 1) {
		if ([userIDsController selectionIndex] == NSNotFound) {
			return;
		}
		userID = [[userIDsController selectedObjects] objectAtIndex:0];
	}
	
	GPGKey *key = [[keys anyObject] primaryKey];
	
	NSSet *secretKeys = [[KeychainController sharedInstance] secretKeys];
	
	sheetController.secretKeys = [secretKeys allObjects];
	GPGKey *defaultKey = [[KeychainController sharedInstance] defaultKey];
	if (!defaultKey) {
		[sheetController alertSheetForWindow:mainWindow messageText:localized(@"NO_SECRET_KEY_TITLE") infoText:localized(@"NO_SECRET_KEY_MESSAGE") defaultButton:nil alternateButton:nil otherButton:nil suppressionButton:nil];
		return;
	}
	sheetController.secretKey = defaultKey;
	sheetController.msgText = [NSString stringWithFormat:localized(userID ? @"GenerateUidSignature_Msg" : @"GenerateSignature_Msg"), userID ? userID.userID : key.userID, key.shortKeyID];
	
	sheetController.sheetType = SheetTypeAddSignature;
	if ([sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	self.progressText = localized(@"AddSignature_Progress");
	self.errorText = localized(@"AddSignature_Error");
	[gpgc signUserID:[userID hashID] ofKey:key signKey:sheetController.secretKey type:sheetController.sigType local:sheetController.localSig daysToExpire:sheetController.daysToExpire];
}
- (IBAction)removeSignature:(NSButton *)sender {
	if ([signaturesController selectionIndex] != NSNotFound) {
		GPGKeySignature *gpgKeySignature = [[signaturesController selectedObjects] objectAtIndex:0];
		GPGUserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
		GPGKey *key = [userID primaryKey];
		
		self.progressText = localized(@"RemoveSignature_Progress");
		self.errorText = localized(@"RemoveSignature_Error");
		[gpgc removeSignature:gpgKeySignature fromUserID:userID ofKey:key];
	}
}
- (IBAction)revokeSignature:(NSButton *)sender {
	if ([signaturesController selectionIndex] != NSNotFound) {
		GPGKeySignature *gpgKeySignature = [[signaturesController selectedObjects] objectAtIndex:0];
		GPGUserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
		GPGKey *key = [userID primaryKey];
		
		self.progressText = localized(@"RevokeSignature_Progress");
		self.errorText = localized(@"RevokeSignature_Error");
		[gpgc revokeSignature:gpgKeySignature fromUserID:userID ofKey:key reason:0 description:nil];
	}
}




#pragma mark "Miscellaneous :)"
- (void)cancelOperation:(id)sender {
	[gpgc cancel];
}

- (void)receiveKeysFromServer:(NSObject <EnumerationList> *)keys {
	gpgc.userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:ShowResultAction] forKey:@"action"];
	
	self.progressText = localized(@"ReceiveKeysFromServer_Progress");
	self.errorText = localized(@"ReceiveKeysFromServer_Error");
	[gpgc receiveKeysFromServer:keys];
}

- (NSString *)importResultWithStatusText:(NSString *)statusText {
	NSInteger flags;
	NSString *fingerprint, *keyID, *userID;
	NSNumber *no = [NSNumber numberWithBool:0], *yes = [NSNumber numberWithBool:1];
	NSCharacterSet *hexCharSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"];
	NSMutableArray *lines = [NSMutableArray array];
	NSMutableDictionary *changedKeys = [NSMutableDictionary dictionary];
	
	NSScanner *scanner = [NSScanner scannerWithString:statusText];
	NSUInteger length = [statusText length];
	NSRange range = {0, length};
	
	
	while ((range = [statusText rangeOfString:@"[GNUPG:] IMPORT_OK " options:NSLiteralSearch range:range]).length > 0) {
		[scanner setScanLocation:range.location + 19];
		[scanner scanInteger:&flags];
		
		[scanner scanCharactersFromSet:hexCharSet intoString:&fingerprint];
		userID = [[[(KeychainController *)[KeychainController sharedInstance] allKeys] member:fingerprint] userID];
		keyID = [fingerprint shortKeyID];
		
		if (flags > 0) {
			if (flags & 1) {
				if (flags & 16) {
					[lines addObject:[NSString stringWithFormat:localized(@"ImportResult_Secret"), keyID, userID]];
				} else {
					[lines addObject:[NSString stringWithFormat:localized(@"ImportResult_Public"), keyID, userID]];
				}
			}
			if (flags & 2) {
				[lines addObject:[NSString stringWithFormat:localized(@"ImportResult_UserID"), keyID, userID]];
			}
			if (flags & 4) {
				[lines addObject:[NSString stringWithFormat:localized(@"ImportResult_Signature"), keyID, userID]];
			}
			if (flags & 8) {
				[lines addObject:[NSString stringWithFormat:localized(@"ImportResult_Subkey"), keyID, userID]];
			}
			[changedKeys setObject:yes forKey:fingerprint];
		} else {
			if ([changedKeys objectForKey:fingerprint] == nil) {
				[changedKeys setObject:no forKey:fingerprint];
			}
		}
		
		range.location += range.length;
		range.length = length - range.location;
	}
	
	for (fingerprint in [changedKeys allKeysForObject:no]) {
		userID = [[[(KeychainController *)[KeychainController sharedInstance] allKeys] member:fingerprint] userID];
		keyID = [fingerprint shortKeyID];
		
		[lines addObject:[NSString stringWithFormat:localized(@"ImportResult_NoChanges"), keyID, userID]];
	}
	
	
	//TODO: Present summary in a human readable form.
	range = [statusText rangeOfString:@"[GNUPG:] IMPORT_RES "];
	if (range.length > 0) {
		NSInteger values[14];
		[scanner setScanLocation:range.location + 20];
		
		NSInteger total = 0;
		for (int i = 0; i < 14; i++) {
			[scanner scanInteger:&values[i]];
			total += values[i];
		}
		if (total >  values[0]) {
			[lines addObject:[NSString stringWithFormat:@"%ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld %ld", values[0], values[1], values[2], values[3], values[4], values[5], values[6], values[7], values[8], values[9], values[10], values[11], values[12], values[13]]];
		}
	}
	
	
	
	
	if ([lines count] == 0) {
		return localized(@"ImportResult_Nothing");
	}
	
	return [lines componentsJoinedByString:@"\n"];
}

- (NSUndoManager *)undoManager {
	if (!undoManager) {
		undoManager = [NSUndoManager new];
		[undoManager setLevelsOfUndo:50];
	}
	return [[undoManager retain] autorelease];
}

- (NSSet *)selectedKeys {
	NSInteger clickedRow = [keyTable clickedRow];
	if (clickedRow != -1 && ![keyTable isRowSelected:clickedRow]) {
		return [NSSet setWithObject:[[keyTable itemAtRow:clickedRow] representedObject]];
	} else {
		NSMutableSet *keySet = [NSMutableSet set];
		for (GPGKey *key in [keysController selectedObjects]) {
			[keySet addObject:[key primaryKey]];
		}
		return keySet;
	}
}

- (BOOL)validateUserInterfaceItem:(id)anItem {
    SEL selector = [anItem action];
	
    if (selector == @selector(copy:)) {
		if ([[self selectedKeys] count] >= 1) {
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
		NSSet *keys = [self selectedKeys];
		if ([keys count] == 1 && ((GPGKey*)[keys anyObject]).secret) {
			return YES;
		}
		return NO;
    } else if (selector == @selector(editAlgorithmPreferences:)) {
		NSSet *keys = [self selectedKeys];
		if ([keys count] == 1) {
			return YES;
		}
		return NO;
	}
	return YES;
}



#pragma mark "Delegate"
- (void)gpgControllerOperationDidStart:(GPGController *)gc {
	sheetController.progressText = self.progressText;
	[sheetController performSelectorOnMainThread:@selector(showProgressSheet) withObject:nil waitUntilDone:YES];
}
- (void)gpgController:(GPGController *)gc operationThrownException:(NSException *)e {
	NSLog(@"Exception: %@", e.description);
	if ([e isKindOfClass:[GPGException class]]) {
		if ([(GPGException *)e errorCode] == GPGErrorCancelled) {
			return;
		}
	}

	[sheetController errorSheetWithmessageText:self.errorText infoText:[NSString stringWithFormat:@"%@", e.description]];
}
- (void)gpgController:(GPGController *)gc operationDidFinishWithReturnValue:(id)value {
	[sheetController performSelectorOnMainThread:@selector(endProgressSheet) withObject:nil waitUntilDone:YES];

	NSInteger action = [[gc.userInfo objectForKey:@"action"] integerValue];
	
	switch (action) {
		case ShowResultAction: {
			if (gc.error) break;
			
			NSString *statusText = gc.lastReturnValue;
			if ([statusText length] > 0) {
				sheetController.msgText = [self importResultWithStatusText:statusText];
				
				sheetController.sheetType = SheetTypeShowResult;
				[sheetController runModalForWindow:mainWindow];
			}
			break;
		}
		case ShowFoundKeysAction: {
			if (gc.error) break;
			NSArray *keys = gc.lastReturnValue;
			if ([keys count] == 0) {
				sheetController.msgText = localized(@"No keys Found");
				sheetController.sheetType = SheetTypeShowResult;
				[sheetController runModalForWindow:mainWindow];
			} else {
				sheetController.keys = keys;
				
				sheetController.sheetType = SheetTypeShowFoundKeys;
				if ([sheetController runModalForWindow:mainWindow] != NSOKButton) break;
				
				[self receiveKeysFromServer:sheetController.keys];
			}
			break;
		}
		case SaveDataToURLAction: {
			if (gc.error) break;
			
			NSURL *URL = [gc.userInfo objectForKey:@"URL"];
			[(NSData *)value writeToURL:URL atomically:YES];
			
			break;
		}
		default:
			break;
	}
	self.progressText = nil;
	self.errorText = nil;
	gc.userInfo = nil;
}
- (void)gpgController:(GPGController *)gpgc keysDidChanged:(NSObject<EnumerationList> *)keys external:(BOOL)external {
	[(KeychainController *)[KeychainController sharedInstance] updateKeys:keys];
}



#pragma mark "Singleton: alloc, init etc."
+ (id)sharedInstance {
	static id sharedInstance = nil;
    if (!sharedInstance) {
        sharedInstance = [[super allocWithZone:nil] init];
    }
    return sharedInstance;	
}
- (id)init {
	static BOOL initialized = NO;
	if (!initialized) {
		initialized = YES;
		self = [super init];
		
		gpgc = [[GPGController gpgController] retain];
		gpgc.delegate = self;
		gpgc.undoManager = self.undoManager;
		gpgc.printVersion = YES;
		gpgc.async = YES;
		sheetController = [[SheetController sharedInstance] retain];
	}
	return self;
}
+ (id)allocWithZone:(NSZone *)zone {
    return [[self sharedInstance] retain];	
}
- (id)copyWithZone:(NSZone *)zone {
    return self;
}
- (id)retain {
    return self;
}
- (NSUInteger)retainCount {
    return NSUIntegerMax;
}
- (oneway void)release {
}
- (id)autorelease {
    return self;
}


@end

