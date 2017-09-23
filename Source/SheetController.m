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

#import "SheetController.h"
#import <AddressBook/AddressBook.h>
#import "Globales.h"
#import "ActionController.h"
#import "GKAExtensions.h"
#import "AppDelegate.h"
#import <objc/runtime.h>
#import "Mail.h"


@interface SheetController ()
@property (weak) NSView *displayedView;
@property (assign) NSWindow *modalWindow;
@property (strong) NSArray *foundKeyDicts;
@property (strong) NSArray *URLs;
@property (nonatomic, strong) NSArray *volumes;
@property (nonatomic, strong) NSDictionary *result;
@property (nonatomic) BOOL enableOK;
@property (nonatomic) BOOL disableUserIDCommentsField;


- (void)runAndWait;
- (void)setStandardExpirationDates;
- (void)setDataFromAddressBook;
- (BOOL)checkName;
- (BOOL)checkEmail;
- (BOOL)checkComment;
- (BOOL)checkPassphrase;
- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (BOOL)generateFoundKeyDicts;
- (void)runSavePanel;
- (void)runOpenPanelWithAccessoryView:(NSView *)accessoryView;
@end

@interface NSSavePanel ()
- (void)setShowsTagField:(BOOL)flag;
@end



@implementation SheetController
@synthesize name, email, comment, passphrase, confirmPassphrase, pattern, title,
hasExpirationDate, localSig, allowEdit,
expirationDate, minExpirationDate, maxExpirationDate,
algorithmPreferences, keys, emailAddresses, secretKeys, availableLengths, allowedFileTypes,
sigType, length, sheetType, URL, URLs,
modalWindow, foundKeyDicts, hideExtension;




- (void)setProgressText:(NSString *)value {
	if (value == nil) {
		value = @"";
	}
	if (value != progressText) {
		progressText = value;
	}
}
- (NSString *)progressText {
	return progressText;
}

- (void)setMsgText:(NSString *)value {
	if (value == nil) {
		value = @"";
	}
	if (value != msgText) {
		msgText = value;
	}
}
- (NSString *)msgText {
	return msgText ? msgText : @"";
}


// Running sheets //
- (NSInteger)runModal {
	return [self runModalForWindow:mainWindow];
}
- (NSInteger)runModalForWindow:(NSWindow *)window {
	clickedButton = 0;
	self.modalWindow = window;
	
	switch (self.sheetType) {
		case SheetTypeNewKey:
			self.length = 4096;
			self.keyType = 1;
			self.expirationDate = nil;
			[self setStandardExpirationDates];
			[self setDataFromAddressBook];
			self.comment = @"";
			self.passphrase = @"";
			self.confirmPassphrase = @"";
			
			self.displayedView = _genNewKeyView;
			break;
		case SheetTypeSearchKeys:
			self.pattern = @"";
			
			self.displayedView = _searchKeysView;
			break;
		case SheetTypeReceiveKeys:
			self.pattern = @"";
			
			self.displayedView = _receiveKeysView;
			break;
		case SheetTypeShowResult:
			if (NSAppKitVersionNumber >= NSAppKitVersionNumber10_9) {
				NSAlert *alert = [NSAlert new];
				alert.messageText = self.title;
				alert.informativeText = self.msgText;
				[alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
					[NSApp stopModal];
				}];
				[NSApp runModalForWindow:window];
				return 0;
			} else {
				self.msgText = [NSString stringWithFormat:@"%@\n%@", self.title, self.msgText];
				self.displayedView = _resultView;
			}
			break;
		case SheetTypeShowFoundKeys:
			if ([self generateFoundKeyDicts]) {
				self.displayedView = _foundKeysView;
			} else {
				self.title = localized(@"KeySearch_NoKeysFound_Title");
				if (NSAppKitVersionNumber >= NSAppKitVersionNumber10_9) {
					NSAlert *alert = [NSAlert new];
					alert.messageText = self.title;
					[alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
						[NSApp stopModal];
					}];
					[NSApp runModalForWindow:window];
					return 0;
				} else {
					self.msgText = [NSString stringWithFormat:@"%@", self.title];
					self.displayedView = _resultView;
				}
			}
			break;
		case SheetTypeExpirationDate:
			[self setStandardExpirationDates];
			
			self.displayedView = _changeExpirationDateView;
			break;
		case SheetTypeAddUserID:
			if (showExpertSettings) {
				self.disableUserIDCommentsField = NO;
				self.generateUserID_CommentConstraint.priority = 999;
			} else {
				self.disableUserIDCommentsField = YES;
				self.generateUserID_CommentConstraint.priority = 1;
			}
			
			[self setDataFromAddressBook];
			self.comment = @"";
			
			self.displayedView = _generateUserIDView;
			break;
		case SheetTypeAddSubkey:
			self.length = 4096;
			self.keyType = 6;
			self.expirationDate = nil;
			[self setStandardExpirationDates];
			
			self.displayedView = _generateSubkeyView;
			break;
		case SheetTypeAddSignature:
			self.expirationDate = nil;
			[self setStandardExpirationDates];
			self.sigType = 0;
			self.localSig = NO;
			
			self.displayedView = _generateSignatureView;
			break;
		case SheetTypeSavePanel:
			[self runSavePanel];
			
			return clickedButton;
		case SheetTypeOpenPanel:
		case SheetTypeOpenPhotoPanel:
			[self runOpenPanelWithAccessoryView:nil];
			
			return clickedButton;
		case SheetTypeExportKey: {
			[self runSavePanel];
			
			return clickedButton; }
		case SheetTypeAlgorithmPreferences:
			self.displayedView = _editAlgorithmPreferencesView;
			break;
		case SheetTypeSelectVolume:
			[self prepareVolumeCollection];
			self.displayedView = _selectVolumeView;
			break;
		default:
			return -1;
	}
	[self runAndWait];
	self.displayedView = nil;
	return clickedButton;
}

