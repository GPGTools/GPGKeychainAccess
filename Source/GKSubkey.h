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

@class GKKey;

@interface GKSubkey : NSObject {
	NSInteger index;
	GKKey *primaryKeyInfo;
	
	NSString *fingerprint;
	NSString *keyID;
	NSString *shortKeyID;
	
	GPGPublicKeyAlgorithm algorithm;
	unsigned int length;
	NSCalendarDate *creationDate;
	NSCalendarDate *expirationDate;
	
	GPGValidity validity;
	BOOL expired;
	BOOL disabled;
	BOOL invalid;
	BOOL revoked;
	
}

@property (assign) GKKey *primaryKeyInfo;
@property (readonly) NSString *type;
@property NSInteger index;

@property (retain) NSString *fingerprint;
@property (retain) NSString *keyID;
@property (retain) NSString *shortKeyID;

@property GPGPublicKeyAlgorithm algorithm;
@property unsigned int length;
@property (retain) NSCalendarDate *creationDate;
@property (retain) NSCalendarDate *expirationDate;

@property GPGValidity validity;
@property BOOL expired;
@property BOOL disabled;
@property BOOL invalid;
@property BOOL revoked;
@property (readonly) NSInteger status;

@property (readonly) id children;
@property (readonly) id name;
@property (readonly) id email;
@property (readonly) id comment;



- (id)initWithListing:(NSArray *)listing fingerprint:(NSString *)aFingerprint parentKeyInfo:(GKKey *)keyInfo;
- (void)updateWithListing:(NSArray *)listing;

@end
