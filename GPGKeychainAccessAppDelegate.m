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
#import "ActionController.h"

@implementation GPGKeychainAccessAppDelegate

@synthesize keyTable;
@synthesize userIDTable;
@synthesize subkeyTable;
@synthesize signatureTable;


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
	NSLog(@"GPGKeychainAccessAppDelegate awakeFromNib");
	[keyTable setDoubleAction:@selector(orderFront:)];
	[keyTable setTarget:inspectorWindow];
	
	[self generateContextMenuForTable:keyTable];
	[self generateContextMenuForTable:subkeyTable];
	[self generateContextMenuForTable:userIDTable];
	[self generateContextMenuForTable:signatureTable];
	
	
	NSArray *draggedTypes = [NSArray arrayWithObjects:NSFilenamesPboardType, NSStringPboardType, nil];
	[window registerForDraggedTypes:draggedTypes];
}


- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
	NSPasteboard *pboard = [sender draggingPasteboard];
	NSString *pboardType = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType, NSStringPboardType, nil]];
	
	if ([pboardType isEqualToString:NSFilenamesPboardType]) {
		NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
		for (NSString *fileName in fileNames) {
			NSString *extension = [fileName pathExtension];
			if ([extension isEqualToString:@"asc"] || [extension isEqualToString:@"gpgkey"]) {
				return NSDragOperationCopy;
			}
		}
	} else if ([pboardType isEqualToString:NSStringPboardType]) {
		NSString *string = [pboard stringForType:NSStringPboardType];
		if (containsPGPKeyBlock(string)) {
			return NSDragOperationCopy;
		}
	}
	return NSDragOperationNone;
}
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender {
	return YES;
}
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
	NSPasteboard *pboard = [sender draggingPasteboard];
	NSString *pboardType = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType, NSStringPboardType, nil]];
	
	if ([pboardType isEqualToString:NSFilenamesPboardType]) {
		NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
		NSMutableArray *filesToImport = [NSMutableArray arrayWithCapacity:[fileNames count]];
		for (NSString *fileName in fileNames) {
			NSString *extension = [fileName pathExtension];
			if ([extension isEqualToString:@"asc"] || [extension isEqualToString:@"gpgkey"]) {
				[filesToImport addObject:fileName];
			}
		}
		if ([filesToImport count] > 0) {
			[NSThread detachNewThreadSelector:@selector(importFromURLs:) toTarget:actionController withObject:filesToImport];
			return YES;
		}
	} else if ([pboardType isEqualToString:NSStringPboardType]) {
		NSString *string = [pboard stringForType:NSStringPboardType];
		if (containsPGPKeyBlock(string)) {
			[NSThread detachNewThreadSelector:@selector(importFromData:) toTarget:actionController withObject:stringToData(string)];
			return YES;
		}
	}
	return NO;
}



- (void)generateContextMenuForTable:(NSTableView *)table {
	NSMenuItem *menuItem;
	NSString *title;
	NSMenu *contextMenu = [[NSMenu alloc] initWithTitle:@""];
	[[table headerView] setMenu:contextMenu];
	
	NSArray *columns = [table tableColumns];
	for (NSTableColumn *column in columns) {
		title = [[column headerCell] title];
		if (![title isEqualToString:@""]) {
			menuItem = [contextMenu addItemWithTitle:title action:@selector(selectHeaderVisibility:) keyEquivalent:@""];
			[menuItem setTarget:self];
			[menuItem setRepresentedObject:column];
			[menuItem setState:[column isHidden] ? NSOffState : NSOnState];
		}
	}
}

- (IBAction)selectHeaderVisibility:(NSMenuItem *)sender {
	[[sender representedObject] setHidden:sender.state];
	sender.state = !sender.state;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
	[window makeKeyAndOrderFront:nil];
	return YES;
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames {
	[actionController importFromURLs:filenames];
}

- (CGFloat) splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex {
	return proposedMinimumPosition + 68;
}
- (CGFloat) splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex {
	return proposedMaximumPosition - 108;
}



@end