- (void)errorSheetWithMessageText:(NSString *)messageText infoText:(NSString *)infoText {
	[self alertSheetForWindow:mainWindow messageText:messageText infoText:infoText defaultButton:nil alternateButton:nil otherButton:nil suppressionButton:nil];
}

- (NSInteger)alertSheetWithTitle:(NSString *)theTitle
						 message:(NSString *)message
				   defaultButton:(NSString *)button1
				 alternateButton:(NSString *)button2
					 otherButton:(NSString *)button3
			   suppressionButton:(NSString *)suppressionButton {
	return [self alertSheetForWindow:mainWindow
						 messageText:theTitle
							infoText:message
					   defaultButton:button1
					 alternateButton:button2
						 otherButton:button3
				   suppressionButton:suppressionButton
						   customize:nil];
}

- (NSInteger)alertSheetForWindow:(NSWindow *)window
					 messageText:(NSString *)messageText
						infoText:(NSString *)infoText
				   defaultButton:(NSString *)button1
				 alternateButton:(NSString *)button2
					 otherButton:(NSString *)button3
			   suppressionButton:(NSString *)suppressionButton {
	return [self alertSheetForWindow:window
						 messageText:messageText
							infoText:infoText
					   defaultButton:button1
					 alternateButton:button2
						 otherButton:button3
				   suppressionButton:suppressionButton
						   customize:nil];
}

- (NSInteger)alertSheetForWindow:(NSWindow *)window
					 messageText:(NSString *)messageText
						infoText:(NSString *)infoText
				   defaultButton:(NSString *)button1
				 alternateButton:(NSString *)button2
					 otherButton:(NSString *)button3
			   suppressionButton:(NSString *)suppressionButton
					   customize:(void (^)(NSAlert *))customize {
	return [self alertSheetForWindow:window
						 messageText:messageText
							infoText:infoText
					   defaultButton:button1
					 alternateButton:button2
						 otherButton:button3
				   suppressionButton:suppressionButton
						cancelButton:nil
						   customize:customize];
}


