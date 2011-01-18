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
#import "GKKey.h"
#import "ActionController.h"

//KeychainController kümmert sich um das anzeigen und Filtern der Schlüssel-Liste.



@implementation KeychainController

@synthesize filteredKeyList;
@synthesize filterStrings;
@synthesize keychain;
@synthesize userIDsSortDescriptors;
@synthesize subkeysSortDescriptors;
@synthesize keyInfosSortDescriptors;
@synthesize secretKeys;

NSLock *updateLock;
NSSet *draggedKeyInfos;



- (BOOL)outlineView:(NSOutlineView*)outlineView writeItems:(NSArray*)items toPasteboard:(NSPasteboard *)pasteboard {
	NSMutableSet *keyInfos = [NSMutableSet setWithCapacity:[items count]];
	
	for (NSTreeNode *node in items) {
		[keyInfos addObject:[[node representedObject] primaryKeyInfo]];
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
	keychain = [[NSMutableDictionary alloc] initWithCapacity:10];
	filteredKeyList = [[NSMutableArray alloc] initWithCapacity:10];
}


- (void)asyncUpdateKeyInfo:(GKKey *)keyInfo {
	[NSThread detachNewThreadSelector:@selector(updateKeyInfos:) toTarget:self withObject:[NSSet setWithObject:keyInfo]];
}
- (void)updateKeyInfo:(GKKey *)keyInfo {
	[self updateKeyInfos:[NSSet setWithObject:keyInfo] withSigs:NO];
	
}
- (void)asyncUpdateKeyInfos:(NSObject <GKEnumerationList> *)keyInfos {
	[NSThread detachNewThreadSelector:@selector(updateKeyInfos:) toTarget:self withObject:keyInfos];
}
- (void)updateKeyInfos:(NSObject <GKEnumerationList> *)keyInfos {
	[self updateKeyInfos:keyInfos withSigs:NO];
}

- (void)updateKeyInfos:(NSObject <GKEnumerationList> *)keyInfos withSigs:(BOOL)withSigs {
	NSLog(@"Starte: updateKeyInfos");
	if (![updateLock tryLock]) {
		NSLog(@"updateKeyInfos tryLock return");
		return;
	}
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	GKKey *keyInfo;
	
	NSSet *secKeyFingerprints;
	NSArray *fingerprints;
	NSArray *listings;
	NSString *pubColonListing, *secColonListing;
	
	
	@try {
		if (keyInfos && [keyInfos count] > 0) { // Nur die übergebenene Schlüssel aktualisieren.
			NSLog(@"updateKeyInfos: Update selected keys");
			
			NSData *outData;
			NSMutableArray *arguments;
			NSMutableSet *fingerprintSet = [NSMutableSet setWithCapacity:[keyInfos count]];
			
			
			for (NSObject *aObject in keyInfos) {
				if ([aObject isKindOfClass:[GKKey class]]) {
					[fingerprintSet addObject:[[(GKKey *)aObject primaryKeyInfo] fingerprint]];
				} else {
					[fingerprintSet addObject:[aObject description]];
				}
			}
			NSArray *fingerprintsToUpdate = [fingerprintSet allObjects];
			
			arguments = [NSMutableArray arrayWithObjects:withSigs || [keyInfos count] < 5 ? @"--list-sigs" : @"--list-public-keys", @"--with-fingerprint", @"--with-fingerprint", nil];
			[arguments addObjectsFromArray:fingerprintsToUpdate];
			runGPGCommandWithArray(nil, &outData, nil, nil, nil, arguments);
			pubColonListing = dataToString(outData);
			
			
			arguments = [NSMutableArray arrayWithObjects:@"--list-secret-keys", @"--with-fingerprint", nil];
			[arguments addObjectsFromArray:fingerprintsToUpdate];
			runGPGCommandWithArray(nil, &outData, nil, nil, nil, arguments);
			secColonListing = dataToString(outData);
			
			
			[GKKey colonListing:pubColonListing toArray:&listings andFingerprints:&fingerprints];
			secKeyFingerprints = [GKKey fingerprintsFromColonListing:secColonListing];
			
			
			NSDictionary *argumentDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
												listings, @"listings", 
												fingerprints, @"fingerprints", 
												secKeyFingerprints, @"secKeyFingerprints", 
												fingerprintSet, @"keysToUpdate",
												[NSNumber numberWithBool:withSigs], @"withSigs", nil];
			
			
			[self performSelectorOnMainThread:@selector(updateKeyInfosWithDict:) withObject:argumentDictionary waitUntilDone:YES];
			
			
			NSString *fingerprint;
			NSMutableSet *newSecretKeysSet = [NSMutableSet setWithSet:secretKeys];
			for (fingerprint in secretKeys) {
				if ([fingerprintSet containsObject:fingerprint] && ![secKeyFingerprints containsObject:fingerprint]) {
					[newSecretKeysSet removeObject:fingerprint];
				}
			}
			secKeyFingerprints = [newSecretKeysSet copy];
			
			for (fingerprint in fingerprintSet) {
				keyInfo = [keychain objectForKey:fingerprint];
				[keyInfo updateFilterText];
			}
		} else { // Den kompletten Schlüsselbund aktualisieren.
			NSLog(@"updateKeyInfos: Update all keys");
			
			runGPGCommand(nil, &pubColonListing, nil, withSigs ? @"--list-sigs" : @"--list-public-keys", @"--with-fingerprint", @"--with-fingerprint", nil);
			runGPGCommand(nil, &secColonListing, nil, @"--list-secret-keys", @"--with-fingerprint", nil);
			
			[GKKey colonListing:pubColonListing toArray:&listings andFingerprints:&fingerprints];
			secKeyFingerprints = [GKKey fingerprintsFromColonListing:secColonListing];
			
			
			NSDictionary *argumentDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
												listings, @"listings", 
												fingerprints, @"fingerprints", 
												secKeyFingerprints, @"secKeyFingerprints",
												[NSNumber numberWithBool:withSigs], @"withSigs", nil];
			
			
			[self performSelectorOnMainThread:@selector(updateKeyInfosWithDict:) withObject:argumentDictionary waitUntilDone:YES];
			
			
			
			NSEnumerator *keychainEnumerator = [keychain objectEnumerator];
			while (keyInfo = [keychainEnumerator nextObject]) {
				[keyInfo updateFilterText];
			}
		}
		self.secretKeys = secKeyFingerprints;
		[self performSelectorOnMainThread:@selector(updateFilteredKeyList:) withObject:nil waitUntilDone:YES];
		
	} @catch (NSException * e) {
		NSLog(@"Fehler in updateKeyInfos: %@", [e reason]);
	} @finally {
		[pool drain];
		[updateLock unlock];
	}
	NSLog(@"Fertig: updateKeyInfos");
}



