#import <Libmacgpg/Libmacgpg.h>

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
	SheetTypeAlgorithmPreferences
} SheetType;

enum {
	SheetSuppressionButton = 0x400
};


@interface SheetController : NSObject <NSOpenSavePanelDelegate, NSTabViewDelegate> {
	IBOutlet NSWindow *sheetWindow;
	IBOutlet NSView *sheetView;
	
	IBOutlet KeyLengthFormatter *keyLengthFormatter;
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSArrayController *foundKeysController;
	IBOutlet NSArrayController *secretKeysController;
	
	IBOutlet NSView *exportKeyOptionsView;

	//Views die im Sheet angezeigt werden können.
	IBOutlet NSView *progressView;
	IBOutlet NSView *errorView;
	IBOutlet NSView *newKeyView;
	IBOutlet NSView *newKey_passphraseSubview;
	IBOutlet NSView *newKey_topSubview;
	IBOutlet NSView *generateSubkeyView;
	IBOutlet NSView *generateUserIDView;
	IBOutlet NSView *generateSignatureView;
	IBOutlet NSView *changeExpirationDateView;
	IBOutlet NSView *searchKeysView;
	IBOutlet NSView *foundKeysView;
	IBOutlet NSView *receiveKeysView;
	IBOutlet NSView *resultView;
	IBOutlet NSView *editAlgorithmPreferencesView;

	
	NSInteger keyType;
	NSInteger exportFormat;
	
	
	NSView *displayedView;
	NSInteger clickedButton;
	NSView *oldDisplayedView;
	NSLock *sheetLock, *progressSheetLock;
	NSInteger numberOfProgressSheets; //Anzahl der angeforderten progressSheets.
}

@property (retain) NSString *progressText, *errorText, *msgText, *name, *email, *comment, *passphrase, *confirmPassphrase, *pattern, *title;
@property BOOL hasExpirationDate, allowSecretKeyExport, localSig, allowEdit;
@property (retain) NSDate *expirationDate, *minExpirationDate, *maxExpirationDate;
@property (retain) NSArray *algorithmPreferences, *keys, *emailAddresses, *secretKeys, *availableLengths, *allowedFileTypes;
@property NSInteger exportFormat, keyType, sigType, length, sheetType;
@property (readonly, retain) NSArray *foundKeyDicts;
@property (readonly) NSInteger daysToExpire;
@property (retain) GPGKey *secretKey;
@property (readonly, retain) NSURL *URL;
@property (readonly, retain) NSArray *URLs;


- (NSInteger)runModal;
- (NSInteger)runModalForWindow:(NSWindow *)window;
- (NSInteger)alertSheetForWindow:(NSWindow *)window messageText:(NSString *)messageText infoText:(NSString *)infoText defaultButton:(NSString *)button1 alternateButton:(NSString *)button2 otherButton:(NSString *)button3 suppressionButton:(NSString *)suppressionButton;

+ (id)sharedInstance;


- (void)showProgressSheet;
- (void)endProgressSheet;
- (void)showErrorSheet;

- (IBAction)buttonClicked:(NSButton *)sender;

@end





@interface KeyLengthFormatter : NSFormatter {
	NSInteger minKeyLength;
	NSInteger maxKeyLength;
}
@property NSInteger minKeyLength;
@property NSInteger maxKeyLength;
- (NSInteger)checkedValue:(NSInteger)value;
@end