- (NSInteger)alertSheetForWindow:(NSWindow *)window
					 messageText:(NSString *)messageText
						infoText:(NSString *)infoText
				   defaultButton:(NSString *)button1
				 alternateButton:(NSString *)button2
					 otherButton:(NSString *)button3
			   suppressionButton:(NSString *)suppressionButton
					cancelButton:(NSString *)cancelButton
					   customize:(void (^)(NSAlert *))customize {
	
	if (![NSThread isMainThread]) {
		__block NSInteger returnValue;
		dispatch_sync(dispatch_get_main_queue(), ^{
			returnValue = [self alertSheetForWindow:window messageText:messageText infoText:infoText defaultButton:button1 alternateButton:button2 otherButton:button3 suppressionButton:suppressionButton];
		});
		return returnValue;
	}
	
	NSAlert *alert = [[NSAlert alloc] init];
	if (messageText) {
		alert.messageText = messageText;
	}
	if (infoText) {
		alert.informativeText = infoText;
	}
	if (button1) {
		[alert addButtonWithTitle:button1];
	}
	if (button2) {
		[alert addButtonWithTitle:button2];
	}
	if (button3) {
		[alert addButtonWithTitle:button3];
	}
	if (suppressionButton) {
		alert.showsSuppressionButton = YES;
		if ([suppressionButton length] > 0) {
			alert.suppressionButton.title = suppressionButton;
			alert.suppressionButton.state = NSOnState;
		}
	}
	
	
	NSInteger cancelButtonTag = 0;
	if (cancelButton) {
		if ([button1 isEqualToString:cancelButton]) {
			cancelButtonTag = NSAlertFirstButtonReturn;
		} else if ([button2 isEqualToString:cancelButton]) {
			cancelButtonTag = NSAlertSecondButtonReturn;
		} else if ([button3 isEqualToString:cancelButton]) {
			cancelButtonTag = NSAlertThirdButtonReturn;
		}
	} else if ([button1 isEqual:localized(@"Cancel")]) {
		cancelButtonTag = NSAlertFirstButtonReturn;
	}
	
	if (cancelButtonTag != 0) {
		// This is a hack to allow, to close the alert with the escape-key.
		[alert addButtonWithTitle:@"Cancel"]; // Add a cancel button. NSAlert sets the key equivalent automatically to esc.
		[alert layout]; // Layout the alert, so it's possible to manipulate the layout.

		NSButton *button = alert.buttons[alert.buttons.count - 1];
		
		// This button causes a "CGAffineTransformInvert: singular matrix." error in the log.
		// It's ugly but harmless and i don't know a better solution.
		button.bounds = NSMakeRect(-10, -10, 1, 1); // Hide the button.
		button.tag = cancelButtonTag; // Set the tag to mtach the real cancel button.
		button.refusesFirstResponder = YES;
	} else {
		[alert layout]; // Layout the alert, so it's possible to manipulate the layout.
	}
	
	if (customize) {
		customize(alert);
	}
	
	if (window && window.isVisible && [sheetLock tryLock]) {
		[alert beginSheetModalForWindow:window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
		[NSApp runModalForWindow:window];
		[sheetLock unlock];
	} else {
		clickedButton = [alert runModal];
	}
	
	if (alert.suppressionButton.state == NSOnState) {
		clickedButton = clickedButton | SheetSuppressionButton;
	}
	
	
	return clickedButton;
}

- (BOOL)showProgressSheet {
	BOOL result = NO;
	[progressSheetLock lock];
	if (numberOfProgressSheets == 0) { //Nur anzeigen wenn das progressSheet nicht bereits angezeigt wird.
		oldDisplayedView = displayedView; //displayedView sichern.
		self.displayedView = _progressView; //progressView anzeigen.
		if ([sheetLock tryLock]) { //Es wird kein anderes Sheet angezeigt.
			oldDisplayedView = nil;
			[NSApp beginSheet:_sheetWindow modalForWindow:mainWindow modalDelegate:nil didEndSelector:nil contextInfo:nil];
		}
		result = YES;
	}
	numberOfProgressSheets++;
	[progressSheetLock unlock];
	return result;
}
- (BOOL)endProgressSheet {
	BOOL result = NO;
	[progressSheetLock lock];
	numberOfProgressSheets--;
	if (numberOfProgressSheets == 0) { //Nur ausführen wenn das progressSheet angezeigt wird.
		if (oldDisplayedView) { //Soll ein zuvor angezeigtes Sheet wieder angezeigt werden?
			self.displayedView = oldDisplayedView; //Altes Sheet wieder anzeigen.
		} else {
			[NSApp endSheet:_sheetWindow]; //Sheet beenden...
			[_sheetWindow orderOut:self]; // und ausblenden.
			[sheetLock unlock];
		}
		result = YES;
	} else if (numberOfProgressSheets < 0) {
		numberOfProgressSheets = 0;
	}
	[progressSheetLock unlock];
	return result;
}

- (void)runSavePanel {
	NSString *filename;
	_pubFilename = nil;
	_secFilename = nil;
	
	self.exportSecretKey = NO;
	
	if (!self.pattern && self.keys) {
		NSString *secFilename = nil;
		filename = filenameForExportedKeys(self.keys, &secFilename);
		
		if (secFilename) {
			_secFilename = secFilename;
			_pubFilename = filename;
		}
	} else {
		filename = self.pattern ? self.pattern : @"";
	}
	
    // If the user is trying to export key,
    // and it is a key pair, display a checkbox to let the user choose
    // whether they want to export the secret key as well or not.
    __block NSView *accessoryView = nil;
    if(self.sheetType == SheetTypeExportKey) {
        [keys enumerateObjectsUsingBlock:^(GPGKey *key, NSUInteger idx, BOOL *stop) {
            if (key.secret) {
                accessoryView = _exportKeyOptionsView;
                *stop = YES;
            }
        }];
    }

	NSSavePanel *panel = [NSSavePanel savePanel];
	
	if ([panel respondsToSelector:@selector(setShowsTagField:)]) {
		[panel setShowsTagField:NO];
	}
	panel.delegate = self;
	panel.allowsOtherFileTypes = YES;
	panel.canSelectHiddenExtension = YES;
	panel.allowedFileTypes = self.allowedFileTypes;
	panel.nameFieldStringValue = filename;
	
	panel.accessoryView = accessoryView; //First the accessoryView is set...
	self.exportFormat = 1; //then exportFormat is set!
	
	panel.message = self.msgText ? self.msgText : @"";
	panel.title = self.title ? self.title : @"";
	
	
	[sheetLock lock];
	[panel beginSheetModalForWindow:modalWindow completionHandler:^(NSInteger result) {
		[NSApp stopModalWithCode:result];
	}];
	
	clickedButton = [NSApp runModalForWindow:modalWindow];
	[sheetLock unlock];
	
	self.URL = panel.URL;
	hideExtension = panel.isExtensionHidden;
}
- (void)runOpenPanelWithAccessoryView:(NSView *)accessoryView {
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	panel.delegate = self;
	panel.canChooseFiles = YES;
	panel.canChooseDirectories = NO;
	panel.allowsMultipleSelection = NO;
	
	panel.allowsOtherFileTypes = NO;
	panel.canSelectHiddenExtension = NO;
	panel.allowedFileTypes = self.allowedFileTypes;
	panel.nameFieldStringValue = self.pattern ? self.pattern : @"";
	panel.accessoryView = accessoryView;
	panel.message = self.msgText ? self.msgText : @"";
	panel.title = self.title ? self.title : @"";
	
	
	[sheetLock lock];
	[panel beginSheetModalForWindow:modalWindow completionHandler:^(NSInteger result) {
		[NSApp stopModalWithCode:result];
	}];
	
	clickedButton = [NSApp runModalForWindow:modalWindow];
	[sheetLock unlock];
	
	self.URL = panel.URL;
	self.URLs = panel.URLs;
}




// buttonClicked //
- (IBAction)buttonClicked:(NSButton *)sender {
	clickedButton = sender.tag;
	if (![_sheetWindow makeFirstResponder:_sheetWindow]) {
		[_sheetWindow endEditingFor:nil];
	}
	
	if (numberOfProgressSheets > 0) {
		[[ActionController sharedInstance] cancelGPGOperation:self];
	} else {
		if (clickedButton == NSOKButton) {
			switch (self.sheetType) {
				case SheetTypeNewKey:
					if (![self checkName]) return;
					if (![self checkEmail]) return;
					if (![self checkComment]) return;
					if (![self checkPassphrase]) return;
					break;
				case SheetTypeReceiveKeys: {
					NSSet *keyIDs = [self.pattern keyIDs];
					if (keyIDs.count == 0) {
						NSRunAlertPanel(localized(@"Error"), localized(@"CheckError_NoKeyID"), nil, nil, nil);
						return;
					}
					
					break;
				}
				case SheetTypeShowFoundKeys: {
					NSMutableArray *selectedKeys = [NSMutableArray arrayWithCapacity:[keys count]];
					for (NSDictionary *keyDict in self.foundKeyDicts) {
						if ([[keyDict objectForKey:@"selected"] boolValue]) {
							[selectedKeys addObject:[keyDict objectForKey:@"key"]];
						}
					}
					self.keys = selectedKeys;
					break;
				}
				case SheetTypeAddUserID:
					if (![self checkName]) return;
					if (![self checkEmail]) return;
					if (![self checkComment]) return;
					break;
				case SheetTypeSelectVolume: {
					NSUInteger index = self.selectedVolumeIndexes.firstIndex;
					if (index < self.volumes.count) {
						self.result = self.volumes[index];
						self.URL = self.volumes[index][@"url"];
					} else {
						self.result = nil;
					}
					break; }
			}
		} else { // NSCancelButton
			self.result = nil;
		}
		
		[NSApp stopModal];
	}
}


- (IBAction)advancedButton:(NSButton *)sender {
	[self showAdvanced:sender.state == NSOnState animate:YES];
}


// Propertys //
- (NSInteger)keyType {
	return keyType;
}
- (void)setKeyType:(NSInteger)value {
	keyType = value;
	if (value == 2 || value == 3) {
		_keyLengthFormatter.minKeyLength = 2048;
		_keyLengthFormatter.maxKeyLength = 3072;
		self.length = [_keyLengthFormatter checkedValue:length];
		self.availableLengths = [NSArray arrayWithObjects:@"2048", @"3072", nil];
	} else {
		_keyLengthFormatter.minKeyLength = 2048;
		_keyLengthFormatter.maxKeyLength = 4096;
		self.length = [_keyLengthFormatter checkedValue:length];
		self.availableLengths = [NSArray arrayWithObjects:@"2048", @"3072", @"4096", nil];
	}
}

- (NSInteger)daysToExpire {
	return self.hasExpirationDate ? [self.expirationDate daysSinceNow] : 0;
}
- (GPGKey *)secretKey {
	return [[_secretKeysController selectedObjects] objectAtIndex:0];
}
- (void)setSecretKey:(GPGKey *)value {
	[_secretKeysController setSelectedObjects:[NSArray arrayWithObject:value]];
}

- (NSIndexSet *)selectedVolumeIndexes {
	return selectedVolumeIndexes;
}
- (void)setSelectedVolumeIndexes:(NSIndexSet *)value {
	if (value.count > 0) {
		self.enableOK = (value.firstIndex != oldVolumeIndex);
		selectedVolumeIndexes = value;
	}
}

- (BOOL)showAlgorithmPrefsDropdown {
	return self.algorithmPreferences.count > 1;
}
+ (NSSet *)keyPathsForValuesAffectingShowAlgorithmPrefsDropdown {
	return [NSSet setWithObjects:@"algorithmPreferences", nil];
}



// Internal methods //
- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	clickedButton = returnCode;
	[NSApp stopModal];
}

