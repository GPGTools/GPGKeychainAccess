#import <Libmacgpg/Libmacgpg.h>

@class KeyLengthFormatter;


typedef enum {
	SheetTypeNoSheet = 0,
	SheetTypeNewKey,
	SheetTypeSearchKeys,
	SheetTypeReceiveKeys
} SheetType;

enum {
	SheetSuppressionButton = 0x400
};


@interface SheetController : NSObject <NSOpenSavePanelDelegate> {
	IBOutlet NSWindow *sheetWindow;
	IBOutlet NSView *sheetView;
	
	IBOutlet KeyLengthFormatter *keyLengthFormatter;
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSArrayController *foundKeysController;
	
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
	
	
	NSView *displayedView;
	NSInteger clickedButton;
	NSView *oldDisplayedView;
	NSLock *sheetLock, *progressSheetLock;
	NSInteger numberOfProgressSheets; //Anzahl der angeforderten progressSheets.
}

@property (retain) NSString *progressText, *errorText, *msgText, *name, *email, *comment, *passphrase, *confirmPassphrase, *pattern;
@property BOOL hasExpirationDate, allowSecretKeyExport, localSig, allowEdit;
@property (retain) NSDate *expirationDate, *minExpirationDate, *maxExpirationDate;
@property (retain) NSArray *userIDs, *foundKeys, *emailAddresses, *secretKeys, *availableLengths;
@property NSInteger exportFormat, secretKeyId, keyType, sigType, length, sheetType;


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
