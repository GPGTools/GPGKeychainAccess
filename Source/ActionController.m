/*
 Copyright © Roman Zechmeister, 2017
 
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
#import "GKPhotoPopoverController.h"



@implementation ActionController
@synthesize progressText, errorText, keysController, signaturesController,
			subkeysController, userIDsController, keyTable,
			signaturesTable, userIDsTable, subkeysTable, gpgc;


static NSString * const dealsWithErrorsKey = @"dealsWithErrors";
static NSString * const actionKey = @"action";



#pragma mark General
- (void)awakeFromNib {
#warning This code is required until jenkins is up to date.
	userIDsTable.doubleAction = @selector(userIDDoubleClick:);
	userIDsTable.target = self;
	userIDsTable.action = nil;
	signaturesTable.doubleAction = @selector(signatureDoubleClick:);
	signaturesTable.target = self;
	signaturesTable.action = nil;
}

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
	[self exportKeyCompact:NO];
}
- (IBAction)exportCompact:(id)sender {
	[self exportKeyCompact:YES];
}
- (void)exportKeyCompact:(BOOL)compact {
	NSArray *keys = [self selectedKeys];
	if (keys.count == 0) {
		return;
	}
	
	self.sheetController.title = nil; //TODO
	self.sheetController.msgText = nil; //TODO
	
	self.sheetController.keys = keys;
	self.sheetController.pattern = nil;
	self.sheetController.allowedFileTypes = [NSArray arrayWithObjects:@"asc", nil];
	self.sheetController.sheetType = SheetTypeExportKey;
	if ([self.sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	self.progressText = localized(@"ExportKey_Progress");
	
	BOOL armor = self.sheetController.exportFormat != 0;
	BOOL exportSecretKey = self.sheetController.exportSecretKey;
	GPGExportOptions options = exportSecretKey ? GPGExportSecretKeys : 0;
	
	
	if (compact) {
		// Export minimal and remove all photos.
		options |= GPGExportMinimal;
		gpgc.useArmor = NO;
	} else {
		// Normal export (not compact).
		gpgc.useArmor = armor;
	}

	
	actionCallback callback = [^(GPGController *gc, NSData *exportedData, NSDictionary *userInfo) {
		if (gc.error || exportedData.length < 10) {
			NSString *message;
			if (gc.error) {
				message = [self errorMessageFromException:gc.error gpgTask:gc.gpgTask description:nil];
			}
			[self.sheetController errorSheetWithMessageText:localized(@"ExportKey_Error") infoText:message];
			return;
		}
		
		
		if (compact) {
			// Remove the photos with all attached signatures.
			NSMutableData *cmopactData = [NSMutableData data];
			__block BOOL removeSignatures = NO;
			[GPGPacket enumeratePacketsWithData:exportedData block:^(GPGPacket *packet, BOOL *stop) {
				if (packet.tag == GPGUserAttributePacketTag) {
					removeSignatures = YES;
					return;
				} else if (removeSignatures) {
					if (packet.tag == GPGSignaturePacketTag) {
						return;
					} else {
						removeSignatures = NO;
					}
				}
				[cmopactData appendData:packet.data];
			}];
			
			
			if (cmopactData.length < 10) {
				// Something went wrong.
				[self.sheetController errorSheetWithMessageText:localized(@"ExportKey_Error") infoText:@""];
				return;
			}
			
			
			if (armor) {
				// Convert to ASCII armored format with crc.
				UInt32 crc = [cmopactData crc24];
				UInt8 crcBytes[3];
				crcBytes[0] = crc >> 16;
				crcBytes[1] = crc >> 8;
				crcBytes[2] = crc;
				NSData *crcData = [[NSData dataWithBytes:crcBytes length:3] base64EncodedDataWithOptions:0];
				
				NSData *base64Data = [cmopactData base64EncodedDataWithOptions:NSDataBase64Encoding64CharacterLineLength | NSDataBase64EncodingEndLineWithLineFeed];
				
				NSString *blockType = exportSecretKey ? @"PRIVATE" : @"PUBLIC";
				
				
				NSMutableData *armoredData = [NSMutableData data];
				[armoredData appendData:[@"-----BEGIN PGP " UTF8Data]];
				[armoredData appendData:[blockType UTF8Data]];
				[armoredData appendData:[@" KEY BLOCK-----\n\n" UTF8Data]];
				[armoredData appendData:base64Data];
				[armoredData appendData:[@"\n=" UTF8Data]];
				[armoredData appendData:crcData];
				[armoredData appendData:[@"-----END PGP " UTF8Data]];
				[armoredData appendData:[blockType UTF8Data]];
				[armoredData appendData:[@" KEY BLOCK-----\n\n" UTF8Data]];
				
				exportedData = armoredData;
			} else {
				exportedData = cmopactData;
			}
			
		}
		
		
		
		// Save the exported key(s).
		NSError *error = nil;
		NSURL *url = self.sheetController.URL;
		
		if ([exportedData writeToURL:self.sheetController.URL options:NSDataWritingAtomic error:&error]) {
			[[NSFileManager defaultManager] setAttributes:@{NSFileExtensionHidden: @(self.sheetController.hideExtension)} ofItemAtPath:url.path error:nil];
			
			[self.sheetController alertSheetWithTitle:localized(@"ExportSuccess_Title")
											  message:localizedStringWithFormat(@"ExportSuccess_Msg", [self descriptionForKeys:keys maxLines:8 withOptions:0])
										defaultButton:nil
									  alternateButton:nil
										  otherButton:nil
									suppressionButton:nil];
		} else {
			[self.sheetController errorSheetWithMessageText:localized(@"ExportKey_Error") infoText:error.localizedDescription];
		}
	} copy];
	
	
	
	gpgc.userInfo = @{@"action": @[callback], dealsWithErrorsKey: @YES};
	[gpgc exportKeys:keys options:options];
}
- (IBAction)importKey:(id)sender {
	self.sheetController.title = nil; //TODO
	self.sheetController.msgText = nil; //TODO
	//self.sheetController.allowedFileTypes = [NSArray arrayWithObjects:@"asc", @"gpg", @"pgp", @"key", @"gpgkey", nil];
	
	self.sheetController.sheetType = SheetTypeOpenPanel;
	if ([self.sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	[self importFromURLs:self.sheetController.URLs];
}

- (void)importFromURLs:(NSArray *)urls {
	[self importFromURLs:urls askBeforeOpen:YES];
}

- (BOOL)importFromURLs:(NSArray *)urls askBeforeOpen:(BOOL)ask {
	BOOL onlyGPGServicesUsed = NO;
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
					NSInteger returnCode = [self.sheetController alertSheetForWindow:mainWindow
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
			if (dataToImport.length == 0) {
				onlyGPGServicesUsed = YES;
			}
		}
		if (dataToImport.length > 0) {
			[self importFromData:dataToImport];
		}
	}
	return onlyGPGServicesUsed;
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
							
							GPGKey *key = [GPGKeyManager sharedInstance].keysByKeyID[sigPacket.keyID];
							if (key && key.revoked == NO) {
								
								NSInteger returnCode = [self.sheetController alertSheetForWindow:mainWindow
																		  messageText:localized(@"RevokeKey_Title")
																				   infoText:[NSString stringWithFormat:localized(@"RevokeKey_Msg"), [self descriptionForKey:key]]
																			  defaultButton:localized(@"RevokeKey_No")
																			alternateButton:localized(@"RevokeKey_Yes")
																				otherButton:nil
																		  suppressionButton:nil];
								
								if (returnCode != NSAlertSecondButtonReturn) {
									ignorePacket = YES;
								} else {
									if (packets.count == 1) {
										action = @{@"action": @[[self uploadCallbackForKey:key string:@"RevokedKeyWantToUpload"]]};
										myProgressText = localized(@"RevokeKey_Progress");
										myErrorText = localized(@"RevokeKey_Error");
									}
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
		[self.sheetController errorSheetWithMessageText:title infoText:message];
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
		[self.sheetController errorSheetWithMessageText:title infoText:message];
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

	
	
	NSString *emailApp = @"";
	if (NSAppKitVersionNumber >= 1343) {
		NSURL *mailtoURL = [NSURL URLWithString:@"mailto:"];
		NSURL *appURL = CFBridgingRelease(LSCopyDefaultApplicationURLForURL((__bridge CFURLRef)mailtoURL, kLSRolesAll, nil));
		emailApp = appURL.lastPathComponent;
	}
	
	
	if ([emailApp isEqualToString:@"Mail.app"]) {
		// Use NSSharingService, to create an email, with an attached key-file.
		NSString *templateString = [NSTemporaryDirectory() stringByAppendingPathComponent:@"GKA.XXXXXX"];
		NSMutableData *template = [[templateString dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
		
		char *tempDir = [template mutableBytes];
		if (!mkdtemp(tempDir)) {
			return;
		}
		
		
		NSString *path = [NSString stringWithFormat:@"%s/%@.asc", tempDir, filenameForExportedKeys(keys, nil)];
		NSURL *url = [NSURL fileURLWithPath:path];
		NSError *error = nil;
		[data writeToURL:url options:0 error:&error];
		if (error) {
			return;
		}
		
		
		NSSharingService *service = [NSSharingService sharingServiceNamed:NSSharingServiceNameComposeEmail];
		
		[service setValue:@{@"NSSharingServiceParametersDefaultSubjectKey": subject} forKey:@"parameters"];
		[service performWithItems:@[message, url]];
		
	} else {
		// Use a mailto: link and add the key-block as normal text.
		message = [message stringByAppendingFormat:@"\n\n\n%@\n", [data gpgString]];
		message = [message stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		subject = [subject stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		
		NSString *mailto = [NSString stringWithFormat:@"mailto:?subject=%@&body=%@", subject, message];
		
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:mailto]];
		
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
		[mainWindow endSheet:mainWindow.sheets[0]];
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
	
}


#pragma mark Window and display
- (IBAction)refreshDisplayedKeys:(id)sender {
	[[GPGKeyManager sharedInstance] loadAllKeys];
}

#pragma mark Keys
- (IBAction)generateNewKey:(id)sender {
	self.sheetController.sheetType = SheetTypeNewKey;
	if ([self.sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	GPGPublicKeyAlgorithm keyType, subkeyType;
	
	switch (self.sheetController.keyType) {
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
	
	
	NSString *passphrase = self.sheetController.passphrase;
	if (!passphrase) {
		passphrase = @"";
	}
	gpgc.passphrase = passphrase;
	
	
	
	actionCallback uploadCallback = [^(GPGController *gc, NSString *fingerprint, NSDictionary *userInfo) {
		if (gc.error) {
			return;
		}
		if ([self warningSheetWithDefault:NO string:@"NewKeyWantToUpload"]) {
			self.progressText = localizedStringWithFormat(@"SendKeysToServer_Progress", [self descriptionForKey:fingerprint]);;
			self.errorText = localized(@"SendKeysToServer_Error");
			[gpgc sendKeysToServer:@[fingerprint]];
		}
	} copy];
	gpgc.userInfo = @{@"action": @[uploadCallback]};
	
	
	[gpgc generateNewKeyWithName:self.sheetController.name
						   email:self.sheetController.email
						 comment:self.sheetController.comment
						 keyType:keyType
					   keyLength:(int)self.sheetController.length
					  subkeyType:subkeyType
					subkeyLength:(int)self.sheetController.length
					daysToExpire:(int)self.sheetController.daysToExpire
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
	[self.sheetController alertSheetForWindow:mainWindow
							 messageText:title
								infoText:message
						   defaultButton:button1
						 alternateButton:button2
							 otherButton:button3
					   suppressionButton:checkbox
							   customize:^(NSAlert *alert) {
								   NSWindow *window = alert.window;
								   NSView *contentView = window.contentView;
								   NSView *textField = nil;
								   NSView *checkBoxButton;
								   NSAttributedString *attributedString;
								   
								   NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
								   paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
								   NSDictionary *attributes = @{NSFontAttributeName: [NSFont systemFontOfSize:NSFont.smallSystemFontSize],
																NSParagraphStyleAttributeName: paragraphStyle};

								   
								   if (NSAppKitVersionNumber > /*NSAppKitVersionNumber10_10*/1343) {
									   if (hasSecretKey) {
										   attributedString = [[NSAttributedString alloc] initWithString:checkbox attributes:attributes];
										   // The checkbox must be checked before the delete buttons are enabled.
										   NSButtonCell *checkboxCell = alert.suppressionButton.cell;
										   checkboxCell.lineBreakMode = NSLineBreakByCharWrapping;
										   [checkboxCell setAttributedTitle:attributedString];
										   checkboxCell.state = NSOffState;
										   [alert.buttons[1] bind:@"enabled" toObject:checkboxCell withKeyPath:@"state" options:nil];
										   [alert.buttons[2] bind:@"enabled" toObject:checkboxCell withKeyPath:@"state" options:nil];
									   }
									   
									   return;
								   }

								   
								   // Calulate widths.
								   CGFloat minWidth = [description sizeWithAttributes:attributes].width + 20;
								   CGFloat maxWidth = window.screen.frame.size.width;
								   if (minWidth > 1000) {
									   minWidth = 1000;
								   }
								   if (maxWidth < 200) {
									   maxWidth = 200;
								   } else if (maxWidth > 700) {
									   maxWidth = 700;
								   }
								   if (minWidth > maxWidth) {
									   minWidth = maxWidth;
								   }
								   
								   
								   for (NSView *subview in contentView.subviews) {
									   if ([subview isKindOfClass:[NSTextField class]] && [[(NSTextField *)subview stringValue] isEqualToString:message]) {
										   textField = subview; // The minimum width will be set the message text field.
										   break;
									   }
								   }
								   if (!textField) { // No text field? Should be impossible.
									   textField = contentView; // Set minimum width on the content view.
								   }
								   checkBoxButton = checkbox ? alert.suppressionButton : contentView; // contentView is only set because a dictionary doesn't allow nil.
								   NSDictionary *views = @{@"content": contentView, @"text": textField, @"checkbox": checkBoxButton};

								   
								   // Add minimum width constraint
								   NSString *format = [NSString stringWithFormat:@"[text(>=%f@999)]", minWidth];
								   NSArray *constraints = [NSLayoutConstraint constraintsWithVisualFormat:format options:0 metrics:nil views:views];
								   [contentView addConstraints:constraints];

								   // and maximum width constraint.
								   format = [NSString stringWithFormat:@"[content(<=%f)]", maxWidth];
								   constraints = [NSLayoutConstraint constraintsWithVisualFormat:format options:0 metrics:nil views:views];
								   [contentView addConstraints:constraints];
								   
								   
								   
								   if (hasSecretKey) {
									   NSRect frame = alert.suppressionButton.frame;
									   NSInteger maxCheckboxWidth = maxWidth - frame.origin.x - 40;
									   
									   // The checkbox would be to wide for the window.
									   if (maxCheckboxWidth < frame.size.width) {
										   NSMutableArray *lineEnds = [NSMutableArray new];
										   NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:attributedString];
										   NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(maxCheckboxWidth, CGFLOAT_MAX)];
										   NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
										   
										   [layoutManager addTextContainer:textContainer];
										   [textStorage addLayoutManager:layoutManager];
										   
										   textContainer.lineFragmentPadding = 0;
										   
										   // Get the lines for the desired width.
										   NSUInteger lastGlyph = NSMaxRange([layoutManager glyphRangeForCharacterRange:NSMakeRange(0, checkbox.length) actualCharacterRange:nil]);
										   NSUInteger glyphIndex = 0;
										   while (glyphIndex < lastGlyph) {
											   NSRange lineFragmentGlyphRange;
											   [layoutManager lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:&lineFragmentGlyphRange];
											   glyphIndex = NSMaxRange(lineFragmentGlyphRange);
											   [lineEnds addObject:@([layoutManager characterIndexForGlyphAtIndex:glyphIndex])];
										   }
										   
										   // Add necessary line breaks.
										   if (lineEnds.count > 1) {
											   NSMutableString *newString = [NSMutableString new];
											   NSUInteger lineStart = 0;
											   for (NSNumber *lineEndValue in lineEnds) {
												   NSUInteger lineEnd = lineEndValue.unsignedIntegerValue;
												   NSString *line = [checkbox substringWithRange:NSMakeRange(lineStart, lineEnd - lineStart)];
												   [newString appendFormat:@"%@\n", line];
												   lineStart = lineEnd;
											   }
											   [newString replaceCharactersInRange:NSMakeRange(newString.length - 1, 1) withString:@""];
											   attributedString = [[NSAttributedString alloc] initWithString:newString attributes:attributes];
											   
											   // Set checkbox height, so all lines will fit.
											   CGFloat height = [layoutManager usedRectForTextContainer:textContainer].size.height;
											   frame.size.height = height;
											   alert.suppressionButton.frame = frame;
											   
											   constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[text]-20-[checkbox]" options:0 metrics:nil views:views];
											   [contentView addConstraints:constraints];
										   }
									   }
									   
									   // The checkbox must be checked before the delete buttons are enabled.
									   NSButtonCell *checkboxCell = alert.suppressionButton.cell;
									   checkboxCell.lineBreakMode = NSLineBreakByCharWrapping;
									   [checkboxCell setAttributedTitle:attributedString];
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
- (IBAction)setDisabled:(NSButton *)sender {
	NSArray *keys = [self selectedKeys];
	if (keys.count != 1) {
		return;
	}
	GPGKey *key = keys[0];
	BOOL disabled = [sender state] == NSOnState;
	
	self.progressText = localized(@"SetDisabled_Progress");
	self.errorText = localized(@"SetDisabled_Error");
	[self showProgressUntilKeyIsRefreshed:key];
	[gpgc key:key setDisabled:disabled];
}
- (IBAction)setTrust:(NSPopUpButton *)sender {
	NSArray *keys = [self selectedKeys];
	if (keys.count != 1) {
		return;
	}
	GPGKey *key = keys[0];
	NSInteger trust = sender.selectedTag;
	
	self.progressText = localized(@"SetOwnerTrust_Progress");
	self.errorText = localized(@"SetOwnerTrust_Error");
	[self showProgressUntilKeyIsRefreshed:key];
	[gpgc key:key setOwnerTrust:(GPGValidity)trust];
}