- (BOOL)generateFoundKeyDicts {
	NSMutableArray *dicts = [NSMutableArray arrayWithCapacity:keys.count];
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
	
	GPGKeyAlgorithmNameTransformer *algorithmNameTransformer = [GPGKeyAlgorithmNameTransformer new];
	NSArray *gpgtoolsKeys = @[@"85E38F69046B44C1EC9FB07B76D78F0500D026C4"/*Team*/,
							  @"55AB1B128F18E135A522A12DDD1C907A50FE9D32"/*Alex*/,
							  @"608B00ABE1DAA3501C5FF91AE58271326F9F4937"/*Luke*/,
							  @"BDA498EAC51993F2FC97DAB2DA870C1346A957B0"/*Mento*/,
							  @"8C371C40B31DA620815E01A9779FEB1392CBBADF"/*Steve*/];
	BOOL showInvalidKeys = [[GPGOptions sharedOptions] boolForKey:@"KeyserverShowInvalidKeys"];
	
	NSDate *now = [NSDate date];
	
	
	for (GPGRemoteKey *key in keys) {
		NSDictionary *stringAttributes = nil;
		
		BOOL isGpgtoolsKey = [key respondsToSelector:@selector(fingerprint)] && [gpgtoolsKeys containsObject:key.fingerprint];
		NSNumber *selected = @NO;
		
		if (key.expired || key.revoked || [key.expirationDate compare:now] == NSOrderedAscending) {
			if (!showInvalidKeys) {
				continue;
			}
			stringAttributes = [NSDictionary dictionaryWithObject:[NSColor redColor] forKey:NSForegroundColorAttributeName];
		} else if (isGpgtoolsKey) {
			selected = @YES;
		}
				
		
		NSString *tempDescription = [NSString stringWithFormat:localized(@"FOUND_KEY_DESCRIPTION_FORMAT"),
									 key.keyID,
									 [algorithmNameTransformer transformedIntegerValue:key.algorithm],
									 key.length,
									 [dateFormatter stringFromDate:key.creationDate]];
		
		NSMutableAttributedString *description = [[NSMutableAttributedString alloc] initWithString:tempDescription attributes:stringAttributes];
		
		for (GPGRemoteUserID *userID in key.userIDs) {
			[description appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"\n	%@", userID.userIDDescription]]];
		}
		
		[dicts addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:description, @"description", selected, @"selected", [NSNumber numberWithUnsignedInteger:[key.userIDs count] + 1], @"lines", key, @"key", @(isGpgtoolsKey), @"gpgtools", nil]];
	}
	
	
	
	[dicts sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
		GPGRemoteKey *key1 = obj1[@"key"];
		GPGRemoteKey *key2 = obj2[@"key"];
		
		if (key1.revoked && !key2.revoked) {
			return NSOrderedDescending;
		} else if (!key1.revoked && key2.revoked) {
			return NSOrderedAscending;
		}
		
		BOOL isGpgtools1 = [obj1[@"gpgtools"] boolValue];
		BOOL isGpgtools2 = [obj2[@"gpgtools"] boolValue];
		
		if (isGpgtools1 && !isGpgtools2) {
			return NSOrderedAscending;
		} else if (!isGpgtools1 && isGpgtools2) {
			return NSOrderedDescending;
		}
		
		return 0 - [key1.creationDate compare:key2.creationDate];
	}];
	
	if (dicts.count) {
		dicts[0][@"selected"] = @YES;
	}
	
	self.foundKeyDicts = dicts;
	return dicts.count > 0;
}

