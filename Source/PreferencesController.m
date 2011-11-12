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

@end

