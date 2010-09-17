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

#import "GPGKeychainAccessAppDelegate.h"
#import "KeychainController.h"

@implementation GPGKeychainAccessAppDelegate

@synthesize keyTable;

- (NSWindow *)window {
    return window;
}
- (void)setWindow:(NSWindow *)value {
	window = value;
	mainWindow = value;
}

- (NSWindow *)inspectorWindow {
    return inspectorWindow;
}
- (void)setInspectorWindow:(NSWindow *)value {
	inspectorWindow = value;
}


- (void)awakeFromNib {
	[keyTable setDoubleAction:@selector(orderFront:)];
	[keyTable setTarget:inspectorWindow];	
}

- (IBAction)selectHeaderVisibility:(NSMenuItem *)sender {
	NSArray *columns = [NSArray arrayWithObjects:@"type",@"name",@"email",@"shortKeyID",@"creationDate",@"length",@"algorithmDescription",@"keyID",@"fingerprint",@"comment",nil];
	[[keyTable tableColumnWithIdentifier:[columns objectAtIndex:sender.tag]] setHidden:sender.state];
	sender.state = !sender.state;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
	[window makeKeyAndOrderFront:nil];
	return YES;
}


@end
