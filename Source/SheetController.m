/*
 Copyright © Roman Zechmeister, 2018
 
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
#import "Globales.h"
#import "ActionController.h"
#import "GKAExtensions.h"
#import "AppDelegate.h"
#import <objc/runtime.h>
#import <Zxcvbn/Zxcvbn.h>
#import <CommonCrypto/CommonDigest.h>
#import <sqlite3.h>


@interface KeyLengthFormatter : NSFormatter
@property (nonatomic) NSInteger minKeyLength;
@property (nonatomic) NSInteger maxKeyLength;
- (NSInteger)checkedValue:(NSInteger)value;
@end

@interface GKSheetWindow : NSPanel
@end

@interface SheetController () <NSOpenSavePanelDelegate, NSTabViewDelegate> {
	NSInteger _clickedButton;
	NSView *_oldDisplayedView;
	NSLock *_sheetLock;
	NSLock *_progressSheetLock;
	NSInteger _numberOfProgressSheets; //Anzahl der angeforderten progressSheets.
	NSString *_pubFilename;
	NSString *_secFilename;
	NSUInteger _oldVolumeIndex;
	NSArray *_topLevelObjects;
	DBZxcvbn *_zxcvbn;
	NSArray<NSString *> *_badPasswordIngredients;
}

@property (nonatomic, weak) IBOutlet NSWindow *sheetWindow;

@property (nonatomic, weak) IBOutlet KeyLengthFormatter *keyLengthFormatter;
@property (nonatomic, weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (nonatomic, weak) IBOutlet NSArrayController *foundKeysController;
@property (nonatomic, weak) IBOutlet NSArrayController *secretKeysController;
@property (nonatomic, weak) IBOutlet NSArrayController *userIDsController;

@property (nonatomic, weak) IBOutlet NSStackView *sign_stackView;
@property (nonatomic, weak) IBOutlet NSView *sign_singleUserIDView;
@property (nonatomic, weak) IBOutlet NSView *sign_multiUserIDsView;
@property (nonatomic, weak) IBOutlet NSView *sign_singleSecretKeyView;
@property (nonatomic, weak) IBOutlet NSView *sign_multiSecretKeysView;
@property (nonatomic, weak) IBOutlet NSView *sign_publishExampleView;
@property (nonatomic, weak) IBOutlet NSView *sign_expertView;
@property (nonatomic, weak) IBOutlet NSTableView *sign_userIDsTable;

@property (nonatomic, weak) IBOutlet NSView *exportKeyOptionsView;

@property (nonatomic, weak) IBOutlet NSLayoutConstraint *hideProgressTitleConstraint;


//Views die im Sheet angezeigt werden können.
@property (nonatomic, weak) IBOutlet NSView *progressView;
@property (nonatomic, weak) IBOutlet NSView *genNewKeyView;
@property (nonatomic, weak) IBOutlet NSView *genNewKey_advancedSubview;
@property (nonatomic, weak) IBOutlet NSView *genNewKey_confirmPasswordSubview;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *genNewKey_advancedConstraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *genNewKey_confirmPasswordConstraint;
@property (nonatomic, weak) IBOutlet NSView *generateSubkeyView;
@property (nonatomic, weak) IBOutlet NSView *generateUserIDView;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *generateUserID_CommentConstraint;
@property (nonatomic, weak) IBOutlet NSView *generateSignatureView;
@property (nonatomic, weak) IBOutlet NSView *changeExpirationDateView;
@property (nonatomic, weak) IBOutlet NSView *searchKeysView;
@property (nonatomic, weak) IBOutlet NSView *foundKeysView;
@property (nonatomic, weak) IBOutlet NSView *receiveKeysView;
@property (nonatomic, weak) IBOutlet NSView *resultView;
@property (nonatomic, weak) IBOutlet NSView *editAlgorithmPreferencesView;
@property (nonatomic, weak) IBOutlet NSView *selectVolumeView;


@property (nonatomic, weak) NSView *displayedView;
@property (nonatomic, weak) NSWindow *modalWindow;
@property (nonatomic, strong) NSArray *foundKeyDicts;
@property (nonatomic, strong) NSArray *URLs;
@property (nonatomic, strong) NSArray *volumes;
@property (nonatomic, strong) NSDictionary *result;
@property (nonatomic) BOOL enableOK;
@property (nonatomic) BOOL disableUserIDCommentsField;
@property (nonatomic, readwrite, strong) NSArray *userIDs;
@property (nonatomic, readwrite) double passwordStrength;



- (IBAction)buttonClicked:(NSButton *)sender;
- (IBAction)advancedButton:(NSButton *)sender;




- (void)runAndWait;
- (void)setStandardExpirationDates;
- (void)setDataFromMailAccounts;
- (BOOL)checkName;
- (BOOL)checkEmail;
- (BOOL)checkComment;
- (BOOL)checkPassphrase;
- (BOOL)generateFoundKeyDicts;
- (void)runSavePanel;
- (void)runOpenPanelWithAccessoryView:(NSView *)accessoryView;
@end

@interface NSSavePanel ()
- (void)setShowsTagField:(BOOL)flag;
@end










@implementation SheetController
@synthesize progressText = _progressText;
@synthesize msgText = _msgText;



// Running sheets //
- (NSInteger)runModal {
	return [self runModalForWindow:mainWindow];
}
- (NSInteger)runModalForWindow:(NSWindow *)window {
	_clickedButton = 0;
	self.modalWindow = window;
	
	switch (self.sheetType) {
		case SheetTypeNewKey:
			self.length = 4096;
			self.keyType = 1;
			self.expirationDate = nil;
			[self setStandardExpirationDates];
			[self setDataFromMailAccounts];
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
			
			[self setDataFromMailAccounts];
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
			if (self.userIDs.count == 1) {
				[self.sign_stackView setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible forView:self.sign_multiUserIDsView];
				[self.sign_stackView setVisibilityPriority:NSStackViewVisibilityPriorityMustHold forView:self.sign_singleUserIDView];
			} else {
				[self.sign_stackView setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible forView:self.sign_singleUserIDView];
				[self.sign_stackView setVisibilityPriority:NSStackViewVisibilityPriorityMustHold forView:self.sign_multiUserIDsView];
			}
			
			[self.sign_stackView setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible forView:self.sign_singleSecretKeyView];
			if (self.secretKeys.count == 1) {
				[self.sign_stackView setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible forView:self.sign_multiSecretKeysView];
			} else {
				[self.sign_stackView setVisibilityPriority:NSStackViewVisibilityPriorityMustHold forView:self.sign_multiSecretKeysView];
			}
			if (showExpertSettings) {
				[self.sign_stackView setVisibilityPriority:NSStackViewVisibilityPriorityMustHold forView:self.sign_expertView];
			} else {
				[self.sign_stackView setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible forView:self.sign_expertView];
			}

			
			
			self.expirationDate = nil;
			[self setStandardExpirationDates];
			self.hasExpirationDate = NO;
			self.publish = NO;
			
			self.displayedView = _generateSignatureView;
			break;
		case SheetTypeSavePanel:
			[self runSavePanel];
			
			return _clickedButton;
		case SheetTypeOpenPanel:
		case SheetTypeOpenPhotoPanel:
			[self runOpenPanelWithAccessoryView:nil];
			
			return _clickedButton;
		case SheetTypeExportKey: {
			[self runSavePanel];
			
			return _clickedButton; }
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
	return _clickedButton;
}

- (IBAction)togglePublishExample:(NSButton *)sender {
	[self.sign_stackView setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible forView:self.sign_singleSecretKeyView];

	[self.sign_stackView setVisibilityPriority:sender.state == NSOnState ? NSStackViewVisibilityPriorityMustHold : NSStackViewVisibilityPriorityNotVisible forView:self.sign_publishExampleView];
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
		// Add an invisible button to the dialog, so an user can close it by pressing the escape-key

		[alert layout]; // Layout the alert, so it's possible to manipulate the layout.
		
		 // Get the first button of the dialog, so we can use it's target and action for our new button.
		NSButton *someButton = alert.buttons[0];
		NSView *superview = someButton.superview;

		// Create a very small button outside of the visible area.
		NSButton *newButton = [[NSButton alloc] initWithFrame:NSMakeRect(-10, -10, 1, 1)];
		newButton.keyEquivalent = @"\x1b"; // escape-key
		// Set the target and action to match the other buttons.
		newButton.target = someButton.target;
		newButton.action = someButton.action;
		newButton.tag = cancelButtonTag; // Set the tag to mtach the real cancel button.
		newButton.refusesFirstResponder = YES; // Prevent selecting the button using tab-key.

		[superview addSubview:newButton]; // Last step: Add the button to the dialog.
		// Do not call [alert layout] anymore or the new button would be visible.
	} else {
		[alert layout]; // Layout the alert, so it's possible to manipulate the layout.
	}
	
	if (customize) {
		// Allow the caller to customize the dialog.
		customize(alert);
	}
	
	if (window && window.isVisible && [_sheetLock tryLock]) {
		[alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
			_clickedButton = returnCode;
			[NSApp stopModal];
		}];
		[NSApp runModalForWindow:window];
		[_sheetLock unlock];
	} else {
		_clickedButton = [alert runModal];
	}
	
	if (alert.suppressionButton.state == NSOnState) {
		_clickedButton = _clickedButton | SheetSuppressionButton;
	}
	
	
	return _clickedButton;
}

- (BOOL)showProgressSheet {
	BOOL result = NO;
	[_progressSheetLock lock];
	if (_numberOfProgressSheets == 0) { //Nur anzeigen wenn das progressSheet nicht bereits angezeigt wird.
		_oldDisplayedView = _displayedView; //displayedView sichern.
		self.displayedView = _progressView; //progressView anzeigen.
		if ([_sheetLock tryLock]) { //Es wird kein anderes Sheet angezeigt.
			_oldDisplayedView = nil;
			[mainWindow beginSheet:_sheetWindow completionHandler:^(NSModalResponse returnCode) {}];
		}
		result = YES;
	}
	_numberOfProgressSheets++;
	[_progressSheetLock unlock];
	return result;
}
- (BOOL)endProgressSheet {
	BOOL result = NO;
	[_progressSheetLock lock];
	_numberOfProgressSheets--;
	if (_numberOfProgressSheets == 0) { //Nur ausführen wenn das progressSheet angezeigt wird.
		if (_oldDisplayedView) { //Soll ein zuvor angezeigtes Sheet wieder angezeigt werden?
			self.displayedView = _oldDisplayedView; //Altes Sheet wieder anzeigen.
		} else {
			[mainWindow endSheet:_sheetWindow]; // Hide the sheet.
			[_sheetLock unlock];
		}
		result = YES;
	} else if (_numberOfProgressSheets < 0) {
		_numberOfProgressSheets = 0;
	}
	[_progressSheetLock unlock];
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
        [_keys enumerateObjectsUsingBlock:^(GPGKey *key, NSUInteger idx, BOOL *stop) {
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
	
	
	[_sheetLock lock];
	[panel beginSheetModalForWindow:_modalWindow completionHandler:^(NSInteger result) {
		[NSApp stopModalWithCode:result];
	}];
	
	_clickedButton = [NSApp runModalForWindow:_modalWindow];
	[_sheetLock unlock];
	
	self.URL = panel.URL;
	_hideExtension = panel.isExtensionHidden;
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
	
	
	[_sheetLock lock];
	[panel beginSheetModalForWindow:_modalWindow completionHandler:^(NSInteger result) {
		[NSApp stopModalWithCode:result];
	}];
	
	_clickedButton = [NSApp runModalForWindow:_modalWindow];
	[_sheetLock unlock];
	
	self.URL = panel.URL;
	self.URLs = panel.URLs;
}




// buttonClicked //
- (IBAction)buttonClicked:(NSButton *)sender {
	_clickedButton = sender.tag;
	if (![_sheetWindow makeFirstResponder:_sheetWindow]) {
		[_sheetWindow endEditingFor:nil];
	}
	
	if (_numberOfProgressSheets > 0) {
		[[ActionController sharedInstance] cancelGPGOperation:self];
	} else {
		if (_clickedButton == NSOKButton) {
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
					NSMutableArray *selectedKeys = [NSMutableArray new];
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


#pragma mark Properties


- (void)setProgressText:(NSString *)value {
	if (value == nil) {
		value = @"";
	}
	if (value != _progressText) {
		_progressText = value;
	}
}
- (void)setProgressTitle:(NSString *)progressTitle {
	if (progressTitle.length == 0) {
		progressTitle = @"";
		// Hide the title label.
		self.hideProgressTitleConstraint.priority = 999;
	} else {
		self.hideProgressTitleConstraint.priority = 997;
	}
	_progressTitle = progressTitle;
}

- (void)setMsgText:(NSString *)value {
	if (value == nil) {
		value = @"";
	}
	if (value != _msgText) {
		_msgText = value;
	}
}
- (NSString *)msgText {
	return _msgText ? _msgText : @"";
}

- (void)setName:(NSString *)name {
	_name = name;
	_badPasswordIngredients = nil;
}
- (void)setEmail:(NSString *)email {
	_email = email;
	_badPasswordIngredients = nil;
}
- (void)setComment:(NSString *)comment {
	_comment = comment;
	_badPasswordIngredients = nil;
}

- (void)setKeyType:(NSInteger)value {
	_keyType = value;
	if (value == 2 || value == 3) {
		_keyLengthFormatter.minKeyLength = 2048;
		_keyLengthFormatter.maxKeyLength = 3072;
		self.length = [_keyLengthFormatter checkedValue:_length];
		self.availableLengths = [NSArray arrayWithObjects:@"2048", @"3072", nil];
	} else {
		_keyLengthFormatter.minKeyLength = 2048;
		_keyLengthFormatter.maxKeyLength = 4096;
		self.length = [_keyLengthFormatter checkedValue:_length];
		self.availableLengths = [NSArray arrayWithObjects:@"2048", @"3072", @"4096", nil];
	}
}

- (NSInteger)daysToExpire {
	return self.hasExpirationDate ? self.expirationDate.daysSinceNow : 0;
}
- (GPGKey *)secretKey {
	NSArray *selectedSecretKeys = [_secretKeysController selectedObjects];
	return selectedSecretKeys.count > 0 ? selectedSecretKeys[0] : nil;
}
- (void)setSecretKey:(GPGKey *)value {
	if ([self.secretKeys containsObject:value]) {
		[_secretKeysController setSelectedObjects:@[value]];
	} else if (self.secretKeys.count > 0) {
		[_secretKeysController setSelectedObjects:@[self.secretKeys.firstObject]];
	}
}


- (void)setSelectedVolumeIndexes:(NSIndexSet *)value {
	if (value.count > 0) {
		self.enableOK = (value.firstIndex != _oldVolumeIndex);
		_selectedVolumeIndexes = value;
	}
}

- (BOOL)showAlgorithmPrefsDropdown {
	return self.algorithmPreferences.count > 1;
}
+ (NSSet *)keyPathsForValuesAffectingShowAlgorithmPrefsDropdown {
	return [NSSet setWithObjects:@"algorithmPreferences", nil];
}


- (void)setPublicKey:(GPGKey *)publicKey {
	_publicKey = publicKey;
	
	
	[self.userIDs removeObserver:self fromObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.userIDs.count)] forKeyPath:@"selected"];
	
	NSMutableArray *userIDs = [NSMutableArray new];
	ActionController *ac = [ActionController sharedInstance];
	
	for (GPGUserID *userID in self.publicKey.userIDs) {
		if (userID.validity >= GPGValidityInvalid || userID.isUat) {
			continue;
		}
		
		NSString *description = [ac descriptionForKeys:@[userID] maxLines:0 withOptions:DescriptionNoKeyID];
		
		NSMutableDictionary *item = [NSMutableDictionary dictionaryWithObjectsAndKeys:@NO, @"selected", userID, @"userID", description, @"description", nil];
		[userIDs addObject:item];
	}

	[userIDs addObserver:self toObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, userIDs.count)] forKeyPath:@"selected" options:0 context:nil];
	
	
	self.userIDs = userIDs;
}

- (NSString *)userIDDescription {
	if (!self.publicKey) {
		return @"";
	}
	NSString *userIDDescription = [[ActionController sharedInstance] descriptionForKeys:@[self.publicKey] maxLines:0 withOptions:DescriptionNoKeyID];
	return userIDDescription;
}
+ (NSSet *)keyPathsForValuesAffectingUserIDDescription {
	return [NSSet setWithObjects:@"publicKey", nil];
}

- (NSString *)keyClaimsMultipleIdentities {
	return [NSString stringWithFormat:localized(@"SignKey_KeyClaimsMultipleIdentities"), self.userIDDescription];
}
+ (NSSet *)keyPathsForValuesAffectingKeyClaimsMultipleIdentities {
	return [NSSet setWithObjects:@"publicKey", nil];
}

- (NSString *)signKeyMainMsg {
	NSString *formattedFingerprint = [[GKFingerprintTransformer sharedInstance] transformedValue:self.publicKey.fingerprint];
	return [NSString stringWithFormat:localized(@"SignKey_MainMsg"), formattedFingerprint];
}
+ (NSSet *)keyPathsForValuesAffectingSignKeyMainMsg {
	return [NSSet setWithObjects:@"publicKey", nil];
}

- (BOOL)signEnabled {
	if (self.userIDs.count == 1) {
		return YES;
	} else {
		return self.selectedUserIDs.count > 0;
	}
}
+ (NSSet *)keyPathsForValuesAffectingSignEnabled {
	return [NSSet setWithObjects:@"userIDs", @"selectedUserIDs", nil];
}

- (NSString *)publishLabel {
	if (self.userIDs.count == 1) {
		return [NSString stringWithFormat:localized(@"SignKey_PublishSingleIdentity"), ((GPGUserID *)self.userIDs.firstObject[@"userID"]).name];
	} else {
		return localized(@"SignKey_PublishMultipleIdentities");
	}
}
+ (NSSet *)keyPathsForValuesAffectingPublishLabel {
	return [NSSet setWithObjects:@"userIDs", nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if ([keyPath isEqualToString:@"selected"]) {
		[self willChangeValueForKey:@"selectedUserIDs"];
		[self didChangeValueForKey:@"selectedUserIDs"];
	}
}
- (NSArray *)selectedUserIDs {
	if (self.userIDs.count == 1) {
		return @[self.userIDs[0][@"userID"]];
	}
	NSMutableArray *selectedUserIDs = [NSMutableArray new];
	for (NSDictionary *dict in self.userIDs) {
		if ([dict[@"selected"] boolValue]) {
			[selectedUserIDs addObject:dict[@"userID"]];
		}
	}
	return selectedUserIDs;
}
- (void)setSelectedUserIDs:(NSArray *)selectedUserIDs {
	NSUInteger index = 0;
	BOOL scrolled = NO;
	for (NSMutableDictionary *dict in self.userIDs) {
		if ([selectedUserIDs containsObject:dict[@"userID"]]) {
			dict[@"selected"] = @YES;
			if (!scrolled) {
				[self.sign_userIDsTable scrollRowToVisible:index];
				scrolled = YES;
			}
		} else {
			dict[@"selected"] = @NO;
		}
		index++;
	}
}
+ (NSSet *)keyPathsForValuesAffectingSelectedUserIDs {
	return [NSSet setWithObjects:@"userIDs", nil];
}


- (void)setPassphrase:(NSString *)value {
	if ([_passphrase isEqualToString:value]) {
		return;
	}
	if (self.genNewKey_confirmPasswordConstraint.constant == 0) {
		[self showConfirmPassword:YES animate:YES];
	}
	
	_passphrase = value;

	if (_passphrase.length == 0 || _passphrase.UTF8Length > 255) {
		self.passwordStrength = 0;
	} else {
		DBResult *result = [self.zxcvbn passwordStrength:self.passphrase userInputs:self.badPasswordIngredients];
		
		double seconds = result.crackTime;
		double score = log10(seconds * 1000000);
		score = MAX(score, 1);
		
		self.passwordStrength = score;
	}
}

- (BOOL)passwordsEqual {
	if (self.passphrase.length == 0 && self.confirmPassphrase.length == 0) {
		return YES;
	}
	return [self.passphrase isEqualToString:self.confirmPassphrase];
}
+ (NSSet *)keyPathsForValuesAffectingPasswordsEqual {
	return [NSSet setWithObjects:@"passphrase", @"confirmPassphrase", nil];
}

- (NSArray<NSString *> *)badPasswordIngredients {
	// This method builds a list of words, which sould not be in a good password for the key.
	if (_badPasswordIngredients) {
		return _badPasswordIngredients;
	}
	
	NSMutableSet *ingredients = [NSMutableSet new];
	NSMutableString *jointString = [NSMutableString new];
	
	if (self.name.length > 0) {
		[jointString appendString:self.name];
	}
	if (self.email.length > 0) {
		[jointString appendString:self.email];
	}
	if (self.comment.length > 0) {
		[jointString appendString:self.comment];
	}

	// Add all possible substrings longer than 2 charaters from name, email and comment to the list.
	NSInteger length = jointString.length;
	for (NSInteger i = 0; i < length - 2; i++) {
		for (NSInteger j = 3; i + j < length; j++) {
			[ingredients addObject:[jointString substringWithRange:NSMakeRange(i, j)]];
		}
	}
	
	NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"length" ascending:NO];
	_badPasswordIngredients = [ingredients sortedArrayUsingDescriptors:@[sortDescriptor]];
	
	return _badPasswordIngredients;
}


- (void)setDisplayedView:(NSView *)value {
	if (_displayedView != value) {
		if (_displayedView == _progressView) {
			[_progressIndicator stopAnimation:nil];
		}
		
		//[displayedView removeFromSuperview];
		//displayedView = value;
		if (value != nil) {
			[_sheetWindow setContentView:value];
			
			static BOOL	newKeyViewInitialized = NO;
			if (value == _genNewKeyView) {
				[self showConfirmPassword:NO animate:NO];
				if (!newKeyViewInitialized) {
					[self showAdvanced:NO animate:NO];
					newKeyViewInitialized = YES;
				}
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

- (void)setExportFormat:(NSInteger)value {
	_exportFormat = value;
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

- (void)setExportSecretKey:(BOOL)value {
	_exportSecretKey = value;
	
	NSSavePanel *panel = (id)_exportKeyOptionsView.window;
	NSString *filename = panel.nameFieldStringValue;
	
	NSString *basename = filename.stringByDeletingPathExtension;
	NSString *extension = filename.pathExtension;
	
	if ([_pubFilename isEqualToString:basename] || [_secFilename isEqualToString:basename]) {
		filename = [_exportSecretKey ? _secFilename : _pubFilename stringByAppendingPathExtension:extension];
		panel.nameFieldStringValue = filename;
	}
}

- (DBZxcvbn *)zxcvbn {
	if (_zxcvbn == nil) {
		// Lazy load DBZxcvbn.
		_zxcvbn = [DBZxcvbn new];
	}
	return _zxcvbn;
}



// Internal methods //
- (BOOL)generateFoundKeyDicts {
	NSMutableArray *dicts = [NSMutableArray arrayWithCapacity:_keys.count];
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
	
	GPGKeyAlgorithmNameTransformer *algorithmNameTransformer = [GPGKeyAlgorithmNameTransformer new];
	NSArray *gpgtoolsKeys = @[@"85E38F69046B44C1EC9FB07B76D78F0500D026C4"/*Team*/,
							  @"55AB1B128F18E135A522A12DDD1C907A50FE9D32"/*Alex*/,
							  @"608B00ABE1DAA3501C5FF91AE58271326F9F4937"/*Luke*/,
							  @"BDA498EAC51993F2FC97DAB2DA870C1346A957B0"/*Mento*/,
							  @"8C371C40B31DA620815E01A9779FEB1392CBBADF"/*Steve*/,
							  @"0A292B5F8A3C247F586F19D7E1AF518CC4B1DC35"/*kristof*/,
							  @"A9470AD17F1F693944AD2C5BB258CB1E8A3A21CA"/*business*/];
	BOOL showInvalidKeys = [[GPGOptions sharedOptions] boolForKey:@"KeyserverShowInvalidKeys"];
	
	NSDate *now = [NSDate date];
	
	
	for (GPGRemoteKey *key in _keys) {
		NSDictionary *stringAttributes = nil;
		
		BOOL isGpgtoolsKey = NO;
		if ([key respondsToSelector:@selector(fingerprint)]) {
			NSString *fingerprint = key.fingerprint;
			if (fingerprint.length == 40) {
				isGpgtoolsKey = [gpgtoolsKeys containsObject:fingerprint];
			} else {
				// Some keyservers do not return the fingerprint, but rather a key id.
				for (NSString *gpgtoolsKey in gpgtoolsKeys) {
					NSUInteger fingerprintLength = fingerprint.length;
					NSUInteger gpgtoolsKeyLength = gpgtoolsKey.length;
					if (gpgtoolsKeyLength >= fingerprintLength) {
						if ([[gpgtoolsKey substringFromIndex:gpgtoolsKeyLength - fingerprintLength] isEqualToString:fingerprint]) {
							isGpgtoolsKey = YES;
							break;
						}
					}
				}
			}
		}
		
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
	//Setzt minExpirationDate 7 Tage in die Zukunft.
	//Setzt maxExpirationDate 500 Jahre in die Zukunft.
	//Setzt expirationDate 4 Jahre in die Zukunft.
	
	NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDate *curDate = [NSDate date];
	
	[dateComponents setDay:7];
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
- (void)setDataFromMailAccounts {
	@autoreleasepool {
		
		if (NSAppKitVersionNumber < NSAppKitVersionNumber10_11) {
			NSString *userName = nil;
			NSMutableSet *mailAddresses = [NSMutableSet new];

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

			NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:@"description" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
			NSArray *sortedAddresses = [mailAddresses sortedArrayUsingDescriptors:@[descriptor]];

			self.emailAddresses = sortedAddresses;
			
			if (sortedAddresses.count > 0) {
				self.email = sortedAddresses[0];
			} else {
				self.email = @"";
			}
			
			self.name = userName ? userName : @"";
			
		} else {
			NSDictionary<NSString *, NSString *> *emailAddresses = [self getUserEmailAddresses];
			
			NSArray *addresses = emailAddresses.allKeys;
			NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:@"description" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
			NSArray *sortedAddresses = [addresses sortedArrayUsingDescriptors:@[descriptor]];
			
			self.emailAddresses = sortedAddresses;
			
			if (sortedAddresses.count > 0) {
				NSString *email = sortedAddresses[0];
				self.email = email;
				self.name = emailAddresses[email];
			} else {
				self.email = @"";
				self.name = @"";
			}
		}
		
		
	}
}
- (NSDictionary<NSString *, NSString *> *)getUserEmailAddresses {
	// Return a dictionary with the email-addresses as keys and the names as values.
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *directoryPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Accounts"];
	NSURL *directoryURL = [NSURL fileURLWithPath:directoryPath];
	
	
	NSMutableArray *accountFiles = [NSMutableArray array];
	NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:directoryURL includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey] options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:nil];
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^Accounts\\d+.sqlite$" options:0 error:nil];
	
	// Find current ~/Library/AccountsAccountsX.plist
	for (NSURL *fileURL in enumerator) {
		NSNumber *isDirectory = nil;
		[fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
		
		if (isDirectory.boolValue) {
			continue;
		}
		
		NSString *name = nil;
		[fileURL getResourceValue:&name forKey:NSURLNameKey error:nil];
		
		if ([regex firstMatchInString:name options:0 range:NSMakeRange(0, name.length)]) {
			[accountFiles addObject:name];
		}
	}
	
	if (accountFiles.count == 0) {
		NSLog(@"Unable to find Accounts.plist");
		return nil;
	}
	
	[accountFiles sortUsingComparator:^NSComparisonResult(NSString *str1, NSString *str2) {
		return [str2 compare:str1 options:NSNumericSearch];
	}];
	
	NSString *filename = accountFiles[0];
	NSString *path = [directoryPath stringByAppendingPathComponent:filename];
	
	
	
	NSMutableDictionary<NSString *, NSString *> *emailAddresses = [NSMutableDictionary dictionary];
	Class arrayClass = [NSArray class];
	Class dictClass = [NSDictionary class];
	Class stringClass = [NSString class];
	sqlite3 *db;
	
	
	if (sqlite3_open(path.UTF8String, &db) != SQLITE_OK) {
		sqlite3_close(db);
		NSLog(@"Unable to open Accounts.plist");
		return nil;
	}
	
	
	@try {
		NSString *sql = @"SELECT ZVALUE FROM ZACCOUNTPROPERTY WHERE ZKEY = 'EmailAliases'";
		sqlite3_stmt *statement;
		
		if (sqlite3_prepare_v2(db, sql.UTF8String, -1, &statement, nil) != SQLITE_OK) {
			NSLog(@"Unable to parse Accounts.plist: prepare");
			return nil;
		}

		// Iterate through all accounts.
		while (sqlite3_step(statement) == SQLITE_ROW) {
			
			// Get all aliases from this account.
			// aliases is a keyed archived NSDictionary and stored as a data blob in the db.
			const uint8_t *blob = sqlite3_column_blob(statement, 0);
			int length = sqlite3_column_bytes(statement, 0);
			
			NSData *data = [NSData dataWithBytes:blob length:length];
			NSArray *aliases = [NSKeyedUnarchiver unarchiveObjectWithData:data];
			
			if (![aliases isKindOfClass:arrayClass]) {
				NSLog(@"Unable to parse Accounts.plist: aliases");
				continue;
			}
			
			// Iterate through the aliases.
			for (NSDictionary *alias in aliases) {
				if (![alias isKindOfClass:dictClass]) {
					NSLog(@"Unable to parse Accounts.plist: alias");
					continue;
				}
				
				NSString *name = alias[@"DisplayName"];
				if (![name isKindOfClass:stringClass]) {
					name = @"";
				}
				
				NSArray *addresses = alias[@"EmailAddresses"];
				if (![addresses isKindOfClass:arrayClass]) {
					NSLog(@"Unable to parse Accounts.plist: addresses");
					continue;
				}
				
				for (NSDictionary *address in addresses) {
					if (![address isKindOfClass:dictClass]) {
						NSLog(@"Unable to parse Accounts.plist: address");
						continue;
					}
					
					NSString *emailAddress = address[@"EmailAddress"];
					if (![emailAddress isKindOfClass:stringClass] || emailAddress.length == 0) {
						NSLog(@"Unable to parse Accounts.plist: EmailAddress");
						continue;
					}
					
					if (emailAddresses[emailAddress].length == 0) {
						// Add the email address from the alias to the list of addresses.
						emailAddresses[emailAddress] = name;
					}
				}
			}
		}
		
	} @catch (NSException *exception) {
		NSLog(@"Unable to parse Accounts.plist: exception '%@'", exception);
	} @finally {
		sqlite3_close(db);
	}
	
	return [NSDictionary dictionaryWithDictionary:emailAddresses];
}





