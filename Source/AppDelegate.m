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

#import "AppDelegate.h"
#import "KeychainController.h"
#import "ActionController.h"
#import "PreferencesController.h"
#import "SBSystemPreferences.h"


@implementation GPGKeychainAppDelegate
@synthesize keyTable, userIDTable, subkeyTable, signatureTable, drawer, updater, inspectorWindow, inspectorView;

- (NSWindow *)window {
    return mainWindow;
}
- (void)setWindow:(NSWindow *)value {
	mainWindow = value;
}


- (NSSize)drawerWillResizeContents:(NSDrawer *)sender toSize:(NSSize)contentSize {
	[[GPGOptions sharedOptions] setValue:@(contentSize.width) forKey:@"drawerWidth"];
	return contentSize;
}

- (BOOL)inspectorVisible {
	return drawer.state || inspectorWindow.isVisible;
}
- (void)setInspectorVisible:(BOOL)inspectorVisible {
	[self showInspector:inspectorVisible];
}

- (void)showInspector:(int)show {
	BOOL isDrawer, isVisible;
	isDrawer = drawer.state;
	isVisible = isDrawer || inspectorWindow.isVisible;
	
	if (show == -1) {
		show = !isVisible;
	}

	if (show) {
		if (!isVisible) {
			NSRect windowFrame = self.window.frame;
			CGFloat drawerWidth = drawer.contentSize.width;
			CGFloat minSpace = drawer.minContentSize.width + 10;
			CGFloat spaceLeft = windowFrame.origin.x;
			CGFloat spaceRight = self.window.screen.frame.size.width - windowFrame.origin.x - windowFrame.size.width;
			
			isDrawer = spaceRight >= minSpace || spaceLeft >= minSpace;
			
			if (isDrawer) {
				CGFloat maxSpace = MAX(spaceRight, spaceLeft) - 10;
				if (drawerWidth > maxSpace) {
					NSSize size = drawer.contentSize;
					size.width = maxSpace;
					drawer.contentSize = size;
				}
				[drawer setContentView:inspectorView];
				[drawer open];
			} else {
				[inspectorWindow setContentView:inspectorView];
				[inspectorWindow makeKeyAndOrderFront:nil];
			}
		}
	} else if (isDrawer) {
		[drawer close];
	} else {
		[inspectorWindow close];
	}
}
- (IBAction)toggleInspector:(id)sender {
	[self showInspector:-1];
}
- (void)openInspector:(id)sender {
	[self showInspector:1];
}



- (IBAction)singleClick:(NSOutlineView *)sender {
	rowWasSelected = [keyTable clickedRowWasSelected];
}
- (IBAction)doubleClick:(NSOutlineView *)sender {
	if (keyTable.clickedRow >= 0) {
		if (keyTable.selectedRowIndexes.count > 1 ? [keyTable clickedRowWasSelected] : rowWasSelected) {
			[self showInspector:-1];
		} else {
			[self showInspector:1];
		}
	}
}
- (IBAction)showKeyDetails:(id)sender {
	[self showInspector:-1];
	return;
	
	NSInteger row = keyTable.clickedRow;
	if (row >= 0) {
		NSIndexSet *indexes = keyTable.selectedRowIndexes;
		if (indexes.count == 1 && [indexes containsIndex:row]) {
			[self showInspector:-1];
		} else {
			KeychainController *kc = [KeychainController sharedInstance];
			[kc selectRow:row];
			
			[self showInspector:1];
		}
	} else {
		[self showInspector:-1];
	}
	
}


- (id)init {
	self = [super init];
	appDelegate = self;
	return self;
}