- (void)setStandardExpirationDates {
	//Setzt minExpirationDate einen Tag in die Zukunft.
	//Setzt maxExpirationDate 500 Jahre in die Zukunft.
	//Setzt expirationDate 4 Jahre in die Zukunft.
	
	NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDate *curDate = [NSDate date];
	
	[dateComponents setDay:1];
	self.minExpirationDate = [calendar dateByAddingComponents:dateComponents toDate:curDate options:0];
	[dateComponents setDay:0];
	
	[dateComponents setYear:500];
	self.maxExpirationDate = [calendar dateByAddingComponents:dateComponents toDate:curDate options:0];
	
	if (self.expirationDate) {
		self.minExpirationDate = [self.minExpirationDate earlierDate:self.expirationDate];
		self.maxExpirationDate = [self.maxExpirationDate laterDate:self.expirationDate];
		self.hasExpirationDate = YES;
	} else {
		[dateComponents setYear:4];
		self.expirationDate = [calendar dateByAddingComponents:dateComponents toDate:curDate options:0];
		self.hasExpirationDate = YES;
	}
}
- (void)setDataFromAddressBook {
	@autoreleasepool {
		NSString *userName = nil;
		NSMutableSet *mailAddresses = [NSMutableSet new];
		
		
		// Get name and email-addresses from Mail via Accounts.plist.
		@try {
			NSString *path = [NSHomeDirectory() stringByAppendingString:@"/Library/Mail/V2/MailData/Accounts.plist"];
			NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:path];
			
			NSArray *mailAccounts = [plist objectForKey:@"MailAccounts"];
			
			for (NSDictionary *account in mailAccounts) {
				[mailAddresses addObjectsFromArray:[account objectForKey:@"EmailAddresses"]];
				if (userName.length == 0) {
					userName = [account objectForKey:@"FullUserName"];
				}
			}
			
		} @catch (id e) {}
		
		// Get name and email-addresses from Mail via ScriptingBridge.
		@try {
			MailApplication *mail = [SBApplication applicationWithBundleIdentifier:@"com.apple.Mail"];
			if (mail.running) {
				SBElementArray *accounts = [mail accounts];
				for (MailAccount *account in accounts) {
					[mailAddresses addObjectsFromArray:account.emailAddresses];
					if (userName.length == 0) {
						userName = account.fullName;
					}
				}
			}
		} @catch (id e) {}
		
		
		NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:@"description" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
		NSArray *sortedAddresses = [mailAddresses sortedArrayUsingDescriptors:@[descriptor]];
		self.emailAddresses = sortedAddresses;
		
		if (sortedAddresses.count > 0) {
			self.email = sortedAddresses[0];
		} else {
			self.email = @"";
		}
		
		self.name = userName ? userName : @"";

	}
}

- (void)runAndWait {
	[sheetLock lock];
	GPGDebugLog(@"SheetController runAndWait. modalWindow = '%@', sheetWindow = '%@'", modalWindow, _sheetWindow);
	
	if (modalWindow.isVisible) {
		[NSApp beginSheet:_sheetWindow modalForWindow:modalWindow modalDelegate:nil didEndSelector:nil contextInfo:nil];
		[NSApp runModalForWindow:_sheetWindow];
		[NSApp endSheet:_sheetWindow];
	} else {
		[_sheetWindow makeKeyAndOrderFront:self];
		[NSApp runModalForWindow:_sheetWindow];
	}
	[_sheetWindow orderOut:self];
	[sheetLock unlock];
}

- (void)showAdvanced:(BOOL)show animate:(BOOL)animate {
	static NSUInteger fullHeight = 0;
	NSLayoutConstraint *constraint;
	
	[NSAnimationContext beginGrouping];

	if (show) {
		[[NSAnimationContext currentContext] setCompletionHandler:^{
			[self.sheetWindow recalculateKeyViewLoop];
		}];
	}

	
	if (animate) {
		constraint = self.genNewKey_advancedConstraint.animator;
	} else {
		constraint = self.genNewKey_advancedConstraint;
	}
	
	if (fullHeight == 0) {
		fullHeight = constraint.constant;
	}
	
	if (show == NO) {
		[self.sheetWindow endEditingFor:nil];
	}
	
	constraint.constant = show ? fullHeight : 0;
	
	for (NSControl *subview in self.genNewKey_advancedSubview.subviews) {
		if ([subview respondsToSelector:@selector(setEnabled:)]) {
			subview.enabled = show;
		}
	}
	[NSAnimationContext endGrouping];
}


