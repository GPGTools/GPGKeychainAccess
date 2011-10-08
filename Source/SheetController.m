#import "SheetController.h"
#import <AddressBook/AddressBook.h>
#import "Globales.h"
#import "ActionController.h"


@interface SheetController ()
@property (assign) NSView *displayedView;
@property (assign) NSWindow *modalWindow;
- (void)runAndWait;
- (void)setStandardExpirationDates;
- (void)setDataFromAddressBook;
- (BOOL)checkName;
- (BOOL)checkEmailMustSet:(BOOL)mustSet;
- (BOOL)checkComment;
- (BOOL)checkPassphrase;
- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
@end


@implementation SheetController
@synthesize progressText, errorText, msgText, name, email, comment, passphrase, confirmPassphrase, pattern, 
	hasExpirationDate, allowSecretKeyExport, localSig, allowEdit,
	expirationDate, minExpirationDate, maxExpirationDate,
	userIDs, foundKeys, emailAddresses, secretKeys, availableLengths,
	exportFormat, secretKeyId, sigType, length, sheetType,
	modalWindow;


- (void)showProgressSheet {
	if (self.displayedView == errorView) {
		return;
	}
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
	if (self.displayedView == errorView) {
		return;
	}
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

- (void)showErrorSheet {
	[self performSelectorOnMainThread:@selector(endProgressSheet) withObject:nil waitUntilDone:YES];
	self.displayedView = errorView;
	self.sheetType = SheetTypeNoSheet;
	if (!self.modalWindow) {
		self.modalWindow = mainWindow;
	}
	[self runAndWait];
}


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
			[self setStandardExpirationDates];
			[self setDataFromAddressBook];
			self.comment = @"";
			self.passphrase = @"";
			self.confirmPassphrase = @"";
			
			self.displayedView = newKeyView;
			[self runAndWait];
			break;
		case SheetTypeSearchKeys:
			self.pattern = @"";
			
			self.displayedView = searchKeysView;
			[self runAndWait];
			break;
		case SheetTypeReceiveKeys:
			self.pattern = @"";
			
			self.displayedView = receiveKeysView;
			[self runAndWait];
			break;
		default:
			return -1;
	}
	self.displayedView = nil;
	return clickedButton;
}



- (NSInteger)alertSheetForWindow:(NSWindow *)window messageText:(NSString *)messageText infoText:(NSString *)infoText defaultButton:(NSString *)button1 alternateButton:(NSString *)button2 otherButton:(NSString *)button3 suppressionButton:(NSString *)suppressionButton {
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText:messageText];
	[alert setInformativeText:infoText];
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
	
	[sheetLock lock];
	[alert beginSheetModalForWindow:window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
	[NSApp runModalForWindow:window];
	[sheetLock unlock];
	
	if (alert.suppressionButton.state == NSOnState) {
		clickedButton = clickedButton | SheetSuppressionButton;
	}

	
	return clickedButton;
}











//Internal methods.
- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	clickedButton = returnCode;
	[NSApp stopModal];
}



- (void)setStandardExpirationDates {
	//Setzt minExpirationDate einen Tag in die Zukunft.
	//Setzt maxExpirationDate 500 Jahre in die Zukunft.
	//Setzt expirationDate ein Jahr in die Zukunft.	
	
	NSDateComponents *dateComponents = [[[NSDateComponents alloc] init] autorelease];
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDate *curDate = [NSDate date];
	[dateComponents setDay:1];
	self.minExpirationDate = [calendar dateByAddingComponents:dateComponents toDate:curDate options:0];
	[dateComponents setDay:0];
	[dateComponents setYear:10];
	self.expirationDate = [calendar dateByAddingComponents:dateComponents toDate:curDate options:0]; 	
	[dateComponents setYear:500];
	self.maxExpirationDate = [calendar dateByAddingComponents:dateComponents toDate:curDate options:0]; 	

	self.hasExpirationDate = NO;
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
			self.emailAddresses = [newEmailAddresses copy];
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
	[NSApp beginSheet:sheetWindow modalForWindow:modalWindow modalDelegate:nil didEndSelector:nil contextInfo:nil];
	[NSApp runModalForWindow:sheetWindow];
	[NSApp endSheet:sheetWindow];
	[sheetWindow orderOut:self];
	[sheetLock unlock];
}



- (IBAction)buttonClicked:(NSButton *)sender {
	clickedButton = sender.tag;
	
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
				case SheetTypeSearchKeys:
					break;
				case SheetTypeReceiveKeys: {
					NSSet *keyIDs = [pattern keyIDs];
					if (!keyIDs) {
						NSRunAlertPanel(localized(@"Error"), localized(@"CheckError_NoKeyID"), nil, nil, nil);
						return;
					}

					break; 
				}
			}
		}
		
		[NSApp stopModal];
	}
}



