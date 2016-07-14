/*
 Copyright © Roman Zechmeister, 2016
 
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
			signaturesTable, userIDsTable, subkeysTable, gpgc;


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
	NSArray *keys = [self selectedKeys];
	NSUInteger count = keys.count;
	if (count == 0) {
		return;
	}
	
	sheetController.title = nil; //TODO
	sheetController.msgText = nil; //TODO
	
	if (count == 1) {
		sheetController.pattern = [keys[0] shortKeyID];
	} else {
		NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
		dateFormatter.dateFormat = @"Y-MM-dd";
		NSString *date = [dateFormatter stringFromDate:[NSDate date]];
		sheetController.pattern = [NSString stringWithFormat:localized(@"ExportKeysFilename"), date, count];
	}
	
	[keys enumerateObjectsUsingBlock:^(GPGKey *key, NSUInteger idx, BOOL *stop) {
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
	[self importFromURLs:urls askBeforeOpen:YES];
}

- (void)importFromURLs:(NSArray *)urls askBeforeOpen:(BOOL)ask {
	@autoreleasepool {
		NSMutableData *dataToImport = [NSMutableData data];
		NSMutableArray *filesToOpen = [NSMutableArray array];
		
		
		BOOL useGPGServices = YES;
		BOOL gpgSeriviceInitialized = NO;
		BOOL haveGPGServices = NO;
		
		for (NSURL *url in urls) {
			NSString *path;
			if ([url isKindOfClass:[NSURL class]]) {
				path = [url path];
			} else if ([url isKindOfClass:[NSString class]]) {
				path = (NSString *)url;
			} else {
				continue;
			}
			
			
			GPGFileStream *stream = [GPGFileStream fileStreamForReadingAtPath:path];
			if (stream.isArmored) {
				GPGUnArmor *unArmor = [GPGUnArmor unArmorWithGPGStream:stream];
				[unArmor decodeAll];
				stream = [GPGMemoryStream memoryStreamForReading:unArmor.data];
			}
			
			BOOL shouldUseGPGServices = [self shouldUseGPGServicesForStream:stream];
			if (shouldUseGPGServices && gpgSeriviceInitialized == NO) {
				gpgSeriviceInitialized = YES;
				
				haveGPGServices = [[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:@"org.gpgtools.gpgservices"
																					   options:0
																additionalEventParamDescriptor:nil
																			  launchIdentifier:nil];
				
				if (haveGPGServices == NO) {
					useGPGServices = NO;
				} else if (ask) {
					NSInteger returnCode = [sheetController alertSheetForWindow:mainWindow
																	messageText:localized(@"OpenWithGPGServices_Title")
																	   infoText:localized(@"OpenWithGPGServices_Msg")
																  defaultButton:localized(@"OpenWithGPGServices_Yes")
																alternateButton:localized(@"OpenWithGPGServices_No")
																	otherButton:nil
															  suppressionButton:nil];
					useGPGServices = (returnCode == NSAlertFirstButtonReturn);
				}
			}

			if (shouldUseGPGServices && haveGPGServices) {
				if (useGPGServices) {
					[filesToOpen addObject:[NSURL fileURLWithPath:path]];
				}
			} else {
				[dataToImport appendData:stream.readAllData];
			}
		}
		
		if (filesToOpen.count > 0) {
			[[NSWorkspace sharedWorkspace] openURLs:filesToOpen
							withAppBundleIdentifier:@"org.gpgtools.gpgservices"
											options:0
					 additionalEventParamDescriptor:nil
								  launchIdentifiers:nil];
		}
		
		
		if (dataToImport.length > 0) {
			[self importFromData:dataToImport];
		}
	}
}
- (BOOL)shouldUseGPGServicesForStream:(GPGStream *)stream {
	
	if (stream.isArmored) {
		GPGUnArmor *unArmor = [GPGUnArmor unArmorWithGPGStream:stream];
		
		[unArmor decodeAll];
		
		stream = [GPGMemoryStream memoryStreamForReading:unArmor.data];
	}
	

	GPGPacketParser *parser = [[GPGPacketParser alloc] initWithStream:stream];
	GPGPacket *packet;
	
	while ((packet = [parser nextPacket])) {
		switch (packet.tag) {
			case GPGSignaturePacketTag: {
				switch (((GPGSignaturePacket *)packet).type) {
					case GPGBinarySignature:
					case GPGTextSignature:
						return YES;
					case GPGRevocationSignature:
					case GPGGeneriCertificationSignature:
					case GPGPersonaCertificationSignature:
					case GPGCasualCertificationSignature:
					case GPGPositiveCertificationSignature:
					case GPGSubkeyBindingSignature:
					case GPGKeyBindingSignature:
					case GPGDirectKeySignature:
					case GPGSubkeyRevocationSignature:
					case GPGCertificationRevocationSignature:
						return NO;
					default:
						break;
				}
				break;
			}
			case GPGSecretKeyPacketTag:
			case GPGPublicKeyPacketTag:
			case GPGSecretSubkeyPacketTag:
			case GPGUserIDPacketTag:
			case GPGPublicSubkeyPacketTag:
			case GPGUserAttributePacketTag:
				return NO;
			case GPGPublicKeyEncryptedSessionKeyPacketTag:
			case GPGSymmetricEncryptedSessionKeyPacketTag:
			case GPGEncryptedDataPacketTag:
			case GPGEncryptedProtectedDataPacketTag:
			case GPGCompressedDataPacketTag:
				return YES;
			default:
				break;
		}
	}
	
	return NO;
}


- (void)importFromData:(NSData *)data {
	BOOL containsPGP = NO;
	BOOL containsImportable = NO;
	GPGPacket *previousPacket = nil;
	NSMutableData *dataToImport = [NSMutableData data];
	NSDictionary *action = nil;
	NSString *myProgressText = localized(@"ImportKey_Progress");
	NSString *myErrorText = nil;
	__block NSMutableArray *packets = [NSMutableArray array];
	NSMutableSet *affectedKeys = [NSMutableSet set];
	
	[GPGPacket enumeratePacketsWithData:data block:^(GPGPacket *packet, BOOL *stop) {
		[packets addObject:packet];
	}];
	
	for (GPGPacket *packet in packets) {
		BOOL ignorePacket = NO;
		containsPGP = YES;
		
		switch (packet.tag) {
			case GPGSignaturePacketTag: {
				GPGSignaturePacket *sigPacket = (GPGSignaturePacket *)packet;
				switch (sigPacket.type) {
					case GPGBinarySignature:
					case GPGTextSignature:
						ignorePacket = YES;
						break;
					case GPGRevocationSignature: {
						if (previousPacket.tag != GPGPublicKeyPacketTag &&
							previousPacket.tag != GPGSecretKeyPacketTag &&
							sigPacket.keyID)
						{
							GPGKey *key = [[[GPGKeyManager sharedInstance] keysByKeyID] objectForKey:sigPacket.keyID];
							if (key && key.revoked == NO) {
								
								NSInteger returnCode;
								if (packets.count == 1) {
									returnCode = [sheetController alertSheetForWindow:mainWindow
																		  messageText:localized(@"RevokeKey_Title")
																			 infoText:[NSString stringWithFormat:localized(@"RevokeKey_Msg"), [self descriptionForKey:key]]
																		defaultButton:localized(@"RevokeKey_No")
																	  alternateButton:localized(@"RevokeKey_Yes")
																		  otherButton:nil
																	suppressionButton:localized(@"RevokeKey_Upload")];
									if (returnCode & SheetSuppressionButton) {
										returnCode -= SheetSuppressionButton;
										action = @{@"action": @[@(UploadKeyAction)], @"keys":[NSSet setWithObject:key]};
										myProgressText = localized(@"RevokeKey_Progress");
										myErrorText = localized(@"RevokeKey_Error");
									}
								} else {
									returnCode = [sheetController alertSheetForWindow:mainWindow
																		  messageText:localized(@"RevokeKey_Title")
																			 infoText:[NSString stringWithFormat:localized(@"RevokeKey_Msg"), [self descriptionForKey:key]]
																		defaultButton:localized(@"RevokeKey_No")
																	  alternateButton:localized(@"RevokeKey_Yes")
																		  otherButton:nil
																	suppressionButton:nil];
								}
								
								if (returnCode != NSAlertSecondButtonReturn) {
									ignorePacket = YES;
								} else {
									[affectedKeys addObject:key];
								}
							}
						}
					}
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
						break;
					default:
						// Ignore packet?
						break;
				}
				break;
			}
			case GPGSecretKeyPacketTag:
			case GPGPublicKeyPacketTag:
				[affectedKeys addObject:[(GPGPublicKeyPacket *)packet fingerprint]];
			case GPGSecretSubkeyPacketTag:
			case GPGUserIDPacketTag:
			case GPGPublicSubkeyPacketTag:
			case GPGUserAttributePacketTag:
				containsImportable = YES;
				break;
			case GPGPublicKeyEncryptedSessionKeyPacketTag:
			case GPGSymmetricEncryptedSessionKeyPacketTag:
			case GPGEncryptedDataPacketTag:
			case GPGEncryptedProtectedDataPacketTag:
			case GPGCompressedDataPacketTag:
				ignorePacket = YES;
				break;
			default:
				// Ignore packet?
				break;
		}
		
		if (ignorePacket == NO) {
			[dataToImport appendData:packet.data];
		}
		
		previousPacket = packet;
	}
	
	
	
	if (dataToImport.length == 0) {
		NSString *title, *message;
		if (containsPGP) {
			if (containsImportable) {
				return;
			} else {
				title = localized(@"ImportKeyErrorPGP_Title");
				message = localized(@"ImportKeyErrorPGP_Msg");
			}
		} else {
			title = localized(@"ImportKeyErrorNoPGP_Title");
			message = localized(@"ImportKeyErrorNoPGP_Msg");
		}
		[sheetController errorSheetWithMessageText:title infoText:message];
	} else {
		if (action == nil) {
			action = @{@"action": @(ShowResultAction), @"operation": @(ImportOperation), @"keys": affectedKeys};
		}
		
		self.progressText = myProgressText;
		self.errorText = myErrorText;
		gpgc.userInfo = action;
		[gpgc importFromData:dataToImport fullImport:showExpertSettings];
	}
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
			stringForPasteboard = [[GPGFingerprintTransformer new] transformedValue:subkey.fingerprint];
		}
	} else {
		NSArray *keys = [self selectedKeys];
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
- (IBAction)copyFingerprint:(id)sender {
	NSString *stringForPasteboard = nil;
	NSResponder *responder = mainWindow.firstResponder;
	
	if (responder == appDelegate.userIDTable) {
		if (userIDsController.selectedObjects.count == 1) {
			GPGUserID *userID = [userIDsController.selectedObjects objectAtIndex:0];
			stringForPasteboard = userID.hashID;
		}
	} else if (responder == appDelegate.signatureTable) {
		if (signaturesController.selectedObjects.count == 1) {
			GPGUserIDSignature *signature = [signaturesController.selectedObjects objectAtIndex:0];
			stringForPasteboard = signature.primaryKey.fingerprint;
		}
	} else if (responder == appDelegate.subkeyTable) {
		if (subkeysController.selectedObjects.count == 1) {
			GPGKey *subkey = [subkeysController.selectedObjects objectAtIndex:0];
			stringForPasteboard = subkey.fingerprint;
		}
	} else {
		NSArray *keys = [self selectedKeys];
		if (keys.count > 0) {
			stringForPasteboard = [keys componentsJoinedByString:@"\n"];
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
	NSArray *keys = [self selectedKeys];
	if (keys.count == 0) {
		return;
	}
	NSMutableArray *invalidKeys = [NSMutableArray new];
	for (GPGKey *key in keys) {
		if (key.validity >= GPGValidityInvalid) {
			[invalidKeys addObject:key];
		}
	}
	if (invalidKeys.count > 0) {
		NSString *title = localized(@"MAIL_KEY_INVALID_KEY_SELECTED_TITLE");
		NSString *message = localizedStringWithFormat(@"MAIL_KEY_INVALID_KEY_SELECTED_MESSAGE", [self descriptionForKeys:invalidKeys maxLines:8 withOptions:0]);
		[sheetController errorSheetWithMessageText:title infoText:message];
		return;
	}
	
	

	BOOL yourKey = keys.count == 1 && [keys[0] secret];
	
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
	
	
	NSString *subjectDescription = [self descriptionForKeys:keys maxLines:1 withOptions:DescriptionSingleLine | DescriptionNoKeyID | DescriptionNoEmail];
	
	
	NSString *links = localized(@"MailKey_Message_Links");
	NSString *subject = [NSString stringWithFormat:localized(yourKey ? @"MailKey_Subject_Your" : @"MailKey_Subject"), subjectDescription];
	NSString *message;
	if (yourKey) {
		message = [NSString stringWithFormat:localized(@"MailKey_Message_Your"), description, links];
	} else {
		message = [NSString stringWithFormat:localized(@"MailKey_Message"), description, subjectDescription, links];
	}

	
	
	if (NSAppKitVersionNumber < 1187) {
		// Mac OS X < 10.8 doesn't have NSSharingService. Let's use a mailto: link and add the key-block as normal text.
		
		message = [message stringByAppendingFormat:@"\n\n\n%@\n", [data gpgString]];
		message = [message stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		subject = [subject stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		
		NSString *mailto = [NSString stringWithFormat:@"mailto:?subject=%@&body=%@", subject, message];
		
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:mailto]];
		
	} else {
		// On Mac OS X 10.8 and higher, we use NSSharingService, to create an email, with an attached key-file.
		NSString *templateString = [NSTemporaryDirectory() stringByAppendingPathComponent:@"GKA.XXXXXX"];
		NSMutableData *template = [[templateString dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
		
		char *tempDir = [template mutableBytes];
		if (!mkdtemp(tempDir)) {
			return;
		}
		
		NSString *path = [NSString stringWithFormat:@"%s/%@.asc", tempDir, keys.count == 1 ? [keys[0] shortKeyID] : localized(@"Keys")];
		NSURL *url = [NSURL fileURLWithPath:path];
		NSError *error = nil;
		[data writeToURL:url options:0 error:&error];
		if (error) {
			return;
		}
		
		
		NSSharingService *service = [NSSharingService sharingServiceNamed:NSSharingServiceNameComposeEmail];
		
		[service setValue:@{@"NSSharingServiceParametersDefaultSubjectKey": subject} forKey:@"parameters"];
		[service performWithItems:@[message, url]];
	}
}
- (void)checkPasteboardChanges {
	// This method only works on OS X >= 10.9.
	
	static NSInteger changeCount = NSIntegerMax;
	static NSData *lastData = nil;
	static NSWindow *sheet = nil;
	
	if (generalPboard.changeCount == changeCount) {
		// The content of the pasteboard have not changed.
		return;
	}
	
	if ([NSApp modalWindow]) {
		return;
	}
	
	NSData *pboardData = [generalPboard dataForType:NSStringPboardType];
	BOOL dataChanged = ![pboardData isEqualToData:lastData];
	
	if (sheet) {
		if (mainWindow.sheets.count != 1) {
			// Should never happen!
			return;
		}
		if (!dataChanged) {
			return;
		}
		dispatch_sync(dispatch_get_main_queue(), ^{
			[mainWindow endSheet:mainWindow.sheets[0]];
		});
	}
	
	
	changeCount = generalPboard.changeCount;
	
	if (!pboardData || !dataChanged) {
		// Return if we have no string in the pasteboard or
		//  if the string have not changed.
		return;
	}
	if ([NSApp isActive]) {
		// GPG Keychain is the active application, probably the user exported a key.
		return;
	}
	
	
	lastData = pboardData;
	
	
	GPGStream *stream = [GPGMemoryStream memoryStreamForReading:pboardData];
	
	if (stream.isArmored) {
		stream = [GPGUnArmor unArmor:stream];
	}
	
	
	// Get a list of all affected keys.
	// TODO: GPGSignaturePacket get the signed instead of the signer key.
	NSMutableSet *keyInfos = [NSMutableSet set];
	NSMutableSet *keyIDs = [NSMutableSet set];
	NSMutableDictionary *keyInfo = nil;
	GPGPacketParser *parser = [GPGPacketParser packetParserWithStream:stream];
	GPGPacket *packet;
	
	while ((packet = parser.nextPacket)) {
		switch (packet.tag) {
			case GPGPublicKeyPacketTag:
			case GPGSecretKeyPacketTag:
				keyInfo = [NSMutableDictionary dictionary];
				keyInfo[@"packet"] = packet;
				[keyInfos addObject:keyInfo];
				break;
			case GPGUserIDPacketTag:
				if (keyInfo[@"userID"] == nil) {
					keyInfo[@"userID"] = [(GPGUserIDPacket *)packet userID];
				}
				break;
			case GPGSignaturePacketTag: {
				GPGSignaturePacket *signaturePacket = (GPGSignaturePacket *)packet;
				if (signaturePacket.type == 32 && signaturePacket.keyID) {
					[keyIDs addObject:signaturePacket.keyID];
				}
				break;
			}
			default:
				break;
		}
	}
	if (keyInfos.count == 0 && keyIDs.count == 0) {
		// No keys to import.
		return;
	}
	
	NSSet *allKeys = [GPGKeyManager sharedInstance].allKeys;
	NSMutableSet *keys = [NSMutableSet new];
	
		
	for (keyInfo in keyInfos) {
		GPGPublicKeyPacket *keyPacket = keyInfo[@"packet"];
		
		GPGKey *key = [allKeys member:keyPacket.fingerprint];
		if (key) {
			[keys addObject:key];
		} else {
			NSDictionary *userIDParts = [keyInfo[@"userID"] splittedUserIDDescription];
			
			NSString *keyID = keyPacket.keyID;
			if (!keyID) {
				keyID = @"";
			}
			NSString *name = userIDParts[@"name"];
			if (!name) {
				name = @"";
			}
			NSString *email = userIDParts[@"email"];
			if (!email) {
				email = @"";
			}
			
			NSDictionary *dict = @{@"keyID": keyID, @"name": name, @"email": email};
			[keys addObject:dict];
		}
		
		[keyIDs removeObject:keyPacket.keyID];
	}
	
	NSDictionary *keysByKeyID = [GPGKeyManager sharedInstance].keysByKeyID;
	for (NSString *keyID in keyIDs) {
		GPGKey *key = keysByKeyID[keyID];
		if (key) {
			[keys addObject:key];
		}
	}
	
	if (keys.count == 0) {
		// Nothing usefull to import.
		return;
	}
	
	
	NSString *description = [self descriptionForKeys:keys maxLines:8 withOptions:0];
	
	NSString *title = localized(@"PasteboardKeyFound_Title");
	NSString *message = localizedStringWithFormat(@"PasteboardKeyFound_Msg", description);
	NSString *okText = localized(@"PasteboardKeyFound_Yes");
	NSString *cancelText = localized(@"PasteboardKeyFound_No");
	
	
	dispatch_sync(dispatch_get_main_queue(), ^{
		
		NSAlert *alert = [NSAlert new];
		
		alert.messageText = title;
		alert.informativeText = message;
		[alert addButtonWithTitle:okText];
		[alert addButtonWithTitle:cancelText];
		
		[alert beginSheetModalForWindow:mainWindow completionHandler:^(NSModalResponse returnCode) {
			[sheet orderOut:nil];
			sheet = nil;
			if (returnCode == NSAlertFirstButtonReturn) {
				[self importFromData:lastData];
			}
		}];
		sheet = alert.window;
	});
	
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
	GPGPublicKeyAlgorithm keyType, subkeyType;
	
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
					   keyLength:(int)sheetController.length
					  subkeyType:subkeyType
					subkeyLength:(int)sheetController.length
					daysToExpire:(int)sheetController.daysToExpire
					 preferences:nil];
}
- (IBAction)deleteKey:(id)sender {
	NSArray *keys = [self selectedKeys];
	if (keys.count == 0) {
		return;
	}
	
	
	NSString *title, *message, *button1, *button2, *button3 = nil, *description, *template, *checkbox = nil;
	BOOL hasSecretKey = NO;
	BOOL onlyRevoked = YES;
	NSDictionary *attributes = @{NSFontAttributeName: [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]};

	NSMutableArray *secretKeys = [NSMutableArray array];
	NSMutableArray *publicKeys = [NSMutableArray array];
	
	for (GPGKey *key in keys) {
		if (key.secret) {
			[secretKeys addObject:key];
			hasSecretKey = YES;
		} else {
			[publicKeys addObject:key];
		}
		if (key.revoked == NO) {
			onlyRevoked = NO;
		}
	}
	
	if (secretKeys.count > 0 && publicKeys.count > 0) {
		NSString *secretDescription = [self descriptionForKeys:secretKeys maxLines:8 withOptions:DescriptionIndent];
		NSString *publicDescription = [self descriptionForKeys:publicKeys maxLines:8 withOptions:DescriptionIndent];
		description = [NSString stringWithFormat:localized(@"SecretAndPublicKeyListing"), secretDescription, publicDescription];
	} else {
		description = [self descriptionForKeys:keys maxLines:8 withOptions:DescriptionIndent];
	}
	
	if (hasSecretKey) {
		if (onlyRevoked) {
			template = @"DeleteRevokedSecKey";
		} else {
			template = @"DeleteSecKey";
		}
	} else {
		template = @"DeleteKey";
	}
	
	
	title = localized([template stringByAppendingString:@"_Title"]);
	message = [NSString stringWithFormat:localized([template stringByAppendingString:@"_Msg"]), description];
	button1 = localized([template stringByAppendingString:@"_No"]);
	if (hasSecretKey) {
		button2 = localized([template stringByAppendingString:@"_SecOnly"]);
		button3 = localized([template stringByAppendingString:@"_Yes"]);
		checkbox = localized([template stringByAppendingString:@"_Checkbox"]);
	} else {
		button2 = localized([template stringByAppendingString:@"_Yes"]);
	}
	
	
	

	NSInteger result =
	[sheetController alertSheetForWindow:mainWindow
							 messageText:title
								infoText:message
						   defaultButton:button1
						 alternateButton:button2
							 otherButton:button3
					   suppressionButton:checkbox
							   customize:^(NSAlert *alert) {
								   // Add an invisible view to force a minimum width of the alert.
								   CGFloat minWidth = [description sizeWithAttributes:attributes].width + 20;
								   if (minWidth > 1000) {
									   minWidth = 1000;
								   }
								   NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, minWidth, 0)];
								   alert.accessoryView = view;
								   
								   // The checkbox must be checked before the delete buttons are enabled.
								   if (hasSecretKey) {
									   NSButtonCell *checkboxCell = alert.suppressionButton.cell;
									   NSAttributedString *string = [[NSAttributedString alloc] initWithString:checkbox attributes:attributes];
									   [checkboxCell setAttributedTitle:string];
									   checkboxCell.state = NSOffState;
									   [alert.buttons[1] bind:@"enabled" toObject:checkboxCell withKeyPath:@"state" options:nil];
									   [alert.buttons[2] bind:@"enabled" toObject:checkboxCell withKeyPath:@"state" options:nil];
								   }
							   }];
	
	result &= ~SheetSuppressionButton;
	
	GPGDeleteKeyMode mode;
	switch (result) {
		case NSAlertSecondButtonReturn:
			if (hasSecretKey) {
				mode = GPGDeleteSecretKey;
				keys = secretKeys;
			} else {
				mode = GPGDeletePublicKey;
			}
			break;
		case NSAlertThirdButtonReturn: {
			mode = GPGDeletePublicAndSecretKey;
			break; }
		default:
			return;
	}
	
	self.progressText = localized(@"DeleteKeys_Progress");
	self.errorText = localized(@"DeleteKeys_Error");
	[gpgc deleteKeys:keys withMode:mode];
}

#pragma mark Key attributes
- (IBAction)changePassphrase:(id)sender {
	NSArray *keys = [self selectedKeys];
	if (keys.count == 1) {
		GPGKey *key = [keys[0] primaryKey];
		
		self.progressText = localized(@"ChangePassphrase_Progress");
		self.errorText = localized(@"ChangePassphrase_Error");
		[gpgc changePassphraseForKey:key];
	}
}
- (IBAction)setDisabled:(id)sender {
	NSArray *keys = [self selectedKeys];
	BOOL disabled = [sender state] == NSOnState;
	[self setDisabled:disabled forKeys:[NSSet setWithArray:keys]];
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
	NSArray *keys = [self selectedKeys];
	NSInteger trust = sender.selectedTag;
	[self setTrust:trust forKeys:[NSSet setWithArray:keys]];
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
	
	[gpgc key:key setOwnerTrust:(GPGValidity)trust];
}

- (IBAction)changeExpirationDate:(id)sender {
	NSArray *keys = [self selectedKeys];
	if (keys.count != 1) {
		return;
	}
	GPGKey *subkey = nil;
	GPGKey *key = [keys[0] primaryKey];
	
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
	NSArray *keys = [self selectedKeys];
	if (keys.count != 1) {
		return;
	}
	GPGKey *key = [keys[0] primaryKey];
	
	
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
	NSArray *keys = [self selectedKeys];
	
	self.progressText = localized(@"CleanKey_Progress");
	self.errorText = localized(@"CleanKey_Error");

	[gpgc cleanKeys:keys];
}
- (IBAction)minimizeKey:(id)sender {
	NSArray *keys = [self selectedKeys];
	
	self.progressText = localized(@"MinimizeKey_Progress");
	self.errorText = localized(@"MinimizeKey_Error");
	[gpgc minimizeKeys:keys];
}
- (IBAction)genRevokeCertificate:(id)sender {
	NSArray *keys = [self selectedKeys];
	if (keys.count != 1) {
		return;
	}
	GPGKey *key = [keys[0] primaryKey];

	[self revCertificateForKey:key customPath:YES];
}
- (void)revCertificateForKey:(NSObject <KeyFingerprint> *)key customPath:(BOOL)customPath {
	BOOL hideExtension = NO;
	NSObject *url = nil;
	
	
	
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
	}
 
	if (!customPath || ![self.revCertCache containsObject:key.keyID]) {
		NSString *path = [[GPGOptions sharedOptions] gpgHome];
		path = [path stringByAppendingPathComponent:@"openpgp-revocs.d"];

		
		[[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil];
		path = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.rev", key.description]];
		
		NSURL *deafultURL = nil;
		if ([[NSFileManager defaultManager] fileExistsAtPath:path] == NO) {
			deafultURL = [NSURL fileURLWithPath:path];
		}
		 
		if (url) {
			url = [NSSet setWithObjects:url, deafultURL, nil];
		} else {
			url = [NSSet setWithObjects:deafultURL, nil];
		}
		
		self.revCertCache = nil;
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
	NSArray *keys = [self selectedKeys];
	if (keys.count != 1) {
		return;
	}
	GPGKey *key = [keys[0] primaryKey];

	[self revokeKey:key generateIfNeeded:YES];
}

- (void)revokeKey:(NSObject <KeyFingerprint> *)key generateIfNeeded:(BOOL)generate {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *home = [[GPGOptions sharedOptions] gpgHome];
	
	NSString *path = [home stringByAppendingPathComponent:[NSString stringWithFormat:@"openpgp-revocs.d/%@.rev", key.description]];
	
	if ([fileManager fileExistsAtPath:path] == NO) {
		path = [home stringByAppendingPathComponent:[NSString stringWithFormat:@"RevCerts/%@_rev.asc", key.keyID]];
	}
	
	
	__block BOOL haveValidRevCert = NO;
	if ([fileManager fileExistsAtPath:path]) {
		NSData *data = [NSData dataWithContentsOfFile:path];
		
		[GPGPacket enumeratePacketsWithData:data block:^(GPGPacket *packet, BOOL *stop) {
			if (packet.tag == GPGSignaturePacketTag) {
				GPGSignaturePacket *sigPacket = (GPGSignaturePacket *)packet;
				if (sigPacket.type == GPGRevocationSignature) {
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
			NSDictionary *userInfo = nil;
			
			if (returnCode & SheetSuppressionButton) {
				returnCode -= SheetSuppressionButton;
				userInfo = @{@"action": @[@(UploadKeyAction)], @"keys":[NSSet setWithObject:key]};
			}
			if (returnCode != NSAlertSecondButtonReturn) {
				return;
			}
			
			gpgc.userInfo = userInfo;
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
	return !key.revoked && (key.secret || [self.revCertCache containsObject:key.keyID]);
}

- (NSSet *)revCertCache {
	if (!revCertCache) {
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSMutableSet *keyIDs = [NSMutableSet set];
		
		NSString *path = [[[GPGOptions sharedOptions] gpgHome] stringByAppendingPathComponent:@"RevCerts"];
		NSArray *files = [fileManager contentsOfDirectoryAtPath:path error:nil];
		
		if (files) {
			for (NSString *file in files) {
				if (file.length == 24 && [[file substringFromIndex:16] isEqualToString:@"_rev.asc"]) {
					[keyIDs addObject:[file substringToIndex:16]];
				}
			}
		}
		
		path = [[[GPGOptions sharedOptions] gpgHome] stringByAppendingPathComponent:@"openpgp-revocs.d"];
		files = [fileManager contentsOfDirectoryAtPath:path error:nil];
		
		if (files) {
			for (NSString *file in files) {
				if (file.length == 44 && [[file substringFromIndex:40] isEqualToString:@".rev"]) {
					[keyIDs addObject:[file substringToIndex:40].keyID];
				}
			}
		}
		
		revCertCache = [keyIDs copy];

	}
	return revCertCache;
}
- (void)setRevCertCache:(NSSet *)value {
	revCertCache = value;
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
	NSArray *keys = [self selectedKeys];
	if (keys.count > 0) {
		self.progressText = [NSString stringWithFormat:localized(@"SendKeysToServer_Progress"), [self descriptionForKeys:keys maxLines:8 withOptions:0]];
		self.errorText = localized(@"SendKeysToServer_Error");
		[gpgc sendKeysToServer:keys];
	}
}
- (IBAction)refreshKeysFromServer:(id)sender {
	NSArray *keys = [self selectedKeys];
	if (keys.count > 0) {
		self.progressText = [NSString stringWithFormat:localized(@"RefreshKeysFromServer_Progress"), [self descriptionForKeys:keys maxLines:8 withOptions:0]];
		self.errorText = localized(@"RefreshKeysFromServer_Error");
		[gpgc receiveKeysFromServer:keys];
	}
}

#pragma mark Subkeys
- (IBAction)addSubkey:(id)sender {
	NSArray *keys = [self selectedKeys];
	if (keys.count != 1) {
		return;
	}
	GPGKey *key = [keys[0] primaryKey];
	
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
	NSArray *keys = [self selectedKeys];
	if (keys.count != 1) {
		return;
	}
	GPGKey *key = [keys[0] primaryKey];
	
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
	NSArray *keys = [self selectedKeys];
	if (keys.count != 1) {
		return;
	}
	GPGKey *key = [keys[0] primaryKey];
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
		NSArray *keys = [self selectedKeys];
		GPGKey *key = [keys[0] primaryKey];
		
		self.progressText = localized(@"RemovePhoto_Progress");
		self.errorText = localized(@"RemovePhoto_Error");
		[gpgc removeUserID:[[[photosController selectedObjects] objectAtIndex:0] hashID] fromKey:key];
	}
}
- (IBAction)setPrimaryPhoto:(id)sender {
	if ([photosController selectionIndex] != NSNotFound) {
		NSArray *keys = [self selectedKeys];
		GPGKey *key = [keys[0] primaryKey];
		
		self.progressText = localized(@"SetPrimaryPhoto_Progress");
		self.errorText = localized(@"SetPrimaryPhoto_Error");
		[gpgc setPrimaryUserID:[[[photosController selectedObjects] objectAtIndex:0] hashID] ofKey:key];
	}
}
- (IBAction)revokePhoto:(id)sender {
	if ([photosController selectionIndex] != NSNotFound) {
		NSArray *keys = [self selectedKeys];
		GPGKey *key = [keys[0] primaryKey];
		
		self.progressText = localized(@"RevokePhoto_Progress");
		self.errorText = localized(@"RevokePhoto_Error");
		[gpgc revokeUserID:[[[photosController selectedObjects] objectAtIndex:0] hashID] fromKey:key reason:0 description:nil];
	}
}

#pragma mark Signatures
- (IBAction)addSignature:(id)sender {
	NSArray *keys = [self selectedKeys];
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
	
	GPGKey *key = [keys[0] primaryKey];
	
	NSSet *secretKeys = [[KeychainController sharedInstance] secretKeys];
	
	sheetController.secretKeys = [secretKeys allObjects];
	GPGKey *defaultKey = [[KeychainController sharedInstance] defaultKey];
	if (!defaultKey) {
		defaultKey = [secretKeys anyObject];
	}
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
	[gpgc signUserID:[userID hashID]
			   ofKey:key
			 signKey:sheetController.secretKey
				type:(int)sheetController.sigType
			   local:sheetController.localSig
		daysToExpire:(int)sheetController.daysToExpire];
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

- (NSString *)importResultWithStatusDict:(NSDictionary *)statusDict affectedKeys:(NSSet **)affectedKeys {
	const int stateNewKey = 1;
	const int stateNewUserID = 2;
	const int stateNewSignature = 4;
	const int stateNewSubkey = 8;
	const int statePrivateKey = 16;

	NSInteger publicKeysCount = 0;
	NSInteger publicKeysOk = 0;
	NSInteger revocationCount = 0;
	
	NSArray *importResList = [statusDict objectForKey:@"IMPORT_RES"];
	
	if (importResList.count > 0) {
		NSArray *importRes = importResList[0];
		
		publicKeysCount = [importRes[0] integerValue];
		publicKeysOk = [importRes[2] integerValue];
		revocationCount = [importRes[8] integerValue];
	}
	
	
	NSArray *importOkList = [statusDict objectForKey:@"IMPORT_OK"];
	NSMutableDictionary *importStates = [NSMutableDictionary new];
	
	for (NSArray *importOk in importOkList) {
		NSInteger status = [importOk[0] integerValue];
		NSString *fingerprint = importOk[1];
		
		NSNumber *oldStatusNumber = importStates[fingerprint];
		NSInteger oldStatus = [oldStatusNumber integerValue];
		NSInteger newStatus = oldStatus | status;
		
		importStates[fingerprint] = @(newStatus);
		
		if (oldStatusNumber) {
			// gpg2 counts every key block, but we want the count of diffeerent keys.
			// So decrement the key count for multiple key blocks with the same key.
			
			// The new key status is sometimes issued twice. Only decrement a single time.
			publicKeysCount--;
		}
		if (status == 17) {
			// Do not decrement for IMPORT_OK with status 17, because this line is issued in addition to the others.
			publicKeysCount++;
		}

	}
	
	
	
	if (affectedKeys) {
		*affectedKeys = [NSSet setWithArray:importStates.allKeys];
	}
	
	NSMutableArray *newKeys = [NSMutableArray new];
	NSMutableArray *newUserIDs = [NSMutableArray new];
	NSMutableArray *newSignatures = [NSMutableArray new];
	NSMutableArray *newSubkeys = [NSMutableArray new];
	BOOL importSuccessful = NO;
	
	
	
	for (NSString *fingerprint in importStates) {
		NSInteger status = [importStates[fingerprint] integerValue];
		
		
		if (status & stateNewKey) {
			[newKeys addObject:fingerprint];
			importSuccessful = YES;
		} else if ((status & ~statePrivateKey) == 0) {
			// Unchanged.
		} else {
			if (status & stateNewUserID) {
				[newUserIDs addObject:fingerprint];
				importSuccessful = YES;
			} else if (status & stateNewSignature) {
				[newSignatures addObject:fingerprint];
				importSuccessful = YES;
			}
			if (status & stateNewSubkey) {
				[newSubkeys addObject:fingerprint];
				importSuccessful = YES;
			}
		}
	}
	
	NSMutableString *output = [NSMutableString new];
	
	if (newKeys.count > 0) {
		NSString *descriptions = [self descriptionForKeys:newKeys maxLines:8 withOptions:0];
		NSString *key = newKeys.count == 1 ? @"IMPORT_RESULT_NEW_KEY" : @"IMPORT_RESULT_NEW_KEYS";
		NSString *string = localizedStringWithFormat(key, descriptions);
		
		[output appendFormat:@"%@\n\n", string];
	}
	if (newUserIDs.count > 0) {
		NSString *descriptions = [self descriptionForKeys:newUserIDs maxLines:8 withOptions:0];
		NSString *key = @"IMPORT_RESULT_NEW_USER_ID";
		NSString *string = localizedStringWithFormat(key, descriptions);
		
		[output appendFormat:@"%@\n\n", string];
	}
	if (newSignatures.count > 0) {
		NSString *descriptions = [self descriptionForKeys:newSignatures maxLines:8 withOptions:0];
		NSString *key = @"IMPORT_RESULT_NEW_SIGNATURE";
		NSString *string = localizedStringWithFormat(key, descriptions);
		
		[output appendFormat:@"%@\n\n", string];
	}
	if (newSubkeys.count > 0) {
		NSString *descriptions = [self descriptionForKeys:newSubkeys maxLines:8 withOptions:0];
		NSString *key = @"IMPORT_RESULT_NEW_SUBKEY";
		NSString *string = localizedStringWithFormat(key, descriptions);
		
		[output appendFormat:@"%@\n\n", string];
	}
	
	
	if (importResList.count > 0) {
		
		NSString *key, *string;
		if (revocationCount > 0) {
			key = revocationCount == 1 ? @"IMPORT_RESULT_COUNT_REVOCATION_CERTIFICATE" : @"IMPORT_RESULT_COUNT_REVOCATION_CERTIFICATES";
			string = localizedStringWithFormat(key, revocationCount);
			
			[output appendFormat:@"%@\n\n", string];
		}
		
		NSInteger processed = publicKeysCount;
		NSInteger imported = publicKeysOk;
		
		if (processed != 1 || imported != 1) {
			if (processed == 1) {
				if (imported != 0 || importSuccessful == NO) {
					// Don't show this message if only parts of a single key were imported.
					key = @"IMPORT_RESULT_ONE_PROCESSED_AND_X_IMPORTED";
					string = localizedStringWithFormat(key, imported);
					[output appendFormat:@"%@\n", string];
				}
			} else if (imported == 1) {
				key = @"IMPORT_RESULT_X_PROCESSED_AND_ONE_IMPORTED";
				string = localizedStringWithFormat(key, processed);
				[output appendFormat:@"%@\n", string];
			} else {
				key = @"IMPORT_RESULT_X_PROCESSED_AND_X_IMPORTED";
				string = localizedStringWithFormat(key, processed, imported);
				[output appendFormat:@"%@\n", string];
			}
		}
	}
	
	return output;
	
}

- (NSUndoManager *)undoManager {
	/*if (!undoManager) {
		undoManager = [NSUndoManager new];
		[undoManager setLevelsOfUndo:50];
	}
	return undoManager;*/
	return nil;
}

