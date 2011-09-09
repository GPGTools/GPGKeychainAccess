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

#import "KeychainController.h"
#import "ActionController.h"

//KeychainController kümmert sich um das anzeigen und Filtern der Schlüssel-Liste.



@implementation KeychainController

@synthesize filteredKeyList;
@synthesize filterStrings;
//@synthesize keychain;
@synthesize userIDsSortDescriptors;
@synthesize subkeysSortDescriptors;
@synthesize keyInfosSortDescriptors;
//@synthesize secretKeys;

NSLock *updateLock;
NSSet *draggedKeyInfos;



- (BOOL)outlineView:(NSOutlineView*)outlineView writeItems:(NSArray*)items toPasteboard:(NSPasteboard *)pasteboard {
	NSMutableSet *keyInfos = [NSMutableSet setWithCapacity:[items count]];
	
	for (NSTreeNode *node in items) {
		[keyInfos addObject:[[node representedObject] primaryKey]];
	}
	draggedKeyInfos = keyInfos;
	
	NSPoint mousePoint = [mainWindow mouseLocationOutsideOfEventStream];
	
	NSScrollView *scrollView = [outlineView enclosingScrollView];
	NSRect visibleRect = [scrollView documentVisibleRect];
	NSRect scrollFrame = [scrollView frame];
	
	
	NSPoint imagePoint;
	imagePoint.x = mousePoint.x - scrollFrame.origin.x + visibleRect.origin.x - 40;
	imagePoint.y = scrollFrame.size.height - mousePoint.y + scrollFrame.origin.y + visibleRect.origin.y;

	NSEvent *event = [NSEvent mouseEventWithType:NSLeftMouseDown location:mousePoint modifierFlags:0 timestamp:0 windowNumber:[mainWindow windowNumber] context:nil eventNumber:0 clickCount:0 pressure:1];
	
	NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
    [pboard declareTypes:[NSArray arrayWithObject:NSFilesPromisePboardType] owner:self];
    [pboard setPropertyList:[NSArray arrayWithObject:@"asc"] forType:NSFilesPromisePboardType];
	
	NSImage *image = [NSImage imageNamed:@"asc"];
	[image setSize:(NSSize){56, 56}];
	
	[outlineView dragImage:image at:imagePoint offset:(NSSize){0, 0} event:event pasteboard:pboard source:self slideBack:YES];
	
	draggedKeyInfos = nil;
	
	return YES;
}

