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

#import "KeychainController.h"
#import "KeyInfo.h"
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
		[keyInfos addObject:[node representedObject]];
	}
	draggedKeyInfos = keyInfos;
	
	NSPoint point = [mainWindow mouseLocationOutsideOfEventStream];
	NSRect rect;
	rect.size.width = 0;
	rect.size.height = 0;
	rect.origin.x = point.x - 45;
	rect.origin.y = [outlineView frame].size.height - point.y + 55;
	
	NSEvent *event = [NSEvent mouseEventWithType:NSLeftMouseDown location:point modifierFlags:0 timestamp:0 windowNumber:[mainWindow windowNumber] context:nil eventNumber:0 clickCount:0 pressure:1];
	
	[outlineView dragPromisedFilesOfTypes:[NSArray arrayWithObject:@"asc"] fromRect:rect source:self slideBack:YES event:event];
	
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


- (void)asyncUpdateKeyInfos:(NSObject <GKEnumerationList> *)keyInfos {
	[NSThread detachNewThreadSelector:@selector(updateKeyInfos:) toTarget:self withObject:keyInfos];
}

- (void)updateKeyInfos:(NSObject <GKEnumerationList> *)keyInfos {
	NSLog(@"Starte: updateKeyInfos");
	if (![updateLock tryLock]) {
		NSLog(@"updateKeyInfos tryLock return");
		return;
	}
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	KeyInfo *keyInfo;
	GPGKey *gpgKey, *secKey;
	NSString *fingerprint;
	
	NSMutableSet *secKeys;
	
	@try {
		
		[gpgContext setKeyListMode:(GPGKeyListModeLocal | GPGKeyListModeSignatures)];
		
		if (keyInfos && [keyInfos count] > 0) { // Nur die übergebenene Schlüssel aktualisieren.
			NSLog(@"updateKeyInfos: Update selected keys");
			NSMutableSet *processedKeyInfos = [NSMutableSet setWithCapacity:[keyInfos count]];
			NSMutableArray *keyInfosToUpdate = [NSMutableArray array];
			NSMutableArray *gpgKeysToUpdate = [NSMutableArray array];
			NSMutableArray *secKeysToUpdate = [NSMutableArray array];
			secKeys = [secretKeys mutableCopy];
			
			for (NSObject *aObject in keyInfos) {
				if ([aObject isKindOfClass:[KeyInfo class]]) {
					fingerprint = [[(KeyInfo *)aObject primaryKeyInfo] fingerprint];
				} else {
					fingerprint = [aObject description];
				}
				
				keyInfo = [keychain objectForKey:fingerprint];
				
				if (![processedKeyInfos containsObject:fingerprint]) {
					[processedKeyInfos addObject:fingerprint];
					
					gpgKey = [gpgContext keyFromFingerprint:fingerprint secretKey:NO];
					secKey = [gpgContext keyFromFingerprint:fingerprint secretKey:YES];
					
					if (gpgKey) {
						if (keyInfo) {
							[keyInfosToUpdate addObject:keyInfo];
						} else {
							[keyInfosToUpdate addObject:fingerprint];
						}
						
						[gpgKeysToUpdate addObject:gpgKey];
						[secKeysToUpdate addObject:secKey ? secKey : gpgKey];
						if ([secKeys containsObject:fingerprint]) {
							if (!secKey) {
								[secKeys removeObject:fingerprint];
							}
						} else if (secKey) {
							[secKeys addObject:fingerprint];
						}
					} else {
						[keychain removeObjectForKey:fingerprint];
						[secKeys removeObject:fingerprint];
					}
				}
				if ([keyInfosToUpdate count] > 0) {
					[self performSelectorOnMainThread:@selector(updateKeyInfosWithDict:) withObject:[NSDictionary dictionaryWithObjectsAndKeys:keyInfosToUpdate, @"keyInfos", gpgKeysToUpdate, @"gpgKeys", secKeysToUpdate, @"secKeys", nil] waitUntilDone:YES];
				}
			}
			
		} else { // Den kompletten Schlüsselbund aktualisieren.
			NSLog(@"updateKeyInfos: Update all keys");
			NSArray *gpgKeyList;
			NSMutableDictionary *secKeyDict = [NSMutableDictionary dictionaryWithCapacity:1];
			
			secKeys = [NSMutableSet setWithCapacity:1];
			
			gpgKeyList = [[gpgContext keyEnumeratorForSearchPattern:nil secretKeysOnly:NO] allObjects]; //Liste aller GPGKeys.
			NSEnumerator *secKeyEnum = [gpgContext keyEnumeratorForSearchPattern:nil secretKeysOnly:YES];
			
			while (secKey = [secKeyEnum nextObject]) {
				[secKeyDict setObject:secKey forKey:[secKey fingerprint]];
				[secKeys addObject:[secKey fingerprint]];
			}
			
			[self performSelectorOnMainThread:@selector(updateKeychain:) withObject:[NSDictionary dictionaryWithObjectsAndKeys:gpgKeyList, @"gpgKeyList", secKeyDict, @"secKeyDict", nil] waitUntilDone:YES];
			
			
			NSEnumerator *keychainEnumerator;
			keychainEnumerator = [keychain objectEnumerator];
			while (keyInfo = [keychainEnumerator nextObject]) {
				[keyInfo updateFilterText];
			}
		}
		self.secretKeys = secKeys;
		[self performSelectorOnMainThread:@selector(updateFilteredKeyList:) withObject:nil waitUntilDone:YES];
	} @catch (NSException * e) {
		NSLog(@"Fehler in updateKeyInfos: %@", [e reason]);
	} @finally {
		[pool drain];
		[updateLock unlock];
	}
	NSLog(@"Fartig: updateKeyInfos");
}

