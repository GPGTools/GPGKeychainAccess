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

#import "GKKey.h"
#import "ActionController.h"
#import "KeychainController.h"


@implementation GKKey

+ (id)keyInfoWithListing:(NSArray *)listing fingerprint:(NSString *)aFingerprint isSecret:(BOOL)isSec withSigs:(BOOL)withSigs {
	return [[[[self class] alloc] initWithListing:listing fingerprint:aFingerprint isSecret:isSec  withSigs:withSigs] autorelease];
}
- (id)initWithListing:(NSArray *)listing fingerprint:(NSString *)aFingerprint isSecret:(BOOL)isSec withSigs:(BOOL)withSigs {
	[self init];
	
	subkeyCount = 0;
	self.children = [NSMutableArray arrayWithCapacity:2];
	self.subkeys = [NSMutableArray arrayWithCapacity:1];
	self.userIDs = [NSMutableArray arrayWithCapacity:1];
	self.fingerprint = aFingerprint;
	
	[self updateWithListing:listing isSecret:isSec withSigs:withSigs];
	return self;	
}
- (void)updateWithListing:(NSArray *)listing isSecret:(BOOL)isSec withSigs:(BOOL)withSigs {
	NSString *tempItem, *aHash, *aFingerprint;
	NSArray *splitedLine;
	GKSubkey *subkeyChild;
	GKUserID *userIDChild;
	NSUInteger subkeyIndex = 0, userIDIndex = 0;
	
	secret = isSec;
	
	
	NSUInteger i = 1, c = [listing count];
	splitedLine = [[listing objectAtIndex:0] componentsSeparatedByString:@":"];
	
	
	validity = [GKKey validityForLetter:[splitedLine objectAtIndex:1] invalid:&invalid revoked:&revoked expired:&expired];
	length = [[splitedLine objectAtIndex:2] intValue];
	algorithm = [[splitedLine objectAtIndex:3] intValue];
	self.keyID = [splitedLine objectAtIndex:4];
	self.shortKeyID = getShortKeyID(keyID);
	self.creationDate = [NSDate dateWithTimeIntervalSince1970:[[splitedLine objectAtIndex:5] integerValue]];
	if ([(tempItem = [splitedLine objectAtIndex:6]) length] > 0) {
		self.expirationDate = [NSDate dateWithTimeIntervalSince1970:[tempItem integerValue]];
		if (!expired) {
			expired = [[NSDate date] isGreaterThanOrEqualTo:expirationDate];
		}
	} else {
		self.expirationDate = nil;
	}
	ownerTrust = [GKKey validityForLetter:[splitedLine objectAtIndex:8] invalid:nil revoked:nil expired:nil];
	
	
	tempItem = [splitedLine objectAtIndex:11];
	disabled = [tempItem rangeOfString:@"D"].length > 0;
	
	
	primaryUserID = nil;
	
	
	NSMutableSet *subkeysToRemove = [NSMutableSet setWithArray:subkeys];
	NSMutableSet *userIDsToRemove = [NSMutableSet setWithArray:userIDs];
	
	
	for	(; i < c; i++) {
		splitedLine = [[listing objectAtIndex:i] componentsSeparatedByString:@":"];
		
		tempItem = [splitedLine objectAtIndex:0];
		if ([tempItem isEqualToString:@"uid"]) {
			NSArray *sigListing = nil;
			NSUInteger numSigs = 0;
			
			for (; i + numSigs + 1 < c; numSigs++) {
				NSString *line = [listing objectAtIndex:i + numSigs + 1];
				if (![line hasPrefix:@"sig"] && ![line hasPrefix:@"rev"]) {
					break;
				}
			}
			
			if (numSigs > 0) {
				sigListing = [listing subarrayWithRange:(NSRange){i + 1, numSigs}];
			} else if (withSigs) {
				sigListing = [NSArray array];
			}
			
			aHash = [splitedLine objectAtIndex:7];
			
			userIDChild = [userIDsToRemove member:aHash];
			
			if (userIDChild) {
				[userIDsToRemove removeObject:userIDChild];
				[userIDChild updateWithListing:splitedLine signatureListing:sigListing];
			} else {
				userIDChild = [[GKUserID alloc] initWithListing:splitedLine signatureListing:sigListing parentKeyInfo:self];
				
				[self insertObject:userIDChild inUserIDsAtIndex:0];
				[self insertObject:userIDChild inChildrenAtIndex:subkeyCount + 0];
			}
			if (!primaryUserID) {
				primaryUserID = userIDChild;
			}
			userIDChild.index = userIDIndex++;
			
			
		} else if ([tempItem isEqualToString:@"sub"]) {
			aFingerprint = [[[listing objectAtIndex:++i] componentsSeparatedByString:@":"] objectAtIndex:9];
			
			subkeyChild = [subkeysToRemove member:aFingerprint];
			
			if (subkeyChild) {
				[subkeysToRemove removeObject:subkeyChild];
				[subkeyChild updateWithListing:splitedLine];
			} else {
				subkeyChild = [[GKSubkey alloc] initWithListing:splitedLine fingerprint:aFingerprint parentKeyInfo:self];
				
				[self insertObject:subkeyChild inSubkeysAtIndex:0];
				[self insertObject:subkeyChild inChildrenAtIndex:0];
				
				subkeyCount++;
			}
			subkeyChild.index = subkeyIndex++;
		}
	}
	
	NSArray *toRemove = [subkeysToRemove allObjects];
	[subkeys removeObjectsInArray:toRemove];
	[children removeObjectsInArray:toRemove];
	subkeyCount -= [toRemove count];
	
	toRemove = [userIDsToRemove allObjects];
	[userIDs removeObjectsInArray:toRemove];
	[children removeObjectsInArray:toRemove];
	
	for (userIDChild in userIDs) {
		userIDChild.index += subkeyCount;
	}
	
	self.photos = nil;
}

