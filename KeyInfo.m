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

#import "KeyInfo.h"
#import "ActionController.h"
#include <sys/stat.h>


@implementation KeyInfo

@synthesize gpgKey;
@synthesize secKey;
@synthesize primaryUserID;
@synthesize primarySubkey;
@synthesize primaryKeyInfo;
//@synthesize subkeys;
@synthesize textForFilter;
@synthesize isSecret;



- (void)setChildren:(NSMutableArray *)value {
	if (value != children) {
		[children release];
		children = [value retain];
	}
}
- (NSArray *)children {
    return [[children retain] autorelease];
}
- (unsigned)countOfChildren {
    return [children count];
}
- (id)objectInChildrenAtIndex:(unsigned)theIndex {
    return [children objectAtIndex:theIndex];
}
- (void)getChildren:(id *)objsPtr range:(NSRange)range {
    [children getObjects:objsPtr range:range];
}
- (void)insertObject:(id)obj inChildrenAtIndex:(unsigned)theIndex {
    [children insertObject:obj atIndex:theIndex];
}
- (void)removeObjectFromChildrenAtIndex:(unsigned)theIndex {
    [children removeObjectAtIndex:theIndex];
}
- (void)replaceObjectInChildrenAtIndex:(unsigned)theIndex withObject:(id)obj {
    [children replaceObjectAtIndex:theIndex withObject:obj];
}

- (void)setSubkeys:(NSMutableArray *)value {
	if (value != subkeys) {
		[subkeys release];
		subkeys = [value retain];
	}
}
- (NSArray *)subkeys {
    return [[subkeys retain] autorelease];
}
- (unsigned)countOfSubkeys {
    return [subkeys count];
}
- (id)objectInSubkeysAtIndex:(unsigned)theIndex {
    return [subkeys objectAtIndex:theIndex];
}
- (void)getSubkeys:(id *)objsPtr range:(NSRange)range {
    [subkeys getObjects:objsPtr range:range];
}
- (void)insertObject:(id)obj inSubkeysAtIndex:(unsigned)theIndex {
    [subkeys insertObject:obj atIndex:theIndex];
}
- (void)removeObjectFromSubkeysAtIndex:(unsigned)theIndex {
    [subkeys removeObjectAtIndex:theIndex];
}
- (void)replaceObjectInSubkeysAtIndex:(unsigned)theIndex withObject:(id)obj {
    [subkeys replaceObjectAtIndex:theIndex withObject:obj];
}

- (void)setUserIDs:(NSMutableArray *)value {
	if (value != userIDs) {
		[userIDs release];
		userIDs = [value retain];
	}
}
- (NSArray *)userIDs {
    return [[userIDs retain] autorelease];
}
- (unsigned)countOfUserIDs {
    return [userIDs count];
}
- (id)objectInUserIDsAtIndex:(unsigned)theIndex {
    return [userIDs objectAtIndex:theIndex];
}
- (void)getUserIDs:(id *)objsPtr range:(NSRange)range {
    [userIDs getObjects:objsPtr range:range];
}
- (void)insertObject:(id)obj inUserIDsAtIndex:(unsigned)theIndex {
    [userIDs insertObject:obj atIndex:theIndex];
}
- (void)removeObjectFromUserIDsAtIndex:(unsigned)theIndex {
    [userIDs removeObjectAtIndex:theIndex];
}
- (void)replaceObjectInUserIDsAtIndex:(unsigned)theIndex withObject:(id)obj {
    [userIDs replaceObjectAtIndex:theIndex withObject:obj];
}



