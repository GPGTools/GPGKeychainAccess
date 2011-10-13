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

#import <Libmacgpg/Libmacgpg.h>


@interface KeychainController : NSObject <NSOutlineViewDelegate> {
    IBOutlet NSTextField *numberOfKeysLabel;
	IBOutlet NSOutlineView *keyTable;
	
	NSArray *keysSortDescriptors;
	NSArray *userIDsSortDescriptors;
	NSArray *subkeysSortDescriptors;
	
	
	NSMutableSet *allKeys; // Liste aller Schlüssel.
	NSSet *secretKeys;
	NSMutableArray *filteredKeyList; // Liste der momentan angezeigten Schlüssel.
	NSArray *filterStrings;
	
	BOOL showSecretKeysOnly;
	
	GPGController *gpgc;
}

@property (readonly) NSSet *secretKeys;
@property (readonly, retain) NSMutableArray *filteredKeyList;
@property (readonly, retain) NSMutableSet *allKeys;
@property (retain) NSArray *filterStrings;
@property (retain) NSArray *keysSortDescriptors;
@property (retain) NSArray *userIDsSortDescriptors;
@property (retain) NSArray *subkeysSortDescriptors;
@property BOOL showSecretKeysOnly;

+ (id)sharedInstance;


- (void)updateKeys:(NSObject <EnumerationList> *)keys withSigs:(BOOL)withSigs;
- (void)updateKeys:(NSObject <EnumerationList> *)keys;
- (void)asyncUpdateKeys:(NSObject <EnumerationList> *)keys;
- (void)asyncUpdateKey:(GPGKey *)key;
- (void)updateKey:(GPGKey *)key;


- (IBAction)updateFilteredKeyList:(id)sender;

- (BOOL)isKeyPassingFilterTest:(GPGKey *)key;



@end

@interface GPGKey (GKAExtension)
- (NSString *)type;
- (NSString *)longType;
@end


