/*
 Copyright © Roman Zechmeister, 2011
 
 Diese Datei ist Teil von GPG Keychain Access.
 
 GPG Keychain Access ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung von GPG Keychain Access erfolgt in der Hoffnung, daß es Ihnen 
 von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite 
 Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck. 
 Details finden Sie in der GNU General Public License.
 
 Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem 
 Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
*/

#import "KeychainController.h"
#import "ActionController.h"

//KeychainController kümmert sich um das anzeigen und Filtern der Schlüssel-Liste.

@interface KeychainController ()
@property (retain) NSMutableSet *allKeys;
@property (retain) NSMutableArray *filteredKeyList;
@property (retain) GPGController *gpgc;
- (void)updateKeyList:(NSDictionary *)dict;
@end


@implementation KeychainController
@synthesize filteredKeyList, filterStrings, userIDsSortDescriptors, subkeysSortDescriptors, keysSortDescriptors, allKeys, gpgc;
NSLock *updateLock;
NSSet *draggedKeys;


- (BOOL)showSecretKeysOnly {
    return showSecretKeysOnly;
}
- (void)setShowSecretKeysOnly:(BOOL)value {
    if (showSecretKeysOnly != value) {
        showSecretKeysOnly = value;
		[self updateFilteredKeyList:nil];
    }
}

- (NSSet *)secretKeys {
	if (!secretKeys) {
		NSPredicate *secrectKeyPredicate = [NSPredicate predicateWithFormat:@"secret==YES"];
		secretKeys = [[allKeys filteredSetUsingPredicate:secrectKeyPredicate] retain];
	}
	return [[secretKeys retain] autorelease];
}


// Für Drag & Drop.
- (BOOL)outlineView:(NSOutlineView*)outlineView writeItems:(NSArray*)items toPasteboard:(NSPasteboard *)pasteboard {
	NSMutableSet *keys = [NSMutableSet setWithCapacity:[items count]];
	
	for (NSTreeNode *node in items) {
		[keys addObject:[[node representedObject] primaryKey]];
	}
	draggedKeys = keys;
	
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
	
	draggedKeys = nil;
	
	return YES;
}