- (NSArray *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination {
	NSString *fileName;
	if ([draggedKeyInfos count] == 1) {
		fileName = [NSString stringWithFormat:@"%@.asc", [[draggedKeyInfos anyObject] shortKeyID]];
	} else {
		fileName = localized(@"Exported keys.asc");
	}
	
	NSData *exportedData = [actionController exportKeys:draggedKeyInfos armored:YES allowSecret:NO fullExport:NO];
	if (exportedData && [exportedData length] > 0) {
		[exportedData writeToFile:[[dropDestination path] stringByAppendingPathComponent:fileName] atomically:YES];
		
		return [NSArray arrayWithObject:fileName];
	} else {
		return nil;
	}
}





- (void)initKeychains {
	NSLog(@"initKeychains");
	allKeys = [[NSMutableSet alloc] init];
	//keychain = [[NSMutableDictionary alloc] initWithCapacity:10];
	filteredKeyList = [[NSMutableArray alloc] initWithCapacity:10];
}


- (void)asyncUpdateKeyInfo:(GPGKey *)keyInfo {
	[NSThread detachNewThreadSelector:@selector(updateKeyInfos:) toTarget:self withObject:[NSSet setWithObject:keyInfo]];
}
- (void)updateKeyInfo:(GPGKey *)keyInfo {
	[self updateKeyInfos:[NSSet setWithObject:keyInfo] withSigs:NO];
	
}
- (void)asyncUpdateKeyInfos:(NSObject <EnumerationList> *)keyInfos {
	[NSThread detachNewThreadSelector:@selector(updateKeyInfos:) toTarget:self withObject:keyInfos];
}
- (void)updateKeyInfos:(NSObject <EnumerationList> *)keyInfos {
	[self updateKeyInfos:keyInfos withSigs:NO];
}

- (void)updateKeyInfos:(NSObject <EnumerationList> *)keyInfos withSigs:(BOOL)withSigs {
	NSLog(@"Starte: updateKeyInfos");
	if (![updateLock tryLock]) {
		NSLog(@"updateKeyInfos tryLock return");
		return;
	}
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	
	GPGController *gpgc = [GPGController gpgController];
	NSSet *updatedKeys = [gpgc updateKeys:keyInfos withSigs:withSigs];
	
	[allKeys addObjectsFromArray:[updatedKeys allObjects]];
	
	[self performSelectorOnMainThread:@selector(updateFilteredKeyList:) withObject:nil waitUntilDone:YES];
	
	[pool drain];
	[updateLock unlock];
	NSLog(@"Fertig: updateKeyInfos");
}



- (IBAction)updateFilteredKeyList:(id)sender { //Darf nur im Main-Thread laufen!
	static BOOL isUpdating = NO;
	if (isUpdating) {return;}
	isUpdating = YES;
	
	NSMutableArray *keysToRemove;
	GPGKey *key;
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self willChangeValueForKey:@"filteredKeyList"];
	
	if ([sender isKindOfClass:[NSTextField class]]) {
		self.filterStrings = [[sender stringValue] componentsSeparatedByString:@" "];
	}
	
	keysToRemove = [NSMutableArray arrayWithArray:filteredKeyList];
	
	for (key in allKeys) {
		if ([self isKeyInfoPassingFilterTest:key]) {
			if ([keysToRemove containsObject:key]) {
				[keysToRemove removeObject:key];
			} else {
				[filteredKeyList addObject:key];
			}
		}
	}
	[filteredKeyList removeObjectsInArray:keysToRemove];
	[self didChangeValueForKey:@"filteredKeyList"];
	
	[numberOfKeysLabel setStringValue:[NSString stringWithFormat:localized(@"%i of %i keys listed"), [filteredKeyList count], [allKeys count]]];
	
	[pool drain];
	isUpdating = NO;
}


- (BOOL)isKeyInfoPassingFilterTest:(GPGKey *)keyInfo {
	if (showSecretKeysOnly && !keyInfo.secret) {
		return NO;
	}
	if (filterStrings && [filterStrings count] > 0) {
		for (NSString *searchString in filterStrings) {
			if ([searchString length] > 0) {
				if ([[keyInfo textForFilter] rangeOfString:searchString options:NSCaseInsensitiveSearch].length == 0) {
					return NO;
				}
			}
		}
	}
	return YES;
}

- (NSSet *)fingerprintsForKeyIDs:(NSSet *)keys {
	NSMutableSet *fingerprints = [NSMutableSet setWithCapacity:[keys count]];
	NSMutableDictionary *keyIdToFingerprint = [NSMutableDictionary dictionaryWithCapacity:[allKeys count] * 2];
	NSString *fingerprint;
	
	for (GPGKey *keyInfo in allKeys) {
		fingerprint = [keyInfo fingerprint];
		[keyIdToFingerprint setObject:fingerprint forKey:[keyInfo shortKeyID]];
		[keyIdToFingerprint setObject:fingerprint forKey:[keyInfo keyID]];
	}
	
	for (NSObject *key in keys) {
		NSString *keyID = [key description];
		if ([keyID length] < 32) {
			fingerprint = [keyIdToFingerprint objectForKey:keyID];
			if (fingerprint) {
				[fingerprints addObject:fingerprint];
			}
		} else {
			[fingerprints addObject:keyID];
		}

	}
	return fingerprints;
}


- (id)init {
	self = [super init];
	keychainController = self;
	return self;
}