- (void)runAndWait {
	[_sheetLock lock];
	GPGDebugLog(@"SheetController runAndWait. modalWindow = '%@', sheetWindow = '%@'", _modalWindow, _sheetWindow);
	
	if (_modalWindow.isVisible) {
		[_modalWindow beginSheet:_sheetWindow completionHandler:^(NSModalResponse returnCode) {}];
		[NSApp runModalForWindow:_sheetWindow];
		[_modalWindow endSheet:_sheetWindow];
	} else {
		[_sheetWindow makeKeyAndOrderFront:self];
		[NSApp runModalForWindow:_sheetWindow];
	}
	[_sheetWindow orderOut:self];
	[_sheetLock unlock];
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

- (void)showConfirmPassword:(BOOL)show animate:(BOOL)animate {
	static NSUInteger fullHeight = 0;
	NSLayoutConstraint *constraint;
	
	[NSAnimationContext beginGrouping];
	
	if (show) {
		[[NSAnimationContext currentContext] setCompletionHandler:^{
			[self.sheetWindow recalculateKeyViewLoop];
		}];
	}
	
	
	if (animate) {
		constraint = self.genNewKey_confirmPasswordConstraint.animator;
	} else {
		constraint = self.genNewKey_confirmPasswordConstraint;
	}
	
	if (fullHeight == 0) {
		fullHeight = constraint.constant;
	}
	
	if (show == NO) {
		[self.sheetWindow endEditingFor:nil];
	}
	
	constraint.constant = show ? fullHeight : 0;
	
	for (NSControl *subview in self.genNewKey_confirmPasswordSubview.subviews) {
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
	
	_oldVolumeIndex = index;
	
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
	BOOL warned = NO;
	
	if (!self.passphrase) {
		self.passphrase = @"";
	}
	if (!self.confirmPassphrase) {
		self.confirmPassphrase = @"";
	}
	
	/*
	 * For the max password length, look in gnupg/agent/genkey.c "agent_ask_new_passphrase" for the pinentry_loopback call.
	 * The limit is the count of bytes, not the count of characters.
	 */
	if (self.passphrase.UTF8Length > 255) {
		NSRunAlertPanel(localized(@"CheckAlert_PassphraseTooLong_Title"), localized(@"CheckAlert_PassphraseTooLong_Message"), nil, nil, nil, 255);
		return NO;
	}
	
	if (![self.passphrase isEqualToString:self.confirmPassphrase]) {
		// Should never happen.
		NSRunAlertPanel(localized(@"Error"), localized(@"Password not equal"), nil, nil, nil);
		return NO;
	}
	
	if ([self.passphrase length] == 0) {
		warned = YES;
		if (NSRunAlertPanel(localized(@"CheckAlert_NoPassphrase_Title"),
							localized(@"CheckAlert_NoPassphrase_Message"),
							localized(@"CheckAlert_NoPassphrase_No"),
							localized(@"CheckAlert_NoPassphrase_Yes"), nil) == NSAlertDefaultReturn) {
			return NO;
		}
	} else {
		DBResult *result = [self.zxcvbn passwordStrength:self.passphrase];
		if (result.crackTime < 3600) {
			warned = YES;
			if (NSRunAlertPanel(localized(@"CheckAlert_PassphraseSimple_Title"),
								localized(@"CheckAlert_PassphraseSimple_Message"),
								localized(@"CheckAlert_PassphraseSimple_No"),
								localized(@"CheckAlert_PassphraseSimple_Yes"), nil) == NSAlertDefaultReturn) {
				return NO;
			}
		}
	}
	
	return YES;
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
		
		_sheetLock = [NSLock new];
		_progressSheetLock = [NSLock new];
		NSArray *objects;
		[[NSBundle mainBundle] loadNibNamed:@"ModalSheets" owner:self topLevelObjects:&objects];
		_topLevelObjects = objects;
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

- (NSString *)stringForObjectValue:(id)obj {
	return [obj description];
}

- (NSInteger)checkedValue:(NSInteger)value {
	if (value < _minKeyLength) {
		value = _minKeyLength;
	}
	if (value > _maxKeyLength) {
		value = _maxKeyLength;
	}
	return value;
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error {
	*obj = [NSString stringWithFormat:@"%li", (long)[self checkedValue:[string integerValue]]];
	return YES;
}

- (BOOL)isPartialStringValid:(NSString *)partialString newEditingString:(NSString **)newString errorDescription:(NSString **)error {
	if ([partialString rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet] options: NSLiteralSearch].length == 0) {
		return YES;
	} else {
		return NO;
	}
}

@end

@implementation GKSheetWindow
- (void)setContentView:(NSView *)aView {
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
@end





