/*
 Copyright © Roman Zechmeister, 2014
 
 Diese Datei ist Teil von GPG Keychain.
 
 GPG Keychain ist freie Software. Sie können es unter den Bedingungen
 der GNU General Public License, wie von der Free Software Foundation
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung von GPG Keychain erfolgt in der Hoffnung, daß es Ihnen
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
#import "AppDelegate.h"
#import "GKAExtensions.h"



@implementation ActionController
@synthesize progressText, errorText, keysController, signaturesController,
			subkeysController, userIDsController, photosController, keyTable,
			signaturesTable, userIDsTable, subkeysTable;


#pragma mark General
- (IBAction)delete:(id)sender {
	NSResponder *responder = mainWindow.firstResponder;
	
	if (responder == appDelegate.userIDTable) {
		[self removeUserID:nil];
	} else if (responder == appDelegate.signatureTable) {
		[self removeSignature:nil];
	} else if (responder == appDelegate.subkeyTable) {
		[self removeSubkey:nil];
	} else {
		[self deleteKey:nil];
	}
}


#pragma mark Import and Export
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
	
	[keys enumerateObjectsUsingBlock:^(GPGKey *key, BOOL *stop) {
		if (key.secret) {
			sheetController.allowSecretKeyExport = YES;
			*stop = YES;
		}
	}];
	
	sheetController.allowedFileTypes = [NSArray arrayWithObjects:@"asc", nil];
	sheetController.sheetType = SheetTypeExportKey;
	if ([sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	self.progressText = localized(@"ExportKey_Progress");
	self.errorText = localized(@"ExportKey_Error");
	gpgc.useArmor = sheetController.exportFormat != 0;
	gpgc.userInfo = @{@"action": @(SaveDataToURLAction), @"URL": sheetController.URL, @"hideExtension": @(sheetController.hideExtension)};
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
	@autoreleasepool {
		NSMutableData *dataToImport = [NSMutableData data];
		
		for (NSObject *url in urls) {
			if ([url isKindOfClass:[NSURL class]]) {
				[dataToImport appendData:[NSData dataWithContentsOfURL:(NSURL *)url]];
			} else if ([url isKindOfClass:[NSString class]]) {
				[dataToImport appendData:[NSData dataWithContentsOfFile:(NSString *)url]];
			}
		}
		[self importFromData:dataToImport];
	}
}
- (void)importFromData:(NSData *)data {
	__block BOOL containsRevSig = NO;
	__block BOOL containsImportable = NO;
	__block BOOL containsNonImportable = NO;
	__block NSMutableArray *keys = nil;
	
	
	[GPGPacket enumeratePacketsWithData:data block:^(GPGPacket *packet, BOOL *stop) {
		switch (packet.type) {
			case GPGSignaturePacket:
				switch (packet.signatureType) {
					case GPGBinarySignature:
					case GPGTextSignature:
						containsNonImportable = YES;
						break;
					case GPGRevocationSignature: {
						if (!keys) {
							keys = [NSMutableArray array];
						}
						GPGKey *key = [[[GPGKeyManager sharedInstance] keysByKeyID] objectForKey:packet.keyID];
						[keys addObject:key ? key : packet.keyID];
						containsRevSig = YES;
					} /* no break */
					case GPGGeneriCertificationSignature:
					case GPGPersonaCertificationSignature:
					case GPGCasualCertificationSignature:
					case GPGPositiveCertificationSignature:
					case GPGSubkeyBindingSignature:
					case GPGKeyBindingSignature:
					case GPGDirectKeySignature:
					case GPGSubkeyRevocationSignature:
					case GPGCertificationRevocationSignature:
						containsImportable = YES;
					default:
						break;
				}
				break;
			case GPGSecretKeyPacket:
			case GPGPublicKeyPacket:
			case GPGSecretSubkeyPacket:
			case GPGUserIDPacket:
			case GPGPublicSubkeyPacket:
			case GPGUserAttributePacket:
				containsImportable = YES;
				break;
			case GPGPublicKeyEncryptedSessionKeyPacket:
			case GPGSymmetricEncryptedSessionKeyPacket:
			case GPGSymmetricEncryptedDataPacket:
			case GPGSymmetricEncryptedProtectedDataPacket:
			case GPGCompressedDataPacket:
				containsNonImportable = YES;
				break;
			default:
				break;
		}
	}];
	
	if (containsRevSig) {
		if ([self warningSheetWithDefault:NO string:@"ImportRevSig", [self descriptionForKeys:keys maxLines:0 withOptions:0]] == NO) {
			return;
		}
	}
	
	
	self.progressText = localized(@"ImportKey_Progress");
	gpgc.userInfo = @{@"action": @(ShowResultAction), @"operation": @(ImportOperation), @"containsImportable": @(containsImportable), @"containsNonImportable": @(containsNonImportable)};
	[gpgc importFromData:data fullImport:NO];
}
- (IBAction)copy:(id)sender {
	NSString *stringForPasteboard = nil;
	
	NSResponder *responder = mainWindow.firstResponder;
	
	if (responder == appDelegate.userIDTable) {
		if (userIDsController.selectedObjects.count == 1) {
			GPGUserID *userID = [userIDsController.selectedObjects objectAtIndex:0];
			stringForPasteboard = userID.userIDDescription;
		}
	} else if (responder == appDelegate.signatureTable) {
		if (signaturesController.selectedObjects.count == 1) {
			GPGUserIDSignature *signature = [signaturesController.selectedObjects objectAtIndex:0];
			stringForPasteboard = signature.keyID;
		}
	} else if (responder == appDelegate.subkeyTable) {
		if (subkeysController.selectedObjects.count == 1) {
			GPGKey *subkey = [subkeysController.selectedObjects objectAtIndex:0];
			stringForPasteboard = subkey.keyID;
		}
	} else {
		NSSet *keys = [self selectedKeys];
		if (keys.count > 0) {
			gpgc.async = NO;
			gpgc.useArmor = YES;
			stringForPasteboard = [[gpgc exportKeys:keys allowSecret:NO fullExport:NO] gpgString];
			gpgc.async = YES;
		}
	}
	
	
	if ([stringForPasteboard length] > 0) {
		NSPasteboard *pboard = [NSPasteboard generalPasteboard];
		[pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
		[pboard setString:stringForPasteboard forType:NSStringPboardType];
	}
	
}
- (IBAction)paste:(id)sender {
	
	NSPasteboard *pboard = [NSPasteboard generalPasteboard];
	NSArray *types = [pboard types];
	if ([types containsObject:NSFilenamesPboardType]) {
		NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
		[self importFromURLs:files];
	} else if ([types containsObject:NSStringPboardType]) {
		NSData *data = [pboard dataForType:NSStringPboardType];
		if (data) {
			[self importFromData:data];
		}
	}
}
- (IBAction)sendKeysPerMail:(id)sender {
	NSSet *keys = [self selectedKeys];
	if (keys.count == 0) {
		return;
	}

	BOOL yourKey = keys.count == 1 && [keys.anyObject secret];
	
	NSString *description = [self descriptionForKeys:keys maxLines:5 withOptions:0];
	
	self.progressText = [NSString stringWithFormat:localized(yourKey ? @"MailKey_Progress_Your" : @"MailKey_Progress"), description];
	self.errorText = localized(@"MailKey_Error");
	
	
	gpgc.async = NO;
	gpgc.useArmor = YES;
	NSData *data = [gpgc exportKeys:keys allowSecret:NO fullExport:NO];
	gpgc.async = YES;
	if (data.length == 0) {
		return;
	}
	
	NSString *templateString = [NSTemporaryDirectory() stringByAppendingPathComponent:@"GKA.XXXXXX"];
	NSMutableData *template = [[templateString dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];

	char *tempDir = [template mutableBytes];
	if (!mkdtemp(tempDir)) {
		return;
	}
	
	NSString *path = [NSString stringWithFormat:@"%s/%@.asc", tempDir, keys.count == 1 ? [[keys anyObject] shortKeyID] : localized(@"Keys")];
	NSURL *url = [NSURL fileURLWithPath:path];
	NSError *error = nil;
	[data writeToURL:url options:0 error:&error];
	if (error) {
		return;
	}
	
	NSString *subjectDescription = [self descriptionForKeys:keys maxLines:1 withOptions:DescriptionSingleLine | DescriptionNoKeyID | DescriptionNoEmail];

	
	NSString *subject = [NSString stringWithFormat:localized(yourKey ? @"MailKey_Subject_Your" : @"MailKey_Subject"), subjectDescription];
	NSString *message = [NSString stringWithFormat:localized(yourKey ? @"MailKey_Message_Your" : @"MailKey_Message"), description, subjectDescription];
	
	
	
	NSSharingService *service = [NSSharingService sharingServiceNamed:NSSharingServiceNameComposeEmail];
	
	[service setValue:@{@"NSSharingServiceParametersDefaultSubjectKey": subject} forKey:@"parameters"];
	[service performWithItems:@[message, url]];
}


#pragma mark Window and display
- (IBAction)refreshDisplayedKeys:(id)sender {
	[[GPGKeyManager sharedInstance] loadAllKeys];
}

#pragma mark Keys
- (IBAction)generateNewKey:(id)sender {
	sheetController.sheetType = SheetTypeNewKey;
	sheetController.autoUpload = NO;
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
	
	
	NSString *passphrase = sheetController.passphrase;
	if (!passphrase) {
		passphrase = @"";
	}
	gpgc.passphrase = passphrase;
	
	NSMutableArray *actions = [NSMutableArray array];
	
	[actions addObject:@(RevCertificateAction)];
	
	if (sheetController.autoUpload) {
		[actions addObject:@(UploadKeyAction)];
	}
	
	gpgc.userInfo = @{@"action": actions, @"operation": @(NewKeyOperation), @"passphrase": passphrase};
	
	
	[gpgc generateNewKeyWithName:sheetController.name
						   email:sheetController.email
						 comment:sheetController.comment
						 keyType:keyType
					   keyLength:sheetController.length
					  subkeyType:subkeyType
					subkeyLength:sheetController.length
					daysToExpire:sheetController.daysToExpire
					 preferences:nil];
}
- (IBAction)deleteKey:(id)sender {
	NSSet *keys = [self selectedKeys];
	if (keys.count == 0) {
		return;
	}
	
	
	NSString *title, *message, *button1, *button2, *button3 = nil, *description, *template;
	NSMutableArray *descriptions = [NSMutableArray arrayWithCapacity:keys.count];
	BOOL hasSecretKey = NO;
	
	for (GPGKey *key in keys) {
		if (key.secret) {
			hasSecretKey = YES;
		}
		description = [NSString stringWithFormat:@"%@ (%@)", key.userIDDescription, key.keyID.shortKeyID];
		[descriptions addObject:description];
	}
	description = [descriptions componentsJoinedByString:@"\n"];
	
	
	
	if (hasSecretKey) {
		if (keys.count == 1) {
			template = @"DeleteSecKey";
		} else {
			template = @"DeleteSecKeys";
		}
	} else {
		if (keys.count == 1) {
			template = @"DeleteKey";
		} else {
			template = @"DeleteKeys";
		}
	}
	
	
	title = localized([template stringByAppendingString:@"_Title"]);
	message = [NSString stringWithFormat:localized([template stringByAppendingString:@"_Msg"]), description];
	button2 = localized([template stringByAppendingString:@"_Yes"]);
	button1 = localized([template stringByAppendingString:@"_No"]);
	if (hasSecretKey) {
		button3 = localized([template stringByAppendingString:@"_SecOnly"]);
		NSMutableSet *secretKeys = [NSMutableSet set];
		for (GPGKey *key in keys) {
			if (key.secret) {
				[secretKeys addObject:key];
			}
		}
		keys = secretKeys;
	}
	
	
	
	NSInteger result;
	result = [sheetController alertSheetWithTitle:title
										  message:message
									defaultButton:button1
								  alternateButton:button2
									  otherButton:button3
								suppressionButton:nil];

	
	
	GPGDeleteKeyMode mode;
	switch (result) {
		case NSAlertSecondButtonReturn:
			mode = GPGDeletePublicAndSecretKey;
			break;
		case NSAlertThirdButtonReturn:
			mode = GPGDeleteSecretKey;
			break;
		default:
			return;
	}
	
	self.progressText = localized(@"DeleteKeys_Progress");
	self.errorText = localized(@"DeleteKeys_Error");
	[gpgc deleteKeys:keys withMode:mode];
}

#pragma mark Key attributes
- (IBAction)changePassphrase:(id)sender {
	NSSet *keys = [self selectedKeys];
	if ([keys count] == 1) {
		GPGKey *key = [[keys anyObject] primaryKey];
		
		self.progressText = localized(@"ChangePassphrase_Progress");
		self.errorText = localized(@"ChangePassphrase_Error");
		[gpgc changePassphraseForKey:key];
	}
}
- (IBAction)setDisabled:(id)sender {
	NSSet *keys = [self selectedKeys];
	BOOL disabled = [sender state] == NSOnState;
	[self setDisabled:disabled forKeys:keys];
}
- (void)setDisabled:(BOOL)disabled forKeys:(NSSet *)keys {
	if (keys.count == 0) {
		return;
	}
	self.progressText = localized(@"SetDisabled_Progress");
	self.errorText = localized(@"SetDisabled_Error");
	
	GPGKey *key = keys.anyObject;
	
	if (keys.count > 1) {
		if (![keys isKindOfClass:[NSMutableSet class]]) {
			keys = [keys mutableCopy];
		}
		[(NSMutableSet *)keys removeObject:key];
		
		gpgc.userInfo = @{@"action": @(SetDisabledAction), @"keys": keys, @"disabled": @(disabled)};
	}
	
	[gpgc key:key setDisabled:disabled];
}
- (IBAction)setTrust:(NSPopUpButton *)sender {
	NSSet *keys = [self selectedKeys];
	NSInteger trust = sender.selectedTag;
	[self setTrust:trust forKeys:keys];
}
- (void)setTrust:(NSInteger)trust forKeys:(NSSet *)keys {
	if (keys.count == 0) {
		return;
	}
	self.progressText = localized(@"SetOwnerTrust_Progress");
	self.errorText = localized(@"SetOwnerTrust_Error");
	
	GPGKey *key = keys.anyObject;
	
	if (keys.count > 1) {
		if (![keys isKindOfClass:[NSMutableSet class]]) {
			keys = [keys mutableCopy];
		}
		[(NSMutableSet *)keys removeObject:key];
		
		gpgc.userInfo = @{@"action": @(SetTrustAction), @"keys": keys, @"trust": @(trust)};
	}
	
	[gpgc key:key setOwnerTrust:trust];
}

- (IBAction)changeExpirationDate:(id)sender {
	NSSet *keys = [self selectedKeys];
	if ([keys count] != 1) {
		return;
	}
	GPGKey *subkey = nil;
	GPGKey *key = [[keys anyObject] primaryKey];
	
	if ([sender tag] == 1 && [[subkeysController selectedObjects] count] == 1) {
		subkey = [[subkeysController selectedObjects] objectAtIndex:0];
	}
	
	if (subkey) {
		sheetController.msgText = [NSString stringWithFormat:localized(@"ChangeSubkeyExpirationDate_Msg"), subkey.keyID.shortKeyID, [key userIDDescription], key.keyID.shortKeyID];
		sheetController.expirationDate = [subkey expirationDate];
	} else {
		sheetController.msgText = [NSString stringWithFormat:localized(@"ChangeExpirationDate_Msg"), [key userIDDescription], key.keyID.shortKeyID];
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
	GPGKey *key = [[keys anyObject] primaryKey];
	
	
	NSArray *algorithmPreferences = [gpgc algorithmPreferencesForKey:key];
		
	NSMutableArray *mutablePreferences = [NSMutableArray array];
	for (NSDictionary *prefs in algorithmPreferences) {
		NSMutableDictionary *tempPrefs = [prefs mutableCopy];
		[mutablePreferences addObject:tempPrefs];
	}
	
	
	
	sheetController.allowEdit = key.secret;
	sheetController.algorithmPreferences = mutablePreferences;
	sheetController.sheetType = SheetTypeAlgorithmPreferences;
	if ([sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	
	NSArray *newPreferences = sheetController.algorithmPreferences;
	
	NSUInteger count = algorithmPreferences.count;
	for (NSUInteger i = 0; i < count; i++) {
		NSDictionary *oldPrefs = [algorithmPreferences objectAtIndex:i];
		NSDictionary *newPrefs = [newPreferences objectAtIndex:i];
		if (![oldPrefs isEqualToDictionary:newPrefs]) {
			NSString *userIDDescription = [newPrefs objectForKey:@"userIDDescription"];
			NSString *cipherPreferences = [[newPrefs objectForKey:@"cipherPreferences"] componentsJoinedByString:@" "];
			NSString *digestPreferences = [[newPrefs objectForKey:@"digestPreferences"] componentsJoinedByString:@" "];
			NSString *compressPreferences = [[newPrefs objectForKey:@"compressPreferences"] componentsJoinedByString:@" "];
			
			self.progressText = localized(@"SetAlgorithmPreferences_Progress");
			self.errorText = localized(@"SetAlgorithmPreferences_Error");
			[gpgc setAlgorithmPreferences:[NSString stringWithFormat:@"%@ %@ %@", cipherPreferences, digestPreferences, compressPreferences] forUserID:userIDDescription ofKey:key];
		}
	}
}

#pragma mark Keys (other)
- (IBAction)cleanKey:(id)sender {
	NSSet *keys = [self selectedKeys];
	
	self.progressText = localized(@"CleanKey_Progress");
	self.errorText = localized(@"CleanKey_Error");

	[gpgc cleanKeys:keys];
}
- (IBAction)minimizeKey:(id)sender {
	NSSet *keys = [self selectedKeys];
	
	self.progressText = localized(@"MinimizeKey_Progress");
	self.errorText = localized(@"MinimizeKey_Error");
	[gpgc minimizeKeys:keys];
}
- (IBAction)genRevokeCertificate:(id)sender {
	NSSet *keys = [self selectedKeys];
	if ([keys count] != 1) {
		return;
	}
	GPGKey *key = [[keys anyObject] primaryKey];

	[self revCertificateForKey:key customPath:YES];
}
- (void)revCertificateForKey:(NSObject <KeyFingerprint> *)key customPath:(BOOL)customPath {
	BOOL hideExtension = NO;
	NSURL *url = nil;
	
	if (customPath) {
		sheetController.title = nil; //TODO
		sheetController.msgText = nil; //TODO
		sheetController.allowedFileTypes = [NSArray arrayWithObjects:@"asc", nil];
		sheetController.pattern = [NSString stringWithFormat:localized(@"%@ Revoke certificate"), key.description.keyID.shortKeyID];
		
		sheetController.sheetType = SheetTypeSavePanel;
		if ([sheetController runModalForWindow:mainWindow] != NSOKButton) {
			return;
		}
		hideExtension = sheetController.hideExtension;
		url = sheetController.URL;
	} else {
		NSString *path = [[GPGOptions sharedOptions] gpgHome];
		path = [path stringByAppendingPathComponent:@"RevCerts"];
		[[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil];
		path = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_rev.asc", key.description.keyID]];
		url = [NSURL fileURLWithPath:path];
		revCertCache = nil;
	}
	
	
	self.progressText = localized(@"GenerateRevokeCertificateForKey_Progress");
	self.errorText = localized(@"GenerateRevokeCertificateForKey_Error");
	
	
	
	if ([gpgc.userInfo[@"action"] isKindOfClass:[NSArray class]]) {
		NSMutableDictionary *userInfo = [gpgc.userInfo mutableCopy];
		NSMutableArray *actions = [NSMutableArray arrayWithObject:@(SaveDataToURLAction)];
		[actions addObjectsFromArray:userInfo[@"action"]];

		userInfo[@"action"] = actions;
		userInfo[@"URL"] = url;
		userInfo[@"hideExtension"] = @(hideExtension);
		
		gpgc.userInfo = userInfo;
	} else {
		gpgc.userInfo = @{@"action": @(SaveDataToURLAction), @"URL": url, @"hideExtension": @(hideExtension)};
	}
	
	
	[gpgc generateRevokeCertificateForKey:key reason:0 description:nil];
}
- (IBAction)revokeKey:(id)sender {
	NSSet *keys = [self selectedKeys];
	if ([keys count] != 1) {
		return;
	}
	GPGKey *key = [[keys anyObject] primaryKey];

	[self revokeKey:key generateIfNeeded:YES];
}

- (void)revokeKey:(NSObject <KeyFingerprint> *)key generateIfNeeded:(BOOL)generate {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	NSString *path = [[[GPGOptions sharedOptions] gpgHome] stringByAppendingPathComponent:[NSString stringWithFormat:@"RevCerts/%@_rev.asc", key.keyID]];
	
	
	__block BOOL haveValidRevCert = NO;
	if ([fileManager fileExistsAtPath:path]) {
		NSData *data = [NSData dataWithContentsOfFile:path];
		
		[GPGPacket enumeratePacketsWithData:data block:^(GPGPacket *packet, BOOL *stop) {
			if (packet.type == GPGSignaturePacket && packet.signatureType == GPGRevocationSignature) {
				if (packet.keyID ) {
					haveValidRevCert = YES;
					*stop = YES;
				}
			}
		}];
		
		if (haveValidRevCert) {
			NSInteger returnCode = [sheetController alertSheetForWindow:mainWindow
												  messageText:localized(@"RevokeKey_Title")
													 infoText:[NSString stringWithFormat:localized(@"RevokeKey_Msg"), [self descriptionForKey:key]]
												defaultButton:localized(@"RevokeKey_No")
											  alternateButton:localized(@"RevokeKey_Yes")
												  otherButton:nil
											suppressionButton:localized(@"RevokeKey_Upload")];
			
			if (returnCode & SheetSuppressionButton) {
				returnCode -= SheetSuppressionButton;
				gpgc.userInfo = @{@"action": @[@(UploadKeyAction)], @"keys":[NSSet setWithObject:key]};
			} else {
				gpgc.userInfo = @{};
			}
			if (returnCode != NSAlertSecondButtonReturn) {
				return;
			}
			
			self.errorText = nil;
			self.progressText = localized(@"RevokeKey_Progress");
			self.errorText = localized(@"RevokeKey_Error");
			
			[gpgc importFromData:data fullImport:NO];
		}
	}
	
	if (!haveValidRevCert && generate) {
		GPGKey *gpgKey = [[[KeychainController sharedInstance] allKeys] member:key];
		if (gpgKey.secret) {
			gpgc.userInfo = @{@"action": @[@(RevokeKeyAction)], @"keys":[NSSet setWithObject:key]};
			[self revCertificateForKey:key customPath:NO];
		}
	}
}
- (BOOL)canRevokeKey:(GPGKey *)key {
	if (!revCertCache) {
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSString *path = [[[GPGOptions sharedOptions] gpgHome] stringByAppendingPathComponent:@"RevCerts"];

		NSArray *files = [fileManager contentsOfDirectoryAtPath:path error:nil];
		if (files) {
			NSMutableSet *keyIDs = [NSMutableSet set];
			for (NSString *file in files) {
				if (file.length == 24 && [[file substringFromIndex:16] isEqualToString:@"_rev.asc"]) {
					[keyIDs addObject:[file substringToIndex:16]];
				}
			}
			
			revCertCache = [keyIDs copy];
		}
	}
	
	return !key.revoked && (key.secret || [revCertCache containsObject:key.keyID]);
}




#pragma mark Keyserver
- (IBAction)searchKeys:(id)sender {
	sheetController.sheetType = SheetTypeSearchKeys;
	if ([sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	gpgc.userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:ShowFoundKeysAction] forKey:@"action"];
	
	self.progressText = localized(@"SearchKeysOnServer_Progress");
	self.errorText = localized(@"SearchKeysOnServer_Error");
	
	
	
	NSString *pattern = sheetController.pattern;
	
	[gpgc searchKeysOnServer:pattern];
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
	if (keys.count > 0) {
		self.progressText = [NSString stringWithFormat:localized(@"SendKeysToServer_Progress"), [self descriptionForKeys:keys maxLines:8 withOptions:0]];
		self.errorText = localized(@"SendKeysToServer_Error");
		[gpgc sendKeysToServer:keys];
	}
}
- (IBAction)refreshKeysFromServer:(id)sender {
	NSSet *keys = [self selectedKeys];
	if (keys.count > 0) {
		self.progressText = [NSString stringWithFormat:localized(@"RefreshKeysFromServer_Progress"), [self descriptionForKeys:keys maxLines:8 withOptions:0]];
		self.errorText = localized(@"RefreshKeysFromServer_Error");
		[gpgc receiveKeysFromServer:keys];
	}
}

#pragma mark Subkeys
- (IBAction)addSubkey:(id)sender {
	NSSet *keys = [self selectedKeys];
	if ([keys count] != 1) {
		return;
	}
	GPGKey *key = [[keys anyObject] primaryKey];
	
	sheetController.msgText = [NSString stringWithFormat:localized(@"GenerateSubkey_Msg"), [key userIDDescription], key.keyID.shortKeyID];
	
	sheetController.sheetType = SheetTypeAddSubkey;
	if ([sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	self.progressText = localized(@"AddSubkey_Progress");
	self.errorText = localized(@"AddSubkey_Error");
	[gpgc addSubkeyToKey:key type:sheetController.keyType length:sheetController.length daysToExpire:sheetController.daysToExpire];
}
- (IBAction)removeSubkey:(id)sender {
	NSArray *objects = [self selectedObjectsOf:subkeysTable];
	if (objects.count != 1) {
		return;
	}
	GPGKey *subkey = [objects objectAtIndex:0];
	GPGKey *key = subkey.primaryKey;
	
	if ([self warningSheetWithDefault:NO string:@"RemoveSubkey"] == NO) {
		return;
	}
	
	self.progressText = localized(@"RemoveSubkey_Progress");
	self.errorText = localized(@"RemoveSubkey_Error");
	[gpgc removeSubkey:subkey fromKey:key];
}
- (IBAction)revokeSubkey:(id)sender {
	NSArray *objects = [self selectedObjectsOf:subkeysTable];
	if (objects.count != 1) {
		return;
	}
	GPGKey *subkey = [objects objectAtIndex:0];
	GPGKey *key = subkey.primaryKey;
	
	if ([self warningSheetWithDefault:NO string:@"RevokeSubkey"] == NO) {
		return;
	}
	
	self.progressText = localized(@"RevokeSubkey_Progress");
	self.errorText = localized(@"RevokeSubkey_Error");
	[gpgc revokeSubkey:subkey fromKey:key reason:0 description:nil];
}

#pragma mark UserIDs
- (IBAction)addUserID:(id)sender {
	NSSet *keys = [self selectedKeys];
	if ([keys count] != 1) {
		return;
	}
	GPGKey *key = [[keys anyObject] primaryKey];
	
	sheetController.msgText = [NSString stringWithFormat:localized(@"GenerateUserID_Msg"), [key userIDDescription], key.keyID.shortKeyID];
	
	sheetController.sheetType = SheetTypeAddUserID;
	if ([sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	self.progressText = localized(@"AddUserID_Progress");
	self.errorText = localized(@"AddUserID_Error");
	gpgc.userInfo = @{@"action": @(SetPrimaryUserIDAction), @"userID": key.primaryUserID};
	[gpgc addUserIDToKey:key name:sheetController.name email:sheetController.email comment:sheetController.comment];
}
- (IBAction)removeUserID:(id)sender {
	NSArray *objects = [self selectedObjectsOf:userIDsTable];
	if (objects.count != 1) {
		return;
	}
	GPGUserID *userID = [objects objectAtIndex:0];
	GPGKey *key = userID.primaryKey;
	
	if ([self warningSheetWithDefault:NO string:@"RemoveUserID", userID.userIDDescription, key.keyID.shortKeyID] == NO) {
		return;
	}
	
	self.progressText = localized(@"RemoveUserID_Progress");
	self.errorText = localized(@"RemoveUserID_Error");
	[gpgc removeUserID:userID.hashID fromKey:key];
}
- (IBAction)setPrimaryUserID:(id)sender {
	NSArray *objects = [self selectedObjectsOf:userIDsTable];
	if (objects.count != 1) {
		return;
	}
	GPGUserID *userID = [objects objectAtIndex:0];
	GPGKey *key = userID.primaryKey;
	
	self.progressText = localized(@"SetPrimaryUserID_Progress");
	self.errorText = localized(@"SetPrimaryUserID_Error");
	[gpgc setPrimaryUserID:userID.hashID ofKey:key];
}
- (IBAction)revokeUserID:(id)sender {
	NSArray *objects = [self selectedObjectsOf:userIDsTable];
	if (objects.count != 1) {
		return;
	}
	GPGUserID *userID = [objects objectAtIndex:0];
	GPGKey *key = userID.primaryKey;
	
	if ([self warningSheetWithDefault:NO string:@"RevokeUserID", userID.userIDDescription, key.keyID.shortKeyID] == NO) {
		return;
	}
	
	self.progressText = localized(@"RevokeUserID_Progress");
	self.errorText = localized(@"RevokeUserID_Error");
	[gpgc revokeUserID:[userID hashID] fromKey:key reason:0 description:nil];
}

#pragma mark Photos
- (void)addPhoto:(NSString *)path toKey:(GPGKey *)key {
	
	self.progressText = localized(@"AddPhoto_Progress");
	self.errorText = localized(@"AddPhoto_Error");
	[gpgc addPhotoFromPath:path toKey:key];
}
- (IBAction)addPhoto:(id)sender {
	NSSet *keys = [self selectedKeys];
	if ([keys count] != 1) {
		return;
	}
	GPGKey *key = [[keys anyObject] primaryKey];
	if (!key.secret) {
		return;
	}
	
	sheetController.title = nil; //TODO
	sheetController.msgText = nil; //TODO
	sheetController.allowedFileTypes = [NSArray arrayWithObjects:@"jpg", @"jpeg", nil];;
	
	sheetController.sheetType = SheetTypeOpenPhotoPanel;
	if ([sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	[self addPhoto:[sheetController.URL path] toKey:key];
}
- (IBAction)removePhoto:(id)sender {
	if ([photosController selectionIndex] != NSNotFound) {
		NSSet *keys = [self selectedKeys];
		GPGKey *key = [[keys anyObject] primaryKey];
		
		self.progressText = localized(@"RemovePhoto_Progress");
		self.errorText = localized(@"RemovePhoto_Error");
		[gpgc removeUserID:[[[photosController selectedObjects] objectAtIndex:0] hashID] fromKey:key];
	}
}
- (IBAction)setPrimaryPhoto:(id)sender {
	if ([photosController selectionIndex] != NSNotFound) {
		GPGKey *key = [[[self selectedKeys] anyObject] primaryKey];
		
		self.progressText = localized(@"SetPrimaryPhoto_Progress");
		self.errorText = localized(@"SetPrimaryPhoto_Error");
		[gpgc setPrimaryUserID:[[[photosController selectedObjects] objectAtIndex:0] hashID] ofKey:key];
	}
}
- (IBAction)revokePhoto:(id)sender {
	if ([photosController selectionIndex] != NSNotFound) {
		GPGKey *key = [[[self selectedKeys] anyObject] primaryKey];
		
		self.progressText = localized(@"RevokePhoto_Progress");
		self.errorText = localized(@"RevokePhoto_Error");
		[gpgc revokeUserID:[[[photosController selectedObjects] objectAtIndex:0] hashID] fromKey:key reason:0 description:nil];
	}
}

#pragma mark Signatures
- (IBAction)addSignature:(id)sender {
	NSSet *keys = [self selectedKeys];
	if (keys.count != 1) {
		return;
	}
	
	GPGUserID *userID = nil;
	if ([sender tag] == 1) {
		NSArray *objects = [self selectedObjectsOf:userIDsTable];
		if (objects.count != 1) {
			return;
		}
		userID = [objects objectAtIndex:0];
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
	
	
	NSString *msgText;
	if (userID) {
		msgText = [NSString stringWithFormat:localized(@"GenerateUidSignature_Msg"), [NSString stringWithFormat:@"%@ (%@)", userID.userIDDescription, key.keyID.shortKeyID]];
	} else {
		msgText = [NSString stringWithFormat:localized(@"GenerateSignature_Msg"), key.userIDAndKeyID];
	}
	
	sheetController.msgText = msgText;
	
	sheetController.sheetType = SheetTypeAddSignature;
	if ([sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	self.progressText = localized(@"AddSignature_Progress");
	self.errorText = localized(@"AddSignature_Error");
	[gpgc signUserID:[userID hashID] ofKey:key signKey:sheetController.secretKey type:sheetController.sigType local:sheetController.localSig daysToExpire:sheetController.daysToExpire];
}
- (IBAction)removeSignature:(id)sender {
	NSArray *objects = [self selectedObjectsOf:signaturesTable];
	if (objects.count != 1) {
		return;
	}
	GPGUserIDSignature *signature = [objects objectAtIndex:0];
	GPGUserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
	GPGKey *key = userID.primaryKey;
	BOOL lastSelfSignature = NO;
	
	if ([signature.primaryKey isEqualTo:key] && !signature.revocation) {
		NSArray *signatures = userID.signatures;
		NSInteger count = 0;
		for (GPGUserIDSignature *sig in signatures) {
			if ([sig.primaryKey isEqualTo:key]) {
				count++;
				if (count > 1) {
					break;
				}
			}
		}
		lastSelfSignature = (count == 1);
	}
	
	NSString *warningTemplate = lastSelfSignature ? @"RemoveLastSelfSignature" : @"RemoveSignature";
	if ([self warningSheetWithDefault:NO string:warningTemplate, signature.userIDDescription, signature.userIDDescription] == NO) {
		return;
	}

	
	self.progressText = localized(@"RemoveSignature_Progress");
	self.errorText = localized(@"RemoveSignature_Error");
	[gpgc removeSignature:signature fromUserID:userID ofKey:key];
}
- (IBAction)revokeSignature:(id)sender {
	NSArray *objects = [self selectedObjectsOf:signaturesTable];
	if (objects.count != 1) {
		return;
	}
	GPGUserIDSignature *signature = [objects objectAtIndex:0];
	GPGUserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
	GPGKey *key = userID.primaryKey;
	BOOL lastSelfSignature = NO;
	
	if ([signature.primaryKey isEqualTo:key] && !signature.revocation) {
		NSArray *signatures = userID.signatures;
		NSInteger count = 0;
		for (GPGUserIDSignature *sig in signatures) {
			if ([sig.primaryKey isEqualTo:key]) {
				count++;
				if (count > 1) {
					break;
				}
			}
		}
		lastSelfSignature = (count == 1);
	}
	
	NSString *warningTemplate = lastSelfSignature ? @"RevokeLastSelfSignature" : @"RevokeSignature";
	if ([self warningSheetWithDefault:NO string:warningTemplate, signature.userIDDescription, signature.userIDDescription] == NO) {
		return;
	}
	
	self.progressText = localized(@"RevokeSignature_Progress");
	self.errorText = localized(@"RevokeSignature_Error");
	[gpgc revokeSignature:signature fromUserID:userID ofKey:key reason:0 description:nil];
}




#pragma mark Miscellaneous :)
- (void)cancelGPGOperation:(id)sender {
	[gpgc cancel];
}

- (void)cancel:(id)sender {
	appDelegate.inspectorVisible = NO;
}


- (void)receiveKeysFromServer:(NSObject <EnumerationList> *)keys {
	gpgc.userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:ShowResultAction] forKey:@"action"];
	
	self.progressText = localized(@"ReceiveKeysFromServer_Progress");
	self.errorText = localized(@"ReceiveKeysFromServer_Error");
	[gpgc receiveKeysFromServer:keys];
}

- (NSString *)importResultWithStatusDict:(NSDictionary *)statusDict {
	int publicKeysCount, publicKeysOk, publicKeysNoChange, secretKeysCount, secretKeysOk, userIDCount, subkeyCount, signatureCount, revocationCount;
	int flags;
	NSString *fingerprint, *keyID, *userID;
	NSArray *importRes = nil;
	NSMutableArray *lines = [NSMutableArray array];
	NSMutableDictionary *changedKeys = [NSMutableDictionary dictionary];
	NSNumber *no = [NSNumber numberWithBool:NO], *yes = [NSNumber numberWithBool:YES];
	NSSet *allKeys = [(KeychainController *)[KeychainController sharedInstance] allKeys];
	
	NSArray *importResList = [statusDict objectForKey:@"IMPORT_RES"];
	NSArray *importOkList = [statusDict objectForKey:@"IMPORT_OK"];
	
	for (NSArray *importOk in importOkList) {
		flags = [[importOk objectAtIndex:0] intValue];
		fingerprint = [importOk objectAtIndex:1];
		
		userID = [[allKeys member:fingerprint] userIDDescription];
		if (!userID) userID = @"";
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
	}
	
	
	
	for (fingerprint in [changedKeys allKeysForObject:no]) {
		userID = [[allKeys member:fingerprint] userIDDescription];
		if (!userID) userID = @"";
		keyID = [fingerprint shortKeyID];
		
		[lines addObject:[NSString stringWithFormat:localized(@"ImportResult_KeyNoChanges"), keyID, userID]];
	}
	
	
	
	if ([importResList count] > 0) {
		importRes = [importResList objectAtIndex:0];
		
		publicKeysCount = [[importRes objectAtIndex:0] intValue];
		publicKeysOk = [[importRes objectAtIndex:2] intValue];
		publicKeysNoChange = [[importRes objectAtIndex:4] intValue];
		userIDCount = [[importRes objectAtIndex:5] intValue];
		subkeyCount = [[importRes objectAtIndex:6] intValue];
		signatureCount = [[importRes objectAtIndex:7] intValue];
		revocationCount = [[importRes objectAtIndex:8] intValue];
		secretKeysCount = [[importRes objectAtIndex:9] intValue];
		secretKeysOk = [[importRes objectAtIndex:10] intValue];
		
		
		//TODO: More infos.
		
		if (revocationCount > 0) {
			if (revocationCount == 1) {
				[lines addObject:[NSString stringWithFormat:localized(@"ImportResult_OneRevocationCertificate"), @""]];
			} else {
				[lines addObject:[NSString stringWithFormat:localized(@"ImportResult_CountRevocationCertificate"), revocationCount]];
			}
		}
		
		if ([lines count] > 0) {
			[lines addObject:@""];
		}
		
		[lines addObject:[NSString stringWithFormat:localized(@"ImportResult_CountProcessed"), publicKeysCount]];
		if (publicKeysOk > 0) {
			[lines addObject:[NSString stringWithFormat:localized(@"ImportResult_CountImported"), publicKeysOk]];
		}
		if (publicKeysNoChange > 0) {
			[lines addObject:[NSString stringWithFormat:localized(@"ImportResult_CountUnchanged"), publicKeysNoChange]];
		}
	}
	
	
	return [lines componentsJoinedByString:@"\n"];
}

- (NSUndoManager *)undoManager {
	/*if (!undoManager) {
		undoManager = [NSUndoManager new];
		[undoManager setLevelsOfUndo:50];
	}
	return undoManager;*/
	return nil;
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
- (NSArray *)selectedObjectsOf:(NSTableView *)table {
	NSArrayController *arrayController;
	if (table == userIDsTable) {
		arrayController = userIDsController;
	} else if (table == signaturesTable) {
		arrayController = signaturesController;
	} else if (table == subkeysTable) {
		arrayController = subkeysController;
	} else {
		return nil;
	}

	NSInteger clickedRow = [table clickedRow];
	if (clickedRow != -1 && ![table isRowSelected:clickedRow]) {
		return @[[arrayController.arrangedObjects objectAtIndex:clickedRow]];
	} else {
		return [arrayController selectedObjects];
	}
}


- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)item {
    SEL selector = item.action;
	NSInteger tag = item.tag;
	
	
	if (selector == @selector(delete:)) {
		NSResponder *responder = mainWindow.firstResponder;
		
		if (responder == appDelegate.userIDTable) {
			selector = @selector(removeUserID:);
		} else if (responder == appDelegate.signatureTable) {
			selector = @selector(removeSignature:);
		} else if (responder == appDelegate.subkeyTable) {
			selector = @selector(removeSubkey:);
		} else {
			selector = @selector(deleteKey:);
		}
	}
	
	
    if (selector == @selector(copy:) ||
		selector == @selector(sendKeysToServer:) ||
		selector == @selector(refreshKeysFromServer:) ||
		selector == @selector(deleteKey:)) {
		return self.selectedKeys.count > 0;
    }
	else if (selector == @selector(paste:)) {
		NSPasteboard *pboard = [NSPasteboard generalPasteboard];
		NSArray *types = [pboard types];
		if ([types containsObject:NSFilenamesPboardType]) {
			return YES;
		} else if ([types containsObject:NSStringPboardType]) {
			NSString *string = [pboard stringForType:NSStringPboardType];
			if (couldContainPGPKey(string)) {
				return YES;
			} else {
				return NO;
			}
		}
    }
	else if (selector == @selector(genRevokeCertificate:)) {
		NSSet *keys = [self selectedKeys];
		return (keys.count == 1 && ((GPGKey*)[keys anyObject]).secret);
    }
	else if (selector == @selector(editAlgorithmPreferences:)) {
		return self.selectedKeys.count == 1;
	}
	else if (selector == @selector(addSignature:)) {
		if (tag == 1) {
			return [self selectedObjectsOf:userIDsTable].count == 1;
		}
	}
	else if (selector == @selector(removeUserID:)) {
		return [self selectedObjectsOf:userIDsTable].count == 1 && [userIDsController.arrangedObjects count] > 1;
	}
	else if (selector == @selector(revokeUserID:)) {
		NSArray *objects = [self selectedObjectsOf:userIDsTable];
		return objects.count == 1 && [[objects objectAtIndex:0] primaryKey].secret;
	}
	else if (selector == @selector(setPrimaryUserID:)) {
		NSArray *objects = [self selectedObjectsOf:userIDsTable];
		return objects.count == 1 && [[objects objectAtIndex:0] primaryKey].secret;
	}
	else if (selector == @selector(removeSignature:)) {
		NSArray *signatures = [self selectedObjectsOf:signaturesTable];
		if (signatures.count != 1) {
			return NO;
		}
		if (!showExpertSettings) {
			// Check if it's the last self-signature.
			GPGUserIDSignature *signature = signatures[0];
			GPGUserID *userID = [self selectedObjectsOf:userIDsTable][0];
			
			GPGKey *key = userID.primaryKey;
			
			if (![signature.primaryKey isEqualTo:key] || signature.revocation) {
				// Not a self signature.
				return YES;
			}
			
			signatures = userID.signatures;
			NSInteger count = 0;
			// Look for other self-signatures.
			for (signature in signatures) {
				if (!signature.revocation && [signature.primaryKey isEqualTo:key]) {
					count++;
					if (count > 1) {
						return YES;
					}
				}
			}
			return NO;
			
		}
		return YES;
	}
	else if (selector == @selector(revokeSignature:)) {
		NSArray *signatures = [self selectedObjectsOf:signaturesTable];
		if (signatures.count != 1) {
			return NO;
		}
		GPGUserIDSignature *signature = signatures[0];
		if (signature.revocation || !signature.primaryKey.secret) {
			return NO;
		}
		
		if (!showExpertSettings) {
			// Check if it's the last self-signature.
			GPGUserID *userID = [self selectedObjectsOf:userIDsTable][0];
			
			GPGKey *key = userID.primaryKey;
			
			if (![signature.primaryKey isEqualTo:key] || signature.revocation) {
				// Not a self signature.
				return YES;
			}
			
			signatures = userID.signatures;
			NSInteger count = 0;
			// Look for other self-signatures.
			for (signature in signatures) {
				if (!signature.revocation && [signature.primaryKey isEqualTo:key]) {
					count++;
					if (count > 1) {
						return YES;
					}
				}
			}
			return NO;
			
		}
		return YES;
	}
	else if (selector == @selector(removeSubkey:)) {
		return [self selectedObjectsOf:subkeysTable].count == 1;
	}
	else if (selector == @selector(revokeSubkey:)) {
		NSArray *objects = [self selectedObjectsOf:subkeysTable];
		return objects.count == 1 && [[objects objectAtIndex:0] primaryKey].secret;
	}
	else if (selector == @selector(changeExpirationDate:)) {
		if (tag == 1) {
			NSArray *objects = [self selectedObjectsOf:subkeysTable];
			return objects.count == 1 && [[objects objectAtIndex:0] primaryKey].secret;
		}
	}
	else if (selector == @selector(revokeKey:)) {
		NSSet *keys = self.selectedKeys;
		if (keys.count == 1) {
			return [self canRevokeKey:keys.anyObject];
		}
		return NO;
	}

	return YES;
}

- (BOOL)respondsToSelector:(SEL)selector {
	if (selector == @selector(copy:)) {
		NSResponder *responder = mainWindow.firstResponder;
		
		if (responder == appDelegate.userIDTable) {
			if (userIDsController.selectedObjects.count == 1) {
				return YES;
			}
		} else if (responder == appDelegate.signatureTable) {
			if (signaturesController.selectedObjects.count == 1) {
				return YES;
			}
		} else if (responder == appDelegate.subkeyTable) {
			if (subkeysController.selectedObjects.count == 1) {
				return YES;
			}
		} else if ([self selectedKeys].count > 0) {
			return YES;
		}
		return NO;
	} else if (selector == @selector(cancel:)) {
		return appDelegate.inspectorVisible;
	}
	
	return [super respondsToSelector:selector];
}

- (NSString *)descriptionForKey:(NSObject <KeyFingerprint> *)key {
	return [self descriptionForKeys:@[key] maxLines:0 withOptions:0];
}


- (NSString *)descriptionForKeys:(NSObject <EnumerationList> *)keys maxLines:(NSUInteger)lines withOptions:(DescriptionOptions)options {
	NSMutableString *descriptions = [NSMutableString string];
	Class gpgKeyClass = [GPGKey class];
	NSUInteger i = 0, count = keys.count;
	if (count == 0) {
		return @"";
	}
	if (lines > 0 && count > lines) {
		lines = lines - 1;
	} else {
		lines = NSUIntegerMax;
	}
	NSUInteger showFlags = (!(options & DescriptionNoName)) + ((!(options & DescriptionNoKeyID)) << 2);
	BOOL showEmail = !(options & DescriptionNoEmail);
	BOOL singleLine = options & DescriptionSingleLine;
	
	NSString *normalSeperator = singleLine ? @", " : @",\n";
	NSString *lastSeperator = [NSString stringWithFormat:@" %@%@", localized(@"and"), singleLine ? @" " : @"\n"];
	NSString *seperator = @"";
	
	for (__strong GPGKey *key in keys) {
		if (i >= lines && i > 0) {
			[descriptions appendFormat:localized(@"%@and %lu more"), singleLine ? @" " : @"\n" , count - i];
			break;
		}

		if (![key isKindOfClass:gpgKeyClass]) {
			GPGKeyManager *keyManager = [GPGKeyManager sharedInstance];
			GPGKey *realKey = [[keyManager allKeysAndSubkeys] member:key];
			
			if (!realKey) {
				realKey = [[keyManager keysByKeyID] objectForKey:key.keyID];
			}
			if (realKey) {
				key = realKey;
			}
		}
		
		if (i > 0) {
			seperator = normalSeperator;
			if (i == count - 1) {
				seperator = lastSeperator;
			}
		}
		
		
		if ([key isKindOfClass:gpgKeyClass]) {
			NSUInteger mailFlag = (showEmail && key.email.length) << 1;
			
			switch (showFlags + mailFlag) {
				case 1:
					[descriptions appendFormat:@"%@%@", seperator, key.name];
					break;
				case 2:
					[descriptions appendFormat:@"%@%@", seperator, key.email];
					break;
				case 3:
					[descriptions appendFormat:@"%@%@ <%@>", seperator, key.name, key.email];
					break;
				case 4:
					[descriptions appendFormat:@"%@%@", seperator, key.shortKeyID];
					break;
				case 5:
					[descriptions appendFormat:@"%@%@ (%@)", seperator, key.name, key.shortKeyID];
					break;
				case 6:
					[descriptions appendFormat:@"%@%@ (%@)", seperator, key.email, key.shortKeyID];
					break;
				default:
					[descriptions appendFormat:@"%@%@ <%@> (%@)", seperator, key.name, key.email, key.shortKeyID];
					break;
			}
		} else {
			[descriptions appendFormat:@"%@%@", seperator, key.shortKeyID];
		}
		
		
		i++;
	}
	
	return descriptions.copy;
}

- (BOOL)warningSheetWithDefault:(BOOL)defaultValue string:(NSString *)string, ... {
	// Show a sheet with the localized message "string_Msg", by replacing placeholders.
	// defaultValue defines, which button should be the default. :)
	// Returns YES when Yes is clicked.
	
	NSInteger returnCode;
	NSString *message = localized([string stringByAppendingString:@"_Msg"]);
	
	va_list args;
	va_start(args, string);
	message = [[NSString alloc] initWithFormat:message arguments:args];
	va_end(args);
	
	NSString *button1, *button2;
	if (defaultValue) {
		button1 = @"_Yes";
		button2 = @"_No";
	} else {
		button1 = @"_No";
		button2 = @"_Yes";
	}
	
	returnCode = [sheetController alertSheetForWindow:mainWindow
										  messageText:localized([string stringByAppendingString:@"_Title"])
											 infoText:message
										defaultButton:localized([string stringByAppendingString:button1])
									  alternateButton:localized([string stringByAppendingString:button2])
										  otherButton:nil
									suppressionButton:nil];
	
	return (returnCode == (defaultValue ? NSAlertFirstButtonReturn : NSAlertSecondButtonReturn));
}


#pragma mark Delegate
- (void)gpgControllerOperationDidStart:(GPGController *)gc {
	sheetController.progressText = self.progressText;
	[sheetController performSelectorOnMainThread:@selector(showProgressSheet) withObject:nil waitUntilDone:YES];
}

- (void)gpgController:(GPGController *)gc operationThrownException:(NSException *)e {
	gc.passphrase = nil;
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:gc, @"GPGController", e, @"exception", nil]; // Do not use @{} for this dcit!
	[self performSelectorOnMainThread:@selector(gpgControllerOperationThrownException:) withObject:args waitUntilDone:NO];
}

- (void)gpgControllerOperationThrownException:(NSDictionary *)args {
	GPGController *gc = [args objectForKey:@"GPGController"];
	NSException *e = [args objectForKey:@"exception"];
	
	NSString *title, *message;
	GPGException *ex = nil;
	GPGTask *gpgTask = nil;
	NSDictionary *userInfo = gc.userInfo;
	
	
	NSLog(@"Exception: %@", e.description);

	if ([e isKindOfClass:[GPGException class]]) {
		ex = (GPGException *)e;
		gpgTask = ex.gpgTask;
		if (ex.errorCode == GPGErrorCancelled) {
			return;
		}
		NSLog(@"Error text: %@\nStatus text: %@", gpgTask.errText, gpgTask.statusText);
	}
	
	
	switch ([[userInfo objectForKey:@"operation"] integerValue]) {
		case ImportOperation:
			if (![[userInfo objectForKey:@"containsImportable"] boolValue]) {
				if ([[userInfo objectForKey:@"containsNonImportable"] boolValue]) {
					title = localized(@"ImportKeyErrorPGP_Title");
					message = localized(@"ImportKeyErrorPGP_Msg");
				} else {
					title = localized(@"ImportKeyErrorNoPGP_Title");
					message = localized(@"ImportKeyErrorNoPGP_Msg");
				}
			} else {
				title = localized(@"ImportKeyError_Title");
				message = localized(@"ImportKeyError_Msg");
			}
			break;
		default:
			title = self.errorText;
			if (gpgTask) {
				NSString *errText = gpgTask.errText;
				if (errText.length > 1000) {
					errText = [NSString stringWithFormat:@"%@\n…\n%@", [errText substringToIndex:400], [errText substringFromIndex:errText.length - 400]];
				}
				message = [NSString stringWithFormat:@"%@\n\nError text:\n%@", e.description, errText];
			} else {
				message = [NSString stringWithFormat:@"%@", e.description];
			}
			break;
	}
	
	
	[sheetController errorSheetWithmessageText:title infoText:message];
}

- (void)gpgController:(GPGController *)gc operationDidFinishWithReturnValue:(id)value {
	gc.passphrase = nil;
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:gc, @"GPGController", value, @"value", nil]; // Do not use @{} for this dcit!
	[self performSelectorOnMainThread:@selector(gpgControllerOperationDidFinish:) withObject:args waitUntilDone:NO];
}

- (void)gpgControllerOperationDidFinish:(NSDictionary *)args {
	BOOL reEvaluate;
	GPGController *gc = [args objectForKey:@"GPGController"];
	id value = [args objectForKey:@"value"];

	[sheetController endProgressSheet];
	
	
	
	do {
		reEvaluate = NO;
		
		NSMutableDictionary *oldUserInfo = [NSMutableDictionary dictionaryWithDictionary:gc.userInfo];
		
		gc.userInfo = nil;
		self.progressText = nil;
		self.errorText = nil;
		
		
		switch ([oldUserInfo[@"operation"] integerValue]) {
			case NewKeyOperation:
				if (value) {
					oldUserInfo[@"keys"] = [NSSet setWithObject:value];
				} else {
					[oldUserInfo removeObjectForKey:@"keys"];
				}
				break;
		}
		oldUserInfo[@"operation"] = @0;
		
		
		NSInteger action = 0;
		NSArray *actionObject = [oldUserInfo objectForKey:@"action"];
		
		if ([actionObject isKindOfClass:[NSArray class]]) {
			if (actionObject.count > 0) {
				action = [actionObject[0] integerValue];
				if (actionObject.count > 1) {
					actionObject = [actionObject subarrayWithRange:NSMakeRange(1, actionObject.count - 1)];
					NSMutableDictionary *tempUserInfo = oldUserInfo.mutableCopy;
					tempUserInfo[@"action"] = actionObject;
					gc.userInfo = tempUserInfo;
				}
			}
		} else {
			action = [(NSNumber *)actionObject integerValue];
		}
		
		
		
		switch (action) {
			case ShowResultAction: {
				if (gc.error) break;
				
				NSDictionary *statusDict = gc.statusDict;
				if (statusDict) {
					[self refreshDisplayedKeys:self];
					
					sheetController.msgText = [self importResultWithStatusDict:statusDict];
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
					if ([sheetController runModalForWindow:mainWindow] != NSOKButton || sheetController.keys.count == 0) break;
					
					[self receiveKeysFromServer:sheetController.keys];
				}
				break;
			}
			case SaveDataToURLAction: {
				if (gc.error) break;
				
				NSURL *URL = [oldUserInfo objectForKey:@"URL"];
				NSNumber *hideExtension = @([[oldUserInfo objectForKey:@"hideExtension"] boolValue]);
				[[NSFileManager defaultManager] createFileAtPath:URL.path contents:value attributes:@{NSFileExtensionHidden: hideExtension}];
				
				reEvaluate = YES;
				
				break;
			}
			case UploadKeyAction: {
				NSSet *keys = oldUserInfo[@"keys"];
				if (gc.error || !keys) break;
				
				self.progressText = [NSString stringWithFormat:localized(@"SendKeysToServer_Progress"), [self descriptionForKeys:keys maxLines:8 withOptions:0]];
				self.errorText = localized(@"SendKeysToServer_Error");
				
				NSLog(@"Upload %@", keys);
				[gpgc sendKeysToServer:keys];
				
				break;
			}
			case SetPrimaryUserIDAction: {
				if (gc.error) break;
				
				GPGUserID *userID = [oldUserInfo objectForKey:@"userID"];
				self.progressText = localized(@"SetPrimaryUserID_Progress");
				self.errorText = localized(@"SetPrimaryUserID_Error");
				[gpgc setPrimaryUserID:userID.hashID ofKey:userID.primaryKey];
				
				break;
			}
			case SetTrustAction: {
				NSMutableSet *keys = [oldUserInfo objectForKey:@"keys"];
				NSInteger trust = [[oldUserInfo objectForKey:@"trust"] integerValue];
				
				[self setTrust:trust forKeys:keys];
				break;
			}
			case SetDisabledAction: {
				NSMutableSet *keys = [oldUserInfo objectForKey:@"keys"];
				BOOL disabled = [[oldUserInfo objectForKey:@"disabled"] boolValue];
				
				[self setDisabled:disabled forKeys:keys];
				break;
			}
			case RevCertificateAction: {
				NSSet *keys = oldUserInfo[@"keys"];
				if (gc.error || !keys) break;
				
				GPGKey *key = [keys anyObject];
				
				self.progressText = [NSString stringWithFormat:localized(@"SendKeysToServer_Progress"), [self descriptionForKey:key]];
				self.errorText = localized(@"SendKeysToServer_Error");
				
				gc.passphrase = oldUserInfo[@"passphrase"];
				[self revCertificateForKey:key customPath:NO];
				
				break;
			}
			case RevokeKeyAction: {
				NSSet *keys = oldUserInfo[@"keys"];
				if (gc.error || !keys) break;
				
				[self revokeKey:[keys anyObject] generateIfNeeded:NO];
				
				break;
			}
			default:
				break;
		}
	} while (reEvaluate);
	
}



#pragma mark Singleton: alloc, init etc.
+ (instancetype)sharedInstance {
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
		
		gpgc = [GPGController gpgController];
		gpgc.delegate = self;
		gpgc.undoManager = self.undoManager;
		gpgc.printVersion = YES;
		gpgc.async = YES;
		gpgc.keyserverTimeout = 20;
		sheetController = [SheetController sharedInstance];
	}
	return self;
}
+ (id)allocWithZone:(NSZone *)zone {
    return [self sharedInstance];
}
- (id)copyWithZone:(NSZone *)zone {
    return self;
}



@end

