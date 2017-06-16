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

#import "Globales.h"


@class KeyLengthFormatter;


typedef enum {
	SheetTypeNoSheet = 0,
	SheetTypeShowResult,
	SheetTypeNewKey,
	SheetTypeSearchKeys,
	SheetTypeReceiveKeys,
	SheetTypeShowFoundKeys,
	SheetTypeExpirationDate,
	SheetTypeAddUserID,
	SheetTypeAddSubkey,
	SheetTypeAddSignature,
	SheetTypeSavePanel,
	SheetTypeOpenPanel,
	SheetTypeExportKey,
	SheetTypeOpenPhotoPanel,
	SheetTypeAlgorithmPreferences,
	SheetTypeSelectVolume
} SheetType;

enum {
	SheetSuppressionButton = 0x400
};


@interface SheetController : NSObject <NSOpenSavePanelDelegate, NSTabViewDelegate> {
	NSView *displayedView;
	NSInteger clickedButton;
	NSView *oldDisplayedView;
	NSLock *sheetLock, *progressSheetLock;
	NSInteger numberOfProgressSheets; //Anzahl der angeforderten progressSheets.
	
	NSString *progressText, *msgText, *name, *email, *comment, *passphrase, *confirmPassphrase, *pattern, *title;
	NSString *_pubFilename, *_secFilename;
	BOOL hasExpirationDate, exportSecretKey, localSig, allowEdit;
	NSDate *expirationDate, *minExpirationDate, *maxExpirationDate;
	NSArray *algorithmPreferences, *keys, *emailAddresses, *secretKeys, *availableLengths, *allowedFileTypes;
	NSInteger exportFormat, keyType, sigType, length, sheetType;
	NSArray *foundKeyDicts;
	GPGKey *secretKey;
	NSURL *URL;
	NSArray *URLs;
	BOOL hideExtension;
	NSIndexSet *selectedVolumeIndexes;
	NSUInteger oldVolumeIndex;
	NSArray *topLevelObjects;
}

@property (assign) IBOutlet NSWindow *sheetWindow;
@property (assign) IBOutlet NSView *sheetView;

@property (assign) IBOutlet KeyLengthFormatter *keyLengthFormatter;
@property (assign) IBOutlet NSProgressIndicator *progressIndicator;
@property (assign) IBOutlet NSArrayController *foundKeysController;
@property (assign) IBOutlet NSArrayController *secretKeysController;


@property (assign) IBOutlet NSView *exportKeyOptionsView;

//Views die im Sheet angezeigt werden können.
@property (assign) IBOutlet NSView *progressView;
@property (assign) IBOutlet NSView *genNewKeyView;
@property (assign) IBOutlet NSView *genNewKey_advancedSubview;
@property (assign) IBOutlet NSLayoutConstraint *genNewKey_advancedConstraint;
@property (assign) IBOutlet NSView *generateSubkeyView;
@property (assign) IBOutlet NSView *generateUserIDView;
@property (assign) IBOutlet NSLayoutConstraint *generateUserID_CommentConstraint;
@property (assign) IBOutlet NSView *generateSignatureView;
@property (assign) IBOutlet NSView *changeExpirationDateView;
@property (assign) IBOutlet NSView *searchKeysView;
@property (assign) IBOutlet NSView *foundKeysView;
@property (assign) IBOutlet NSView *receiveKeysView;
@property (assign) IBOutlet NSView *resultView;
@property (assign) IBOutlet NSView *editAlgorithmPreferencesView;
@property (assign) IBOutlet NSView *selectVolumeView;







@property (nonatomic, strong) NSString *progressText, *msgText, *name, *email, *comment, *passphrase, *confirmPassphrase, *pattern, *title;
@property (nonatomic) BOOL hasExpirationDate, exportSecretKey, localSig, allowEdit;
@property (nonatomic, strong) NSDate *expirationDate, *minExpirationDate, *maxExpirationDate;
@property (nonatomic, strong) NSArray *algorithmPreferences, *keys, *emailAddresses, *secretKeys, *availableLengths, *allowedFileTypes;
@property (nonatomic) NSInteger exportFormat, keyType, sigType, length, sheetType;
@property (nonatomic, readonly, strong) NSArray *foundKeyDicts;
@property (nonatomic, readonly) NSInteger daysToExpire;
@property (nonatomic, strong) GPGKey *secretKey;
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, readonly, strong) NSArray *URLs;
@property (nonatomic, readonly) BOOL hideExtension, enableOK;
@property (nonatomic, strong, readonly) NSArray *volumes;
@property (nonatomic, strong) NSIndexSet *selectedVolumeIndexes;
@property (nonatomic, strong, readonly) NSDictionary *result;
@property (nonatomic, readonly) BOOL disableUserIDCommentsField;



- (NSInteger)runModal;
- (NSInteger)runModalForWindow:(NSWindow *)window;
- (void)errorSheetWithMessageText:(NSString *)messageText infoText:(NSString *)infoText;
- (NSInteger)alertSheetForWindow:(NSWindow *)window messageText:(NSString *)messageText infoText:(NSString *)infoText defaultButton:(NSString *)button1 alternateButton:(NSString *)button2 otherButton:(NSString *)button3 suppressionButton:(NSString *)suppressionButton;
- (NSInteger)alertSheetForWindow:(NSWindow *)window messageText:(NSString *)messageText infoText:(NSString *)infoText defaultButton:(NSString *)button1 alternateButton:(NSString *)button2 otherButton:(NSString *)button3 suppressionButton:(NSString *)suppressionButton customize:(void (^)(NSAlert *))customize;
- (NSInteger)alertSheetForWindow:(NSWindow *)window messageText:(NSString *)messageText infoText:(NSString *)infoText defaultButton:(NSString *)button1 alternateButton:(NSString *)button2 otherButton:(NSString *)button3 suppressionButton:(NSString *)suppressionButton cancelButton:(NSString *)cancelButton customize:(void (^)(NSAlert *))customize;
- (NSInteger)alertSheetWithTitle:(NSString *)title message:(NSString *)message defaultButton:(NSString *)button1 alternateButton:(NSString *)button2 otherButton:(NSString *)button3 suppressionButton:(NSString *)suppressionButton;

+ (id)sharedInstance;


- (BOOL)showProgressSheet;
- (BOOL)endProgressSheet;

- (IBAction)buttonClicked:(NSButton *)sender;
- (IBAction)advancedButton:(NSButton *)sender;

@end





@interface KeyLengthFormatter : NSFormatter {
	NSInteger minKeyLength;
	NSInteger maxKeyLength;
}
@property NSInteger minKeyLength;
@property NSInteger maxKeyLength;
- (NSInteger)checkedValue:(NSInteger)value;
@end

@interface GKSheetWindow : NSPanel
@end
