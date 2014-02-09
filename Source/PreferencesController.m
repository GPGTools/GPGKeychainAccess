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
					 updatesPreferencesView, @"updates", nil];		
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

+ (NSSet *)keyPathsForValuesAffectingKeyservers {
	return [NSSet setWithObject:@"options.keyservers"];
}
+ (NSSet *)keyPathsForValuesAffectingKeyserver {
	return [NSSet setWithObject:@"options.keyserver"];
}



@end