- (void)updateFilterText { // Muss für den Schlüssel aufgerufen werden, bevor auf textForFilter zugegriffen werden kann!
	NSMutableString *newText = [NSMutableString stringWithCapacity:200];
	
	[newText appendFormat:@"0x%@\n0x%@\n0x%@\n", [self fingerprint], [self keyID], [self shortKeyID]];
	for (GKSubkey *subkey in self.subkeys) {
		[newText appendFormat:@"0x%@\n0x%@\n0x%@\n", [subkey fingerprint], [subkey keyID], [subkey shortKeyID]];
	}
	for (GKUserID *userID in self.userIDs) {
		[newText appendFormat:@"%@\n", [userID userID]];
	}
	
	[textForFilter release];
	textForFilter = [newText copy];
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
	
	NSArray *statusFields, *colons;
	NSInteger pos = 0, dataLength, photoStatus;
	int curOutLine = 0, countOutLines = [outLines count];
	NSString *outLine, *photoHash;
	
	for (NSString *statuLine in statusLines) {
		if ([statuLine hasPrefix:@"[GNUPG:] ATTRIBUTE "]) {
			photoHash = nil;
			for (; curOutLine < countOutLines; curOutLine++) {
				outLine = [outLines objectAtIndex:curOutLine];
				if ([outLine hasPrefix:@"uat:"]) {
					colons = [outLine componentsSeparatedByString:@":"];
					photoHash = [colons objectAtIndex:7];
					photoStatus = [[colons objectAtIndex:1] isEqualToString:@"r"] ? GPGKeyStatus_Revoked : 0;
					curOutLine++;
					break;
				}
			}
			statusFields = [statuLine componentsSeparatedByString:@" "];
			dataLength = [[statusFields objectAtIndex:3] integerValue];
			if ([[statusFields objectAtIndex:4] isEqualToString:@"1"]) { //1 = Bild
				NSImage *aPhoto = [[NSImage alloc] initWithData:[attributeData subdataWithRange:(NSRange) {pos + 16, dataLength - 16}]];
				if (aPhoto && photoHash) {
					GKPhotoID *photoID = [[GKPhotoID alloc] initWithImage:aPhoto hashID:photoHash status:photoStatus];
					
					[thePhotos addObject:photoID];
					[photoID release];
					[aPhoto release];
				}
			}
			pos += dataLength;
		}
	}
	photos = [thePhotos copy];
}


