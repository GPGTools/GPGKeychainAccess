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

#import "GKSubkey.h"
#import "GKKey.h"


@implementation GKSubkey

@synthesize index;
@synthesize primaryKeyInfo;

@synthesize fingerprint;
@synthesize keyID;
@synthesize shortKeyID;

@synthesize algorithm;
@synthesize length;
@synthesize creationDate;
@synthesize expirationDate;

@synthesize validity;
@synthesize expired;
@synthesize disabled;
@synthesize invalid;
@synthesize revoked;


- (id)children {return nil;}
- (id)name {return nil;}
- (id)email {return nil;}
- (id)comment {return nil;}

- (NSInteger)status {
	NSInteger statusValue = 0;
	
	if (invalid) {
		statusValue = GPGKeyStatus_Invalid;
	}
	if (revoked) {
		statusValue += GPGKeyStatus_Revoked;
	}
	if (expired) {
		statusValue += GPGKeyStatus_Expired;
	}
	if (disabled) {
		statusValue += GPGKeyStatus_Disabled;
	}
	return statusValue;
}
- (NSString *)type {return @"sub";}

- (NSUInteger)hash {
	return [fingerprint hash];
}
- (BOOL)isEqual:(id)anObject {
	return [fingerprint isEqualToString:[anObject description]];
}
- (NSString *)description {
	return [[fingerprint retain] autorelease];
}



- (id)initWithListing:(NSArray *)listing fingerprint:(NSString *)aFingerprint parentKeyInfo:(GKKey *)keyInfo {
	[self init];
	primaryKeyInfo = keyInfo;
	self.fingerprint = aFingerprint;
	[self updateWithListing:listing];
	return self;
}
- (void)updateWithListing:(NSArray *)listing {
	validity = [GKKey validityForLetter:[listing objectAtIndex:1] invalid:&invalid revoked:&revoked expired:&expired];
	length = [[listing objectAtIndex:2] intValue];
	algorithm = [[listing objectAtIndex:3] intValue];
	self.keyID = [listing objectAtIndex:4];
	self.shortKeyID = getShortKeyID(keyID);
	self.creationDate = [NSDate dateWithTimeIntervalSince1970:[[listing objectAtIndex:5] integerValue]];
	NSString *tempItem;
	if ([(tempItem = [listing objectAtIndex:6]) length] > 0) {
		self.expirationDate = [NSDate dateWithTimeIntervalSince1970:[tempItem integerValue]];
		if (!expired) {
			expired = [[NSDate date] isGreaterThanOrEqualTo:expirationDate];
		}
	} else {
		self.expirationDate = nil;
	}
	
}

- (void)dealloc {
	self.fingerprint = nil;
	self.keyID = nil;
	self.shortKeyID = nil;
	
	self.creationDate = nil;
	self.expirationDate = nil;
	
	[super dealloc];
}


@end
