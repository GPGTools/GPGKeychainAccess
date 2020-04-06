/*
 Copyright © Roman Zechmeister, 2020
 
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
	SheetTypeUploadKeys,
	SheetTypeSelectVolume
} SheetType;

enum {
	SheetSuppressionButton = 0x400
};




@interface SheetController : NSObject
@property (nonatomic, strong) NSString *progressText, *msgText, *name, *email, *comment, *passphrase, *confirmPassphrase, *pattern, *title;
@property (nonatomic, strong) NSString *progressTitle;
@property (nonatomic) BOOL hasExpirationDate, exportSecretKey, allowEdit, publish, suppress;
@property (nonatomic, strong) NSDate *expirationDate, *minExpirationDate, *maxExpirationDate;
@property (nonatomic, strong) NSArray *algorithmPreferences, *keys, *emailAddresses, *secretKeys, *availableLengths, *allowedFileTypes;
@property (nonatomic) NSInteger exportFormat, keyType, length, sheetType;
@property (nonatomic, strong, readonly) NSArray *foundKeyDicts;
@property (nonatomic, readonly) NSInteger daysToExpire;
@property (nonatomic, strong) GPGKey *secretKey;
@property (nonatomic, strong) GPGKey *publicKey;
@property (nonatomic, strong) NSArray *userIDs;
@property (nonatomic, strong) NSArray *selectedUserIDs;
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, strong, readonly) NSArray *URLs;
@property (nonatomic, readonly) BOOL hideExtension, enableOK;
@property (nonatomic, strong, readonly) NSArray *volumes;
@property (nonatomic, strong) NSIndexSet *selectedVolumeIndexes;
@property (nonatomic, strong, readonly) NSDictionary *result;
@property (nonatomic, readonly) BOOL disableUserIDCommentsField;
@property (nonatomic, readonly) double passwordStrength;
@property (nonatomic, readonly) NSInteger clickedButton;



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

@end