- (void)updateKeyInfosWithDict:(NSDictionary *)aDict {
	NSArray *keyInfos = [aDict objectForKey:@"keyInfos"];
	NSArray *gpgKeys = [aDict objectForKey:@"gpgKeys"];
	NSArray *secKeys = [aDict objectForKey:@"secKeys"];
	GPGKey *gpgKey, *secKey;
	KeyInfo *keyInfo;
	
	NSUInteger i, count = [keyInfos count];
	for (i = 0; i < count; i++) {
		gpgKey = [gpgKeys objectAtIndex:i];
		secKey = [secKeys objectAtIndex:i];
		secKey = gpgKey == secKey ? nil : secKey;
		keyInfo = [keyInfos objectAtIndex:i];
		
		if ([keyInfo isKindOfClass:[KeyInfo class]]) {
			[keyInfo updateWithGPGKey:gpgKey secretKey:secKey];
		} else {
			keyInfo = [KeyInfo keyInfoWithGPGKey:gpgKey secretKey:secKey];
			[keychain setObject:keyInfo forKey:[keyInfo description]];
		}
		[keyInfo updateFilterText];
	}
}

- (void)updateKeychain:(NSDictionary *)aDict { //Darf nur im Main-Thread laufen!
	NSLog(@"updateKeychain");
	
	NSArray *gpgKeyList = [aDict objectForKey:@"gpgKeyList"];
	NSDictionary *secKeyDict = [aDict objectForKey:@"secKeyDict"];
	
	KeyInfo *keyInfo;
	GPGKey *gpgKey, *secKey;
	NSArray *keysToRemove;
	NSString *fingerprint;
	NSMutableDictionary *oldKeys;
	
	
	oldKeys = [NSMutableDictionary dictionaryWithDictionary:keychain];
	for (gpgKey in gpgKeyList) {
		fingerprint = [gpgKey fingerprint];
		secKey = [secKeyDict objectForKey:fingerprint];
		if (keyInfo = [keychain objectForKey:fingerprint]) {
			[keyInfo updateWithGPGKey:gpgKey secretKey:secKey];
			[oldKeys removeObjectForKey:[gpgKey fingerprint]];
		} else {
			keyInfo = [KeyInfo keyInfoWithGPGKey:gpgKey secretKey:secKey];
			[keychain setObject:keyInfo forKey:[keyInfo fingerprint]];
		}
	}
	
	keysToRemove = [oldKeys allKeys];
	for (fingerprint in keysToRemove) {
		[keychain removeObjectForKey:fingerprint];
	}
	
}


