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

@class KeychainController;
@class ActionController;

extern NSString *GPG_PATH;
extern NSString *GPG_AGENT_PATH;
extern NSInteger GPG_VERSION;
extern KeychainController *keychainController;
extern ActionController *actionController;
extern NSWindow *mainWindow;
extern NSWindow *inspectorWindow;
extern NSUndoManager *undoManager;
extern BOOL useUndo;


typedef enum {
    GPGValidityUnknown   = 0,
    GPGValidityUndefined = 1,
    GPGValidityNever     = 2,
    GPGValidityMarginal  = 3,
    GPGValidityFull      = 4,
    GPGValidityUltimate  = 5
} GPGValidity;

typedef enum {
    GPG_RSAAlgorithm                =  1,
    GPG_RSAEncryptOnlyAlgorithm     =  2,
    GPG_RSASignOnlyAlgorithm        =  3,
    GPG_ElgamalEncryptOnlyAlgorithm = 16,
    GPG_DSAAlgorithm                = 17,
    GPG_EllipticCurveAlgorithm      = 18,
    GPG_ECDSAAlgorithm              = 19,
    GPG_ElgamalAlgorithm            = 20,
    GPG_DiffieHellmanAlgorithm      = 21
} GPGPublicKeyAlgorithm;


NSSet* keyInfoSet(NSArray *keyInfos);
NSInteger getDaysToExpire(NSDate *expirationDate);

NSString* dataToString(NSData *data);
NSData* stringToData(NSString *string);

NSString* getShortKeyID(NSString *keyID);

NSSet* keyIDsFromString(NSString *string);

BOOL containsPGPKeyBlock(NSString *string);

BOOL isGpgAgentRunning();

int hexToByte (const char *text);
NSString *unescapeString(NSString *string);

#define NotImplementedAlert NSRunAlertPanel(@"Noch nicht implementiert", @"", @"OK", nil, nil)

#define localized(key) [[NSBundle mainBundle] localizedStringForKey:(key) value:nil table:nil]



@protocol GKEnumerationList <NSFastEnumeration>
- (NSUInteger)count;
@end
@interface NSArray (KeyList) <GKEnumerationList>
@end
@interface NSSet (KeyList) <GKEnumerationList>
@end