- (void)updateKeyInfosWithDict:(NSDictionary *)aDict {
	NSLog(@"updateKeyInfosWithDict");

	NSArray *fingerprints = [aDict objectForKey:@"fingerprints"];
	NSArray *listings = [aDict objectForKey:@"listings"];	
	NSSet *secKeyFingerprints = [aDict objectForKey:@"secKeyFingerprints"];
	NSSet *keysToUpdate = [aDict objectForKey:@"keysToUpdate"];
	BOOL withSigs = [[aDict objectForKey:@"withSigs"] boolValue];
	
	
	NSUInteger i, count = [fingerprints count];
	for (i = 0; i < count; i++) {
		NSString *fingerprint = [fingerprints objectAtIndex:i];
		NSArray *listing = [listings objectAtIndex:i];
		
		GKKey *keyInfo = [keychain objectForKey:fingerprint];
		BOOL secret = [secKeyFingerprints containsObject:fingerprint];
		if (keyInfo) {
			[keyInfo updateWithListing:listing isSecret:secret withSigs:withSigs];
		} else {
			keyInfo = [GKKey keyInfoWithListing:listing fingerprint:fingerprint isSecret:secret withSigs:withSigs];
			[keychain setObject:keyInfo forKey:fingerprint];
		}
		
	}	
	
	NSMutableArray *keysToRemove = [NSMutableArray arrayWithArray:keysToUpdate ? [keysToUpdate allObjects] : [keychain allKeys]];
	[keysToRemove removeObjectsInArray:fingerprints];
	
	[keychain removeObjectsForKeys:keysToRemove];
	NSLog(@"updateKeyInfosWithDict Fertig");
}


