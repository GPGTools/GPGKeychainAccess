/*
 Copyright © Roman Zechmeister, 2010
 
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

@class KeyInfo;

@interface KeychainController : NSObject {
    IBOutlet NSTextField *numberOfKeysLabel;
	
	NSArray *keyInfosSortDescriptors;
	NSArray *userIDsSortDescriptors;
	NSArray *subkeysSortDescriptors;
	
	
	NSMutableDictionary *keychain; //Liste der KeyInfos
	NSSet *secretKeys;
	
	NSMutableArray *filteredKeyList; //Liste der momentan angezeigten KeyInfos.
	NSArray *filterStrings;
	
	BOOL showSecretKeysOnly;
}
@property (readonly) NSMutableDictionary *keychain;
@property (retain) NSMutableArray *filteredKeyList;
@property (retain) NSArray *filterStrings;
@property BOOL showSecretKeysOnly;
@property (retain) NSArray *keyInfosSortDescriptors;
@property (retain) NSArray *userIDsSortDescriptors;
@property (retain) NSArray *subkeysSortDescriptors;
@property (copy) NSSet *secretKeys;



- (void)updateKeychain:(NSDictionary *)aDict;
- (void)initKeychains;
- (void)updateKeyInfos:(NSArray *)keyInfos;
- (void)asyncUpdateKeyInfos:(NSArray *)keyInfos;
- (void)updateKeyInfosWithDict:(NSDictionary *)aDict;


- (IBAction)updateFilteredKeyList:(id)sender;


- (BOOL)initGPG;
- (void)initKeychains;
- (BOOL)isKeyInfoPassingFilterTest:(KeyInfo *)keyInfo;
- (void)updateThread;

@end


@interface KeyAlgorithmTransformer : NSValueTransformer {}
@end

@interface GPGKeyStatusTransformer : NSValueTransformer {}
@end

@interface SplitFormatter : NSFormatter {
	NSInteger blockSize;
}
@property NSInteger blockSize;
@end