- (NSArray *)photos {
	if (!photos) {
		[self updatePhotos];
	}
	return [[photos retain] autorelease];
}
- (void)updatePhotos {
	NSData *outData, *statusData, *attributeData;
	
	NSArray *arguments = [NSArray arrayWithObjects:@"-k", self.fingerprint, nil];
	if (runGPGCommandWithArray(nil, &outData, nil, &statusData, &attributeData, arguments) != 0) {
		NSLog(@"updatePhotos: --attribute-fd für Schlüssel %@ fehlgeschlagen.", self.keyID);
		photos = nil;
		return;
	}
	
	NSString *outText = dataToString(outData);
	NSString *statusText = dataToString(statusData);
	
	NSArray *outLines = [outText componentsSeparatedByString:@"\n"];
	NSArray *statusLines = [statusText componentsSeparatedByString:@"\n"];
	
	
	NSMutableArray *thePhotos = [NSMutableArray array];
	
	NSArray *fields;
	NSInteger pos = 0, dataLength;
	int curOutLine = 0, countOutLines = [outLines count];
	NSString *outLine, *photoHash;
	
	for (NSString *statuLine in statusLines) {
		if ([statuLine hasPrefix:@"[GNUPG:] ATTRIBUTE "]) {
			photoHash = nil;
			for (; curOutLine < countOutLines; curOutLine++) {
				outLine = [outLines objectAtIndex:curOutLine];
				if ([outLine hasPrefix:@"uat:"]) {
					photoHash = [[outLine componentsSeparatedByString:@":"] objectAtIndex:7];
					curOutLine++;
					break;
				}
			}
			fields = [statuLine componentsSeparatedByString:@" "];
			dataLength = [[fields objectAtIndex:3] integerValue];
			if ([[fields objectAtIndex:4] isEqualToString:@"1"]) { //1 = Bild
				NSImage *aPhoto = [[NSImage alloc] initWithData:[attributeData subdataWithRange:(NSRange) {pos + 16, dataLength - 16}]];
				if (aPhoto && photoHash) {
					[thePhotos addObject:[NSDictionary dictionaryWithObjectsAndKeys:aPhoto, @"photo", photoHash, @"hash", nil]];
					[aPhoto release];
				}
			}
			pos += dataLength;
		}
	}
	photos = [thePhotos copy];
}



+ (KeyInfo *)keyInfoWithGPGKey:(GPGKey *)aGPGKey secretKey:(GPGKey *)secGPGKey{
	return [[[KeyInfo alloc] initWithGPGKey:aGPGKey secretKey:secGPGKey] autorelease];
}
- (KeyInfo *)initWithGPGKey:(GPGKey *)aGPGKey secretKey:(GPGKey *)secGPGKey {
	if (self = [super init]) {
		primaryKeyInfo = self;
		self.children = [NSMutableArray arrayWithCapacity:2];
		self.subkeys = [NSMutableArray arrayWithCapacity:1];
		self.userIDs = [NSMutableArray arrayWithCapacity:1];
		[self updateWithGPGKey:aGPGKey secretKey:secGPGKey];
	}
	return self;
}

