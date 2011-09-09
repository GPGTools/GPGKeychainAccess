/*
 Copyright © Roman Zechmeister, 2011
 
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

#import <Libmacgpg/Libmacgpg.h>

enum {
	RunCmdNoKeyserverFound = 501, //Es wurde kein Schlüsselserver festgelegt.
	RunCmdIllegalProtocolType = 502,
	RunCmdNoKeyserverHelperFound = 503
} RunCmdReturnValue;

enum {
	RunServerCommandSearch,
	RunServerCommandSend,
	RunServerCommandGet
} RunServerCommandType;

enum {
	GKOpenSavePanelExportKeyAction = 1,
	GKOpenSavePanelImportKeyAction,
	GKOpenSavePanelAddPhotoAction,
	GKOpenSavePanelSaveRevokeCertificateAction
} GKOpenSavePanelAction;



@class SheetController;

@interface ActionController : NSWindowController {
    IBOutlet NSTreeController *keysController;
    IBOutlet NSArrayController *signaturesController;
    IBOutlet NSArrayController *subkeysController;
    IBOutlet NSArrayController *userIDsController;
	IBOutlet NSArrayController *photosController;
	IBOutlet NSOutlineView *keyTable;
	
	GPGController *gpgc;
}
- (BOOL)validateUserInterfaceItem:(id)anItem;
- (IBAction)copy:(id)sender;

- (IBAction)cleanKey:(id)sender;
- (IBAction)minimizeKey:(id)sender;
- (IBAction)addPhoto:(NSButton *)sender;
- (IBAction)removePhoto:(NSButton *)sender;
- (IBAction)revokePhoto:(NSButton *)sender;
- (IBAction)setPrimaryPhoto:(NSButton *)sender;
- (IBAction)exportKey:(id)sender;
- (IBAction)importKey:(id)sender;
- (IBAction)addSignature:(id)sender;
- (IBAction)addSubkey:(NSButton *)sender;
- (IBAction)addUserID:(NSButton *)sender;
- (IBAction)changeExpirationDate:(NSButton *)sender;
- (IBAction)changePassphrase:(NSButton *)sender;
- (IBAction)removeSignature:(NSButton *)sender;
- (IBAction)removeSubkey:(NSButton *)sender;
- (IBAction)removeUserID:(NSButton *)sender;
- (IBAction)revokeSignature:(NSButton *)sender;
- (IBAction)revokeSubkey:(NSButton *)sender;
- (IBAction)revokeUserID:(NSButton *)sender;
- (IBAction)setDisabled:(NSButton *)sender;
- (IBAction)setPrimaryUserID:(NSButton *)sender;
- (IBAction)setTrsut:(NSPopUpButton *)sender;
- (IBAction)generateNewKey:(id)sender;
- (IBAction)deleteKey:(id)sender;
- (IBAction)refreshDisplayedKeys:(id)sender;
- (IBAction)sendKeysToServer:(id)sender;
- (IBAction)searchKeys:(id)sender;
- (IBAction)receiveKeys:(id)sender;
- (IBAction)refreshKeysFromServer:(id)sender;
- (IBAction)showInspector:(id)sender;
- (IBAction)genRevokeCertificate:(id)sender;
- (IBAction)editAlgorithmPreferences:(id)sender;


- (NSSet *)selectedKeyInfos;

- (NSData *)exportKeys:(NSObject <EnumerationList> *)keys armored:(BOOL)armored allowSecret:(BOOL)allowSec fullExport:(BOOL)fullExport;
- (void)importFromURLs:(NSArray *)urls;
- (void)importFromData:(NSData *)data;
- (NSString *)importResultWithStatusText:(NSString *)statusText;

- (void)generateNewKeyWithName:(NSString *)name email:(NSString *)email comment:(NSString *)comment passphrase:(NSString *)passphrase type:(NSInteger)type length:(NSInteger)length daysToExpire:(NSInteger)daysToExpire;
- (void)addSubkeyForKeyInfo:(GPGKey *)keyInfo type:(NSInteger)type length:(NSInteger)length daysToExpire:(NSInteger)daysToExpire;
- (void)addUserIDForKeyInfo:(GPGKey *)keyInfo name:(NSString *)name email:(NSString *)email comment:(NSString *)comment;
- (void)addSignatureForKeyInfo:(GPGKey *)keyInfo andUserID:(NSString *)userID signKey:(NSString *)signFingerprint type:(NSInteger)type local:(BOOL)local daysToExpire:(NSInteger)daysToExpire;
- (void)changeExpirationDateForKeyInfo:(GPGKey *)keyInfo subkey:(GPGSubkey *)subkey daysToExpire:(NSInteger)daysToExpire;
- (NSMutableArray *)searchKeysWithPattern:(NSString *)pattern errorText:(NSString **)errText;
- (NSString *)receiveKeysWithIDs:(NSSet *)keyIDs;
- (void)addPhotoForKeyInfo:(GPGKey *)keyInfo photoPath:(NSString *)path;
- (void)deleteKeys:(NSObject <EnumerationList> *)keys withMode:(GPGDeleteKeyMode)mode;
- (NSSet *)keysInExportedData:(NSData *)data;
- (void)registerUndoForKeys:(NSObject <EnumerationList> *)keys withName:(NSString *)actionName;
- (void)registerUndoForKey:(NSObject *)key withName:(NSString *)actionName;
- (void)setDisabled:(BOOL)disabled forKeyInfos:(NSObject <EnumerationList> *)keys;
- (NSData *)genRevokeCertificateForKey:(GPGKey *)keyInfo;
- (void)editAlgorithmPreferencesForKey:(GPGKey *)keyInfo preferences:(NSArray *)userIDs;


@end