- (void)awakeFromNib {
	GPGDebugLog(@"GPGKeychainAppDelegate awakeFromNib");
	
	
	[keyTable setAction:@selector(singleClick:)];
	[keyTable setDoubleAction:@selector(doubleClick:)];
	[keyTable setTarget:self];
	
	
	drawer.delegate = self;
	NSNumber *drawerWidth = [[GPGOptions sharedOptions] valueForKey:@"drawerWidth"];
	if (drawerWidth) {
		NSSize size = drawer.contentSize;
		size.width = drawerWidth.floatValue;
		drawer.contentSize = size;
	}
	
	
	[self generateContextMenuForTable:keyTable];
	[self generateContextMenuForTable:subkeyTable];
	[self generateContextMenuForTable:userIDTable];
	[self generateContextMenuForTable:signatureTable];
		
	NSArray *draggedTypes = [NSArray arrayWithObjects:NSFilenamesPboardType, NSStringPboardType, nil];
	[mainWindow registerForDraggedTypes:draggedTypes];
}




- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
	if ([NSApp modalWindow]) {
		return NSDragOperationNone;
	}
	NSPasteboard *pboard = [sender draggingPasteboard];
	NSString *pboardType = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType, NSStringPboardType, nil]];
	
	if ([pboardType isEqualToString:NSFilenamesPboardType]) {
		/*NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
		for (NSString *fileName in fileNames) {
			
			//TODO: Check if any key to import are available.
			
			NSString *extension = [fileName pathExtension];
			if ([extension isEqualToString:@"asc"] || [extension isEqualToString:@"gpgkey"] || [extension isEqualToString:@"gpg"]) {
			return NSDragOperationCopy;
			}
		}*/
		return NSDragOperationCopy;
	} else if ([pboardType isEqualToString:NSStringPboardType]) {
		NSString *string = [pboard stringForType:NSStringPboardType];
		if (couldContainPGPKey(string)) {
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
			
			/*NSString *extension = [fileName pathExtension];
			if ([extension isEqualToString:@"asc"] || [extension isEqualToString:@"gpgkey"] || [extension isEqualToString:@"gpg"]) {*/
			[filesToImport addObject:fileName];
			/*}*/
			
		}
		if ([filesToImport count] > 0) {
			[NSThread detachNewThreadSelector:@selector(importFromURLs:) toTarget:[ActionController sharedInstance] withObject:filesToImport];
			return YES;
		}
	} else if ([pboardType isEqualToString:NSStringPboardType]) {
		NSString *string = [pboard stringForType:NSStringPboardType];
		if (couldContainPGPKey(string)) {
			[NSThread detachNewThreadSelector:@selector(importFromData:) toTarget:[ActionController sharedInstance] withObject:[string UTF8Data]];
			return YES;
		}
	}
	return NO;
}


- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)awindow {
	return [[ActionController sharedInstance] undoManager];
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
	[mainWindow makeKeyAndOrderFront:nil];
	return YES;
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames {
	if (![NSApp modalWindow]) {
		[[ActionController sharedInstance] importFromURLs:filenames askBeforeOpen:NO];
	}
}


- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex {
	return proposedMinimumPosition + 68;
}
- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex {
	return proposedMaximumPosition - 108;
}

- (IBAction)showPreferences:(id)sender {
	[[PreferencesController sharedInstance] showPreferences:sender];
}

- (IBAction)showHelp:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://gpgtools.tenderapp.com/kb/gpg-keychain-faq/"]];
}
- (IBAction)showSupport:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://gpgtools.tenderapp.com/home"]];
}
- (IBAction)sendReport:(id)sender {
	SBSystemPreferencesApplication *systemPrefs = [SBApplication applicationWithBundleIdentifier:@"com.apple.systempreferences"];
	SBElementArray *panes = systemPrefs.panes;
	SBSystemPreferencesPane *gpgPane = nil;
	BOOL success = NO;
	
	
	for (SBSystemPreferencesPane *pane in panes) {
		if ([pane.id isEqualToString:@"org.gpgtools.gpgpreferences"]) {
			gpgPane = pane;
			break;
		}
	}
	if (gpgPane) {
		SBElementArray *anchors = gpgPane.anchors;
		
		for (SBSystemPreferencesAnchor *anchor in anchors) {
			if ([anchor.name isEqualToString:@"report"]) {
				[systemPrefs activate];
				[anchor reveal];
				success = YES;
				break;
			}
		}
	}
	if (success == NO) {
		[self showSupport:sender];
	}
}




@end