- (IBAction)changeExpirationDate:(NSButton *)sender {
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
		self.sheetController.msgText = [NSString stringWithFormat:localized(@"ChangeSubkeyExpirationDate_Msg"), subkey.keyID.shortKeyID, [key userIDDescription], key.keyID.shortKeyID];
		self.sheetController.expirationDate = [subkey expirationDate];
	} else {
		self.sheetController.msgText = [NSString stringWithFormat:localized(@"ChangeExpirationDate_Msg"), [key userIDDescription], key.keyID.shortKeyID];
		self.sheetController.expirationDate = [key expirationDate];
	}
	
	self.sheetController.sheetType = SheetTypeExpirationDate;
	if ([self.sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	self.progressText = localized(@"ChangeExpirationDate_Progress");
	self.errorText = localized(@"ChangeExpirationDate_Error");
	
	gpgc.userInfo = @{@"action": @[[self uploadCallbackForKey:key string:@"ExpirationDateChangedWantToUpload"]]};
	
	[gpgc setExpirationDateForSubkey:subkey fromKey:key daysToExpire:self.sheetController.daysToExpire];
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
	
	
	
	self.sheetController.allowEdit = key.secret;
	self.sheetController.algorithmPreferences = mutablePreferences;
	self.sheetController.sheetType = SheetTypeAlgorithmPreferences;
	if ([self.sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	
	NSArray *newPreferences = self.sheetController.algorithmPreferences;
	
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
		self.sheetController.title = nil; //TODO
		self.sheetController.msgText = nil; //TODO
		self.sheetController.allowedFileTypes = [NSArray arrayWithObjects:@"asc", nil];
		self.sheetController.pattern = [NSString stringWithFormat:localized(@"%@ Revoke certificate"), key.description.keyID.shortKeyID];
		
		self.sheetController.sheetType = SheetTypeSavePanel;
		if ([self.sheetController runModalForWindow:mainWindow] != NSOKButton) {
			return;
		}
		hideExtension = self.sheetController.hideExtension;
		url = self.sheetController.URL;
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

- (void)revokeKey:(GPGKey *)key generateIfNeeded:(BOOL)generate {
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
			NSInteger returnCode = [self.sheetController alertSheetForWindow:mainWindow
												  messageText:localized(@"RevokeKey_Title")
													 infoText:[NSString stringWithFormat:localized(@"RevokeKey_Msg"), [self descriptionForKey:key]]
												defaultButton:localized(@"RevokeKey_No")
											  alternateButton:localized(@"RevokeKey_Yes")
												  otherButton:nil
											suppressionButton:nil];
			
			if (returnCode != NSAlertSecondButtonReturn) {
				return;
			}
			
			self.progressText = localized(@"RevokeKey_Progress");
			self.errorText = localized(@"RevokeKey_Error");
			
			gpgc.userInfo = @{@"action": @[[self uploadCallbackForKey:key string:@"RevokedKeyWantToUpload"]]};

			[gpgc importFromData:data fullImport:NO];
		}
	}
	
	if (!haveValidRevCert && generate) {
		GPGKey *gpgKey = [[[KeychainController sharedInstance] allKeys] member:key];
		if (gpgKey.secret) {
			actionCallback callback = [^(GPGController *gc, NSString *fingerprint, NSDictionary *userInfo) {
				if (!gc.error) {
					[self revokeKey:key generateIfNeeded:NO];
				}
			} copy];
			
			gpgc.userInfo = @{@"action": @[callback]};
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
	self.sheetController.sheetType = SheetTypeSearchKeys;
	if ([self.sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	
	actionCallback callback = [^(GPGController *gc, NSString *fingerprint, NSDictionary *userInfo) {
		if (gc.error) {
			if ([gc.error isKindOfClass:[GPGException class]] && [(GPGException *)gc.error errorCode] == GPGErrorCancelled) {
				return;
			}
			NSString *title = localized(@"KeyserverSearchError_Title");
			NSString *message = [self errorMessageFromException:gc.error gpgTask:gc.gpgTask description:localized(@"KeyserverSearchError_Msg")];
			
			[self.sheetController errorSheetWithMessageText:title infoText:message];
			return;
		}
		
		NSArray *keys = gc.lastReturnValue;
		if (keys.count == 0) {
			self.sheetController.title = localized(@"KeySearch_NoKeysFound_Title");
			self.sheetController.msgText = @"";
			self.sheetController.sheetType = SheetTypeShowResult;
			[self.sheetController runModalForWindow:mainWindow];
		} else {
			self.sheetController.keys = keys;
			self.sheetController.sheetType = SheetTypeShowFoundKeys;
			if ([self.sheetController runModalForWindow:mainWindow] == NSOKButton && self.sheetController.keys.count > 0) {
				[self receiveKeysFromServer:self.sheetController.keys];
			}
			self.sheetController.keys = nil;
		}
	} copy];
	
	gpgc.userInfo = @{actionKey: @[callback], dealsWithErrorsKey: @YES};
	self.progressText = localized(@"SearchKeysOnServer_Progress");
	
	NSString *pattern = self.sheetController.pattern;
	[gpgc searchKeysOnServer:pattern];
}
- (IBAction)receiveKeys:(id)sender {
	self.sheetController.sheetType = SheetTypeReceiveKeys;
	if ([self.sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	NSSet *keyIDs = [self.sheetController.pattern keyIDs];
	
	[self receiveKeysFromServer:keyIDs];
}
- (IBAction)sendKeysToServer:(id)sender {
	NSArray *keys = [self selectedKeys];
	if (keys.count == 0) {
		return;
	}
	if (keys.count > 1 && !showExpertSettings) {
		return;
	}
	
	__block BOOL canceled = NO;
	NSString *progressString = localizedStringWithFormat(@"SendKeysToServer_Progress", [self descriptionForKeys:keys maxLines:3 withOptions:0]);
	
	void (^performUpload)() = ^() {
		self.progressText = progressString;
		self.errorText = localized(@"SendKeysToServer_Error");
		
		actionCallback callback = ^(GPGController *gc, id value, NSDictionary *userInfo) {
			[self.sheetController endProgressSheet];
			if (!gc.error) {
				[self.sheetController alertSheetWithTitle:localized(@"UploadSuccess_Title")
											 message:localizedStringWithFormat(@"UploadSuccess_Msg", [self descriptionForKeys:keys maxLines:8 withOptions:0])
									   defaultButton:nil
									 alternateButton:nil
										 otherButton:nil
								   suppressionButton:nil];
			}
		};
		gpgc.userInfo = @{@"action": @[[callback copy]]};
		[gpgc sendKeysToServer:keys];
	};
	
	
	
	if ([gpgc respondsToSelector:@selector(keysExistOnServer:callback:)]) {
		NSArray *publicKeys = [keys filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(GPGKey *key, NSDictionary *bindings) {
			return !key.secret;
		}]];
		
		if (publicKeys.count > 0) {
			cancelCallback cancelBlock = ^() {
				canceled = YES;
				[self.sheetController endProgressSheet];
			};
			
			NSString *cancelKey = [[NSProcessInfo processInfo] globallyUniqueString];
			[cancelCallbacks setObject:[cancelBlock copy] forKey:cancelKey];
			
			self.sheetController.progressText = progressString;
			[self.sheetController showProgressSheet];
			[gpgc keysExistOnServer:publicKeys callback:^(NSArray *existingKeys, NSArray *nonExistingKeys) {
				void (^block)() = ^{
					[cancelCallbacks removeObjectForKey:cancelKey];
					if (nonExistingKeys.count > 0) {
						[self.sheetController endProgressSheet];
						NSString *description = [self descriptionForKeys:nonExistingKeys maxLines:8 withOptions:0];
						[self.sheetController errorSheetWithMessageText:localized(@"FirstUploadForeignKey_Title")
														  infoText:localizedStringWithFormat(@"FirstUploadForeignKey_Msg", description)];
					} else {
						performUpload();
					}
				};
				
				if (!canceled) {
					if ([NSThread isMainThread]) {
						block();
					} else {
						dispatch_async(dispatch_get_main_queue(), block);
					}
				}
			}];
		}
	} else {
		performUpload();
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
	
	self.sheetController.msgText = [NSString stringWithFormat:localized(@"GenerateSubkey_Msg"), [key userIDDescription], key.keyID.shortKeyID];
	
	self.sheetController.sheetType = SheetTypeAddSubkey;
	if ([self.sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	self.progressText = localized(@"AddSubkey_Progress");
	self.errorText = localized(@"AddSubkey_Error");
	
	gpgc.userInfo = @{@"action": @[[self uploadCallbackForKey:key string:@"NewSubkeyWantToUpload"]]};

	[gpgc addSubkeyToKey:key type:self.sheetController.keyType length:self.sheetController.length daysToExpire:self.sheetController.daysToExpire];
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
	[self showProgressUntilKeyIsRefreshed:key];
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

	gpgc.userInfo = @{@"action": @[[self uploadCallbackForKey:key string:@"RevokedSubkeyWantToUpload"]]};
	
	[gpgc revokeSubkey:subkey fromKey:key reason:0 description:nil];
}

#pragma mark UserIDs
- (IBAction)addUserID:(id)sender {
	NSArray *keys = [self selectedKeys];
	if (keys.count != 1) {
		return;
	}
	GPGKey *key = [keys[0] primaryKey];
	GPGUserID *userID = key.primaryUserID;

	self.sheetController.msgText = [NSString stringWithFormat:localized(@"GenerateUserID_Msg"), key.userIDDescription, key.keyID.shortKeyID];
	
	self.sheetController.sheetType = SheetTypeAddUserID;
	if ([self.sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	self.progressText = localized(@"AddUserID_Progress");
	self.errorText = localized(@"AddUserID_Error");
	
	
	actionCallback primaryUserIDCallback = [^(GPGController *gc, id value, NSDictionary *userInfo) {
		if (gc.error) {
			[self.sheetController endProgressSheet];
			return;
		}
		self.progressText = localized(@"SetPrimaryUserID_Progress");
		self.errorText = localized(@"SetPrimaryUserID_Error");
		[gpgc setPrimaryUserID:userID.hashID ofKey:userID.primaryKey];
	} copy];
	
	gpgc.userInfo = @{@"action": @[primaryUserIDCallback, [self uploadCallbackForKey:key string:@"NewUserIDWantToUpload"]]};

	[gpgc addUserIDToKey:key name:self.sheetController.name email:self.sheetController.email comment:self.sheetController.comment];
}
- (IBAction)removeUserID:(id)sender {
	NSArray *objects = [self selectedObjectsOf:userIDsTable];
	if (objects.count != 1) {
		return;
	}
	GPGUserID *userID = [objects objectAtIndex:0];
	GPGKey *key = userID.primaryKey;
	
	if (userID.isUat == NO && [self warningSheetWithDefault:NO string:@"RemoveUserID", userID.userIDDescription, key.keyID.shortKeyID] == NO) {
		return;
	}
	
	self.progressText = localized(@"RemoveUserID_Progress");
	self.errorText = localized(@"RemoveUserID_Error");
	[self showProgressUntilKeyIsRefreshed:key];
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
	[self showProgressUntilKeyIsRefreshed:key];
	[gpgc setPrimaryUserID:userID.hashID ofKey:key];
}
- (IBAction)revokeUserID:(id)sender {
	NSArray *objects = [self selectedObjectsOf:userIDsTable];
	if (objects.count != 1) {
		return;
	}
	GPGUserID *userID = [objects objectAtIndex:0];
	GPGKey *key = userID.primaryKey;
	
	if (userID.isUat == NO && [self warningSheetWithDefault:NO string:@"RevokeUserID", userID.userIDDescription, key.keyID.shortKeyID] == NO) {
		return;
	}
	
	self.progressText = localized(@"RevokeUserID_Progress");
	self.errorText = localized(@"RevokeUserID_Error");
	
	gpgc.userInfo = @{@"action": @[[self uploadCallbackForKey:key string:@"RevokedUserIDWantToUpload"]]};
	
	[gpgc revokeUserID:[userID hashID] fromKey:key reason:0 description:nil];
}

#pragma mark Photos
- (void)addPhoto:(NSString *)path toKey:(GPGKey *)key {
	self.progressText = localized(@"AddPhoto_Progress");
	self.errorText = localized(@"AddPhoto_Error");
	
	
	void (^failed)(NSString *) = ^(NSString *message) {
		[self.sheetController errorSheetWithMessageText:localized(@"AddPhoto_Error") infoText:localized(message)];
	};
	
	
	NSData *data = [NSData dataWithContentsOfFile:path];
	if (!data) {
		failed(@"");
		return;
	}
	
	CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef) data, nil);
	if (!source) {
		failed(@"");
		return;
	}

	NSString *imageType = (__bridge NSString *)CGImageSourceGetType(source);
	if (!imageType) {
		CFRelease(source);
		failed(@"");
		return;
	}
	
	if ([imageType isEqualToString:@"public.jpeg"]) {
		unsigned long long filesize = [[[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] objectForKey:NSFileSize] unsignedLongLongValue];
		if (filesize < 15000) {
			// No need to shrink the image.
			CFRelease(source);
			[gpgc addPhotoFromPath:path toKey:key];
			return;
		}
	}
	// The image isn't a JPEG or is too large.
	// Shrink and convert it.
	
	
	CGImageRef inputImage = CGImageSourceCreateImageAtIndex(source, 0, nil);
	CFRelease(source);
	if (!inputImage) {
		failed(@"");
		return;
	}
	
	
	// Calculate new size.
	size_t width = CGImageGetWidth(inputImage);
	size_t height = CGImageGetHeight(inputImage);
	size_t max = MAX(width, height);
	if (max > 250) {
		// Images is larger than 250px. Resize it.
		double scale = 250.0 / max ;
		width *= scale;
		height *= scale;
	}
	
	
	// Use different color spaces for grayscale and RGB.
	BOOL isGrayscale = CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(inputImage)) == 1;
	
	CGContextRef context;
	CGColorSpaceRef colorSpace;
	
	if (isGrayscale) {
		colorSpace =  CGColorSpaceCreateDeviceGray();
		context = CGBitmapContextCreate(nil, width, height, 8, 0, colorSpace, (CGBitmapInfo)kCGImageAlphaNone);
	} else {
		colorSpace =  CGColorSpaceCreateDeviceRGB();
		context = CGBitmapContextCreate(nil, width, height, 8, 0, colorSpace, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
	}
	
	CGColorSpaceRelease(colorSpace);
	if (!context) {
		CFRelease(inputImage);
		failed(@"");
		return;
	}
	
	
	// High quality scaling.
	CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
	
	
	CGContextDrawImage(context, CGRectMake(0, 0, width, height), inputImage);
	CFRelease(inputImage);
	CGImageRef scaledImage = CGBitmapContextCreateImage(context);
	
	
	// Qulaity 35% and porgressive.
	NSDictionary *properties = @{
								 (__bridge NSString *)kCGImageDestinationLossyCompressionQuality: @(0.35),
								 (__bridge NSString *)kCGImagePropertyJFIFDictionary: @{(__bridge NSString *)kCGImagePropertyJFIFIsProgressive: @YES}
								};

	
	// Get a temp file name.
	NSString *fileName = [NSString stringWithFormat:@"%@_gpg_tmp.jpg", [[NSProcessInfo processInfo] globallyUniqueString]];
	NSURL *fileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];

	
	// Save the image.
	CGImageDestinationRef imgDest = CGImageDestinationCreateWithURL((__bridge CFURLRef)fileURL, kUTTypeJPEG, 1, nil);
	CGImageDestinationAddImage(imgDest, scaledImage, (__bridge CFDictionaryRef)properties);
	BOOL sucess = CGImageDestinationFinalize(imgDest);
	
	if (sucess) {
		[self showProgressUntilKeyIsRefreshed:key];
		
		actionCallback callback = ^(GPGController *gc, id value, NSDictionary *userInfo) {
			[[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
		};
		gpgc.userInfo = @{@"action": @[[callback copy]]};
		
		[gpgc addPhotoFromPath:[fileURL path] toKey:key];
	} else {
		failed(@"");
		[[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
	}
	
	CFRelease(imgDest);
	CFRelease(scaledImage);
	CFRelease(context);
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
	if (key.photoID) {
		return;
	}
	
	self.sheetController.title = nil;
	self.sheetController.msgText = localized(@"AddPhoto_SelectMessage");
	self.sheetController.allowedFileTypes = @[@"jpg", @"jpeg", @"png", @"tif", @"tiff", @"gif"];
	
	self.sheetController.sheetType = SheetTypeOpenPhotoPanel;
	if ([self.sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	[self addPhoto:[self.sheetController.URL path] toKey:key];
}
- (IBAction)removePhoto:(id)sender {
	NSArray *keys = self.selectedKeys;
	if (keys.count != 1) {
		return;
	}
	GPGKey *key = [keys[0] primaryKey];
	
	self.progressText = localized(@"RemovePhoto_Progress");
	self.errorText = localized(@"RemovePhoto_Error");

	[self showProgressUntilKeyIsRefreshed:key];
	[gpgc removeUserID:key.photoID.hashID fromKey:key];
}
- (IBAction)revokePhoto:(id)sender {
	NSArray *keys = self.selectedKeys;
	if (keys.count != 1) {
		return;
	}
	GPGKey *key = [keys[0] primaryKey];
	
	self.progressText = localized(@"RevokePhoto_Progress");
	self.errorText = localized(@"RevokePhoto_Error");
	
	[self showProgressUntilKeyIsRefreshed:key];
	[gpgc revokeUserID:key.photoID.hashID fromKey:key reason:0 description:nil];
}
- (IBAction)photoClicked:(id)sender {
	if (self.photoPopover.shown) {
		[self closePhotoPopover];
		return;
	}
	NSArray *keys = self.selectedKeys;
	if (keys.count != 1) {
		return;
	}
	GPGKey *key = [keys[0] primaryKey];
	
	if (key.photoID) {
		// The key has a photo, show it in a popover.
		self.photoPopoverController.photoID = key.photoID;
		[self.photoPopover showRelativeToRect:NSZeroRect ofView:sender preferredEdge:NSMinYEdge];
		return;
	}
	
	if (key.secret) {
		[self addPhoto:self];
	}
}
- (IBAction)userIDDoubleClick:(id)sender {
	if (userIDsTable.clickedRow >= 0 && userIDsTable.selectedRowIndexes.count == 1) {
		NSUInteger index = userIDsTable.selectedRowIndexes.firstIndex;
		GPGUserID *userID = userIDsController.arrangedObjects[index];
		if (userID.isUat) {
			self.photoPopoverController.photoID = userID;
			[self.photoPopover showRelativeToRect:[userIDsTable rectOfRow:index] ofView:userIDsTable preferredEdge:NSMinYEdge];
		}
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
	if (key.validity >= GPGValidityInvalid) {
		return;
	}
	
	NSSet *usableSecretKeys = [[KeychainController sharedInstance].secretKeys objectsPassingTest:^BOOL(GPGKey *secretKey, BOOL *stop) {
		return secretKey.validity < GPGValidityInvalid && secretKey.canAnySign;
	}];
	
	if (usableSecretKeys.count == 0) {
		[self.sheetController errorSheetWithMessageText:localized(@"NO_SECRET_KEY_TITLE") infoText:localized(@"NO_SECRET_KEY_MESSAGE")];
		return;
	}

	NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
	NSArray *secretKeys = [usableSecretKeys sortedArrayUsingDescriptors:@[descriptor]];

	
	GPGKey *defaultKey = [KeychainController sharedInstance].defaultKey;
	if (!defaultKey) {
		defaultKey = secretKeys[0];
	}
	
	
	NSString *msgText;
	if (userID) {
		msgText = [NSString stringWithFormat:localized(@"GenerateUidSignature_Msg"), [NSString stringWithFormat:@"%@ (%@)", userID.userIDDescription, key.keyID.shortKeyID]];
	} else {
		msgText = [NSString stringWithFormat:localized(@"GenerateSignature_Msg"), key.userIDAndKeyID];
	}
	
	self.sheetController.msgText = msgText;
	self.sheetController.secretKeys = secretKeys;
	self.sheetController.secretKey = defaultKey;
	
	self.sheetController.sheetType = SheetTypeAddSignature;
	if ([self.sheetController runModalForWindow:mainWindow] != NSOKButton) {
		return;
	}
	
	self.progressText = localized(@"AddSignature_Progress");
	self.errorText = localized(@"AddSignature_Error");
	[gpgc signUserID:[userID hashID]
			   ofKey:key
			 signKey:self.sheetController.secretKey
				type:(int)self.sheetController.sigType
			   local:self.sheetController.localSig
		daysToExpire:(int)self.sheetController.daysToExpire];
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
- (IBAction)showKeyForSignature:(id)sender {
	NSArray *signatures = [self selectedObjectsOf:signaturesTable];
	if (signatures.count != 1) {
		return;
	}
	GPGUserIDSignature *signature = signatures[0];
	if (!signature.primaryKey) {
		return;
	}
	[[KeychainController sharedInstance] selectKeys:[NSSet setWithObject:signature.primaryKey]];
}
- (IBAction)receiveKeyForSignature:(id)sender {
	NSArray *signatures = [self selectedObjectsOf:signaturesTable];
	if (signatures.count != 1) {
		return;
	}
	GPGUserIDSignature *signature = signatures[0];
	NSString *keyID = signature.primaryKey ? signature.primaryKey.fingerprint : signature.keyID;
	
	self.progressText = localized(@"ReceiveKeysFromServer_Progress");
	self.errorText = localized(@"ReceiveKeysFromServer_Error");
	
	GPGKey *key = [keysController selectedObjects][0];
	
	
	self.sheetController.progressText = self.progressText;
	[self.sheetController showProgressSheet];
	key.isRefreshing = YES;
	
	NSString *cancelKey = [[NSProcessInfo processInfo] globallyUniqueString];
	keyUpdateCallback keyChangeBlock = ^(NSArray *keys) {
		if (!keys || [keys containsObject:key]) {
			if ([[[GPGKeyManager sharedInstance].allKeys member:key] isRefreshing] == NO) {
				[cancelCallbacks removeObjectForKey:cancelKey];
				[signaturesController setSelectedObjects:signatures];
				
				NSUInteger index = [[signaturesController arrangedObjects] indexOfObject:signature];
				[signaturesTable scrollRowToVisible:index];
				
				[self.sheetController endProgressSheet];
				return YES;
			}
		}
		return NO;
	};
	cancelCallback cancelBlock = [^() {
		[self.sheetController endProgressSheet];
		[[KeychainController sharedInstance] removeKeyUpdateCallback:keyChangeBlock];
	} copy];
	[cancelCallbacks setObject:cancelBlock forKey:cancelKey];
	[[KeychainController sharedInstance] addKeyUpdateCallback:keyChangeBlock];

	
	[gpgc receiveKeysFromServer:@[keyID]];
}
- (IBAction)signatureDoubleClick:(id)sender {
	if (signaturesTable.clickedRow < 0 || signaturesTable.selectedRowIndexes.count != 1) {
		return;
	}
	
	NSUInteger index = signaturesTable.selectedRowIndexes.firstIndex;
	GPGUserIDSignature *signature = signaturesController.arrangedObjects[index];
	
	if (signature.primaryKey) {
		[self showKeyForSignature:sender];
	} else {
		[self receiveKeyForSignature:sender];
	}
}




#pragma mark Miscellaneous :)

- (void)showProgressUntilKeyIsRefreshed:(GPGKey *)key {
	self.sheetController.progressText = self.progressText;
	[self.sheetController showProgressSheet];
	
	key.isRefreshing = YES;
	
	NSString *cancelKey = [[NSProcessInfo processInfo] globallyUniqueString];
	
	keyUpdateCallback keyChangeBlock = ^(NSArray *keys) {
		if (!keys || [keys containsObject:key]) {
			if ([[[GPGKeyManager sharedInstance].allKeys member:key] isRefreshing] == NO) {
				[cancelCallbacks removeObjectForKey:cancelKey];
				[self.sheetController endProgressSheet];
				return YES;
			}
		}
		return NO;
	};
	cancelCallback cancelBlock = [^() {
		[self.sheetController endProgressSheet];
		[[KeychainController sharedInstance] removeKeyUpdateCallback:keyChangeBlock];
	} copy];
	
	[cancelCallbacks setObject:cancelBlock forKey:cancelKey];

	[[KeychainController sharedInstance] addKeyUpdateCallback:keyChangeBlock];
}

- (void)cancelGPGOperation:(id)sender {
	[gpgc cancel];
	[cancelCallbacks enumerateKeysAndObjectsUsingBlock:^(id key, cancelCallback callback, BOOL *stop) {
		callback();
	}];
	[cancelCallbacks removeAllObjects];
}

- (void)cancel:(id)sender {
	if (self.photoPopover.shown) {
		[self closePhotoPopover];
	} else {
		appDelegate.inspectorVisible = NO;
	}
}

- (void)closePhotoPopover {
	[self.photoPopover close];
}


- (void)receiveKeysFromServer:(NSObject <EnumerationList> *)keys {
	gpgc.userInfo = @{@"action": @(ShowResultAction)};
	
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
	if (output.length == 0) {
		[output appendString:localized(@"IMPORT_RESULT_NOTHING_IMPORTED")];
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
		return @[[keysController.arrangedObjects objectAtIndex:clickedRow]];
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
	else if (selector == @selector(sendKeysToServer:)) {
		NSArray *keys = self.selectedKeys;
		if ([(NSObject *)item isKindOfClass:[NSMenuItem class]]) {
			NSMenuItem *menuItem = (id)item;
			BOOL secSelected = NO;
			for (GPGKey *key in keys) {
				if (key.secret) {
					secSelected = YES;
					break;
				}
			}
			if (secSelected) {
				menuItem.title = localized(@"SendPublicKeyToKeyserver_MenuItem");
			} else {
				menuItem.title = localized(@"SendToKeyserver_MenuItem");
			}
		}
		if (keys.count == 0) {
			return NO;
		}
		if (keys.count > 1 && !showExpertSettings) {
			return NO;
		}
		return YES;
	}
	else if (selector == @selector(exportKey:) ||
			 selector == @selector(exportCompact:) ||
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
			NSArray *userIDs = [self selectedObjectsOf:userIDsTable];
			if (userIDs.count != 1 || [userIDs[0] validity] >= GPGValidityInvalid) {
				return NO;
			}
		}
		NSArray *keys = self.selectedKeys;
		if (keys.count != 1 || [keys[0] validity] >= GPGValidityInvalid) {
			return NO;
		} else {
			return YES;
		}
	}
	else if (selector == @selector(removeUserID:)) {
		return [self selectedObjectsOf:userIDsTable].count == 1 && [userIDsController.arrangedObjects count] > 1;
	}
	else if (selector == @selector(revokeUserID:) || selector == @selector(setPrimaryUserID:)) {
		NSArray *objects = [self selectedObjectsOf:userIDsTable];
		if (objects.count != 1) {
			return NO;
		}
		GPGUserID *userID = objects[0];
		return userID.primaryKey.secret && !(userID.validity & GPGValidityRevoked);
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
		if (objects.count != 1) {
			return NO;
		}
		GPGKey *subkey = objects[0];
		return subkey.primaryKey.secret && !subkey.revoked;
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
	}
	else if (selector == @selector(sendKeysPerMail:)) {
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
	else if (selector == @selector(showKeyForSignature:)) {
		NSArray *signatures = [self selectedObjectsOf:signaturesTable];
		if (signatures.count != 1) {
			return NO;
		}
		GPGUserIDSignature *signature = signatures[0];
		if (!signature.primaryKey || [signature.primaryKey isEqual:[keysController selectedObjects][0]]) {
			return NO;
		}
		return YES;
	}
	else if (selector == @selector(receiveKeyForSignature:)) {
		NSArray *signatures = [self selectedObjectsOf:signaturesTable];
		return signatures.count == 1;
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
			if (name.length == 0) {
				name = email;
				email = nil;
			}
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
	
	NSString *button1, *button2, *cancelButton;
	if (defaultValue) {
		button1 = localized([string stringByAppendingString:@"_Yes"]);
		button2 = localized([string stringByAppendingString:@"_No"]);
		cancelButton = button2;
	} else {
		button1 = localized([string stringByAppendingString:@"_No"]);
		button2 = localized([string stringByAppendingString:@"_Yes"]);
		cancelButton = button1;
	}
	
	returnCode = [self.sheetController alertSheetForWindow:mainWindow
										  messageText:localized([string stringByAppendingString:@"_Title"])
											 infoText:message
										defaultButton:button1
									  alternateButton:button2
										  otherButton:nil
									suppressionButton:nil
										 cancelButton:cancelButton
											customize:nil];
	
	return (returnCode == (defaultValue ? NSAlertFirstButtonReturn : NSAlertSecondButtonReturn));
}

- (actionCallback)uploadCallbackForKey:(GPGKey *)key string:(NSString *)string {
	__block int64_t runningTasks = 2;
	__block BOOL keyExistsOnServer = NO;
	
	[self showProgressUntilKeyIsRefreshed:key];
	
	
	void (^uploadBlock)() = ^() {
		if (OSAtomicAdd64Barrier(-1, &runningTasks) == 0) {
			// Run this code when uploadBlock is called the second time.
			
			if ([self warningSheetWithDefault:keyExistsOnServer string:string]) {
				self.progressText = localizedStringWithFormat(@"SendKeysToServer_Progress", [self descriptionForKey:key]);
				self.errorText = localized(@"SendKeysToServer_Error");
				[gpgc sendKeysToServer:@[key]];
			}
		}
	};
	
	[gpgc keysExistOnServer:@[key] callback:^(NSArray *existingKeys, NSArray *nonExistingKeys) {
		keyExistsOnServer = existingKeys.count == 1;
		
		uploadBlock();
	}];
	
	actionCallback callback = ^(GPGController *gc, id value, NSDictionary *userInfo) {
		if (gc.error) {
			[self.sheetController endProgressSheet];
			return;
		}
		
		uploadBlock();
	};
	
	
	return [callback copy]; // Always copy blocks!
}


- (SheetController *)sheetController {
	return [SheetController sharedInstance];
}

#pragma mark Delegate
- (void)gpgControllerOperationDidStart:(GPGController *)gc {
	self.sheetController.progressText = self.progressText;
	[self.sheetController performSelectorOnMainThread:@selector(showProgressSheet) withObject:nil waitUntilDone:NO];
}

- (void)gpgController:(GPGController *)gc operationThrownException:(NSException *)e {
	gc.passphrase = nil;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		NSString *title, *message;
		GPGException *ex = nil;
		GPGTask *gpgTask = nil;
		NSDictionary *userInfo = gc.userInfo;
		
		
		NSLog(@"Exception: %@", e.description);
		
		[self cancelGPGOperation:nil];
		
		if ([e isKindOfClass:[GPGException class]]) {
			ex = (GPGException *)e;
			gpgTask = ex.gpgTask;
			if ((ex.errorCode & 0xFFFF) == GPGErrorCancelled) {
				return;
			}
			NSLog(@"Error text: %@\nStatus text: %@", gpgTask.errText, gpgTask.statusText);
		}
		
		
		if (![userInfo[dealsWithErrorsKey] boolValue]) {
			switch ([[userInfo objectForKey:@"operation"] integerValue]) {
				case ImportOperation:
					title = localized(@"ImportKeyError_Title");
					message = localized(@"ImportKeyError_Msg");
					break;
				default:
					title = self.errorText;
					message = [self errorMessageFromException:e gpgTask:gpgTask description:nil];
					break;
			}
			
			[self.sheetController errorSheetWithMessageText:title infoText:message];
		}
		
	});
}

- (void)gpgController:(GPGController *)gc operationDidFinishWithReturnValue:(id)value {
	gc.passphrase = nil;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		BOOL reEvaluate;
		
		__block BOOL ended = NO;
		void (^endProgressSheet)() = ^void() {
			if (ended == NO) {
				ended = YES;
				[self.sheetController endProgressSheet];
			}
		};
		
		do {
			reEvaluate = NO;
			
			NSMutableDictionary *oldUserInfo = [NSMutableDictionary dictionaryWithDictionary:gc.userInfo];
			
			gc.userInfo = nil;
			self.progressText = nil;
			self.errorText = nil;
			
			
			oldUserInfo[@"operation"] = @0;
			
			
			NSInteger actionCode = 0;
			NSArray *actions = [oldUserInfo objectForKey:@"action"];
			id action = nil;
			actionCallback callback = nil;
			
			if ([actions isKindOfClass:[NSArray class]]) {
				if (actions.count > 0) {
					action = actions[0];
					
					if (actions.count > 1) {
						NSArray *newActions = [actions subarrayWithRange:NSMakeRange(1, actions.count - 1)];
						NSMutableDictionary *tempUserInfo = oldUserInfo.mutableCopy;
						tempUserInfo[@"action"] = newActions;
						gc.userInfo = tempUserInfo;
					}
				}
			} else {
				action = actions;
			}
			
			if ([action isKindOfClass:NSClassFromString(@"NSBlock")]) {
				actionCode = CallbackAction;
				callback = action;
			} else {
				actionCode = [action integerValue];
			}
			
			
			switch (actionCode) {
				case CallbackAction: {
					endProgressSheet();
					callback(gc, value, oldUserInfo);
					break;
				}
				case ShowResultAction: {
					if (gc.error) break;
					
					NSDictionary *statusDict = gc.statusDict;
					if (statusDict) {
						[self refreshDisplayedKeys:self];
						
						NSSet *affectedkeys = nil;
						NSString *message = [self importResultWithStatusDict:statusDict affectedKeys:&affectedkeys];
						affectedkeys = [affectedkeys setByAddingObjectsFromSet:oldUserInfo[@"keys"]];
						[[KeychainController sharedInstance] keysDidChange:affectedkeys.allObjects];
						endProgressSheet();
						
						self.sheetController.msgText = message;
						self.sheetController.title = localized(@"KeySearch_ImportResults_Title");
						self.sheetController.sheetType = SheetTypeShowResult;
						[self.sheetController runModalForWindow:mainWindow];
						
						[[KeychainController sharedInstance] selectKeys:affectedkeys];
					}
					break;
				}
				case SaveDataToURLAction: { // Saves value to one or more files (@"URL"). You can specify @"hideExtension".
					endProgressSheet();
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
				default:
					break;
			}
			endProgressSheet();
			
		} while (reEvaluate);
		
		
	});
}


- (BOOL)popoverShouldClose:(NSPopover *)popover {
	return YES;
}

- (BOOL)menuButtonShouldShowMenu:(GKMenuButton *)menuButton {
	NSArray *keys = self.selectedKeys;
	if (keys.count == 1) {
		GPGKey *key = keys[0];
		if (key.secret && !key.photoID) {
			[self photoClicked:menuButton];
			return NO;
		}
	}
	return YES;
}

- (NSString *)errorMessageFromException:(NSException *)exception gpgTask:(GPGTask *)task description:(NSString *)description {
	NSString *message;
	
	if (task) {
		NSString *errText = task.errText;
		if (errText.length > 1000) {
			errText = [NSString stringWithFormat:@"%@\n…\n%@", [errText substringToIndex:400], [errText substringFromIndex:errText.length - 400]];
		}
		message = [NSString stringWithFormat:@"%@\nError text:\n%@", exception.description, errText];
	} else {
		message = exception.description;
	}
	if (description.length > 0) {
		message = [NSString stringWithFormat:@"%@\n\n%@\n%@", description, localized(@"Details:"), message];
	}

	return message;
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
		
		cancelCallbacks = [NSMutableDictionary new];
		
		if (NSAppKitVersionNumber >= NSAppKitVersionNumber10_9) {
			// Pasteboard check.
			generalPboard = [NSPasteboard generalPasteboard];
			
			pasteboardTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
			if (pasteboardTimer) {
				dispatch_source_set_timer(pasteboardTimer, dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), 1 * NSEC_PER_SEC, 0.8 * NSEC_PER_SEC);
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

