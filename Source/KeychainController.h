/*
 Copyright © Roman Zechmeister, 2017
 
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

typedef BOOL (^keyUpdateCallback)(NSArray *keys);

@interface KeychainController : NSObject <NSTableViewDelegate, NSTableViewDataSource> {
    IBOutlet NSTextField *numberOfKeysLabel;
	IBOutlet NSTableView *keyTable;
	IBOutlet NSArrayController *keysController;
	
	NSArray *keysSortDescriptors;
	NSArray *userIDsSortDescriptors;
	NSArray *subkeysSortDescriptors;
	
	
	NSArray *filteredKeyList; // Liste der momentan angezeigten Schlüssel.
	NSString *_searchString;
	
	NSIndexSet *_selectionIndexes;
	
	BOOL showSecretKeysOnly;
	
	NSSet *oldAllKeys;

	NSMutableArray *keyUpdateCallbacks;
}

@property (weak, readonly) NSSet *secretKeys;
@property (weak, readonly) NSArray *filteredKeyList;
@property (weak, readonly) NSSet *allKeys;
@property (readonly) NSString *noKeysFoundMessage;
@property (strong) NSString *searchString;
@property (strong) NSArray *keysSortDescriptors;
@property (strong) NSArray *userIDsSortDescriptors;
@property (strong) NSArray *subkeysSortDescriptors;
@property (nonatomic, strong) NSIndexSet *selectionIndexes;
@property BOOL showSecretKeysOnly;
@property (weak, readonly) GPGKey *defaultKey;

+ (instancetype)sharedInstance;



- (void)selectKeys:(NSSet *)keys;
- (void)keysDidChange:(NSArray *)keys;

- (void)addKeyUpdateCallback:(keyUpdateCallback)callback;
- (void)removeKeyUpdateCallback:(keyUpdateCallback)callback;

@end


