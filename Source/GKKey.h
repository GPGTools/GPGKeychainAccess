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

#import "GKUserID.h"
#import "GKSubkey.h"
#import "GKKeySignature.h"
#import "GKPhotoID.h"


typedef enum { 
    GPGKeyStatus_Invalid = 8,
    GPGKeyStatus_Revoked = GPGKeyStatus_Invalid << 1,
    GPGKeyStatus_Expired = GPGKeyStatus_Revoked << 1,
    GPGKeyStatus_Disabled = GPGKeyStatus_Expired << 1
} GPGKeyStatus;



@interface GKKey : NSObject {
	NSMutableArray *children;
	NSMutableArray *subkeys;
	NSMutableArray *userIDs;
	NSMutableArray *photos;
	
	NSString *textForFilter; //In diesem String stehen die verschiedenen Informationen über den Schlüssel, damit das Filtern schnell funktioniert.
	
	
	GKUserID *primaryUserID;
	NSInteger subkeyCount;
	
	
	NSString *fingerprint;
	NSString *keyID;
	NSString *shortKeyID;
	
	GPGPublicKeyAlgorithm algorithm;
	unsigned int length;
	NSCalendarDate *creationDate;
	NSCalendarDate *expirationDate;
	
	GPGValidity ownerTrust;
	GPGValidity validity;
	BOOL expired;
	BOOL disabled;
	BOOL invalid;
	BOOL revoked;
	
	BOOL secret;
}

+ (void)colonListing:(NSString *)colonListing toArray:(NSArray **)array andFingerprints:(NSArray **)fingerprints;
+ (NSSet *)fingerprintsFromColonListing:(NSString *)colonListing;
+ (GPGValidity)validityForLetter:(NSString *)letter invalid:(BOOL *)invalid revoked:(BOOL *)revoked expired:(BOOL *)expired;
+ (void)splitUserID:(NSString *)aUserID forObject:(id)object;


+ (id)keyInfoWithListing:(NSArray *)listing fingerprint:(NSString *)aFingerprint isSecret:(BOOL)isSec withSigs:(BOOL)withSigs;
- (id)initWithListing:(NSArray *)listing fingerprint:(NSString *)aFingerprint isSecret:(BOOL)isSec withSigs:(BOOL)withSigs;
- (void)updateWithListing:(NSArray *)listing isSecret:(BOOL)isSec withSigs:(BOOL)withSigs;

- (void)updateFilterText;


- (void)updatePhotos;
- (void)updatePreferences;






@property (retain) NSMutableArray *photos;
@property (retain) NSString *textForFilter; //In diesem String stehen die verschiedenen Informationen über den Schlüssel, damit das Filtern schnell funktioniert.
@property (retain) NSString *fingerprint;
@property (retain) NSString *keyID;
@property (retain) NSString *shortKeyID;
@property GPGPublicKeyAlgorithm algorithm;
@property unsigned int length;
@property (retain) NSCalendarDate *creationDate;
@property (retain) NSCalendarDate *expirationDate;
@property GPGValidity ownerTrust;
@property GPGValidity validity;
@property BOOL expired;
@property BOOL disabled;
@property BOOL invalid;
@property BOOL revoked;
@property (readonly) NSInteger status;
@property BOOL secret;
@property (readonly) BOOL safe; //Gibt an ob der Schlüssel sicher ist. (Länge > 1024 Bit, kein MD5 oder SHA-1)



@property (readonly) GKKey *primaryKeyInfo;
@property (readonly) NSString *type;
@property (readonly) NSInteger index;

@property (readonly) NSString *userID;
@property (readonly) NSString *name;
@property (readonly) NSString *email;
@property (readonly) NSString *comment;




- (void)setChildren:(NSMutableArray *)value;
- (NSArray *)children;
- (unsigned)countOfChildren;
- (id)objectInChildrenAtIndex:(unsigned)theIndex;
- (void)getChildren:(id *)objsPtr range:(NSRange)range;
- (void)insertObject:(id)obj inChildrenAtIndex:(unsigned)theIndex;
- (void)removeObjectFromChildrenAtIndex:(unsigned)theIndex;
- (void)replaceObjectInChildrenAtIndex:(unsigned)theIndex withObject:(id)obj;

- (void)setSubkeys:(NSMutableArray *)value;
- (NSArray *)subkeys;
- (unsigned)countOfSubkeys;
- (id)objectInSubkeysAtIndex:(unsigned)theIndex;
- (void)getSubkeys:(id *)objsPtr range:(NSRange)range;
- (void)insertObject:(id)obj inSubkeysAtIndex:(unsigned)theIndex;
- (void)removeObjectFromSubkeysAtIndex:(unsigned)theIndex;
- (void)replaceObjectInSubkeysAtIndex:(unsigned)theIndex withObject:(id)obj;

- (void)setUserIDs:(NSMutableArray *)value;
- (NSArray *)userIDs;
- (unsigned)countOfUserIDs;
- (id)objectInUserIDsAtIndex:(unsigned)theIndex;
- (void)getUserIDs:(id *)objsPtr range:(NSRange)range;
- (void)insertObject:(id)obj inUserIDsAtIndex:(unsigned)theIndex;
- (void)removeObjectFromUserIDsAtIndex:(unsigned)theIndex;
- (void)replaceObjectInUserIDsAtIndex:(unsigned)theIndex withObject:(id)obj;

@end
