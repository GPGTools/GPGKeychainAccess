/*
 Copyright © Roman Zechmeister, 2014
 
 Diese Datei ist Teil von GPG Keychain.
 
 GPG Keychain ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung von GPG Keychain erfolgt in der Hoffnung, daß es Ihnen 
 von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite 
 Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck. 
 Details finden Sie in der GNU General Public License.
 
 Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem 
 Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
*/

#import "Globales.h"
#import "PreferencesController.h"
#import "SheetController.h"

@interface GPGOptions ()
- (NSArray *)keyserversInPlist;
@end

@implementation PreferencesController
@synthesize window;
@synthesize keyserverToCheck;
static PreferencesController *_sharedInstance = nil;


+ (id)sharedInstance {
	if (_sharedInstance == nil) {
		_sharedInstance = [[self alloc] init];
	}
	return _sharedInstance;
}

- (id)init {
	if (self = [super init]) {
		@try {
			NSArray *objects;
			[[NSBundle mainBundle] loadNibNamed:@"Preferences" owner:self topLevelObjects:&objects];
			topLevelObjects = objects;
		}
		@catch (NSException *exception) {
			NSLog(@"%@", exception);
		}
	}
	return self;
}



- (IBAction)moveSecring:(id)sender {
	GPGOptions *options = self.options;
	NSString *gpgHome = options.gpgHome;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSError *error = nil;

	
	
	// Get current location.
	NSNumber *tempvalue = [options valueInGPGConfForKey:@"default-keyring"];
	BOOL default_keyring = tempvalue ? tempvalue.boolValue : YES;
	
	NSMutableArray *secrings = [NSMutableArray arrayWithArray:[options valueInGPGConfForKey:@"secret-keyring"]];
	NSString *secring = @"secring.gpg";
	
	if (!default_keyring && secrings.count > 0) {
		secring = secrings[0];
		[secrings removeObjectAtIndex:0];
	}
	
	
	NSString *secringPath = [secring stringByExpandingTildeInPath];
	if ([secringPath characterAtIndex:0] != '/') {
		secringPath = [gpgHome stringByAppendingPathComponent:secring];
	}
	secringPath = [secringPath stringByStandardizingPath];
	
	BOOL isDir;
	if (![fileManager fileExistsAtPath:secringPath isDirectory:&isDir] || isDir) {
		[[SheetController sharedInstance] alertSheetForWindow:window
												  messageText:localized(@"MoveSecringNotFound_Title")
													 infoText:localized(@"MoveSecringNotFound_Msg")
												defaultButton:localized(@"OK")
											  alternateButton:nil
												  otherButton:nil
											suppressionButton:nil];
		return;
	}
	
	
	
	// Let the user select the new location.
	SheetController *sc = [SheetController sharedInstance];
	sc.sheetType = SheetTypeSelectVolume;
	NSString *path = @"/";
	if (secringPath.length > 9 && [secringPath rangeOfString:@"/Volumes/"].length > 0) {
		NSUInteger slash = [secringPath rangeOfString:@"/" options:0 range:NSMakeRange(9, secringPath.length - 9)].location;
		if (slash != NSNotFound) {
			path = [secringPath substringToIndex:slash];
		}
	}
	sc.URL = [NSURL fileURLWithPath:path];
	if ([sc runModalForWindow:window] != NSOKButton) {
		return;
	}
		
	path = sc.URL.path;
	if ([path isEqualToString:@"/"]) {
		path = gpgHome;
	} else {
		path = [path stringByAppendingPathComponent:@".gnupg"];
	}
	
	
	NSString *destDir = [path stringByStandardizingPath];
	NSString *destPath = [destDir stringByAppendingPathComponent:@"secring.gpg"];
	
	if ([destPath isEqualToString:secringPath]) {
		GPGDebugLog(@"moveSecring source and dest are equal: %@", destPath);
		return;
	}
	
	if (![fileManager fileExistsAtPath:destDir]) {
		if (![fileManager createDirectoryAtPath:destDir withIntermediateDirectories:NO attributes:nil error:&error]) {
			[[SheetController sharedInstance] alertSheetForWindow:window
													  messageText:localized(@"MoveSecringCantMove_Title")
														 infoText:error.localizedDescription
													defaultButton:localized(@"OK")
												  alternateButton:nil
													  otherButton:nil
												suppressionButton:nil];
		}
	}
	
	// Select unique filename.
	NSInteger n = 1;
	while ([fileManager fileExistsAtPath:destPath]) {
		n++;
		destPath = [destDir stringByAppendingPathComponent:[NSString stringWithFormat:@"secring_%i.gpg", n]];
	}
	
	
	// Move the secring.
	GPGDebugLog(@"Move Secring from '%@' to '%@'", secringPath, destPath);
	if (![fileManager moveItemAtPath:secringPath toPath:destPath error:&error]) {
		[[SheetController sharedInstance] alertSheetForWindow:window
												  messageText:localized(@"MoveSecringCantMove_Title")
													 infoText:error.localizedDescription
												defaultButton:localized(@"OK")
											  alternateButton:nil
												  otherButton:nil
											suppressionButton:nil];
		return; 
	}
	
	// ... and update the config.
	[self willChangeValueForKey:@"secringPath"];
	[secrings insertObject:destPath atIndex:0];
	[options setValueInGPGConf:secrings forKey:@"secret-keyring"];
	[options setValueInGPGConf:@NO forKey:@"default-keyring"];
	[self didChangeValueForKey:@"secringPath"];
	
}