- (void)updatePreferences {
	NSString *outText;
	
	if (runGPGCommand(nil, &outText, nil, @"--edit-key", fingerprint, @"quit", nil) != 0) {
		NSLog(@"updatePreferences: --edit-key für Schlüssel %@ fehlgeschlagen.", fingerprint);
		return;
	}
	NSArray *lines = [outText componentsSeparatedByString:@"\n"];
	
	NSInteger i = 0, c = [userIDs count];
	for (NSString *line in lines) {
		if ([line hasPrefix:@"uid:"]) {
			if (i >= c) {
				NSLog(@"updatePreferences: index >= count!");				
				break;
			}
			[[userIDs objectAtIndex:i] updatePreferences:line];
			i++;
		}
	}
}




+ (void)colonListing:(NSString *)colonListing toArray:(NSArray **)array andFingerprints:(NSArray **)fingerprints {
	NSRange searchRange, findRange, lineRange;
	NSString *searchText, *foundText, *foundFingerprint;
	NSUInteger textLength = [colonListing length];
	NSMutableArray *listings = [NSMutableArray arrayWithCapacity:10];
	NSMutableArray *theFingerprints = [NSMutableArray arrayWithCapacity:10];
	
	*array = listings;
	*fingerprints = theFingerprints;
	
	
	
	searchText = @"\npub:";
	if ([colonListing hasPrefix:@"pub:"]) {
		findRange.location = 0;
		findRange.length = 1;	
	} else {
		if ([colonListing hasPrefix:@"sec:"]) {
			findRange.location = 0;
			findRange.length = 1;
			searchText = @"\nsec:";
		} else {
			findRange = [colonListing rangeOfString:searchText];
			if (findRange.length == 0) {
				searchText = @"\nsec:";
				findRange = [colonListing rangeOfString:searchText];
				if (findRange.length == 0) {
					return;
				}
			}
			findRange.location++;
		}
	}
	
	lineRange = [colonListing lineRangeForRange:findRange];
	
	searchRange.location = lineRange.location + lineRange.length;
	searchRange.length = textLength - searchRange.location;
	
	while ((findRange = [colonListing rangeOfString:searchText options:NSLiteralSearch range:searchRange]).length > 0) {
		findRange.location++;
		lineRange.length = findRange.location - lineRange.location;
		
		foundText = [colonListing substringWithRange:lineRange];
		
		
		lineRange = [foundText rangeOfString:@"\nfpr:"];
		if (lineRange.length == 0) {
			return; //Fehler!
		}
		lineRange.location++;
		lineRange = [foundText lineRangeForRange:lineRange];
		foundFingerprint = [[[foundText substringWithRange:lineRange] componentsSeparatedByString:@":"] objectAtIndex:9];
		
		[listings addObject:[foundText componentsSeparatedByString:@"\n"]];
		[theFingerprints addObject:foundFingerprint];
		
		lineRange = [colonListing lineRangeForRange:findRange];
		searchRange.location = lineRange.location + lineRange.length;
		searchRange.length = textLength - searchRange.location;
	}
	
	
	lineRange.length = textLength - lineRange.location;
	
	foundText = [colonListing substringWithRange:lineRange];
	
	lineRange = [foundText rangeOfString:@"\nfpr:"];
	if (lineRange.length == 0) {
		return; //Fehler!
	}
	lineRange.location++;
	lineRange = [foundText lineRangeForRange:lineRange];
	foundFingerprint = [[[foundText substringWithRange:lineRange] componentsSeparatedByString:@":"] objectAtIndex:9];
	
	[listings addObject:[foundText componentsSeparatedByString:@"\n"]];
	[theFingerprints addObject:foundFingerprint];
}
+ (NSSet *)fingerprintsFromColonListing:(NSString *)colonListing {
	NSRange searchRange, findRange;
	NSUInteger textLength = [colonListing length];
	NSMutableSet *fingerprints = [NSMutableSet setWithCapacity:3];
	NSString *lineText;
	
	searchRange.location = 0;
	searchRange.length = textLength;
	
	
	while ((findRange = [colonListing rangeOfString:@"\nfpr:" options:NSLiteralSearch range:searchRange]).length > 0) {
		findRange.location++;
		lineText = [colonListing substringWithRange:[colonListing lineRangeForRange:findRange]];
		[fingerprints addObject:[[lineText componentsSeparatedByString:@":"] objectAtIndex:9]];
		
		searchRange.location = findRange.location + findRange.length;
		searchRange.length = textLength - searchRange.location;
	}
	
	return fingerprints;
}
+ (GPGValidity)validityForLetter:(NSString *)letter invalid:(BOOL *)invalid revoked:(BOOL *)revoked expired:(BOOL *)expired {
	if (invalid) {
		*invalid = NO;
	}
	if (revoked) {
		*revoked = NO;
	}
	if (expired) {
		*expired = NO;
	}
	
	if ([letter length] == 0) {
		return 0;
	}
	switch ([letter characterAtIndex:0]) {
		case 'q':
			return 1;
		case 'n':
			return 2;
		case 'm':
			return 3;
		case 'f':
			return 4;
		case 'u':
			return 5;
		case 'i':
			if (invalid) {
				*invalid = YES;
			}
			return 0;
		case 'r':
			if (revoked) {
				*revoked = YES;
			}
			return 0;
		case 'e':
			if (expired) {
				*expired = YES;
			}
			return 0;
		default:
			return 0;
	}
}