- (void)prepareVolumeCollection {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *resKeys = @[NSURLVolumeIsLocalKey, NSURLVolumeIsInternalKey, NSURLVolumeIsReadOnlyKey, NSURLVolumeIsBrowsableKey, NSURLVolumeNameKey, NSURLVolumeUUIDStringKey, NSURLEffectiveIconKey];
	NSArray *urls = [fileManager mountedVolumeURLsIncludingResourceValuesForKeys:resKeys options:NSVolumeEnumerationSkipHiddenVolumes];
	NSMutableArray *volumeList = [NSMutableArray array];
	NSUInteger index = NSNotFound;
	
	for (NSURL *url in urls) {
		NSDictionary *values = [url resourceValuesForKeys:resKeys error:nil];
		BOOL isDefault = [url.path isEqualToString:@"/"];
		if (!isDefault && (![values[NSURLVolumeIsBrowsableKey] boolValue] || ![values[NSURLVolumeIsLocalKey] boolValue] || [values[NSURLVolumeIsReadOnlyKey] boolValue] || [values[NSURLVolumeIsInternalKey] boolValue])) {
			continue;
		}
		
		if ([self.URL isEqualTo:url]) {
			index = volumeList.count;
		}
		
		NSDictionary *volume = @{@"image": values[NSURLEffectiveIconKey],
								 @"name": isDefault ? localized(@"Local") : values[NSURLVolumeNameKey],
								 @"UUID": values[NSURLVolumeUUIDStringKey],
								 @"url": url};
		
		[volumeList addObject:volume];
	}
	
	if (index == NSNotFound) {
		index = volumeList.count;
		NSImage *image = [[NSWorkspace sharedWorkspace] iconForFile:[self.URL.path stringByDeletingLastPathComponent]];
		[image setSize:NSMakeSize(64, 64)];
		
		NSDictionary *volume = [NSDictionary dictionaryWithObjectsAndKeys:self.URL, @"url", self.URL.path.lastPathComponent, @"name", image, @"image", nil];
		[volumeList addObject:volume];
	}
	
	oldVolumeIndex = index;
	
	self.volumes = volumeList;
	self.selectedVolumeIndexes = [NSIndexSet indexSetWithIndex:index];
	
	
	self.msgText = [NSString stringWithFormat:localized(@"MoveSecring_Msg"), volumeList[index][@"name"]];
}



// Checks //
- (BOOL)checkName {
	self.name = [self.name stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\t "]];

	if (self.name.length == 0) {
		return YES;
	}
	if (self.name.length > 500) {
		NSRunAlertPanel(localized(@"Error"), localized(@"CheckError_NameToLong"), nil, nil, nil);
		return NO;
	}
	if ([self.name rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]].length != 0) {
		NSRunAlertPanel(localized(@"Error"), localized(@"CheckError_InvalidCharInName"), nil, nil, nil);
		return NO;
	}
	return YES;
}
- (BOOL)checkEmail {
	{
		if (!self.email) {
			self.email = @"";
		}
		
		if (self.name.length > 0 && self.email.length == 0) {
			return YES;
		}
		if ([self.email length] > 254) {
			NSRunAlertPanel(localized(@"Error"), localized(@"CheckError_EmailToLong"), nil, nil, nil);
			return NO;
		}
		if ([self.email length] < 4) {
			goto emailIsInvalid;
		}
		if ([self.email hasPrefix:@"@"] || [self.email hasSuffix:@"@"] || [self.email hasSuffix:@"."]) {
			goto emailIsInvalid;
		}
		NSArray *components = [self.email componentsSeparatedByString:@"@"];
		if ([components count] != 2) {
			goto emailIsInvalid;
		}
		if ([(NSString *)[components objectAtIndex:0] length] > 64) {
			goto emailIsInvalid;
		}
		
		NSMutableCharacterSet *charSet = [NSMutableCharacterSet characterSetWithRange:(NSRange){128, 65408}];
		[charSet addCharactersInString:@"01234567890_-+.!#$%&'*/=?^`{|}~abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"];
		[charSet invert];
		
		if ([[components objectAtIndex:0] rangeOfCharacterFromSet:charSet].length != 0) {
			goto emailIsInvalid;
		}
		[charSet addCharactersInString:@"+!#$%&'*/=?^`{|}~"];
		if ([[components objectAtIndex:1] rangeOfCharacterFromSet:charSet].length != 0) {
			goto emailIsInvalid;
		}
		
		if ([self.email rangeOfString:@"@gpgtools.org"].length > 0) {
			if ([[[GPGOptions sharedOptions] valueInCommonDefaultsForKey:@"GPGToolsTeamMember"] boolValue] == NO) {
				goto emailIsInvalid;
			}
		}
		
		return YES;
		
	}
emailIsInvalid: //Hierher wird gesprungen, wenn die E-Mail-Adresse ungültig ist und nicht eine spezielle Meldung ausgegeben werden soll.
	NSRunAlertPanel(localized(@"Error"), localized(@"CheckError_InvalidEmail"), nil, nil, nil);
	return NO;
}
- (BOOL)checkComment {
	if (!self.comment) {
		self.comment = @"";
		return YES;
	}
	if ([self.comment length] == 0) {
		return YES;
	}
	if ([self.comment length] > 500) {
		NSRunAlertPanel(localized(@"Error"), localized(@"CheckError_CommentToLong"), nil, nil, nil);
		return NO;
	}
	if ([self.comment rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"()"]].length != 0) {
		NSRunAlertPanel(localized(@"Error"), localized(@"CheckError_InvalidCharInComment"), nil, nil, nil);
		return NO;
	}
	return YES;
}
- (BOOL)checkPassphrase {
	if (!self.passphrase) {
		self.passphrase = @"";
	}
	if (!self.confirmPassphrase) {
		self.confirmPassphrase = @"";
	}
	if (![self.passphrase isEqualToString:self.confirmPassphrase]) {
		NSRunAlertPanel(localized(@"Error"), localized(@"CheckError_PassphraseMissmatch"), nil, nil, nil);
		return NO;
	}
	
	if ([self.passphrase length] == 0) {
		if (NSRunAlertPanel(localized(@"CheckAlert_NoPassphrase_Title"),
							localized(@"CheckAlert_NoPassphrase_Message"),
							localized(@"CheckAlert_NoPassphrase_Button1"),
							localized(@"CheckAlert_NoPassphrase_Button2"), nil) != NSAlertDefaultReturn) {
			return NO;
		}
	} else {
		if ([self.passphrase length] < 8) {
			if (NSRunAlertPanel(localized(@"CheckAlert_PassphraseShort_Title"),
								localized(@"CheckAlert_PassphraseShort_Message"),
								localized(@"CheckAlert_PassphraseShort_Button1"),
								localized(@"CheckAlert_PassphraseShort_Button2"), nil) != NSAlertDefaultReturn) {
				return NO;
			}
		}
		if ([self.passphrase rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet]].length == 0 ||
			[self.passphrase rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]].length == 0 ||
			[self.passphrase rangeOfCharacterFromSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]].length == 0 ) {
			if (NSRunAlertPanel(localized(@"CheckAlert_PassphraseSimple_Title"),
								localized(@"CheckAlert_PassphraseSimple_Message"),
								localized(@"CheckAlert_PassphraseSimple_Button1"),
								localized(@"CheckAlert_PassphraseSimple_Button2"), nil) != NSAlertDefaultReturn) {
				return NO;
			}
		}
	}
	/*
	 * For the max password length, look in gnupg/agent/genkey.c "agent_ask_new_passphrase" for the pinentry_loopback call.
	 */
	if (self.passphrase.length > 100) {
		NSRunAlertPanel(localized(@"CheckAlert_PassphraseTooLong_Title"), localized(@"CheckAlert_PassphraseTooLong_Message"), nil, nil, nil);
		return NO;
	}
	
	return YES;
}