- (IBAction)updateFilteredKeyList:(id)sender { //Darf nur im Main-Thread laufen!
	static BOOL isUpdating = NO;
	if (isUpdating) {return;}
	isUpdating = YES;
	
	NSMutableArray *keysToRemove;
	NSArray *myKeyList;
	GKKey *keyInfo;
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self willChangeValueForKey:@"filteredKeyList"];
	
	if ([sender isKindOfClass:[NSTextField class]]) {
		self.filterStrings = [[sender stringValue] componentsSeparatedByString:@" "];
	}
	
	keysToRemove = [NSMutableArray arrayWithArray:filteredKeyList];
	
	myKeyList = [keychain allValues];
	for (keyInfo in myKeyList) {
		if ([self isKeyInfoPassingFilterTest:keyInfo]) {
			if ([keysToRemove containsObject:keyInfo]) {
				[keysToRemove removeObject:keyInfo];
			} else {
				[filteredKeyList addObject:keyInfo];
			}
		}
	}
	[filteredKeyList removeObjectsInArray:keysToRemove];
	[self didChangeValueForKey:@"filteredKeyList"];
	
	[numberOfKeysLabel setStringValue:[NSString stringWithFormat:localized(@"%i of %i keys listed"), [filteredKeyList count], [keychain count]]];
	
	[pool drain];
	isUpdating = NO;
}