- (void)updateWithGPGKey:(GPGKey *)aGPGKey secretKey:(GPGKey *)secGPGKey {
	
	self.gpgKey = aGPGKey;
	self.secKey = secGPGKey;
	
	isSecret = !!secGPGKey;
	
	
	
	NSUInteger i, aIndex, userIDsCount, subkeysCount;
	
	
	NSMutableIndexSet *subkeysToRemove = [NSMutableIndexSet indexSetWithIndexesInRange:(NSRange) {0, [subkeys count]}];
	NSMutableIndexSet *userIDsToRemove = [NSMutableIndexSet indexSetWithIndexesInRange:(NSRange) {0, [userIDs count]}];
	
	
	NSArray *gpgSubkeys = [gpgKey subkeys];
	NSArray *gpgUserIDs = [gpgKey userIDs];
	GPGSubkey *aSubkey;
	GPGUserID *aUserID;
	KeyInfo_Subkey *subkeyChild;
	KeyInfo_UserID *userIDChild;
	NSString *aFingerprint, *aUserIDString;
	
	
	subkeysCount = [gpgSubkeys count];
	for (i = 1; i < subkeysCount; i++) {
		aSubkey = [gpgSubkeys objectAtIndex:i];
		aFingerprint = [aSubkey fingerprint];
		
		subkeyChild = nil;
		aIndex = [subkeysToRemove firstIndex];
		while (aIndex != NSNotFound) {
			if ([aFingerprint isEqualToString:[[subkeys objectAtIndex:aIndex] fingerprint]]) {
				subkeyChild = [subkeys objectAtIndex:aIndex];
				[subkeysToRemove removeIndex:aIndex];
				break;
			}
			aIndex = [subkeysToRemove indexGreaterThanIndex:aIndex];
		}
		if (subkeyChild) {
			subkeyChild.subkey = aSubkey;
		} else {
			subkeyChild = [[KeyInfo_Subkey alloc] initWithGPGSubkey:aSubkey parentKeyInfo:self];
			[self insertObject:subkeyChild inSubkeysAtIndex:0];
			[self insertObject:subkeyChild inChildrenAtIndex:0];
		}
		subkeyChild.index = i - 1;
	}
	aIndex = [subkeysToRemove firstIndex];
	while (aIndex != NSNotFound) {
		[self removeObjectFromSubkeysAtIndex:aIndex];
		[self removeObjectFromChildrenAtIndex:aIndex];
		aIndex = [subkeysToRemove indexGreaterThanIndex:aIndex];
	}
	subkeysCount--;
	
	
	
	userIDsCount = [gpgUserIDs count];
	for (i = 0; i < userIDsCount; i++) {
		aUserID = [gpgUserIDs objectAtIndex:i];
		aUserIDString = [aUserID userID];
		
		userIDChild = nil;
		aIndex = [userIDsToRemove firstIndex];
		while (aIndex != NSNotFound) {
			NSString *temp = [[userIDs objectAtIndex:aIndex] userID];
			if ([aUserIDString isEqualToString:temp]) {
				userIDChild = [userIDs objectAtIndex:aIndex];
				[userIDsToRemove removeIndex:aIndex];
				break;
			}
			aIndex = [userIDsToRemove indexGreaterThanIndex:aIndex];
		}
		if (userIDChild) {
			userIDChild.gpgUserID = aUserID;
		} else {
			userIDChild = [[KeyInfo_UserID alloc] initWithGPGUserID:aUserID parentKeyInfo:self];
			[self insertObject:userIDChild inUserIDsAtIndex:0];
			[self insertObject:userIDChild inChildrenAtIndex:subkeysCount + 0];
		}
		userIDChild.index = subkeysCount + i;
	}
	aIndex = [userIDsToRemove firstIndex];
	while (aIndex != NSNotFound) {
		[self removeObjectFromUserIDsAtIndex:aIndex];
		[self removeObjectFromChildrenAtIndex:subkeysCount + aIndex];
		aIndex = [userIDsToRemove indexGreaterThanIndex:aIndex];
	}
	
	self.primaryUserID = [[gpgKey userIDs] objectAtIndex:0];
	self.primarySubkey = [[gpgKey subkeys] objectAtIndex:0];
	
	[self willChangeValueForKey:@"photos"];
	photos = nil;
	[self didChangeValueForKey:@"photos"];
}

- (void)updateFilterText { // Muss für den Schlüssel aufgerufen werden, bevor auf textForFilter zugegriffen werden kann!
	NSMutableString *newText = [NSMutableString stringWithCapacity:200];
	
	
	for (GPGSubkey *subkey in [gpgKey subkeys]) {
		[newText appendFormat:@"%@\n%@\n", [subkey fingerprint], [subkey keyID]];
	}
	//NSArray *userIDs = self.userIDs;
	for (GPGUserID *userID in [gpgKey userIDs]) {
		[newText appendFormat:@"%@\n", [userID userID]];
	}
	
	[textForFilter release];
	textForFilter = [newText copy];
}

- (void)dealloc {
	self.gpgKey = nil;
	self.secKey = nil;
	self.children = nil;
	self.subkeys = nil;
	self.userIDs = nil;
	self.primaryUserID = nil;
	self.primarySubkey = nil;
	[photos release];
	[textForFilter release];
	
	[super dealloc];
}



- (void)setOwnerTrust:(GPGValidity)value {}
- (void)setIsKeyDisabled:(BOOL)value {}


- (NSString *)description {return [primaryUserID userID];}

//
//GPGKey Properties
//

- (NSString *)type { return isSecret ? @"sec" : @"pub"; }
- (NSInteger)index { return 0; }

//primaryUserID Properties 
- (NSString *)name { return [primaryUserID name]; }
- (NSString *)email { return [primaryUserID email]; }
- (NSString *)comment { return [primaryUserID comment]; }
- (NSString *)userID { return [primaryUserID userID]; }
- (GPGValidity)validity { return [primaryUserID validity]; }

