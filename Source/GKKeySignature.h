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

@interface GKKeySignature : NSObject {
	NSString *keyID;
	NSString *shortKeyID;
	
	NSString *type;
	
	int signatureClass;
	
	GPGPublicKeyAlgorithm algorithm;
	NSCalendarDate *creationDate;
	NSCalendarDate *expirationDate;
	
	NSString *userID;
	NSString *name;
	NSString *email;
	NSString *comment;
	
	BOOL revocationSignature;
	BOOL local;
}

@property BOOL local;
@property BOOL revocationSignature;
@property int signatureClass;
@property (copy) NSString *type;
@property (retain) NSString *userID;
@property (retain) NSString *name;
@property (retain) NSString *email;
@property (retain) NSString *comment;
@property (retain) NSString *keyID;
@property (retain) NSString *shortKeyID;
@property GPGPublicKeyAlgorithm algorithm;
@property (retain) NSCalendarDate *creationDate;
@property (retain) NSCalendarDate *expirationDate;


+ (id)signatureWithListing:(NSString *)line;
- (id)initWithListing:(NSString *)line;

@end