+ (void)splitUserID:(NSString *)aUserID forObject:(id)object {
	GKUserID *theObject = object;
	if (!aUserID) {
		theObject.email = nil;
		theObject.comment = nil;
		theObject.name = nil;
		return;
	}
	NSString *workText = aUserID;
	NSUInteger textLength = [workText length];
	NSRange range;
	
	range = [workText rangeOfString:@" <" options:NSBackwardsSearch];
	if ([workText hasSuffix:@">"] && range.length > 0) {
		range.location += 2;
		range.length = textLength - range.location - 1;
		theObject.email = [workText substringWithRange:range];
		
		workText = [workText substringToIndex:range.location - 2];
		textLength -= (range.length + 3);
	} else {
		theObject.email = nil;
	}
	
	range = [workText rangeOfString:@" (" options:NSBackwardsSearch];
	if ([workText hasSuffix:@")"] && range.length > 0 && range.location > 0) {
		range.location += 2;
		range.length = textLength - range.location - 1;
		theObject.comment = [workText substringWithRange:range];
		
		workText = [workText substringToIndex:range.location - 2];
		textLength -= (range.length + 3);
	} else {
		theObject.comment = nil;
	}
	
	theObject.name = workText;
}




@synthesize photos;
@synthesize textForFilter;
@synthesize fingerprint;
@synthesize keyID;
@synthesize shortKeyID;
@synthesize algorithm;
@synthesize length;
@synthesize creationDate;
@synthesize expirationDate;
@synthesize ownerTrust;
@synthesize validity;
@synthesize expired;
@synthesize disabled;
@synthesize invalid;
@synthesize revoked;
@synthesize secret;


- (GKKey *)primaryKeyInfo { return self; }
- (NSString *)type { return secret ? @"sec" : @"pub"; }
- (NSInteger)index { return 0; }

- (NSString *)userID { return primaryUserID.userID; }
- (NSString *)name { return primaryUserID.name; }
- (NSString *)email { return primaryUserID.email; }
- (NSString *)comment { return primaryUserID.comment; }


- (NSInteger)status {
	NSInteger statusValue = validity;
	
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

- (BOOL)safe {
	if (length < 1536) { //Länge des Hauptschlüssels.
		return NO;
	}
	
	for (GKSubkey *aSubkey in subkeys) {
		if (aSubkey.length < 1536 && aSubkey.status == 0) { //Länge der gültigen Unterschlüssel.
			return NO;
		}
	}
	
	for (GKUserID *aUserID in userIDs) {
		if ([[aUserID digestPreferences] count] > 0) { //Standard Hashalgorithmus der Benutzer IDs.
			switch ([[[aUserID.digestPreferences objectAtIndex:0] substringFromIndex:1] integerValue]) {
				case 1: //MD5
				case 2: //SHA1
					return NO;
			}
		}
	}
	
	return YES;
}



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


- (NSUInteger)hash {
	return [fingerprint hash];
}
- (BOOL)isEqual:(id)anObject {
	return [fingerprint isEqualToString:[anObject description]];
}
- (NSString *)description {
	return [[fingerprint retain] autorelease];
}

- (void)dealloc {
	self.children = nil;
	self.subkeys = nil;
	self.userIDs = nil;
	self.photos = nil;
	self.textForFilter = nil;;
	
	self.fingerprint = nil;
	self.keyID = nil;
	self.shortKeyID = nil;
	
	self.creationDate = nil;
	self.expirationDate = nil;
	
	[super dealloc];
}



@end