//primarySubkey Properties
- (NSString *)fingerprint { return [primarySubkey fingerprint]; }
- (GPGPublicKeyAlgorithm)algorithm { return [primarySubkey algorithm]; }
- (NSCalendarDate *)creationDate { return [primarySubkey creationDate]; }
- (NSCalendarDate *)expirationDate { return [primarySubkey expirationDate]; }
- (NSString *)keyID { return [primarySubkey keyID]; }
- (NSString *)shortKeyID { return [primarySubkey shortKeyID]; }
- (unsigned int)length { return [primarySubkey length]; }
- (NSInteger)status { return [primarySubkey status]; }

//gpgKey Properties
//- (NSArray *)userIDs { return [[[gpgKey userIDs] retain] autorelease]; }
- (BOOL)hasKeyExpired { return [gpgKey hasKeyExpired]; }
- (BOOL)isKeyInvalid { return [gpgKey isKeyInvalid]; }
- (BOOL)isKeyDisabled { return [gpgKey isKeyDisabled]; }
- (BOOL)isKeyRevoked { return [gpgKey isKeyRevoked]; }
- (GPGValidity)ownerTrust { return [gpgKey ownerTrust]; }

@end


@implementation KeyInfo_Subkey
@synthesize primaryKeyInfo;
@synthesize subkey;
@synthesize index;

- (NSString *)type {return @"sub";}
- (id)children {return nil;}
- (id)name {return nil;}
- (id)email {return nil;}
- (id)comment {return nil;}


- (GPGKey *)gpgkey {return [subkey key];}
- (NSString *)keyID {return [subkey keyID];}
- (NSString *)shortKeyID {return [subkey shortKeyID];}
- (NSString *)fingerprint {return [subkey fingerprint];}
- (NSCalendarDate *)expirationDate {return [subkey expirationDate];}



- (id)initWithGPGSubkey:(GPGSubkey *)gpgSubkey parentKeyInfo:(KeyInfo *)keyInfo {
	if (self = [super init]) {
		self.subkey = gpgSubkey;
		primaryKeyInfo = keyInfo;
	}
	return self;
}
-(void) dealloc {
	self.subkey = nil;
	[super dealloc];
}
- (id)valueForUndefinedKey:(NSString *)key {
	return [subkey valueForKey:key];
}
@end

@implementation KeyInfo_UserID
@synthesize primaryKeyInfo;
@synthesize gpgUserID;
@synthesize index;

- (NSString *)type {return @"uid";}
- (id)children {return nil;}
- (id)creationDate {return nil;}
- (id)length {return nil;}
- (id)algorithm {return nil;}
- (id)keyID {return nil;}
- (id)shortKeyID {return nil;}
- (id)fingerprint {return nil;}


- (NSString *)userID {return [gpgUserID userID];}
- (NSArray *)signatures {return [gpgUserID signatures];}



- (id)initWithGPGUserID:(GPGUserID *)aUserID parentKeyInfo:(KeyInfo *)keyInfo {
	if (self = [super init]) {
		self.gpgUserID = aUserID;
		primaryKeyInfo = keyInfo;
	}
	return self;
}
-(void) dealloc {
	self.gpgUserID = nil;
	[super dealloc];
}
- (id)valueForUndefinedKey:(NSString *)key {
	return [gpgUserID valueForKey:key];
}
@end

@implementation GPGSubkey (Extended)

- (NSInteger)status {
	NSInteger statusValue = 0;
	
	if ([self isKeyInvalid]) {
		statusValue = GPGKeyStatus_Invalid;
	}
	if ([self isKeyRevoked]) {
		statusValue += GPGKeyStatus_Revoked;
	}
	if ([self hasKeyExpired]) {
		statusValue += GPGKeyStatus_Expired;
	}
	if ([self isKeyDisabled]) {
		statusValue += GPGKeyStatus_Disabled;
	}
	return statusValue;
}

@end

@implementation GPGKeySignature (Extended)

- (NSString *)type {
	NSMutableString *sigType = [NSMutableString string];
	[sigType appendString:[self isRevocationSignature] ? @"rev" : @"sig"];
	
	NSInteger sigClass = [self signatureClass];
	if (sigClass & 3) {
		[sigType appendFormat:@" %i", sigClass & 3];
	}
	if (![self isExportable]) {
		[sigType appendString:@" L"];
	}
	
	return [[sigType copy] autorelease];
}
- (NSString *)shortSignerKeyID {
	NSString *keyID = [self signerKeyID];
	return [keyID substringFromIndex:[keyID length] - 8];
}

@end

