/*
 Copyright © Roman Zechmeister, 2013
 
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
    IBOutlet NSTreeController *keysController;
    IBOutlet NSArrayController *signaturesController;
    IBOutlet NSArrayController *subkeysController;
    IBOutlet NSArrayController *userIDsController;
	IBOutlet NSArrayController *photosController;
	IBOutlet NSOutlineView *keyTable;
	IBOutlet NSWindow *inspectorWindow;
	
	GPGController *gpgc;
	SheetController *sheetController;
	NSUndoManager *undoManager;
	
	NSString *progressText, *errorText;
}
@property (readonly) NSUndoManager *undoManager;
@property (assign) NSWindow *inspectorWindow;

+ (id)sharedInstance;


- (BOOL)validateUserInterfaceItem:(id)anItem;
- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;
- (IBAction)cleanKey:(id)sender;
- (IBAction)minimizeKey:(id)sender;
- (void)addPhoto:(NSString *)path toKey:(GPGKey *)key;
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
- (IBAction)setTrust:(NSPopUpButton *)sender;
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


- (NSSet *)selectedKeys;

- (void)importFromURLs:(NSArray *)urls;
- (void)importFromData:(NSData *)data;

- (void)cancelOperation:(id)sender;

@end
