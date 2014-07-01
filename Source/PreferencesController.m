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

#import "Globales.h"
#import "PreferencesController.h"
#import "SheetController.h"

@implementation PreferencesController
@synthesize window;
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
			[NSBundle loadNibNamed:@"Preferences" owner:self];
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
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	panel.canChooseFiles = NO;
	panel.canChooseDirectories = YES;
	panel.canCreateDirectories = YES;
	panel.message = localized(@"MoveSecring_PanelMsg");
	panel.prompt = localized(@"MoveSecring_PanelOk");
	panel.directoryURL = [NSURL fileURLWithPath:gpgHome];
	
	[panel beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
		[NSApp stopModalWithCode:result];
	}];

	if ([NSApp runModalForWindow:window] != NSOKButton) {
		return;
	}
	
	NSString *destDir = [[panel.URL path] stringByStandardizingPath];
	NSString *destPath = [destDir stringByAppendingPathComponent:@"secring.gpg"];
	
	if ([destPath isEqualToString:secringPath]) {
		GPGDebugLog(@"moveSecring source and dest are equal: %@", destPath);
		return;
	}
	
	// Select unique filename.
	NSInteger n = 1;
	while ([fileManager fileExistsAtPath:destPath]) {
		n++;
		destPath = [destDir stringByAppendingPathComponent:[NSString stringWithFormat:@"secring_%i.gpg", n]];
	}
	
	
	// Move the secring.
	NSError *error = nil;
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

	[view removeFromSuperview];
	view = [views objectForKey:sender.itemIdentifier];
	
	[[NSAnimationContext currentContext] setDuration:0.1];
	
	NSRect viewFrame = [window frameRectForContentRect:[view frame]];
	NSRect windowFrame = [window frame];
    windowFrame.origin.y -= viewFrame.size.height - windowFrame.size.height;
	windowFrame.size = viewFrame.size;
	
	[window setFrame:windowFrame display:YES animate:YES];
	
	[[window contentView] addSubview:view];
	[window setTitle:sender.label];
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
static NSString * const kAutoKeyLocate = @"auto-key-locate";

- (NSString *)keyserver {
    return [self.options valueForKey:kKeyserver];
}

- (void)setKeyserver:(NSString *)keyserver {
	if (![[self keyservers] containsObject:keyserver]) {
		GPGController *gpgc = [GPGController gpgController];
		gpgc.keyserver = keyserver;
		gpgc.async = YES;
		gpgc.delegate = self;
		gpgc.keyserverTimeout = 5;
		gpgc.timeout = 5;
		
		[gpgc testKeyserver];
	}
	
    // assign a server name to the "keyserver" option
    [self.options setValue:keyserver forKey:kKeyserver];
    
    NSArray *autoklOptions = [self.options valueForKey:kAutoKeyLocate];
    if (!autoklOptions || ![autoklOptions containsObject:kKeyserver]) {
        // lead with the literal value "keyserver" in the auto-key-locate option
        NSMutableArray *newOptions = [NSMutableArray arrayWithObject:kKeyserver];
        if (autoklOptions)
            [newOptions addObjectsFromArray:autoklOptions];
        [self.options setValue:newOptions forKey:kAutoKeyLocate];
    }
}

- (void)gpgController:(GPGController *)gc operationDidFinishWithReturnValue:(id)value {
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
}


+ (NSSet *)keyPathsForValuesAffectingKeyservers {
	return [NSSet setWithObject:@"options.keyservers"];
}
+ (NSSet *)keyPathsForValuesAffectingKeyserver {
	return [NSSet setWithObject:@"options.keyserver"];
}



@end

