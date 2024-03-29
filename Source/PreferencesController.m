/*
 Copyright © Roman Zechmeister, 2020
 
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
#import "ActionController.h"

@interface GPGOptions ()
- (NSArray *)keyserversInPlist;
@end



@interface PreferencesController ()
@property (nonatomic, strong) GPGController *gpgc;
@end


@implementation PreferencesController
@synthesize testingServer;
@synthesize gpgc;
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
		[[SheetController sharedInstance] alertSheetForWindow:_window
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
	if ([sc runModalForWindow:_window] != NSOKButton) {
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
			[[SheetController sharedInstance] alertSheetForWindow:_window
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
		[[SheetController sharedInstance] alertSheetForWindow:_window
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
	[_window makeKeyAndOrderFront:nil];
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
	
	[_window setContentView:view];
	[_window setTitle:sender.label];
}

- (IBAction)checkKeyserver:(id)sender {
	if (!self.keyserverToCheck) {
		return;
	}
	if (self.testingServer) {
		// Cancel the last check.
		[self.gpgc cancel];
	}
	
	[spinner startAnimation:nil];
	self.testingServer = YES;
	GPGController *gc = [GPGController gpgController];
	self.gpgc = gc;

	__block BOOL serverWorking = NO;
	__block BOOL keepCurrentServer = NO;
	dispatch_group_t dispatchGroup = dispatch_group_create();
	dispatch_group_enter(dispatchGroup);

	dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^{
		if (gc != self.gpgc) {
			// This is not the result of the last check.
			return;
		}
		self.gpgc = nil;
		self.testingServer = NO;
		
		if (!keepCurrentServer) {
			if (serverWorking) {
				// The server passed the check.
				// Set it as default keyserver.
				self.options.keyserver = gc.keyserver;
				
				if (self.options.isVerifyingKeyserver) {
					[[ActionController sharedInstance] askForKeyUpload];
				}
				
			} else {
				[self.options removeKeyserver:gc.keyserver];
				[[SheetController sharedInstance] alertSheetForWindow:_window
														  messageText:localized(@"BadKeyserver_Title")
															 infoText:localized(@"BadKeyserver_Msg")
														defaultButton:nil
													  alternateButton:nil
														  otherButton:nil
													suppressionButton:nil];
			}
		}
		
		self.keyserverToCheck = nil;
	});

	// We can't use options.keyserver anymore, since setting this value
	// will update gpg.conf which doesn't make sense if the keyserver can't be used.
	self.gpgc.keyserver = self.keyserverToCheck;
	dispatch_group_enter(dispatchGroup);
	[self.gpgc testKeyserverWithCompletionHandler:^(BOOL working) {
		serverWorking = working;
		dispatch_group_leave(dispatchGroup);
	}];
	
	
	GPGOptions *options = [GPGOptions sharedOptions];
	if (options.isVerifyingKeyserver && [options isSKSKeyserver:self.keyserverToCheck]) {
		// The user is switching from keys.openpgp.org to an old SKS keyserver. Better warn them.
		NSInteger result = [[SheetController sharedInstance] alertSheetForWindow:_window
																	 messageText:localizedLibmacgpgString(@"SwitchToOldKeyserver_Title")
																		infoText:localizedLibmacgpgString(@"SwitchToOldKeyserver_Msg")
																   defaultButton:localizedLibmacgpgString(@"SwitchToOldKeyserver_No")
																 alternateButton:localizedLibmacgpgString(@"SwitchToOldKeyserver_Yes")
																	 otherButton:nil
															   suppressionButton:nil];
		if (result == NSAlertFirstButtonReturn) {
			// Do not change the server.
			keepCurrentServer = YES;
			[self.gpgc cancel];
		}
	}
	
	dispatch_group_leave(dispatchGroup);
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
		self.keyserver = GPG_DEFAULT_KEYSERVER;
	}
	// End any possible user editing to overwrite with new keyserver.
	[self.window endEditingFor:nil];
}


- (GPGOptions *)options {
    return [GPGOptions sharedOptions];
}

- (NSArray *)keyservers {
    return [self.options keyservers];
}

- (NSString *)keyserver {
    return !self.keyserverToCheck ? self.options.keyserver : self.keyserverToCheck;
}

- (void)setKeyserver:(NSString *)value {
	if (value.length == 0) {
		// Don't allow an empty keyserver. Set the default keyserver.
		_keyserverToCheck = nil;
		self.options.keyserver = GPG_DEFAULT_KEYSERVER;
		[self performSelectorOnMainThread:@selector(setKeyserver:) withObject:GPG_DEFAULT_KEYSERVER waitUntilDone:NO];
	} else {
		// Remove leading and trailing whitespaces.
		value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		// GnuPG treats keyservers with https scheme differently from
		// ones with hkps as scheme.
		// The https version only makes sense if the user speficies a complete
		// query which matches the API of the keyserver.
		// Since most keyservers are based on sks or hockeypuck anyway, it is safe to
		// automatically change http(s) to hkp(s) which in most cases
		// is the correct version.
		NSURL *url = [NSURL URLWithString:value];
		NSString *host = [url host];
		NSString *scheme = [url scheme];

		if(!scheme || [scheme isEqualToString:@"http"]) {
			scheme = @"hkp";
		}
		if([scheme isEqualToString:@"https"] || [value rangeOfString:@"keyserver.ubuntu.com"].location != NSNotFound) {
			scheme = @"hkps";
		}
		value = [NSString stringWithFormat:@"%@://%@", scheme, [host length] > 0 ? host : value];

		_keyserverToCheck = value;
	}
}


- (BOOL)keyserverShowInvalidKeys {
	GPGOptions *options = [GPGOptions sharedOptions];
	return options.isVerifyingKeyserver || [options boolForKey:@"KeyserverShowInvalidKeys"];
}
- (void)setKeyserverShowInvalidKeys:(BOOL)keyserverShowInvalidKeys {
	[[GPGOptions sharedOptions] setBool:keyserverShowInvalidKeys forKey:@"KeyserverShowInvalidKeys"];
}
- (BOOL)enableKeyserverShowInvalidKeys {
	return ![GPGOptions sharedOptions].isVerifyingKeyserver;
}

- (void)setWindow:(NSWindow *)window {
	_window = window;
	
	// Show default preferences toolbar style on Big Sur.
	// This should be set in the XIB, but older Xcode versions overwrite it.
	SEL selector = NSSelectorFromString(@"setToolbarStyle:");
	if ([_window respondsToSelector:selector]) {
		[_window setValue:@2 /* NSWindowToolbarStylePreference */ forKey:@"toolbarStyle"];
	}
}
- (NSWindow *)window {
	return _window;
}

/*
 * Key-Value Observing
 */
+ (NSSet *)keyPathsForValuesAffectingKeyservers {
	return [NSSet setWithObject:@"options.keyservers"];
}
+ (NSSet *)keyPathsForValuesAffectingKeyserver {
	return [NSSet setWithObjects:@"options.keyserver", @"options.gpgConf", @"keyserverToCheck", nil];
}
+ (NSSet *)keyPathsForValuesAffectingEnableKeyserverShowInvalidKeys {
	return [NSSet setWithObject:@"keyserver"];
}
+ (NSSet *)keyPathsForValuesAffectingKeyserverShowInvalidKeys {
	return [NSSet setWithObject:@"keyserver"];
}



@end

