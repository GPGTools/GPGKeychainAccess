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

#import "GKKeySignature.h"
#import "GKKey.h"


@implementation GKKeySignature

@synthesize type;
@synthesize revocationSignature;
@synthesize local;
@synthesize signatureClass;
@synthesize userID;
@synthesize name;
@synthesize email;
@synthesize comment;
@synthesize algorithm;
@synthesize creationDate;
@synthesize expirationDate;
@synthesize keyID;
@synthesize shortKeyID;


+ (id)signatureWithListing:(NSString *)line {
	return [[[GKKeySignature alloc] initWithListing:line] autorelease];
}
- (id)initWithListing:(NSString *)line {
	[self init];
	
	NSArray *splitedLine = [line componentsSeparatedByString:@":"];
	NSString *tempItem;
	
	revocationSignature = [[splitedLine objectAtIndex:0] isEqualToString:@"rev"];
	
	algorithm = [[splitedLine objectAtIndex:3] intValue];
	self.keyID = [splitedLine objectAtIndex:4];
	self.shortKeyID = getShortKeyID(keyID);
	self.creationDate = [NSDate dateWithTimeIntervalSince1970:[[splitedLine objectAtIndex:5] integerValue]];
	if ([(tempItem = [splitedLine objectAtIndex:6]) length] > 0) {
		self.expirationDate = [NSDate dateWithTimeIntervalSince1970:[tempItem integerValue]];
	} else {
		self.expirationDate = nil;
	}
	self.userID = unescapeString([splitedLine objectAtIndex:9]);
	
	tempItem = [splitedLine objectAtIndex:10];
	signatureClass = hexToByte([tempItem UTF8String]);
	local = [tempItem hasSuffix:@"l"];
	NSMutableString *sigType = [NSMutableString stringWithString:revocationSignature ? @"rev" : @"sig"];
	if (signatureClass & 3) {
		[sigType appendFormat:@" %i", signatureClass & 3];
	}
	if (local) {
		[sigType appendString:@" L"];
	}
	self.type = sigType;
	
	return self;
}


- (NSString *)userID {
	return [[userID retain] autorelease];
}
- (void)setUserID:(NSString *)value {
	if (value != userID) {
		[userID release];
		userID = [value retain];
		
		[GKKey splitUserID:value forObject:self];
	}
}

- (void)dealloc {
	self.userID = nil;;
	
	self.keyID = nil;
	self.shortKeyID = nil;
	
	self.creationDate = nil;
	self.expirationDate = nil;
	
	[super dealloc];
}

@end