- (IBAction)updateFilteredKeyList:(id)sender { //Darf nur im Main-Thread laufen!
	static BOOL isUpdating = NO;
	if (isUpdating) {return;}
	isUpdating = YES;
	
	NSMutableArray *keysToRemove;
	NSArray *myKeyList;
	KeyInfo *keyInfo;
	
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


- (BOOL)isKeyInfoPassingFilterTest:(KeyInfo *)keyInfo {
	if (showSecretKeysOnly && ![keyInfo isSecret]) {
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
	
	for (KeyInfo *keyInfo in [[self keychain] allValues]) {
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
	
	
    [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(updateThread) userInfo:nil repeats:YES];
	
	[pool drain];
}

- (BOOL)initGPG {
	NSLog(@"initGPG");
	GPG_AGENT_PATH=nil;
	@try {
		NSArray *engines = [GPGEngine availableEngines];
		GPG_PATH = nil;
		
		for (GPGEngine *engine in engines) {
			if ([[engine availableExecutablePaths] count] > 0) {
				if ([[engine version] hasPrefix:@"2."]) {
					GPG_PATH = [engine executablePath];
					GPG_VERSION = 2;
					break;
				} else if ([[engine version] hasPrefix:@"1.4."]) {
					GPG_PATH = [engine executablePath];
					GPG_VERSION = 1;
				}
			}
		}
		if (GPG_PATH == nil) {
			NSRunAlertPanel(localized(@"Error"), localized(@"GPGNotFound_Msg"), localized(@"Quit_Button"), nil, nil);
			return NO;
		}
		[GPG_PATH retain];
		
		NSLog(@"GPG_VERSION: %i", GPG_VERSION);
		NSLog(@"GPG_PATH: %@", GPG_PATH);
		
		gpgContext = [[GPGContext alloc] init];
		[gpgContext keyEnumeratorForSearchPattern:@"" secretKeysOnly:YES];
		[gpgContext stopKeyEnumeration];
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


- (void)initAgent {
	NSLog(@"initAgent");
	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL agentFound = NO;
	
	NSString *gpgAgentPath = [[GPG_PATH stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"gpg-agent"];
	
	if (![fileManager isExecutableFileAtPath:gpgAgentPath]) {
		gpgAgentPath = @"/usr/local/bin/gpg-agent";
		if (![fileManager isExecutableFileAtPath:gpgAgentPath]) {
			NSString *path = [[[NSProcessInfo processInfo] environment] objectForKey:@"PATH"];
			if (path) {
				NSArray *paths = [path componentsSeparatedByString:@":"];
				for (path in paths) {
					gpgAgentPath = [path stringByAppendingPathComponent:@"gpg-agent"];
					if ([fileManager isExecutableFileAtPath:gpgAgentPath]) {
						agentFound = YES;
						break;
					}
				}
			}
		} else {
			agentFound = YES;
		}
	} else {
		agentFound = YES;
	}

	if (agentFound) {
		GPG_AGENT_PATH = [gpgAgentPath retain];
		NSLog(@"GPG_AGENT_PATH: %@", GPG_AGENT_PATH);
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
					[agentTask setLaunchPath:gpgAgentPath];
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
		}
		@finally {
			if (!started) {
				NSRunAlertPanel(localized(@"GPGAgentNotStart_Title"), localized(@"GPGAgentNotStart_Msg"), nil, nil, nil);
			}
		}
	} else {
		NSRunAlertPanel(localized(@"GPGAgentNotFound_Title"), localized(@"GPGAgentNotFound_Msg"), nil, nil, nil);
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
	BOOL isOK = YES;
	if (intValue & GPGKeyStatus_Invalid) {
		[statusText appendFormat:@"%@", localized(@"Invalid")];
		isOK = NO;
	}
	if (intValue & GPGKeyStatus_Revoked) {
		[statusText appendFormat:@"%@%@", isOK ? @"" : @", ", localized(@"Revoked")];
		isOK = NO;
	}
	if (intValue & GPGKeyStatus_Expired) {
		[statusText appendFormat:@"%@%@", isOK ? @"" : @", ", localized(@"Expired")];
		isOK = NO;
	}
	if (intValue & GPGKeyStatus_Disabled) {
		[statusText appendFormat:@"%@%@", isOK ? @"" : @", ", localized(@"Disabled")];
		isOK = NO;
	}
	if (isOK) {
		[statusText setString:localized(@"Key_Is_OK")];
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