- (NSView *)displayedView {
	return displayedView;
}
- (void)setDisplayedView:(NSView *)value {
	if (displayedView != value) {
		if (displayedView == _progressView) {
			[_progressIndicator stopAnimation:nil];
		}
		
		//[displayedView removeFromSuperview];
		//displayedView = value;
		if (value != nil) {
			[_sheetWindow setContentView:value];
			
			static BOOL	newKeyViewInitialized = NO;
			if (!newKeyViewInitialized && value == _genNewKeyView) {
				[self showAdvanced:NO animate:NO];
				newKeyViewInitialized = YES;
			}
			
			
			if ([value nextKeyView]) {
				[_sheetWindow makeFirstResponder:[value nextKeyView]];
			}
			
			if (value == _progressView) {
				[_progressIndicator startAnimation:nil];
			}
		}
	}
}

- (NSInteger)exportFormat {
	return exportFormat;
}
- (void)setExportFormat:(NSInteger)value {
	exportFormat = value;
	NSArray *extensions;
	switch (value) {
		case 1:
			extensions = [NSArray arrayWithObjects:@"asc", @"gpg", @"pgp", @"key", @"gpgkey", @"txt", nil];
			break;
		default:
			extensions = [NSArray arrayWithObjects:@"gpg", @"asc", @"pgp", @"key", @"gpgkey", @"txt", nil];
			break;
	}
	[(NSSavePanel *)[_exportKeyOptionsView window] setAllowedFileTypes:extensions];
}
- (BOOL)exportSecretKey {
	return exportSecretKey;
}
- (void)setExportSecretKey:(BOOL)value {
	exportSecretKey = value;
	
	NSSavePanel *panel = (id)_exportKeyOptionsView.window;
	NSString *filename = panel.nameFieldStringValue;
	
	if ([_pubFilename isEqualToString:filename] || [_secFilename isEqualToString:filename]) {
		panel.nameFieldStringValue = exportSecretKey ? _secFilename : _pubFilename;
	}
}




// NSTableView delegate.
- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
	NSDictionary *foundKey = [[_foundKeysController arrangedObjects] objectAtIndex:row];
	return [[foundKey objectForKey:@"lines"] integerValue] * [tableView rowHeight] + 1;
}
- (BOOL)tableView:(NSTableView *)tableView shouldTypeSelectForEvent:(NSEvent *)event withCurrentSearchString:(NSString *)searchString {
	if ([event type] == NSKeyDown && [event keyCode] == 49) { //Leertaste gedrückt
		NSArray *selectedKeys = [_foundKeysController selectedObjects];
		if ([selectedKeys count] > 0) {
			NSNumber *selected = [NSNumber numberWithBool:![[[selectedKeys objectAtIndex:0] objectForKey:@"selected"] boolValue]];
			for (NSMutableDictionary *foundKey in [_foundKeysController selectedObjects]) {
				[foundKey setObject:selected forKey:@"selected"];
			}
		}
	}
	return NO;
}


