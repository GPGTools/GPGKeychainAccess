#import <Libmacgpg/Libmacgpg.h>


typedef enum {
	NoAction = 0,
	NewKeyAction,
	AddSubkeyAction,
	AddUserIDAction,
	AddSignatureAction,
	ChangeExpirationDateAction,
	SearchKeysAction,
	ReceiveKeysAction,
	ShowFoundKeysAction,
	AlgorithmPreferencesAction
} SheetAction;

@interface KeyLengthFormatter : NSFormatter {
	NSInteger minKeyLength;
	NSInteger maxKeyLength;
}
@property NSInteger minKeyLength;
@property NSInteger maxKeyLength;
- (NSInteger)checkedValue:(NSInteger)value;
@end




@interface SheetController2 : NSObject <NSOpenSavePanelDelegate> {

	SheetAction currentAction;
	
	//Objekte für die XXX_Action Methoden.
	GPGKey *myKey;
	GPGSubkey *mySubkey;
	NSString *myString;
	
		
	
	NSInteger lastReturnCode;
	
	

	
	NSView *displayedView;
}



@property (retain) GPGKey *myKey;
@property (retain) NSString *myString;
@property (retain) GPGSubkey *mySubkey;




//@property (copy) NSArray *secretKeyFingerprints;




- (IBAction)okButton:(id)sender;
- (IBAction)cancelButton:(id)sender;


+ (id)sharedInstance;
- (void)addSubkey:(GPGKey *)key;
- (void)addUserID:(GPGKey *)key;
- (void)addSignature:(GPGKey *)key userID:(NSString *)userID;
- (void)changeExpirationDate:(GPGKey *)key subkey:(GPGSubkey *)subkey;
- (void)searchKeys;
- (void)searchKeys_Action;
- (void)showFoundKeys:(NSArray *)keys;
- (void)receiveKeys;
- (void)receiveKeys_Action:(NSSet *)keyIDs;
- (void)generateNewKey;
- (void)algorithmPreferences:(GPGKey *)key editable:(BOOL)editable;
- (void)algorithmPreferences_Action;

- (void)addPhoto:(GPGKey *)key;
- (void)importKey;
- (void)exportKeys:(NSSet *)keys;

- (void)genRevokeCertificateForKey:(GPGKey *)key;


- (void)showResult:(NSString *)text;
- (void)showResultText:(NSString *)text;





- (NSInteger)alertSheetForWindow:(NSWindow *)window messageText:(NSString *)messageText infoText:(NSString *)infoText defaultButton:(NSString *)button1 alternateButton:(NSString *)button2 otherButton:(NSString *)button3;



- (void)showProgressSheet;
- (void)endProgressSheet;


@end



