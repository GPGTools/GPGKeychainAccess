/*
 Copyright © Roman Zechmeister, 2014
 
 Diese Datei ist Teil von GPG Keychain Access.
 
 GPG Keychain Access ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung von GPG Keychain Access erfolgt in der Hoffnung, daß es Ihnen 
 von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite 
 Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck. 
 Details finden Sie in der GNU General Public License.
 
 Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem 
 Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
*/

#import "Globales.h"


@class SheetController;


@interface ActionController : NSWindowController <GPGControllerDelegate> {
	GPGController *gpgc;
	SheetController *sheetController;
	NSSet *revCertCache;
	NSString *progressText;
	NSString *errorText;
	
	NSTreeController *keysController;
	NSArrayController *signaturesController;
	NSArrayController *subkeysController;
	NSArrayController *userIDsController;
	NSArrayController *photosController;
	NSOutlineView *keyTable;
	NSTableView *signaturesTable;
	NSTableView *userIDsTable;
	NSTableView *subkeysTable;
	
}

+ (id)sharedInstance;

- (NSSet *)selectedKeys;
- (void)addPhoto:(NSString *)path toKey:(GPGKey *)key;
- (void)importFromURLs:(NSArray *)urls;
- (void)importFromData:(NSData *)data;

- (void)cancelGPGOperation:(id)sender;


- (IBAction)generateNewKey:(id)sender;
- (IBAction)delete:(id)sender;
- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;
- (IBAction)cleanKey:(id)sender;
- (IBAction)minimizeKey:(id)sender;
- (IBAction)addPhoto:(id)sender;
- (IBAction)removePhoto:(id)sender;
- (IBAction)revokePhoto:(id)sender;
- (IBAction)setPrimaryPhoto:(id)sender;
- (IBAction)exportKey:(id)sender;
- (IBAction)importKey:(id)sender;
- (IBAction)addSignature:(id)sender;
- (IBAction)addSubkey:(id)sender;
- (IBAction)addUserID:(id)sender;
- (IBAction)changeExpirationDate:(id)sender;
- (IBAction)changePassphrase:(id)sender;
- (IBAction)removeSignature:(id)sender;
- (IBAction)removeSubkey:(id)sender;
- (IBAction)removeUserID:(id)sender;
- (IBAction)revokeSignature:(id)sender;
- (IBAction)revokeSubkey:(id)sender;
- (IBAction)revokeUserID:(id)sender;
- (IBAction)setDisabled:(id)sender;
- (IBAction)setPrimaryUserID:(id)sender;
- (IBAction)setTrust:(NSPopUpButton *)sender;
- (IBAction)deleteKey:(id)sender;
- (IBAction)refreshDisplayedKeys:(id)sender;
- (IBAction)sendKeysToServer:(id)sender;
- (IBAction)searchKeys:(id)sender;
- (IBAction)receiveKeys:(id)sender;
- (IBAction)refreshKeysFromServer:(id)sender;
- (IBAction)genRevokeCertificate:(id)sender;
- (IBAction)editAlgorithmPreferences:(id)sender;
- (IBAction)sendKeysPerMail:(id)sender;
- (BOOL)validateUserInterfaceItem:(id)anItem;


@end
