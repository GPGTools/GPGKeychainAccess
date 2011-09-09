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


@interface KeychainController : NSObject {
    IBOutlet NSTextField *numberOfKeysLabel;
	IBOutlet NSOutlineView *keyTable;
	
	NSArray *keyInfosSortDescriptors;
	NSArray *userIDsSortDescriptors;
	NSArray *subkeysSortDescriptors;
	
	
	//NSMutableDictionary *keychain; //Liste der KeyInfos
	//NSSet *secretKeys;
	NSMutableSet *allKeys;
	
	NSMutableArray *filteredKeyList; //Liste der momentan angezeigten KeyInfos.
	NSArray *filterStrings;
	
	BOOL showSecretKeysOnly;
}

//@property (readonly) NSMutableDictionary *keychain;
@property (retain) NSMutableArray *filteredKeyList;
@property (retain) NSArray *filterStrings;
@property BOOL showSecretKeysOnly;
@property (retain) NSArray *keyInfosSortDescriptors;
@property (retain) NSArray *userIDsSortDescriptors;
@property (retain) NSArray *subkeysSortDescriptors;
//@property (copy) NSSet *secretKeys;



- (void)initKeychains;
- (void)updateKeyInfos:(NSObject <EnumerationList> *)keyInfos withSigs:(BOOL)withSigs;
- (void)updateKeyInfos:(NSObject <EnumerationList> *)keyInfos;
- (void)asyncUpdateKeyInfos:(NSObject <EnumerationList> *)keyInfos;
- (void)updateKeyInfosWithDict:(NSDictionary *)aDict;
- (void)asyncUpdateKeyInfo:(GPGKey *)keyInfo;
- (void)updateKeyInfo:(GPGKey *)keyInfo;


- (IBAction)updateFilteredKeyList:(id)sender;

- (NSSet *)fingerprintsForKeyIDs:(NSSet *)keys;

- (BOOL)initGPG;
- (BOOL)isKeyInfoPassingFilterTest:(GPGKey *)keyInfo;
- (void)updateThread;


@end


@interface KeyAlgorithmTransformer : NSValueTransformer {}
@end

@interface GPGKeyStatusTransformer : NSValueTransformer {}
@end

@interface GPGKey (GKAExtension)
- (NSString *)type;
- (NSString *)longType;
@end


