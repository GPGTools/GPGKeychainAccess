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

- (GPGKey *)defaultKey {
	if ([self.secretKeys count] == 0) {
		return nil;
	}
	NSString *defaultKey = [[GPGOptions sharedOptions] valueForKey:@"default-key"];
	
	if (defaultKey.length == 0) {
		return nil;
	}
	
	for (GPGKey *key in self.secretKeys) {
		if ([key.textForFilter rangeOfString:defaultKey].length > 0) {
			return key;
		}
	}
	return nil;
}



// NSOutlineView delegate.
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldReorderColumn:(NSInteger)columnIndex toColumn:(NSInteger)newColumnIndex {
	return columnIndex != 0 && newColumnIndex != 0;
}

//Für Drag & Drop.
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
	
	NSData *exportedData = [[ActionController sharedInstance] exportKeys:draggedKeys armored:YES allowSecret:NO fullExport:NO];
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
		NSMutableSet *realKeys = [NSMutableSet setWithCapacity:[keys count]];
		
		//Fingerabdrücke wenn möglich durch die entsprechenden Schlüssel ersetzen.
		Class keyClass = [GPGKey class];
		for (GPGKey *key in keys) {
			if (![key isKindOfClass:keyClass]) {
				GPGKey *tempKey = [allKeys member:key];
				if (tempKey) {
					key = tempKey;
				}
			}
			[realKeys addObject:key];
		}
		keys = realKeys;
		
		NSSet *updatedKeys;
		if ([keys count] == 0) {
			updatedKeys = [gpgc updateKeys:self.allKeys searchFor:nil withSigs:withSigs];
		} else {
			updatedKeys = [gpgc updateKeys:keys withSigs:withSigs];
		}
	
		if (gpgc.error) {
			@throw gpgc.error;
		}
		
		if ([keys count] == 0) {
			keys = self.allKeys;
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

	static NSLock *lock = nil;
	if (!lock) {
		lock = [NSLock new];
	}
	if (![lock tryLock]) {
		return;
	}
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
	[lock unlock];
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











- (void)awakeFromNib {
	NSLog(@"KeychainController awakeFromNib");
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	
	// Testen ob GPG vorhanden und funktionsfähig ist.
	if (![GPGController gpgVersion]) {
		//TODO: Fehlermeldung ausgeben.
		NSLog(@"KeychainController awakeFromNib: NSApp terminate");
		[NSApp terminate:nil]; 
	}
	
	
	// Schlüssellisten initialisieren.
	self.allKeys = [NSMutableSet setWithCapacity:50];
	self.filteredKeyList = [[NSMutableArray alloc] initWithCapacity:10];
	
	
	// Sort Descriptoren anlegen.
	NSSortDescriptor *indexSort = [NSSortDescriptor sortDescriptorWithKey:@"index" ascending:YES];
	NSSortDescriptor *nameSort = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];

	NSArray *sortDesriptors = [NSArray arrayWithObject:indexSort];
	self.subkeysSortDescriptors = sortDesriptors;
	self.userIDsSortDescriptors = sortDesriptors;
	self.keysSortDescriptors = [NSArray arrayWithObjects:indexSort, nameSort, nil];
	
	
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





// Singleton: alloc, init etc.
+ (id)sharedInstance {
	static id sharedInstance = nil;
    if (!sharedInstance) {
        sharedInstance = [[super allocWithZone:nil] init];
    }
    return sharedInstance;	
}
- (id)init {
	static BOOL initialized = NO;
	if (!initialized) {
		initialized = YES;
		self = [super init];
		
		self.gpgc = [GPGController gpgController];
	}
	return self;
}
+ (id)allocWithZone:(NSZone *)zone {
    return [[self sharedInstance] retain];	
}
- (id)copyWithZone:(NSZone *)zone {
    return self;
}
- (id)retain {
    return self;
}
- (NSUInteger)retainCount {
    return NSUIntegerMax;
}
- (oneway void)release {
}
- (id)autorelease {
    return self;
}






@end


@implementation GPGKey (GKAExtension)
- (NSString *)type { return secret ? @"sec" : @"pub"; }
- (NSString *)longType { return secret ? localized(@"Secret and public key") : localized(@"Public key"); }
@end

