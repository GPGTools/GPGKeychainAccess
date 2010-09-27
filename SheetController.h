/*
 Copyright © Roman Zechmeister, 2010
 
 Dieses Programm ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung dieses Programms erfolgt in der Hoffnung, daß es Ihnen 
 von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite 
 Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck. 
 Details finden Sie in der GNU General Public License.
 
 Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem 
 Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
*/

#import <Cocoa/Cocoa.h>

@class KeyInfo;
@class KeyInfo_Subkey;

typedef enum {
	NewKeyAction,
	AddSubkeyAction,
	AddUserIDAction,
	AddSignatureAction,
	ChangeExpirationDateAction,
	SearchKeysAction,
	ReceiveKeysAction
} SheetAction;

@interface KeyLengthFormatter : NSFormatter {
	NSInteger minKeyLength;
	NSInteger maxKeyLength;
}
@property NSInteger minKeyLength;
@property NSInteger maxKeyLength;
- (NSInteger)checkedValue:(NSInteger)value;
@end




@interface SheetController : NSObject {

	SheetAction currentAction;
	
	//Objekte für die XXX_Action Methoden.
	KeyInfo *myKeyInfo;
	KeyInfo_Subkey *mySubkey;
	NSString *myString;
	
	
	//Für Öffnen- und Speichern-Sheets.
	IBOutlet NSView *exportKeyOptionsView;
	
	NSSavePanel *savePanel;
	NSOpenPanel *openPanel;
	
	BOOL allowSecretKeyExport;
	NSInteger exportFormat;
	
	
	
	IBOutlet KeyLengthFormatter *keyLengthFormatter;
	IBOutlet NSWindow *sheetWindow;
	IBOutlet NSView *sheetView;
	
	//Views die im Fenster angezeigt werden können.
	IBOutlet NSView *progressView;
	IBOutlet NSView *newKeyView;
	IBOutlet NSView *generateSubkeyView;
	IBOutlet NSView *generateUserIDView;
	IBOutlet NSView *generateSignatureView;
	IBOutlet NSView *changeExpirationDateView;
	IBOutlet NSView *searchKeysView;
	IBOutlet NSView *foundKeysView;
	IBOutlet NSView *receiveKeysView;
	
	
	IBOutlet NSProgressIndicator *progressIndicator;
	NSView *displayedView;
	
	
	NSString *msgText;
	NSArray *emailAddresses;
	NSArray *secretKeys;
	NSArray *secretKeyFingerprints;
	NSInteger secretKeyId;
	
	NSString *pattern;
	NSString *name;
	NSString *email;
	NSString *comment;
	NSInteger keyType;
	NSInteger sigType;
	BOOL hasExpirationDate;
	NSDate *expirationDate;
	NSDate *minExpirationDate;
	NSDate *maxExpirationDate;
	NSArray *availableLengths;
	NSInteger length;
	BOOL localSig;
	
}

@property BOOL allowSecretKeyExport;
@property NSInteger exportFormat;


@property (retain) KeyInfo *myKeyInfo;
@property (retain) NSString *myString;
@property (retain) KeyInfo_Subkey *mySubkey;


@property (retain) NSString *msgText;
@property (retain) NSArray *emailAddresses;
@property (copy) NSArray *secretKeys;
@property (copy) NSArray *secretKeyFingerprints;
@property NSInteger secretKeyId;

@property (retain) NSString *pattern;
@property (retain) NSString *name;
@property (retain) NSString *email;
@property (retain) NSString *comment;
@property (retain) NSArray *availableLengths;
@property NSInteger keyType;
@property NSInteger sigType;
@property NSInteger length;
@property BOOL hasExpirationDate;
@property (retain) NSDate *expirationDate;
@property (retain) NSDate *minExpirationDate;
@property (retain) NSDate *maxExpirationDate;
@property BOOL localSig;


@property (assign) NSView *displayedView;


+ (id)sharedInstance;
- (void)addSubkey:(KeyInfo *)keyInfo;
- (void)addUserID:(KeyInfo *)keyInfo;
- (void)addSignature:(KeyInfo *)keyInfo userID:(NSString *)userID;
- (void)changeExpirationDate:(KeyInfo *)keyInfo subkey:(KeyInfo_Subkey *)subkey;
- (void)searchKeys;
- (void)searchKeys_Action;
- (void)showFoundKeysWithText:(NSString *)text;
- (void)receiveKeys;
- (void)receiveKeys_Action;
- (void)generateNewKey;

- (void)addPhoto:(KeyInfo *)keyInfo;
- (void)importKey;
- (void)exportKeys:(NSSet *)keyInfos;



- (void)runSheetForWindow:(NSWindow *)window;
- (void)closeSheet;
- (void)setStandardExpirationDates;
- (void)setDataFromAddressBook;


- (IBAction)okButton:(id)sender;
- (IBAction)cancelButton:(id)sender;
- (IBAction)backButton:(id)sender;

- (BOOL)checkName;
- (BOOL)checkEmailMustSet:(BOOL)mustSet;
- (BOOL)checkComment;


- (void)openSavePanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(NSDictionary *)contextInfo;
- (BOOL)panel:(NSOpenPanel *)sender validateURL:(NSURL *)url error:(NSError **)outError;

@end



