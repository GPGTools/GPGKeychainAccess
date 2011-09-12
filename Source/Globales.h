/*
 Copyright © Roman Zechmeister, 2011
 
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

@class KeychainController;
@class ActionController;

extern NSString *GPG_PATH;
extern NSInteger GPG_VERSION;
extern KeychainController *keychainController;
extern ActionController *actionController;
extern NSWindow *mainWindow;
extern NSWindow *inspectorWindow;
extern NSUndoManager *undoManager;
extern BOOL useUndo;




NSInteger getDaysToExpire(NSDate *expirationDate);

NSString* dataToString(NSData *data);
NSData* stringToData(NSString *string);

NSString* getShortKeyID(NSString *keyID);

NSSet* keyIDsFromString(NSString *string);

BOOL containsPGPKeyBlock(NSString *string);


int hexToByte (const char *text);
NSString *unescapeString(NSString *string);

#define NotImplementedAlert NSRunAlertPanel(@"Noch nicht implementiert", @"", @"OK", nil, nil)

#define localized(key) [[NSBundle mainBundle] localizedStringForKey:(key) value:nil table:nil]




