/*
 Copyright © Roman Zechmeister, 2017
 
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


@class GPGOptions;

@interface PreferencesController : NSWindowController <GPGControllerDelegate, NSToolbarDelegate, NSOpenSavePanelDelegate> {
	IBOutlet NSToolbar *toolbar;
	IBOutlet NSView *keyserverPreferencesView;
	IBOutlet NSView *updatesPreferencesView;
	IBOutlet NSView *keyringPreferencesView;
	IBOutlet NSProgressIndicator *spinner;
    NSString *keyserverToCheck;
	
	NSView *view;
	NSArray *topLevelObjects;
}

@property (strong) IBOutlet NSWindow *window;

@property (weak, readonly) GPGOptions *options;

// Get a list of keyservers from GPGOptions
@property (weak, readonly) NSArray *keyservers;

// To set keyserver and also coordinate auto-key-locate
@property (weak) NSString *keyserver;
// Before a keyserver is stored in gpg.conf it's first checked
// if it works properly. The keyserverToCheck variable will hold
// whatever value the user is seeing at the moment of the check.
@property (nonatomic, strong) NSString *keyserverToCheck;
@property (readonly) BOOL canRemoveKeyserver;
@property (nonatomic) BOOL testingServer;

@property (weak, readonly) NSString *secringPath;


+ (id)sharedInstance;
- (IBAction)showPreferences:(id)sender;
- (IBAction)selectTab:(NSToolbarItem *)sender;
- (IBAction)removeKeyserver:(NSButton *)sender;
- (IBAction)moveSecring:(id)sender;

@end