- (BOOL)isKeyInfoPassingFilterTest:(GKKey *)keyInfo {
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
	NSMutableDictionary *keyIdToFingerprint = [NSMutableDictionary dictionaryWithCapacity:[keychain count] * 2];
	NSString *fingerprint;
	
	for (GKKey *keyInfo in [[self keychain] allValues]) {
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
	[self initAgent];

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
	NSLog(@"initGPG");
	@try {
		
		GPG_VERSION = 2;
		NSString *gpgPath = [self findExecutableWithName:@"gpg2"];
		if (!gpgPath) {
			GPG_VERSION = 1;
			gpgPath = [self findExecutableWithName:@"gpg"];
			if (!gpgPath) {
				NSRunAlertPanel(localized(@"Error"), localized(@"GPGNotFound_Msg"), localized(@"Quit_Button"), nil, nil);
				return NO;
			}
		}
		GPG_PATH = [gpgPath retain];
		NSLog(@"GPG_VERSION: %i", GPG_VERSION);
		NSLog(@"GPG_PATH: %@", GPG_PATH);

		
		NSString *gpgAgentPath = [self findExecutableWithName:@"gpg-agent"];
		if (gpgAgentPath) {
			GPG_AGENT_PATH = [gpgAgentPath retain];
			NSLog(@"GPG_AGENT_PATH: %@", GPG_AGENT_PATH);
		} else {
			GPG_AGENT_PATH = nil;
			NSRunAlertPanel(localized(@"GPGAgentNotFound_Title"), localized(@"GPGAgentNotFound_Msg"), nil, nil, nil);
		}

				
		
		NSString *errText;
		if (runGPGCommand(nil, nil, &errText, @"--gpgconf-test", nil) != 0) {
			NSRunAlertPanel(localized(@"GPGNotStart_Title"), localized(@"GPGNotStart_Msg"), localized(@"Quit_Button"), nil, nil);
			NSLog(@"initGPG: --gpgconf-test fehlgeschlagen: \"%@\"", errText);
			return NO;
		}
	}
	@catch (NSException *e) {
		NSRunAlertPanel(localized(@"Error"), localized(@"GPGInitError_Msg"), localized(@"Quit_Button"), nil, nil);
		NSLog(@"initGPG: NSException - Reason: \"%@\"", [e reason]);
		return NO;
	}
	return YES;
}

- (NSString *)findExecutableWithName:(NSString *)executable {
	NSString *foundPath;
	NSArray *searchPaths = [NSMutableArray arrayWithObjects:@"/usr/local/MacGPG2/bin", @"/usr/local/bin", @"/usr/bin", @"/bin", @"/opt/local/bin", @"/sw/bin", nil];
	
	foundPath = [self findExecutableWithName:executable atPaths:searchPaths];
	if (foundPath) {
		return foundPath;
	}
	
	NSString *envPATH = [[[NSProcessInfo processInfo] environment] objectForKey:@"PATH"];
	if (envPATH) {
		NSArray *searchPaths = [envPATH componentsSeparatedByString:@":"];
		foundPath = [self findExecutableWithName:executable atPaths:searchPaths];
		if (foundPath) {
			return foundPath;
		}		
	}
	
	return nil;
}
- (NSString *)findExecutableWithName:(NSString *)executable atPaths:(NSArray *)paths {
	NSString *searchPath, *foundPath;
	for (searchPath in paths) {
		foundPath = [searchPath stringByAppendingPathComponent:executable];
		if ([[NSFileManager defaultManager] isExecutableFileAtPath:foundPath]) {
			return foundPath;
		}
	}
	return nil;
}



- (void)initAgent {
	NSLog(@"initAgent");
	NSFileManager *fileManager = [NSFileManager defaultManager];
	

	if (GPG_AGENT_PATH) {
		BOOL started = NO;
		@try {
			started = isGpgAgentRunning();
		
			if (!started) {
				NSString *socketPath;
				NSData *agentInfoData;
				NSRange range;
				
				if (agentInfoData = [fileManager contentsAtPath:[@"~/.gpg-agent-info" stringByExpandingTildeInPath]]) {
					socketPath = dataToString(agentInfoData);
					if ((range = [socketPath rangeOfString:@"GPG_AGENT_INFO="]).length > 0) {
						NSRange lineRange = [socketPath lineRangeForRange:range];
						range.location = range.location + 15;
						range.length = lineRange.length - 16;
						socketPath = [socketPath substringWithRange:range];
						setenv("GPG_AGENT_INFO", [socketPath cStringUsingEncoding:NSUTF8StringEncoding], 1);
						
						started = isGpgAgentRunning();
					}
				}
				
				if (!started) {
					NSLog(@"Starte gpg-agent");
					
					NSTask *agentTask = [[[NSTask alloc] init] autorelease];
					[agentTask setLaunchPath:GPG_AGENT_PATH];
					[agentTask setArguments:[NSArray arrayWithObjects:@"--pinentry-program", @"/usr/local/libexec/pinentry-mac.app/Contents/MacOS/pinentry-mac", @"--daemon", @"--write-env-file", nil]];
					NSPipe *outPipe = [NSPipe pipe];
					[agentTask setStandardOutput:outPipe];
					[agentTask launch];
					[agentTask waitUntilExit];
					
					if ([agentTask terminationStatus] == 0) {
						NSLog(@"gpg-agent gestartet");
						socketPath = dataToString([[outPipe fileHandleForReading] readDataToEndOfFile]);
						
						if ((range = [socketPath rangeOfString:@";"]).length > 0) {
							range.length = range.location - 15;
							range.location = 15;
							socketPath = [socketPath substringWithRange:range];
							setenv("GPG_AGENT_INFO", [socketPath cStringUsingEncoding:NSUTF8StringEncoding], 1);
							
							if ((range = [socketPath rangeOfString:@":"]).length > 0) {
								range.length = range.location;
								range.location = 0;
								socketPath = [[socketPath substringWithRange:range] stringByStandardizingPath];
								
								NSString *standardSocket = [@"~/.gnupg/S.gpg-agent" stringByExpandingTildeInPath];
								if (![standardSocket isEqualToString:socketPath]) {
									[fileManager removeItemAtPath:standardSocket error:nil];
									[fileManager createSymbolicLinkAtPath:standardSocket withDestinationPath:socketPath error:nil];
								}
							}
						}
						started = YES;
					}
				}
			}
		} @finally {
			if (!started) {
				NSRunAlertPanel(localized(@"GPGAgentNotStart_Title"), localized(@"GPGAgentNotStart_Msg"), nil, nil, nil);
			}
		}
	}
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



@implementation SplitFormatter
@synthesize blockSize;

- (id)init {
	if (self = [super init]) {
		blockSize = 4;
	}
	return self;
}

- (NSString*)stringForObjectValue:(id)obj {
	char const* fingerprint = [[obj description] cStringUsingEncoding:NSASCIIStringEncoding];
	int length = strlen(fingerprint),i = 0, pos = 0;
	char formattedFingerprint[length + (length -1) / blockSize + 1];
	
	for (; i + blockSize < length; i += blockSize) {
		memcpy(formattedFingerprint+pos, fingerprint+i, blockSize);
		pos += blockSize + 1;
		formattedFingerprint[pos-1] = ' ';
	}
	memcpy(formattedFingerprint+pos, fingerprint+i, length - i);
	formattedFingerprint[pos+length - i] = 0;
	
			
	return [NSString stringWithCString:formattedFingerprint encoding:NSASCIIStringEncoding];
}

- (BOOL)getObjectValue:(id*)obj forString:(NSString*)string errorDescription:(NSString**)error {
	return NO;
}
- (BOOL)isPartialStringValid:(NSString*)partialString newEditingString:(NSString**) newString errorDescription:(NSString**)error {
	return YES;
}

@end