- (BOOL)checkName {
	if ([name length] < 5) {
		NSRunAlertPanel(localized(@"Error"), localized(@"CheckError_NameToShort"), nil, nil, nil);
		return NO;
	}
	if ([name length] > 500) {
		NSRunAlertPanel(localized(@"Error"), localized(@"CheckError_NameToLong"), nil, nil, nil);
		return NO;
	}
	if ([name rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]].length != 0) {
		NSRunAlertPanel(localized(@"Error"), localized(@"CheckError_InvalidCharInName"), nil, nil, nil);
		return NO;
	}
	if ([name characterAtIndex:0] <= '9' && [name characterAtIndex:0] >= '0') {
		NSRunAlertPanel(localized(@"Error"), localized(@"CheckError_NameStartWithDigit"), nil, nil, nil);
		return NO;
	}
	return YES;
}
- (BOOL)checkEmailMustSet:(BOOL)mustSet {
	if (!email) {
		email = @"";
	}
	
	if (!mustSet && [email length] == 0) {
		return YES;
	}
	if ([email length] > 254) {
		NSRunAlertPanel(localized(@"Error"), localized(@"CheckError_EmailToLong"), nil, nil, nil);
		return NO;
	}
	if ([email length] < 4) {
		goto emailIsInvalid;
	}
	if ([email hasPrefix:@"@"] || [email hasSuffix:@"@"] || [email hasSuffix:@"."]) {
		goto emailIsInvalid;
	}
	NSArray *components = [email componentsSeparatedByString:@"@"];
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
	
	return YES;
	
emailIsInvalid: //Hierher wird gesprungen, wenn die E-Mail-Adresse ungültig ist und nicht eine spezielle Meldung ausgegeben werden soll.
	NSRunAlertPanel(localized(@"Error"), localized(@"CheckError_InvalidEmail"), nil, nil, nil);
	return NO;
}
- (BOOL)checkComment {
	if (!comment) {
		comment = @"";
		return YES;
	}
	if ([comment length] == 0) {
		return YES;
	}
	if ([comment length] > 500) {
		NSRunAlertPanel(localized(@"Error"), localized(@"CheckError_CommentToLong"), nil, nil, nil);
		return NO;
	}
	if ([comment rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"()"]].length != 0) {
		NSRunAlertPanel(localized(@"Error"), localized(@"CheckError_InvalidCharInComment"), nil, nil, nil);
		return NO;
	}
	return YES;
}
- (BOOL)checkPassphrase {
	if (!passphrase) {
		passphrase = @"";
	}
	if (!confirmPassphrase) {
		confirmPassphrase = @"";
	}
	if (![passphrase isEqualToString:confirmPassphrase]) {
		NSRunAlertPanel(localized(@"Error"), localized(@"CheckError_PassphraseMissmatch"), nil, nil, nil);
		return NO;
	}
	//TODO: Hinweis bei leerer, einfacher oder kurzer Passphrase.
	
	return YES;
}


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


- (NSView *)displayedView {
	return displayedView;
}
- (void)setDisplayedView:(NSView *)value {
	if (displayedView != value) {
		if (displayedView == progressView) {
			[progressIndicator stopAnimation:nil];
		}
		
		[displayedView removeFromSuperview];
		displayedView = value;
		if (value != nil) {
			if (value == newKeyView) { //Passphrase-Felder nur bei GPG 1.4.x anzeigen.
				NSUInteger resizingMask;
				NSSize newSize;
				if ([[GPGController gpgVersion] hasPrefix:@"1"]) {
					if ([newKey_passphraseSubview isHidden] == YES) {
						[newKey_passphraseSubview setHidden:NO];
						newSize = [newKeyView frame].size;
						newSize.height += [newKey_passphraseSubview frame].size.height;
						
						resizingMask = [newKey_topSubview autoresizingMask];
						[newKey_topSubview setAutoresizingMask:NSViewMinYMargin | NSViewWidthSizable];
						[newKeyView setFrameSize:newSize];
						[newKey_topSubview setAutoresizingMask:resizingMask];
					}					
				} else {
					if ([newKey_passphraseSubview isHidden] == NO) {
						[newKey_passphraseSubview setHidden:YES];
						newSize = [newKeyView frame].size;
						newSize.height -= [newKey_passphraseSubview frame].size.height;
						
						resizingMask = [newKey_topSubview autoresizingMask];
						[newKey_topSubview setAutoresizingMask:NSViewMinYMargin | NSViewWidthSizable];
						[newKeyView setFrameSize:newSize];
						[newKey_topSubview setAutoresizingMask:resizingMask];
					}
				}
			}

			NSRect oldRect, newRect;
			oldRect = [sheetWindow frame];
			newRect.size = [value frame].size;
			newRect.origin.x = oldRect.origin.x + (oldRect.size.width - newRect.size.width) / 2;
			newRect.origin.y = oldRect.origin.y + oldRect.size.height - newRect.size.height;
			
			[sheetWindow setFrame:newRect display:YES animate:YES];
			[sheetWindow setContentSize:newRect.size];
			
			[sheetView addSubview:value];
			if ([value nextKeyView]) {
				[sheetWindow makeFirstResponder:[value nextKeyView]];
			}
			
			if (value == progressView) {
				[progressIndicator startAnimation:nil];
				//[progressIndicator display];
				//[progressIndicator setNeedsDisplay:YES];
			}
		}
	}
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
	*obj = [NSString stringWithFormat:@"%i", [self checkedValue:[string integerValue]]];
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


