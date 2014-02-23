/*
 Copyright © Roman Zechmeister, 2014
 
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
#import "SheetController.h"
#include <sys/time.h>


//KeychainController kümmert sich um das anzeigen und Filtern der Schlüssel-Liste.


@implementation KeychainController
@synthesize filterStrings, userIDsSortDescriptors, subkeysSortDescriptors, keysSortDescriptors, showSecretKeysOnly;
NSLock *updateLock;
NSSet *draggedKeys;



- (NSSet *)secretKeys {
	if (!secretKeys) {
		NSPredicate *secrectKeyPredicate = [NSPredicate predicateWithFormat:@"secret==YES"];
		secretKeys = [[self.allKeys filteredSetUsingPredicate:secrectKeyPredicate] retain];
	}
	return [[secretKeys retain] autorelease];
}

- (GPGKey *)defaultKey {
	if ([self.secretKeys count] == 0) {
		return nil;
	}
	NSString *defaultKey = [[GPGOptions sharedOptions] valueForKey:@"default-key"];
	
	if (defaultKey.length == 0) {
		return [self.secretKeys anyObject];
	}
	
	for (GPGKey *key in self.secretKeys) {
		if ([key.textForFilter rangeOfString:defaultKey].length > 0) {
			return key;
		}
	}
	return nil;
}


- (NSArray *)selectionIndexPaths {
	return [[_selectionIndexPaths retain] autorelease];
}
- (void)setSelectionIndexPaths:(NSArray *)value {
	if (!userChangingSelection && _selectionIndexPaths.count > 0) {
		NSUInteger index = [[_selectionIndexPaths objectAtIndex:0] indexAtPosition:0];
		if (index != NSNotFound) {
			if (index >= filteredKeyList.count) {
				index = filteredKeyList.count - 1;
			}
			value = @[[NSIndexPath indexPathWithIndex:index]];
		}
	}
	userChangingSelection = NO;
	if (_selectionIndexPaths != value) {
		id old = _selectionIndexPaths;
		_selectionIndexPaths = [value retain];
		[old release];
		
		[self fetchDetailsForSelectedKey];
	}
}
- (void)selectRow:(NSInteger)row {
	userChangingSelection = YES;
	self.selectionIndexPaths = @[[NSIndexPath indexPathWithIndex:row]];
}

- (BOOL)fetchDetailsForSelectedKey { // Returns YES if the details will be fetched.
	if (_selectionIndexPaths.count == 1) {
		NSUInteger index = [[_selectionIndexPaths objectAtIndex:0] indexAtPosition:0];
		if (index != NSNotFound) {
			GPGKey *key = [[[[treeController.arrangedObjects childNodes] objectAtIndex:index] representedObject] primaryKey];
			key = [self.allKeys member:key];
			if (key && !key.primaryUserID.signatures) {
				[[GPGKeyManager sharedInstance] loadSignaturesAndAttributesForKeys:[NSSet setWithObject:key] completionHandler:nil];
				return YES;
			}
		}
	}
	return NO;
}



- (BOOL)selectionShouldChangeInOutlineView:(NSOutlineView *)outlineView {
	userChangingSelection = YES;
	return YES;
}

// NSOutlineView delegate.
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldReorderColumn:(NSInteger)columnIndex toColumn:(NSInteger)newColumnIndex {
	return columnIndex != 0 && newColumnIndex != 0;
}

//Für Drag & Drop.
- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray*)items toPasteboard:(NSPasteboard *)pasteboard {
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
	
	GPGController *gc = [GPGController gpgController];
	gc.async = NO;
	gc.useArmor = YES;
	gc.printVersion = YES;
	NSData *exportedData = [gc exportKeys:draggedKeys allowSecret:NO fullExport:NO];
	if ([exportedData length] > 0) {
		[exportedData writeToFile:[[dropDestination path] stringByAppendingPathComponent:fileName] atomically:YES];
		
		return [NSArray arrayWithObject:fileName];
	} else {
		return nil;
	}
}






- (IBAction)updateFilteredKeyList:(id)sender {
	if ([sender isKindOfClass:[NSTextField class]]) {
		self.filterStrings = [[sender stringValue] componentsSeparatedByString:@" "];
	}
}



- (void)keysDidChange:(NSNotification *)notification {
	if (![self fetchDetailsForSelectedKey]) {
		[self willChangeValueForKey:@"allKeys"];
		[self didChangeValueForKey:@"allKeys"];
	}
}


- (NSSet *)allKeys {
	return [GPGKeyManager sharedInstance].allKeys;
}


- (NSArray *)filteredKeyList {
	NSSet *filteredKeys = [self.allKeys objectsPassingTest:^BOOL(GPGKey *key, BOOL *stop) {
		if (showSecretKeysOnly && !key.secret) {
			return NO;
		}
		if (filterStrings.count > 0) {
			for (NSString *searchString in filterStrings) {
				if ([searchString length] > 0) {
					if ([[key textForFilter] rangeOfString:searchString options:NSCaseInsensitiveSearch].length == 0) {
						return NO;
					}
				}
			}
		}
		return YES;
	}];
	
	
	NSArray *old = filteredKeyList;
	filteredKeyList = [[filteredKeys allObjects] retain];
	[old release];
	
	[numberOfKeysLabel setStringValue:[NSString stringWithFormat:localized(@"%i of %i keys listed"), filteredKeyList.count, self.allKeys.count]];
	
	return [[filteredKeyList retain] autorelease];
}


+ (NSSet*)keyPathsForValuesAffectingFilteredKeyList {
	return [NSSet setWithObjects:@"allKeys", @"filterStrings", @"showSecretKeysOnly", nil];
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
		
		NSLog(@"GPG Keychain Access version: %@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]);
		
		
		// Testen ob GPG vorhanden und funktionsfähig ist.
		NSException *error = nil;
		GPGErrorCode errorCode = [GPGController testGPGError:&error];
		GPGDebugLog(@"KeychainController init testGPG: %i", errorCode);
		
		switch (errorCode) {
			case GPGErrorNotFound:
				NSRunCriticalAlertPanel(localized(@"GPG_NOT_FOUND_TITLE"), localized(@"GPG_NOT_FOUND_MESSAGE"), nil, nil, nil);
				[NSApp terminate:nil];
				break;
			case GPGErrorConfigurationError: {
				NSString *details = @"";
				if ([error isKindOfClass:[GPGException class]]) {
					details = [(GPGException *)error gpgTask].errText;
				}
				NSRunCriticalAlertPanel(localized(@"GPG_CONFIG_ERROR_TITLE"), [NSString stringWithFormat:localized(@"GPG_CONFIG_ERROR_MESSAGE"), details], nil, nil, nil);
				[NSApp terminate:nil];
				break; }
			default:
				break;
		}

		[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(keysDidChange:) name:GPGKeyManagerKeysDidChangeNotification object:nil];
		@try {
			[[GPGKeyManager sharedInstance] loadAllKeys];
		}
		@catch (NSException *exception) {
			NSLog(@"loadAllKeys threw exception: %@", exception);
		}
		
		
		// Sort Descriptoren anlegen.
		NSSortDescriptor *nameSort = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
		
		self.keysSortDescriptors = [NSArray arrayWithObject:nameSort];
		
		[keyTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];

		
		self = [super init];
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
- (NSString *)type {
	if (_primaryKey == self) {
		return self.secret ? @"sec/pub" : @"pub";
	} else {
		return @"sub";
	}
}
- (NSString *)longType {
	if (_primaryKey == self) {
		return self.secret ? localized(@"Secret and public key") : localized(@"Public key");
	} else {
		return nil;
	}
}
- (NSString *)capabilities {
	
	NSString *e = @"", *s = @"", *c = @"", *a = @"";
	if (self.canEncrypt) {
		e = @"e";
	} else if (self.canAnyEncrypt) {
		e = @"E";
	}
	if (self.canSign) {
		s = @"s";
	} else if (self.canAnySign) {
		s = @"S";
	}
	if (self.canCertify) {
		c = @"c";
	} else if (self.canAnyCertify) {
		c = @"C";
	}
	if (self.canAuthenticate) {
		a = @"a";
	} else if (self.canAnyAuthenticate) {
		a = @"A";
	}
	
	return [NSString stringWithFormat:@"%@%@%@%@", e, s, c, a];
}
- (id)children {
	return nil;
}
- (NSArray *)photos {
	NSArray *photoIDs = [self.userIDs objectsAtIndexes:[self.userIDs indexesOfObjectsPassingTest:^BOOL(GPGUserID *uid, NSUInteger idx, BOOL *stop) {
		return uid.isUat;
	}]];
	
	
	return photoIDs;
}
- (void)setDisabled:(BOOL)value {
}

- (NSString *)userIDAndKeyID {
	return [NSString stringWithFormat:@"%@ (%@)", self.userIDDescription, self.keyID.shortKeyID];
}

- (BOOL)detailsLoaded {
	return !!self.primaryUserID.signatures;
}

@end

@implementation GPGUserID (GKAExtension)
- (NSInteger)status {
	return 0;
}
- (NSString *)type {
	return _name ? @"uid" : @"uat";
}
- (id)shortKeyID {
	return nil;
}
- (id)length {
	return nil;
}
- (id)algorithm {
	return nil;
}
- (id)children {
	return nil;
}
- (NSString *)userIDDescription {
	if (_userIDDescription) {
		return [[_userIDDescription retain] autorelease];
	} else {
		return localized(@"PhotoID");
	}
}
- (NSString *)name {
	if (_name) {
		return [[_name retain] autorelease];
	} else {
		return localized(@"PhotoID");
	}
}
- (BOOL)isUat {
	return !_name;
}

@end

@implementation GPGUserIDSignature (GKAExtension)
- (NSString *)type {
	NSString *classString = (self.signatureClass & 3) ? [NSString stringWithFormat:@" %i", (self.signatureClass & 3)] : @"";
	NSString *typeString = self.revocation ? @"rev" : @"sig";
	NSString *localString = self.local ? @" L" : @"";
	
	return [NSString stringWithFormat:@"%@%@%@", typeString, classString, localString];
}
@end
