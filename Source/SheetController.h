
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
	IBOutlet NSView *newKeyView;
	IBOutlet NSView *newKey_passphraseSubview;
	IBOutlet NSView *newKey_advancedSubview;
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

	
	
	
	NSView *displayedView;
	NSInteger clickedButton;
	NSView *oldDisplayedView;
	NSLock *sheetLock, *progressSheetLock;
	NSInteger numberOfProgressSheets; //Anzahl der angeforderten progressSheets.
	
	NSString *progressText, *msgText, *name, *email, *comment, *passphrase, *confirmPassphrase, *pattern, *title;
	BOOL hasExpirationDate, allowSecretKeyExport, localSig, allowEdit, autoUpload;
	NSDate *expirationDate, *minExpirationDate, *maxExpirationDate;
	NSArray *algorithmPreferences, *keys, *emailAddresses, *secretKeys, *availableLengths, *allowedFileTypes;
	NSInteger exportFormat, keyType, sigType, length, sheetType;
	NSArray *foundKeyDicts;
	GPGKey *secretKey;
	NSURL *URL;
	NSArray *URLs;
	NSWindow *modalWindow;
}

@property (retain) NSString *progressText, *msgText, *name, *email, *comment, *passphrase, *confirmPassphrase, *pattern, *title;
@property BOOL hasExpirationDate, allowSecretKeyExport, localSig, allowEdit, autoUpload;
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
- (void)errorSheetWithmessageText:(NSString *)messageText infoText:(NSString *)infoText;
- (NSInteger)alertSheetForWindow:(NSWindow *)window messageText:(NSString *)messageText infoText:(NSString *)infoText defaultButton:(NSString *)button1 alternateButton:(NSString *)button2 otherButton:(NSString *)button3 suppressionButton:(NSString *)suppressionButton;

+ (id)sharedInstance;


- (void)showProgressSheet;
- (void)endProgressSheet;

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