- (NSString *)secringPath {
	NSNumber *tempvalue = [self.options valueInGPGConfForKey:@"default-keyring"];
	BOOL default_keyring = tempvalue ? tempvalue.boolValue : YES;
	
	NSString *secring = @"secring.gpg";
	if (!default_keyring) {
		NSArray *secrings = [self.options valueInGPGConfForKey:@"secret-keyring"];
		if (secrings.count > 0) {
			secring = secrings[0];
		}
	}
	
	NSString *secringPath = [secring stringByExpandingTildeInPath];
	if ([secringPath characterAtIndex:0] != '/') {
		secringPath = [self.options.gpgHome stringByAppendingPathComponent:secring];
	}
	secringPath = [secringPath stringByStandardizingPath];
	
	return secringPath;
}


- (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url {
	NSLog(@"%@", url);
	return YES;
}

- (BOOL)panel:(id)sender shouldShowFilename:(NSString *)filename {
	NSLog(@"%@", filename);
	return YES;
}




- (IBAction)showPreferences:(id)sender {
	if (!view) {
		NSToolbarItem *item = [[toolbar items] objectAtIndex:0];
		[toolbar setSelectedItemIdentifier:item.itemIdentifier];
		[self selectTab:item];
	}
	[window makeKeyAndOrderFront:nil];
}

- (IBAction)selectTab:(NSToolbarItem *)sender {
	static NSDictionary *views = nil;
	if (!views) {
		views = [[NSDictionary alloc] initWithObjectsAndKeys:
				 keyserverPreferencesView, @"keyserver",
				 updatesPreferencesView, @"updates",
				 keyringPreferencesView, @"keyring",
				 nil];
	}
	view = [views objectForKey:sender.itemIdentifier];
	
	[window setContentView:view];
	[window setTitle:sender.label];
}

- (IBAction)checkKeyserver:(id)sender {
    // We can't use self.options.keyserver anymore, since setting this value
    // will update gpg.conf which doesn't make sense if the keyserver can't be used.
    //NSString *keyserver = self.options.keyserver;
    NSString *keyserver = self.keyserverToCheck;
    if(!keyserver)
        keyserver = self.keyserver;
    
	GPGController *gpgc = [GPGController gpgController];
	gpgc.keyserver = keyserver;
	gpgc.async = YES;
	gpgc.delegate = self;
	gpgc.keyserverTimeout = 3;
	gpgc.timeout = 3;
	self.testingServer = YES;
	
	[gpgc testKeyserver];
}
+ (NSSet*)keyPathsForValuesAffectingCanRemoveKeyserver {
	return [NSSet setWithObjects:@"keyserver", nil];
}
- (BOOL)canRemoveKeyserver {
	static NSArray *keyservers = nil;
	if (keyservers == nil) {
		keyservers = [self.options keyserversInPlist];
	}
	
	return [keyservers containsObject:self.keyserver] == NO;
}
- (IBAction)removeKeyserver:(NSButton *)sender {
	NSString *oldServer = self.keyserver;
	[self.options removeKeyserver:oldServer];
	NSArray *servers = self.keyservers;
	if (servers.count > 0) {
		if (![servers containsObject:oldServer]) {
			self.keyserver = [self.keyservers objectAtIndex:0];
		}
	} else {
		self.keyserver = @"";
	}
}


- (GPGOptions *)options {
    return [GPGOptions sharedOptions];
}

- (NSArray *)keyservers {
    return [self.options keyservers];
}

static NSString * const kKeyserver = @"keyserver";

- (NSString *)keyserver {
    return !self.keyserverToCheck ? [self.options valueForKey:kKeyserver] : self.keyserverToCheck;
}

- (void)setKeyserver:(NSString *)keyserver {
    self.keyserverToCheck = keyserver;
}
- (void)updateKeyserver:(NSString *)keyserver {
    // This method is only called if the keyserver is in fact usable,
    // since otherwise an invalid keyserver would be stored in gpg.conf
    
    // assign a server name to the "keyserver" option
    [self.options setValue:keyserver forKey:kKeyserver];
}

- (void)gpgController:(GPGController *)gc operationDidFinishWithReturnValue:(id)value {
	// Result of the keyserer test.
	dispatch_async(dispatch_get_main_queue(), ^{
		self.testingServer = NO;
	});
	
	if (![value boolValue]) {
		[self.options removeKeyserver:gc.keyserver];
		
		[[SheetController sharedInstance] alertSheetForWindow:window
												  messageText:localized(@"BadKeyserver_Title")
													 infoText:localized(@"BadKeyserver_Msg")
												defaultButton:nil
											  alternateButton:nil
												  otherButton:nil
											suppressionButton:nil];
	}
	else {
		// The keyserver is working, so let's define it as new default key server.
        // updateKeyserver will also update gpg.conf
        [self updateKeyserver:gc.keyserver];
        
        // If the keyserver is not already contained in the list of available keyservers,
		// save it in the common defaults plist (org.gpgtools.common)
		// Fetch the currently available keyservers.
		NSArray *keyservers = [self keyservers];
		if([keyservers containsObject:gc.keyserver])
			return;
		
		// Not found in the currently available list, let's retrieve the keyservers
		// currently available in common defaults and add the new keyserver.
		NSArray *defaultKeyservers = [self.options valueInCommonDefaultsForKey:@"keyservers"];
		NSMutableArray *updatedDefaultKeyservers = [NSMutableArray array];
		if (defaultKeyservers.count) {
			[updatedDefaultKeyservers addObjectsFromArray:defaultKeyservers];
		}
		if (gc.keyserver) {
			[updatedDefaultKeyservers addObject:gc.keyserver];
		}
		[self.options setValueInCommonDefaults:updatedDefaultKeyservers forKey:@"keyservers"];
	}
}


+ (NSSet *)keyPathsForValuesAffectingKeyservers {
	return [NSSet setWithObject:@"options.keyservers"];
}
+ (NSSet *)keyPathsForValuesAffectingKeyserver {
	return [NSSet setWithObject:@"options.keyserver"];
}


- (void)setTestingServer:(BOOL)testingServer {
	_testingServer = testingServer;
	if (testingServer) {
		[spinner startAnimation:nil];
	} else {
		[spinner stopAnimation:nil];
	}
}
- (BOOL)testingServer {
	return _testingServer;
}

@end

