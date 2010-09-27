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

typedef enum { 
    GPGKeyStatus_Invalid = 1,
    GPGKeyStatus_Revoked = 2,
    GPGKeyStatus_Expired = 4,
    GPGKeyStatus_Disabled = 8
} GPGKeyStatus;


@interface KeyInfo : NSObject {
	GPGKey *gpgKey;
	GPGKey *secKey;
	NSMutableArray *children;
	NSMutableArray *subkeys;
	NSMutableArray *userIDs;
	
	GPGUserID *primaryUserID;
	GPGSubkey *primarySubkey;
	KeyInfo *primaryKeyInfo;
	
	NSArray *photos;
	NSString *textForFilter; //In diesem String stehen die verschiedenen Informationen über den Schlüssel, damit das Filtern schnell funktioniert.
	BOOL isSecret;
}




@property ( retain ) GPGKey *gpgKey;
@property ( retain ) GPGKey *secKey;
@property ( retain ) GPGUserID *primaryUserID;
@property ( retain ) GPGSubkey *primarySubkey;
@property ( readonly ) KeyInfo *primaryKeyInfo;
@property ( readonly ) NSString *textForFilter;
@property ( readonly ) NSInteger status;
@property ( readonly ) NSInteger index;

//
//GPGKey Properties
//

//primaryUserID Properties 
@property ( readonly ) NSString *name;
@property ( readonly ) NSString *email;
@property ( readonly ) NSString *comment;
@property ( readonly ) NSString *userID;
@property ( readonly ) GPGValidity validity;

//primarySubkey Properties
@property ( readonly ) NSString *fingerprint;
@property ( readonly ) NSString *keyID;
@property ( readonly ) NSString *shortKeyID;
@property ( readonly ) GPGPublicKeyAlgorithm algorithm;
@property ( readonly ) NSCalendarDate *creationDate;
@property ( readonly ) NSCalendarDate *expirationDate;
@property ( readonly ) unsigned int length;

//gpgKey Properties
@property ( readonly ) BOOL hasKeyExpired;
@property BOOL isKeyDisabled;
@property ( readonly ) BOOL isKeyInvalid;
@property ( readonly ) BOOL isKeyRevoked;
@property ( readonly ) BOOL isSecret;
@property GPGValidity ownerTrust;
@property ( readonly ) NSArray *photos;
@property ( readonly ) NSString *type;

- (void)updatePhotos;


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




+ (KeyInfo *)keyInfoWithGPGKey:(GPGKey *)aGPGKey secretKey:(GPGKey *)secGPGKey;
- (KeyInfo *)initWithGPGKey:(GPGKey *)aGPGKey secretKey:(GPGKey *)secGPGKey;
- (void)updateWithGPGKey:(GPGKey *)aGPGKey secretKey:(GPGKey *)secGPGKey;
- (void)updateFilterText;

@end


@interface KeyInfo_Subkey : NSObject {
	KeyInfo *primaryKeyInfo;
	GPGSubkey *subkey;
	NSInteger index;
}
@property (readonly) KeyInfo *primaryKeyInfo;
@property (retain) GPGSubkey *subkey;
@property NSInteger index;


@property (readonly) NSString *type;
@property (readonly) id children;
@property (readonly) id name;
@property (readonly) id email;
@property (readonly) id comment;
@property (readonly) GPGKey *gpgkey;
@property (readonly) NSString *keyID;
@property (readonly) NSString *shortKeyID;
@property (readonly) NSString *fingerprint;
@property (readonly) NSCalendarDate *expirationDate;



- (id)initWithGPGSubkey:(GPGSubkey *)gpgSubkey parentKeyInfo:(KeyInfo *)keyInfo;
@end


@interface KeyInfo_UserID : NSObject {
	KeyInfo *primaryKeyInfo;
	GPGUserID *gpgUserID;
	NSInteger index;
}
@property (readonly) KeyInfo *primaryKeyInfo;
@property (retain) GPGUserID *gpgUserID;
@property NSInteger index;



@property (readonly) NSString *type;
@property (readonly) id children;
@property (readonly) id keyID;
@property (readonly) id shortKeyID;
@property (readonly) id fingerprint;
@property (readonly) id creationDate;
@property (readonly) id length;
@property (readonly) id algorithm;
@property (readonly) NSString *userID;
@property (readonly) NSArray *signatures;






- (id)initWithGPGUserID:(GPGUserID *)gpgUserID parentKeyInfo:(KeyInfo *)keyInfo;
@end


@interface GPGSubkey (Extended)
@property (readonly) NSInteger status;
@end

@interface GPGUserID (Extended)
@property (readonly) NSInteger status;
@end


@interface GKPhotoID  : NSObject {
	NSImage *image;
	NSString *hashID;
	NSInteger status;
}
@property (readonly) NSImage *image;
@property (readonly) NSString *hashID;
@property (readonly) NSInteger status;

- (id)initWithImage:(NSImage *)aImage hashID:(NSString *)aHashID status:(NSInteger)aStatus;

@end




@interface GPGKeySignature (Extended)
@property (readonly) NSString *type;
@property (readonly) NSString *shortSignerKeyID;
@end