// NSTokenFieldDelegate
- (NSArray *)tokenField:(NSTokenField *)tokenField shouldAddObjects:(NSArray *)tokens atIndex:(NSUInteger)index {
	NSMutableArray *newTokens = [NSMutableArray arrayWithCapacity:[tokens count]];
	
	NSString *tokenPrefix;
	switch ([tokenField tag]) {
		case 1:
			tokenPrefix = @"S";
			break;
		case 2:
			tokenPrefix = @"H";
			break;
		case 3:
			tokenPrefix = @"Z";
			break;
		default:
			return newTokens;
	}
	
	for (NSString *token in tokens) {
		if ([token hasPrefix:tokenPrefix]) {
			[newTokens addObject:token];
		}
	}
	return newTokens;
}
- (id)tokenField:(NSTokenField *)tokenField representedObjectForEditingString:(NSString *)editingString {
	static NSDictionary *algorithmIdentifiers = nil;
	if (!algorithmIdentifiers) {
		algorithmIdentifiers = [[NSDictionary alloc] initWithObjectsAndKeys:@"S0", localized(@"CIPHER_ALGO_NONE"),
								@"S1", localized(@"CIPHER_ALGO_IDEA"),
								@"S2", localized(@"CIPHER_ALGO_3DES"),
								@"S3", localized(@"CIPHER_ALGO_CAST5"),
								@"S4", localized(@"CIPHER_ALGO_BLOWFISH"),
								@"S7", localized(@"CIPHER_ALGO_AES"),
								@"S8", localized(@"CIPHER_ALGO_AES192"),
								@"S9", localized(@"CIPHER_ALGO_AES256"),
								@"S10", localized(@"CIPHER_ALGO_TWOFISH"),
								@"S11", localized(@"CIPHER_ALGO_CAMELLIA128"),
								@"S12", localized(@"CIPHER_ALGO_CAMELLIA192"),
								@"S13", localized(@"CIPHER_ALGO_CAMELLIA256"),
								@"H1", localized(@"DIGEST_ALGO_MD5"),
								@"H2", localized(@"DIGEST_ALGO_SHA1"),
								@"H3", localized(@"DIGEST_ALGO_RMD160"),
								@"H8", localized(@"DIGEST_ALGO_SHA256"),
								@"H9", localized(@"DIGEST_ALGO_SHA384"),
								@"H10", localized(@"DIGEST_ALGO_SHA512"),
								@"H11", localized(@"DIGEST_ALGO_SHA224"),
								@"Z0", localized(@"COMPRESS_ALGO_NONE"),
								@"Z1", localized(@"COMPRESS_ALGO_ZIP"),
								@"Z2", localized(@"COMPRESS_ALGO_ZLIB"),
								@"Z3", localized(@"COMPRESS_ALGO_BZIP2"), nil];
	}
	NSString *algorithmIdentifier = [algorithmIdentifiers objectForKey:[editingString uppercaseString]];
	if (!algorithmIdentifier) {
		algorithmIdentifier = editingString;
	}
	return [algorithmIdentifier uppercaseString];
}
- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject {
	static NSDictionary *algorithmNames = nil;
	if (!algorithmNames) {
		algorithmNames = [[NSDictionary alloc] initWithObjectsAndKeys:localized(@"CIPHER_ALGO_NONE"), @"S0",
						  localized(@"CIPHER_ALGO_IDEA"), @"S1",
						  localized(@"CIPHER_ALGO_3DES"), @"S2",
						  localized(@"CIPHER_ALGO_CAST5"), @"S3",
						  localized(@"CIPHER_ALGO_BLOWFISH"), @"S4",
						  localized(@"CIPHER_ALGO_AES"), @"S7",
						  localized(@"CIPHER_ALGO_AES192"), @"S8",
						  localized(@"CIPHER_ALGO_AES256"), @"S9",
						  localized(@"CIPHER_ALGO_TWOFISH"), @"S10",
						  localized(@"CIPHER_ALGO_CAMELLIA128"), @"S11",
						  localized(@"CIPHER_ALGO_CAMELLIA192"), @"S12",
						  localized(@"CIPHER_ALGO_CAMELLIA256"), @"S13",
						  localized(@"DIGEST_ALGO_MD5"), @"H1",
						  localized(@"DIGEST_ALGO_SHA1"), @"H2",
						  localized(@"DIGEST_ALGO_RMD160"), @"H3",
						  localized(@"DIGEST_ALGO_SHA256"), @"H8",
						  localized(@"DIGEST_ALGO_SHA384"), @"H9",
						  localized(@"DIGEST_ALGO_SHA512"), @"H10",
						  localized(@"DIGEST_ALGO_SHA224"), @"H11",
						  localized(@"COMPRESS_ALGO_NONE"), @"Z0",
						  localized(@"COMPRESS_ALGO_ZIP"), @"Z1",
						  localized(@"COMPRESS_ALGO_ZLIB"), @"Z2",
						  localized(@"COMPRESS_ALGO_BZIP2"), @"Z3", nil];
	}
	NSString *displayString = [algorithmNames objectForKey:[representedObject description]];
	if (!displayString) {
		displayString = [representedObject description];
	}
	return displayString;
}



// Singleton: alloc, init etc.
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
		
		sheetLock = [NSLock new];
		progressSheetLock = [NSLock new];
		NSArray *objects;
		[[NSBundle mainBundle] loadNibNamed:@"ModalSheets" owner:self topLevelObjects:&objects];
		topLevelObjects = objects;
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




@implementation KeyLengthFormatter
@synthesize minKeyLength, maxKeyLength;

- (NSString*)stringForObjectValue:(id)obj {
	return [obj description];
}

- (NSInteger)checkedValue:(NSInteger)value {
	if (value < minKeyLength) {
		value = minKeyLength;
	}
	if (value > maxKeyLength) {
		value = maxKeyLength;
	}
	return value;
}

- (BOOL)getObjectValue:(id*)obj forString:(NSString*)string errorDescription:(NSString**)error {
	*obj = [NSString stringWithFormat:@"%li", (long)[self checkedValue:[string integerValue]]];
	return YES;
}

- (BOOL)isPartialStringValid:(NSString*)partialString newEditingString:(NSString**) newString errorDescription:(NSString**)error {
	if ([partialString rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet] options: NSLiteralSearch].length == 0) {
		return YES;
	} else {
		return NO;
	}
}

@end


@implementation GKSheetWindow
- (void)setContentView:(NSView *)aView {
	if (aView != self.contentView || YES) {
		[super setContentView:nil];
		
		NSRect oldRect, newRect;
		oldRect = [self contentRectForFrameRect:[self frame]];
		
		newRect.size = [aView frame].size;
		newRect.origin.x = oldRect.origin.x + (oldRect.size.width - newRect.size.width) / 2;
		newRect.origin.y = oldRect.origin.y + oldRect.size.height - newRect.size.height;
		
		newRect = [self frameRectForContentRect:newRect];
		[self setFrame:newRect display:YES animate:YES];
		
		[super setContentView:aView];
	}
}
@end





