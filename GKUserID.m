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
#import "GKKey.h"
#import "ActionController.h"


@implementation GKUserID

@synthesize index;
@synthesize primaryKeyInfo;
@synthesize hashID;
@synthesize name;
@synthesize email;
@synthesize comment;
@synthesize creationDate;
@synthesize expirationDate;
@synthesize validity;
@synthesize expired;
@synthesize disabled;
@synthesize invalid;
@synthesize revoked;


- (id)children {return nil;}
- (id)length {return nil;}
- (id)algorithm {return nil;}
- (id)keyID {return nil;}
- (id)shortKeyID {return nil;}
- (id)fingerprint {return nil;}

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
- (NSString *)type {return @"uid";}

- (NSUInteger)hash {
	return [hashID hash];
}
- (BOOL)isEqual:(id)anObject {
	return [hashID isEqualToString:[anObject description]];
}
- (NSString *)description {
	return [[hashID retain] autorelease];
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



- (id)initWithListing:(NSArray *)listing signatureListing:(NSArray *)sigListing parentKeyInfo:(GKKey *)keyInfo {
	[self init];
	primaryKeyInfo = keyInfo;
	signatures = nil;
	cipherPreferences = nil;
	digestPreferences = nil;
	compressPreferences = nil;
	otherPreferences = nil;
	
	
	[self updateWithListing:listing signatureListing:sigListing];
	return self;	
}
- (void)updateWithListing:(NSArray *)listing signatureListing:(NSArray *)sigListing {
	validity = [GKKey validityForLetter:[listing objectAtIndex:1] invalid:&invalid revoked:&revoked expired:&expired];
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
	self.hashID = [listing objectAtIndex:7];
	self.userID = unescapeString([listing objectAtIndex:9]);
	
	
	if (sigListing) {
		NSMutableArray *newSignatures = [NSMutableArray arrayWithCapacity:[sigListing count]];
		for (NSString *line in sigListing) {
			[newSignatures addObject:[GKKeySignature signatureWithListing:line]];
		}
		[signatures release];
		signatures = [newSignatures copy];
	} else {
		signatures = nil;
	}
	
	if (cipherPreferences) {
		[cipherPreferences release];
		cipherPreferences = nil;
	}
	if (digestPreferences) {
		[digestPreferences release];
		digestPreferences = nil;
	}
	if (compressPreferences) {
		[compressPreferences release];
		compressPreferences = nil;
	}
	if (otherPreferences) {
		[otherPreferences release];
		otherPreferences = nil;
	}
}

- (NSArray *)signatures {
	if (!signatures) {
		NSString *listing;
		runGPGCommand(nil, &listing, nil, @"--list-sigs", @"--with-fingerprint", @"--with-fingerprint", [primaryKeyInfo fingerprint], nil);
		
		NSArray *listings, *fingerprints;
		[GKKey colonListing:listing toArray:&listings andFingerprints:&fingerprints];
		
		NSUInteger aIndex = [fingerprints indexOfObject:[primaryKeyInfo fingerprint]];
		
		if (aIndex != NSNotFound) {
			[primaryKeyInfo updateWithListing:[listings objectAtIndex:aIndex] isSecret:[primaryKeyInfo secret] withSigs:YES];
		} else {
			signatures = [[NSArray array] retain];
		}
	}
	return signatures;
}


- (void)updatePreferences:(NSString *)listing {
	NSArray *split = [[[listing componentsSeparatedByString:@":"] objectAtIndex:12] componentsSeparatedByString:@","];
	NSString *prefs = [split objectAtIndex:0];
	
	NSRange range, searchRange;
	NSUInteger stringLength = [prefs length];
	searchRange.location = 0;
	searchRange.length = stringLength;
	
	
	range = [prefs rangeOfString:@"Z" options:NSLiteralSearch range:searchRange];
	if (range.length > 0) {
		range.length = searchRange.length - range.location;
		searchRange.length = range.location - 1;
		compressPreferences = [[[prefs substringWithRange:range] componentsSeparatedByString:@" "] retain];
	} else {
		searchRange.length = stringLength;
		compressPreferences = [[NSArray alloc] init];
	}
	
	range = [prefs rangeOfString:@"H" options:NSLiteralSearch range:searchRange];
	if (range.length > 0) {
		range.length = searchRange.length - range.location;
		searchRange.length = range.location - 1;
		digestPreferences = [[[prefs substringWithRange:range] componentsSeparatedByString:@" "] retain];
	} else {
		searchRange.length = stringLength;
		digestPreferences = [[NSArray alloc] init];
	}
	
	range = [prefs rangeOfString:@"S" options:NSLiteralSearch range:searchRange];
	if (range.length > 0) {
		range.length = searchRange.length - range.location;
		searchRange.length = range.location - 1;
		cipherPreferences = [[[prefs substringWithRange:range] componentsSeparatedByString:@" "] retain];
	} else {
		searchRange.length = stringLength;
		cipherPreferences = [[NSArray alloc] init];
	}
	
	//TODO [mdc] [no-ks-modify]!
}

- (NSArray *)cipherPreferences {
	if (!cipherPreferences) {
		[primaryKeyInfo updatePreferences];
	}
	return cipherPreferences;
}
- (NSArray *)digestPreferences {
	if (!digestPreferences) {
		[primaryKeyInfo updatePreferences];
	}
	return digestPreferences;
}
- (NSArray *)compressPreferences {
	if (!compressPreferences) {
		[primaryKeyInfo updatePreferences];
	}
	return compressPreferences;
}
- (NSArray *)otherPreferences {
	if (!otherPreferences) {
		[primaryKeyInfo updatePreferences];
	}
	return otherPreferences;
}



- (void)dealloc {
	[signatures release];
	
	[cipherPreferences release];
	[digestPreferences release];
	[compressPreferences release];
	[otherPreferences release];
	
	self.hashID = nil;
	self.userID = nil;
	
	self.creationDate = nil;
	self.expirationDate = nil;
	
	[super dealloc];
}


@end

