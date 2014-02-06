/*
 Copyright © Roman Zechmeister, 2013
 
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

#import "SheetController.h"
#import <AddressBook/AddressBook.h>
#import "Globales.h"
#import "ActionController.h"


@interface SheetController ()
@property (assign) NSView *displayedView;
@property (assign) NSWindow *modalWindow;
@property (retain) NSArray *foundKeyDicts;
@property (retain) NSURL *URL;
@property (retain) NSArray *URLs;
- (void)runAndWait;
- (void)setStandardExpirationDates;
- (void)setDataFromAddressBook;
- (BOOL)checkName;
- (BOOL)checkEmailMustSet:(BOOL)mustSet;
- (BOOL)checkComment;
- (BOOL)checkPassphrase;
- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)generateFoundKeyDicts;
- (void)runSavePanelWithaccessoryView:(NSView *)accessoryView;
- (void)runOpenPanelWithaccessoryView:(NSView *)accessoryView;
@end


@implementation SheetController
@synthesize progressText, msgText, name, email, comment, passphrase, confirmPassphrase, pattern, title,
	hasExpirationDate, allowSecretKeyExport, localSig, allowEdit, autoUpload,
	expirationDate, minExpirationDate, maxExpirationDate,
	algorithmPreferences, keys, emailAddresses, secretKeys, availableLengths, allowedFileTypes,
	sigType, length, sheetType, URL, URLs,
	modalWindow, foundKeyDicts;



// Running sheets //
- (NSInteger)runModal {
	return [self runModalForWindow:mainWindow];
}
- (NSInteger)runModalForWindow:(NSWindow *)window {
	clickedButton = 0;
	self.modalWindow = window;
	
	switch (self.sheetType) {
		case SheetTypeNewKey:
			self.length = 2048;
			self.keyType = 1;
			self.expirationDate = nil;
			[self setStandardExpirationDates];
			[self setDataFromAddressBook];
			self.comment = @"";
			self.passphrase = @"";
			self.confirmPassphrase = @"";
			
			self.displayedView = newKeyView;
			break;
		case SheetTypeSearchKeys:
			self.pattern = @"";
			
			self.displayedView = searchKeysView;
			break;
		case SheetTypeReceiveKeys:
			self.pattern = @"";
			
			self.displayedView = receiveKeysView;
			break;
		case SheetTypeShowResult:
			self.displayedView = resultView;
			break;
		case SheetTypeShowFoundKeys:
			[self generateFoundKeyDicts];
			
			self.displayedView = foundKeysView;
			break;
		case SheetTypeExpirationDate:
			[self setStandardExpirationDates];

			self.displayedView = changeExpirationDateView;
			break;
		case SheetTypeAddUserID:
			[self setDataFromAddressBook];
			self.comment = @"";
			
			self.displayedView = generateUserIDView;
			break;
		case SheetTypeAddSubkey:
			self.length = 2048;
			self.keyType = 6;
			self.expirationDate = nil;
			[self setStandardExpirationDates];

			self.displayedView = generateSubkeyView;
			break;
		case SheetTypeAddSignature:
			self.expirationDate = nil;
			[self setStandardExpirationDates];
			self.sigType = 0;
			self.localSig = NO;
			
			self.displayedView = generateSignatureView;
			break;
		case SheetTypeSavePanel:
			[self runSavePanelWithaccessoryView:nil];
			
			return clickedButton;
		case SheetTypeOpenPanel:
		case SheetTypeOpenPhotoPanel:
			[self runOpenPanelWithaccessoryView:nil];
			
			return clickedButton;
		case SheetTypeExportKey:
			[self runSavePanelWithaccessoryView:exportKeyOptionsView];
			
			return clickedButton;
		case SheetTypeAlgorithmPreferences:
			self.displayedView = editAlgorithmPreferencesView;
			break;
		default:
			return -1;
	}
	[self runAndWait];
	self.displayedView = nil;
	return clickedButton;
}

- (void)errorSheetWithmessageText:(NSString *)messageText infoText:(NSString *)infoText {
	[self alertSheetForWindow:nil messageText:messageText infoText:infoText defaultButton:nil alternateButton:nil otherButton:nil suppressionButton:nil];
}

- (NSInteger)alertSheetForWindow:(NSWindow *)window messageText:(NSString *)messageText infoText:(NSString *)infoText defaultButton:(NSString *)button1 alternateButton:(NSString *)button2 otherButton:(NSString *)button3 suppressionButton:(NSString *)suppressionButton {
	if (![NSThread isMainThread]) {
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:_cmd]];
		invocation.selector = _cmd;
		invocation.target = self;
		[invocation setArgument:&window atIndex:2];
		[invocation setArgument:&messageText atIndex:3];
		[invocation setArgument:&infoText atIndex:4];
		[invocation setArgument:&button1 atIndex:5];
		[invocation setArgument:&button2 atIndex:6];
		[invocation setArgument:&button3 atIndex:7];
		[invocation setArgument:&suppressionButton atIndex:8];
		[invocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:YES];
		NSInteger returnValue;
		[invocation getReturnValue:&returnValue];
		return returnValue;
	}
	
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	if (messageText) {
		[alert setMessageText:messageText];
	}
	if (infoText) {
		[alert setInformativeText:infoText];
	}
	if (button1) {
		[alert addButtonWithTitle:button1];
	}
	if (button2) {
		[alert addButtonWithTitle:button2];
	}
	if (button2) {
		[alert addButtonWithTitle:button3];
	}
	if (suppressionButton) {
		alert.showsSuppressionButton = YES;
		if ([suppressionButton length] > 0) {
			alert.suppressionButton.title = suppressionButton;
		}
	}
	if (!window) {
		window = mainWindow;
	}
	
	if (window.isVisible && [sheetLock tryLock]) {
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

- (void)showProgressSheet {
	[progressSheetLock lock];
	if (numberOfProgressSheets == 0) { //Nur anzeigen wenn das progressSheet nicht bereits angezeigt wird.
		oldDisplayedView = displayedView; //displayedView sichern.
		self.displayedView = progressView; //progressView anzeigen.
		if ([sheetLock tryLock]) { //Es wird kein anderes Sheet angezeigt.
			oldDisplayedView = nil;
			[NSApp beginSheet:sheetWindow modalForWindow:mainWindow modalDelegate:nil didEndSelector:nil contextInfo:nil];
		}
	}
	numberOfProgressSheets++;
	[progressSheetLock unlock];
}
- (void)endProgressSheet {
	[progressSheetLock lock];
	numberOfProgressSheets--;
	if (numberOfProgressSheets == 0) { //Nur ausführen wenn das progressSheet angezeigt wird.
		if (oldDisplayedView) { //Soll ein zuvor angezeigtes Sheet wieder angezeigt werden?
			self.displayedView = oldDisplayedView; //Altes Sheet wieder anzeigen.
		} else {
			[NSApp endSheet:sheetWindow]; //Sheet beenden...
			[sheetWindow orderOut:self]; // und ausblenden.
			[sheetLock unlock];
		}
	}
	[progressSheetLock unlock];
}

- (void)runSavePanelWithaccessoryView:(NSView *)accessoryView {
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	panel.delegate = self;
	panel.allowsOtherFileTypes = YES;
	panel.canSelectHiddenExtension = YES;
	panel.allowedFileTypes = self.allowedFileTypes;
	panel.nameFieldStringValue = self.pattern ? self.pattern : @"";
	
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
}
- (void)runOpenPanelWithaccessoryView:(NSView *)accessoryView {
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
	if (![sheetWindow makeFirstResponder:sheetWindow]) {
		[sheetWindow endEditingFor:nil];
	}
	
	if (numberOfProgressSheets > 0) {
		[[ActionController sharedInstance] cancelOperation:self];
	} else {
		if (clickedButton == NSOKButton) {
			switch (self.sheetType) {
				case SheetTypeNewKey:
					if (![self checkName]) return;
					if (![self checkEmailMustSet:NO]) return;
					if (![self checkComment]) return;
					
					if ([[GPGController gpgVersion] hasPrefix:@"1"]) {
						if (![self checkPassphrase]) return;
					} else {
						self.passphrase = nil;
					}
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
					if (![self checkEmailMustSet:NO]) return;
					if (![self checkComment]) return;
					break;
			}
		}
		
		[NSApp stopModal];
	}
}


- (IBAction)advancedButton:(NSButton *)sender {
	BOOL hide = sender.state == NSOffState;
	NSRect newFrame = sheetWindow.frame;
	
	CGFloat height = [newKey_advancedSubview frame].size.height;
	newFrame.size.height += hide ? -height : height;
	
	if (hide) [newKey_advancedSubview setHidden:YES];
	[sheetWindow setFrame:newFrame display:YES animate:YES];
	if (!hide) [newKey_advancedSubview setHidden:NO];
}


// Propertys //
- (NSInteger)keyType {
	return keyType;
}
- (void)setKeyType:(NSInteger)value {
	keyType = value;
	if (value == 2 || value == 3) {
		keyLengthFormatter.minKeyLength = 1024;
		keyLengthFormatter.maxKeyLength = 3072;
		self.length = [keyLengthFormatter checkedValue:length];
		self.availableLengths = [NSArray arrayWithObjects:@"1024", @"2048", @"3072", nil];
	} else {
		keyLengthFormatter.minKeyLength = 1024;
		keyLengthFormatter.maxKeyLength = 4096;
		self.length = [keyLengthFormatter checkedValue:length];
		self.availableLengths = [NSArray arrayWithObjects:@"1024", @"2048", @"3072", @"4096", nil];
	}
}

- (NSInteger)daysToExpire {
	return self.hasExpirationDate ? [self.expirationDate daysSinceNow] : 0;
}
- (GPGKey *)secretKey {
	return [[secretKeysController selectedObjects] objectAtIndex:0];
}
- (void)setSecretKey:(GPGKey *)value {
	[secretKeysController setSelectedObjects:[NSArray arrayWithObject:value]];
}


// Internal methods //
- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	clickedButton = returnCode;
	[NSApp stopModal];
}

- (void)generateFoundKeyDicts {
	NSMutableArray *dicts = [NSMutableArray arrayWithCapacity:[keys count]];
	
	NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
	
	GPGKeyAlgorithmNameTransformer *algorithmNameTransformer = [[GPGKeyAlgorithmNameTransformer new] autorelease];
	BOOL oneKeySelected = NO;
	
	for (GPGRemoteKey *key in keys) {
		NSNumber *selected;
		NSDictionary *stringAttributes;
		NSMutableAttributedString *description;
		
		if (key.expired || key.revoked) {
			selected = [NSNumber numberWithBool:NO];
			stringAttributes = [NSDictionary dictionaryWithObject:[NSColor redColor] forKey:NSForegroundColorAttributeName];
		} else {
			selected = [NSNumber numberWithBool:!oneKeySelected];
			oneKeySelected = YES;
			stringAttributes = nil;
		}
		
		NSString *tempDescription = [NSString stringWithFormat:localized(@"FOUND_KEY_DESCRIPTION_FORMAT"), 
									 key.keyID, //Schlüssel ID
									 [algorithmNameTransformer transformedIntegerValue:key.algorithm], //Algorithmus
									 key.length, //Länge
									 [dateFormatter stringFromDate:key.creationDate]]; //Erstellt
		
		description = [[[NSMutableAttributedString alloc] initWithString:tempDescription attributes:stringAttributes] autorelease];
		
		for (GPGRemoteUserID *userID in key.userIDs) {
			[description appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"\n	%@", userID.userIDDescription]] autorelease]];
		}
		
		[dicts addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:description, @"description", selected, @"selected", [NSNumber numberWithUnsignedInteger:[key.userIDs count] + 1], @"lines", key, @"key", nil]];
	}
	
	self.foundKeyDicts = dicts;
}

- (void)setStandardExpirationDates {
	//Setzt minExpirationDate einen Tag in die Zukunft.
	//Setzt maxExpirationDate 500 Jahre in die Zukunft.
	//Setzt expirationDate 4 Jahre in die Zukunft.	
	
	NSDateComponents *dateComponents = [[[NSDateComponents alloc] init] autorelease];
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
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	ABPerson *myPerson = [[ABAddressBook sharedAddressBook] me];
	if (myPerson) {
		NSString *abFirstName = [myPerson valueForProperty:kABFirstNameProperty];
		NSString *abLastName = [myPerson valueForProperty:kABLastNameProperty];
		
		if (abFirstName && abLastName) {
			self.name = [NSString stringWithFormat:@"%@ %@", abFirstName, abLastName];
		} else if (abFirstName) {
			self.name = abFirstName;
		} else if (abLastName) {
			self.name = abLastName;
		} else {
			self.name = @"";
		}
		
		ABMultiValue *abEmailAddresses = [myPerson valueForProperty:kABEmailProperty];
		
		NSUInteger count = [abEmailAddresses count];
		if (count > 0) {
			NSMutableArray *newEmailAddresses = [NSMutableArray arrayWithCapacity:count];
			for (NSUInteger i = 0; i < count; i++) {
				[newEmailAddresses addObject:[abEmailAddresses valueAtIndex:i]];
			}
			self.emailAddresses = newEmailAddresses;
			self.email = [emailAddresses objectAtIndex:0];
		} else {
			self.emailAddresses = nil;
			self.email = @"";
		}
	} else {
		self.name = @"";
		self.email = @"";
		self.emailAddresses = nil;
	}
	[pool drain];
}

- (void)runAndWait {
	[sheetLock lock];
	GPGDebugLog(@"SheetController runAndWait. modalWindow = '%@', sheetWindow = '%@'", modalWindow, sheetWindow);
	if (modalWindow.isVisible) {
		[NSApp beginSheet:sheetWindow modalForWindow:modalWindow modalDelegate:nil didEndSelector:nil contextInfo:nil];
		[NSApp runModalForWindow:sheetWindow];
		[NSApp endSheet:sheetWindow];
	} else {
		[sheetWindow makeKeyAndOrderFront:self];	
		[NSApp runModalForWindow:sheetWindow];
	}
	[sheetWindow orderOut:self];
	[sheetLock unlock];
}




// Checks //
- (BOOL)checkName {
	if ([self.name length] < 5) {
		NSRunAlertPanel(localized(@"Error"), localized(@"CheckError_NameToShort"), nil, nil, nil);
		return NO;
	}
	if ([self.name length] > 500) {
		NSRunAlertPanel(localized(@"Error"), localized(@"CheckError_NameToLong"), nil, nil, nil);
		return NO;
	}
	if ([self.name rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]].length != 0) {
		NSRunAlertPanel(localized(@"Error"), localized(@"CheckError_InvalidCharInName"), nil, nil, nil);
		return NO;
	}
	if ([self.name characterAtIndex:0] <= '9' && [self.name characterAtIndex:0] >= '0') {
		NSRunAlertPanel(localized(@"Error"), localized(@"CheckError_NameStartWithDigit"), nil, nil, nil);
		return NO;
	}
	return YES;
}
- (BOOL)checkEmailMustSet:(BOOL)mustSet {
	if (!self.email) {
		self.email = @"";
	}
	
	if (!mustSet && [self.email length] == 0) {
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
	[charSet addCharactersInString:@"01234567890_-+@.abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"];
	[charSet invert];
	
	if ([[components objectAtIndex:0] rangeOfCharacterFromSet:charSet].length != 0) {
		goto emailIsInvalid;
	}
	[charSet addCharactersInString:@"+"];
	if ([[components objectAtIndex:1] rangeOfCharacterFromSet:charSet].length != 0) {
		goto emailIsInvalid;
	}
	
	if ([self.email rangeOfString:@"@gpgtools.org"].length > 0) {
		goto emailIsInvalid;
	}
	
	return YES;
	
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
	
	return YES;
}




- (NSView *)displayedView {
	return displayedView;
}
- (void)setDisplayedView:(NSView *)value {
	if (displayedView != value) {
		if (displayedView == progressView) {
			[progressIndicator stopAnimation:nil];
		}
		
		//[displayedView removeFromSuperview];
		//displayedView = value;
		if (value != nil) {
			static BOOL	newKeyViewInitialized = NO;
			if (!newKeyViewInitialized && value == newKeyView) {
				newKeyViewInitialized = YES;
				if (![[GPGController gpgVersion] hasPrefix:@"1"]) { //Passphrase-Felder nur bei GPG 1.x anzeigen.
					[newKey_passphraseSubview setHidden:YES];
					NSSize newSize = [newKeyView frame].size;
					newSize.height -= [newKey_passphraseSubview frame].size.height;
					
					[newKeyView setFrameSize:newSize];
				}
			}
			

			[sheetWindow setContentView:value];
			
			if ([value nextKeyView]) {
				[sheetWindow makeFirstResponder:[value nextKeyView]];
			}
			
			if (value == progressView) {
				[progressIndicator startAnimation:nil];
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
	[(NSSavePanel *)[exportKeyOptionsView window] setAllowedFileTypes:extensions];
}



// NSTableView delegate.
- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
	NSDictionary *foundKey = [[foundKeysController arrangedObjects] objectAtIndex:row];
	return [[foundKey objectForKey:@"lines"] integerValue] * [tableView rowHeight] + 1;
}
- (BOOL)tableView:(NSTableView *)tableView shouldTypeSelectForEvent:(NSEvent *)event withCurrentSearchString:(NSString *)searchString {
	if ([event type] == NSKeyDown && [event keyCode] == 49) { //Leertaste gedrückt
		NSArray *selectedKeys = [foundKeysController selectedObjects];
		if ([selectedKeys count] > 0) {
			NSNumber *selected = [NSNumber numberWithBool:![[[selectedKeys objectAtIndex:0] objectForKey:@"selected"] boolValue]];
			for (NSMutableDictionary *foundKey in [foundKeysController selectedObjects]) {
				[foundKey setObject:selected forKey:@"selected"];
			}
		}
	}
	return NO;
}


// NSOpenSavePanelDelegate
- (BOOL)panel:(NSOpenPanel *)sender validateURL:(NSURL *)url error:(NSError **)outError {
	if (self.sheetType == SheetTypeOpenPhotoPanel) {
		
		NSString *path = [url path];
		unsigned long long filesize = [[[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] objectForKey:NSFileSize] unsignedLongLongValue];
		if (filesize > 500 * 1024) { //Bilder über 500 KiB sind zu gross. (Meiner Meinung nach.)
			[self alertSheetForWindow:sender 
						  messageText:localized(@"ChoosePhoto_ToLarge_Message") 
							 infoText:localized(@"ChoosePhoto_ToLarge_Info") 
						defaultButton:nil 
					  alternateButton:nil 
						  otherButton:nil
					suppressionButton:nil];
			return NO;
		} else if (filesize > 15 * 1024) { //Bei Bildern über 15 KiB nachfragen.
			NSInteger retVal =  [self alertSheetForWindow:sender 
											  messageText:localized(@"ChoosePhoto_Large_Message") 
												 infoText:localized(@"ChoosePhoto_Large_Info") 
											defaultButton:localized(@"ChoosePhoto_Large_Button1") 
										  alternateButton:localized(@"ChoosePhoto_Large_Button2") 
											  otherButton:nil
										suppressionButton:nil];
			if (retVal == NSAlertFirstButtonReturn) {
				return NO;
			}
		}
		
	}
	return YES;
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
		[NSBundle loadNibNamed:@"ModalSheets" owner:self];
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