- (void)awakeFromNib {
	NSLog(@"KeychainController awakeFromNib");
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	if (![self initGPG]) {
		NSLog(@"KeychainController awakeFromNib: NSApp terminate");
		[NSApp terminate:nil]; 
	}

	[self initKeychains];
	
	NSSortDescriptor *indexSort = [[NSSortDescriptor alloc] initWithKey:@"index" ascending:YES];
	NSSortDescriptor *nameSort = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
	NSArray *sortDesriptors = [NSArray arrayWithObject:indexSort];
	self.subkeysSortDescriptors = sortDesriptors;
	self.userIDsSortDescriptors = sortDesriptors;
	self.keyInfosSortDescriptors = [NSArray arrayWithObjects:indexSort, nameSort, nil];
	[indexSort release];
	[nameSort release];
	
	
	
	updateLock = [[NSLock alloc] init];
	[self updateKeyInfos:nil];
	
	
    [NSTimer scheduledTimerWithTimeInterval:300 target:self selector:@selector(updateThread) userInfo:nil repeats:YES];
	
	[pool drain];
}

- (BOOL)initGPG {
	return YES;
}




- (BOOL)showSecretKeysOnly {
    return showSecretKeysOnly;
}
- (void)setShowSecretKeysOnly:(BOOL)value {
    if (showSecretKeysOnly != value) {
        showSecretKeysOnly = value;
		[self updateFilteredKeyList:nil];
    }
}


- (void)updateThread {
	[self updateKeyInfos:nil];
}



@end


@implementation KeyAlgorithmTransformer
+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value {
	switch ([value integerValue]) {
		case GPG_RSAAlgorithm:
			return localized(@"GPG_RSAAlgorithm");
		case GPG_RSAEncryptOnlyAlgorithm:
			return localized(@"GPG_RSAEncryptOnlyAlgorithm");
		case GPG_RSASignOnlyAlgorithm:
			return localized(@"GPG_RSASignOnlyAlgorithm");
		case GPG_ElgamalEncryptOnlyAlgorithm:
			return localized(@"GPG_ElgamalEncryptOnlyAlgorithm");
		case GPG_DSAAlgorithm:
			return localized(@"GPG_DSAAlgorithm");
		case GPG_EllipticCurveAlgorithm:
			return localized(@"GPG_EllipticCurveAlgorithm");
		case GPG_ECDSAAlgorithm:
			return localized(@"GPG_ECDSAAlgorithm");
		case GPG_ElgamalAlgorithm:
			return localized(@"GPG_ElgamalAlgorithm");
		case GPG_DiffieHellmanAlgorithm:
			return localized(@"GPG_DiffieHellmanAlgorithm");
		default:
			return @"";
	}
}

@end

@implementation GPGKeyStatusTransformer
+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value {
	NSMutableString *statusText = [NSMutableString stringWithCapacity:2];
	NSInteger intValue = [value integerValue];
	
	switch (intValue & 7) {
		case 2:
			[statusText appendString:localized(@"?")]; //Was bedeutet 2? 
			break;
		case 3:
			[statusText appendString:localized(@"Marginal")];
			break;
		case 4:
			[statusText appendString:localized(@"Full")];
			break;
		case 5:
			[statusText appendString:localized(@"Ultimate")];
			break;
		default:
			[statusText appendString:localized(@"Unknown")];
			break;
	}
	
	if (intValue & GPGKeyStatus_Invalid) {
		[statusText appendFormat:@", %@", localized(@"Invalid")];
	}
	if (intValue & GPGKeyStatus_Revoked) {
		[statusText appendFormat:@", %@", localized(@"Revoked")];
	}
	if (intValue & GPGKeyStatus_Expired) {
		[statusText appendFormat:@", %@", localized(@"Expired")];
	}
	if (intValue & GPGKeyStatus_Disabled) {
		[statusText appendFormat:@", %@", localized(@"Disabled")];
	}
	return [[statusText copy] autorelease];
}

@end

@implementation GPGKey (GKAExtension)
- (NSString *)type { return secret ? @"sec" : @"pub"; }
- (NSString *)longType { return secret ? localized(@"Secret and public key") : localized(@"Public key"); }
@end