- (NSArray *)selectedKeys {
	NSInteger clickedRow = [keyTable clickedRow];
	if (clickedRow != -1 && ![keyTable isRowSelected:clickedRow]) {
		return @[[[keyTable itemAtRow:clickedRow] representedObject]];
	} else {
		return [keysController selectedObjects];
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
		selector == @selector(copyFingerprint:)) {
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
		} else if (self.selectedKeys.count > 0) {
			return YES;
		}
		return NO;
	}
	else if (selector == @selector(sendKeysToServer:) ||
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
		NSArray *keys = [self selectedKeys];
		return (keys.count == 1 && [keys[0] secret]);
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
		NSArray *keys = self.selectedKeys;
		if (keys.count == 1) {
			return [self canRevokeKey:keys[0]];
		}
		return NO;
	}
	else if (selector == @selector(cancel:)) {
		return appDelegate.inspectorVisible;
	} else if (selector == @selector(sendKeysPerMail:)) {
		NSArray *keys = [self selectedKeys];
		if (keys.count == 0) {
			return NO;
		}
		for (GPGKey *key in keys) {
			if (key.validity < GPGValidityInvalid) {
				return YES;
			}
		}
		return NO;
	}
	
	return YES;
}

- (BOOL)respondsToSelector:(SEL)selector {
	if (selector == @selector(cancel:)) {
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
	Class dictionaryClass = [NSDictionary class];
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
	BOOL indent = options & DescriptionIndent;
	
	NSString *lineBreak = indent ? @"\n\t" : @"\n";
	if (indent) {
		[descriptions appendString:@"\t"];
	}
	
	NSString *normalSeperator = singleLine ? @", " : [@"," stringByAppendingString:lineBreak];
	NSString *lastSeperator = [NSString stringWithFormat:@" %@%@", localized(@"and"), singleLine ? @" " : lineBreak];
	NSString *seperator = @"";
	
	for (__strong GPGKey *key in keys) {
		if (i >= lines && i > 0) {
			[descriptions appendFormat:localized(@"KeyDescriptionAndMore"), singleLine ? @" " : lineBreak , count - i];
			break;
		}

		if (![key isKindOfClass:gpgKeyClass] && ![key isKindOfClass:dictionaryClass]) {
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
		
		
		
		if ([key isKindOfClass:gpgKeyClass] || [key isKindOfClass:dictionaryClass]) {
			NSString *name = [key valueForKey:@"name"];
			NSString *email = [key valueForKey:@"email"];
			NSString *shortKeyID = [[key valueForKey:@"keyID"] shortKeyID];
			
			NSUInteger mailFlag = 0;
			if (showEmail && email.length) {
				mailFlag = 2;
			}
			
			switch (showFlags + mailFlag) {
				case 1:
					[descriptions appendFormat:@"%@%@", seperator, name];
					break;
				case 2:
					[descriptions appendFormat:@"%@%@", seperator, email];
					break;
				case 3:
					[descriptions appendFormat:@"%@%@ <%@>", seperator, name, email];
					break;
				case 4:
					[descriptions appendFormat:@"%@%@", seperator, shortKeyID];
					break;
				case 5:
					[descriptions appendFormat:@"%@%@ (%@)", seperator, name, shortKeyID];
					break;
				case 6:
					[descriptions appendFormat:@"%@%@ (%@)", seperator, email, shortKeyID];
					break;
				default:
					[descriptions appendFormat:@"%@%@ <%@> (%@)", seperator, name, email, shortKeyID];
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
			title = localized(@"ImportKeyError_Title");
			message = localized(@"ImportKeyError_Msg");
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
	
	
	[sheetController errorSheetWithMessageText:title infoText:message];
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
		
		
		NSInteger actionCode = 0;
		NSArray *action = [oldUserInfo objectForKey:@"action"];
		
		if ([action isKindOfClass:[NSArray class]]) {
			if (action.count > 0) {
				actionCode = [action[0] integerValue];
				
				if (action.count > 1) {
					action = [action subarrayWithRange:NSMakeRange(1, action.count - 1)];
					NSMutableDictionary *tempUserInfo = oldUserInfo.mutableCopy;
					tempUserInfo[@"action"] = action;
					gc.userInfo = tempUserInfo;
				}
			}
		} else {
			actionCode = [(NSNumber *)action integerValue];
		}
		
		switch (actionCode) {
			case ShowResultAction: {
				if (gc.error) break;
				
				NSDictionary *statusDict = gc.statusDict;
				if (statusDict) {
					[self refreshDisplayedKeys:self];
					
					NSSet *affectedkeys = nil;
					sheetController.msgText = [self importResultWithStatusDict:statusDict affectedKeys:&affectedkeys];
					sheetController.title = localized(@"Import results");
					sheetController.sheetType = SheetTypeShowResult;
					[sheetController runModalForWindow:mainWindow];
					affectedkeys = [affectedkeys setByAddingObjectsFromSet:oldUserInfo[@"keys"]];
					[[KeychainController sharedInstance] selectKeys:affectedkeys];
				}
				break;
			}
			case ShowFoundKeysAction: {
				if (gc.error) break;
				NSArray *keys = gc.lastReturnValue;
				if ([keys count] == 0) {
					sheetController.title = localized(@"No keys Found");
					sheetController.msgText = @"";
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
			case SaveDataToURLAction: { // Saves value to one or more files (@"URL"). You can specify @"hideExtension".
				if (gc.error) break;
				
				NSSet *urls = [oldUserInfo objectForKey:@"URL"];
				NSNumber *hideExtension = @([[oldUserInfo objectForKey:@"hideExtension"] boolValue]);
				if ([urls isKindOfClass:[NSURL class]]) {
					urls = [NSSet setWithObject:urls];
				}
				
				NSFileManager *fileManager = [NSFileManager defaultManager];
				for (NSURL *url in urls) {
					[fileManager createFileAtPath:url.path contents:value attributes:@{NSFileExtensionHidden: hideExtension}];
				}

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
				[[KeychainController sharedInstance] selectKeys:keys];
				
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
		// The printVersion is managed through gpg.conf via the emit-version and no-emit-version options.  Do not override here.
		//gpgc.printVersion = YES;
		gpgc.async = YES;
		gpgc.keyserverTimeout = 20;
		
		showExpertSettings = [[GPGOptions sharedOptions] boolForKey:@"showExpertSettings"];
		if (showExpertSettings) {
			gpgc.allowNonSelfsignedUid = YES;
			gpgc.allowWeakDigestAlgos = YES;
		}
		
		sheetController = [SheetController sharedInstance];
		
		
		if (NSAppKitVersionNumber >= NSAppKitVersionNumber10_9) {
			// Pasteboard check.
			generalPboard = [NSPasteboard generalPasteboard];
			
			pasteboardTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0));
			if (pasteboardTimer) {
				dispatch_source_set_timer(pasteboardTimer, dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), 0.5 * NSEC_PER_SEC, 0.3 * NSEC_PER_SEC);
				dispatch_source_set_event_handler(pasteboardTimer, ^{
					[self checkPasteboardChanges];
				});
				dispatch_resume(pasteboardTimer);
			}
		}
		
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

