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

@interface KeychainController : NSObject <NSOutlineViewDelegate> {
    IBOutlet NSTextField *numberOfKeysLabel;
	IBOutlet NSOutlineView *keyTable;
	IBOutlet NSTreeController *treeController;
	
	NSArray *keysSortDescriptors;
	NSArray *userIDsSortDescriptors;
	NSArray *subkeysSortDescriptors;
	
	
	NSSet *secretKeys;
	NSArray *filteredKeyList; // Liste der momentan angezeigten Schlüssel.
	NSArray *filterStrings;
	
	NSArray *_selectionIndexPaths;
	
	BOOL showSecretKeysOnly;
	
	NSSet *oldAllKeys;
	
	BOOL userChangingSelection;
}

@property (weak, readonly) NSSet *secretKeys;
@property (weak, readonly) NSArray *filteredKeyList;
@property (weak, readonly) NSSet *allKeys;
@property (strong) NSArray *filterStrings;
@property (strong) NSArray *keysSortDescriptors;
@property (strong) NSArray *userIDsSortDescriptors;
@property (strong) NSArray *subkeysSortDescriptors;
@property (nonatomic, strong) NSArray *selectionIndexPaths;
@property BOOL showSecretKeysOnly;
@property (weak, readonly) GPGKey *defaultKey;

+ (instancetype)sharedInstance;



- (IBAction)updateFilteredKeyList:(id)sender;
- (void)selectRow:(NSInteger)row;



@end