- (NSArray *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination {
	NSString *fileName;
	if ([draggedKeys count] == 1) {
		fileName = [NSString stringWithFormat:@"%@.asc", [[draggedKeys anyObject] shortKeyID]];
	} else {
		fileName = localized(@"Exported keys.asc");
	}
	
	NSData *exportedData = [actionController exportKeys:draggedKeys armored:YES allowSecret:NO fullExport:NO];
	if (exportedData && [exportedData length] > 0) {
		[exportedData writeToFile:[[dropDestination path] stringByAppendingPathComponent:fileName] atomically:YES];
		
		return [NSArray arrayWithObject:fileName];
	} else {
		return nil;
	}
}


// Metoden zum aktualisieren der Schlüsselliste.
- (void)asyncUpdateKey:(GPGKey *)key {
	[NSThread detachNewThreadSelector:@selector(updateKeys:) toTarget:self withObject:[NSSet setWithObject:key]];
}
- (void)updateKey:(GPGKey *)key {
	[self updateKeys:[NSSet setWithObject:key] withSigs:NO];
}
- (void)asyncUpdateKeys:(NSObject <EnumerationList> *)keys {
	[NSThread detachNewThreadSelector:@selector(updateKeys:) toTarget:self withObject:keys];
}
- (void)updateKeys:(NSObject <EnumerationList> *)keys {
	[self updateKeys:keys withSigs:NO];
}
- (void)updateKeys:(NSObject <EnumerationList> *)keys withSigs:(BOOL)withSigs {
	NSLog(@"updateKeys:withSigs: start");
	if (![updateLock tryLock]) {
		NSLog(@"updateKeys:withSigs: tryLock return");
		return;
	}
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	@try {
		NSSet *updatedKeys = [gpgc updateKeys:keys withSigs:withSigs];
		if (gpgc.error) {
			@throw gpgc.error;
		}
		
		NSMutableSet *keysToRemove = [keys mutableCopy];
		[keysToRemove minusSet:updatedKeys];
		
		NSDictionary *updateInfos = [NSDictionary dictionaryWithObjectsAndKeys:updatedKeys, @"keysToAdd", keysToRemove, @"keysToRemove", nil];
		
		[self performSelectorOnMainThread:@selector(updateKeyList:) withObject:updateInfos waitUntilDone:YES];

	} @catch (NSException *exception) {
		NSLog(@"updateKeys:withSigs: failed – %@", exception);
	} @finally {
		[pool drain];
		[updateLock unlock];
	}
	
	NSLog(@"updateKeys:withSigs: end");
}

- (void)updateKeyList:(NSDictionary *)dict {
	NSAssert([NSThread isMainThread], @"updateKeyList must run in the main thread!");
	
	NSSet *keysToRemove = [dict objectForKey:@"keysToRemove"];
	NSSet *keysToAdd = [dict objectForKey:@"keysToAdd"];
	
	[self.allKeys minusSet:keysToRemove];
	[self.allKeys unionSet:keysToAdd];
	
	[secretKeys release];
	secretKeys = nil;
	
	[self updateFilteredKeyList:nil];
}

- (IBAction)updateFilteredKeyList:(id)sender {
	NSAssert([NSThread isMainThread], @"updateFilteredKeyList must run in the main thread!");

	static BOOL isUpdating = NO;
	if (isUpdating) {return;}
	isUpdating = YES;
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSMutableArray *keysToRemove;
	GPGKey *key;
	
	[self willChangeValueForKey:@"filteredKeyList"];
	
	if ([sender isKindOfClass:[NSTextField class]]) {
		self.filterStrings = [[sender stringValue] componentsSeparatedByString:@" "];
	}
	
	keysToRemove = [NSMutableArray arrayWithArray:filteredKeyList];
	
	for (key in self.allKeys) {
		if ([self isKeyPassingFilterTest:key]) {
			if ([keysToRemove containsObject:key]) {
				[keysToRemove removeObject:key];
			} else {
				[filteredKeyList addObject:key];
			}
		}
	}
	[filteredKeyList removeObjectsInArray:keysToRemove];
	[self didChangeValueForKey:@"filteredKeyList"];
	
	[numberOfKeysLabel setStringValue:[NSString stringWithFormat:localized(@"%i of %i keys listed"), [filteredKeyList count], [self.allKeys count]]];
	
	[pool drain];
	isUpdating = NO;
}


- (BOOL)isKeyPassingFilterTest:(GPGKey *)key {
	if (showSecretKeysOnly && !key.secret) {
		return NO;
	}
	if (filterStrings && [filterStrings count] > 0) {
		for (NSString *searchString in filterStrings) {
			if ([searchString length] > 0) {
				if ([[key textForFilter] rangeOfString:searchString options:NSCaseInsensitiveSearch].length == 0) {
					return NO;
				}
			}
		}
	}
	return YES;
}


- (id)init {
	if ((self = [super init])) {
		self.gpgc = [GPGController gpgController];
		keychainController = self;
	}
	return self;
}

- (void)awakeFromNib {
	NSLog(@"KeychainController awakeFromNib");
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	
	// Testen ob GPG vorhanden zbd funktionsfähig ist.
	if ([gpgc testGPG]) {
		//TODO: Fehlermeldung ausgeben.
		NSLog(@"KeychainController awakeFromNib: NSApp terminate");
		[NSApp terminate:nil]; 
	}

	
	// Schlüssellisten initialisieren.
	self.allKeys = [NSMutableSet setWithCapacity:50];
	self.filteredKeyList = [[NSMutableArray alloc] initWithCapacity:10];
	
	
	// Sort Descriptoren anlegen.
	NSSortDescriptor *indexSort = [[NSSortDescriptor alloc] initWithKey:@"index" ascending:YES];
	NSSortDescriptor *nameSort = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
	NSArray *sortDesriptors = [NSArray arrayWithObject:indexSort];
	self.subkeysSortDescriptors = sortDesriptors;
	self.userIDsSortDescriptors = sortDesriptors;
	self.keysSortDescriptors = [NSArray arrayWithObjects:indexSort, nameSort, nil];
	[indexSort release];
	[nameSort release];
	
	
	// updateLock initialisieren und Schlüsselliste füllen.
	updateLock = [[NSLock alloc] init];
	[self updateKeys:nil];
	
	
	// Alle 300 Sekunden die Schlüsselliste aktualisieren.
	NSInvocation *updateInvocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:@selector(updateKeys:)]];
	updateInvocation.target = self;
	updateInvocation.selector = @selector(updateKeys:);
	[NSTimer scheduledTimerWithTimeInterval:300 invocation:updateInvocation repeats:YES];
	
	
	[pool drain];
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

