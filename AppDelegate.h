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

@interface GPGKeychainAccessAppDelegate : NSObject {
    NSWindow *window;
	NSOutlineView *keyTable;
	NSTableView *userIDTable;
	NSTableView *subkeyTable;
	NSTableView *signatureTable;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSWindow *inspectorWindow;
@property (assign) IBOutlet NSOutlineView *keyTable;
@property (assign) IBOutlet NSTableView *userIDTable;
@property (assign) IBOutlet NSTableView *subkeyTable;
@property (assign) IBOutlet NSTableView *signatureTable;

- (void)generateContextMenuForTable:(NSTableView *)table;

- (IBAction)selectHeaderVisibility:(NSMenuItem *)sender;
- (IBAction)showPreferences:(id)sender;


@end
