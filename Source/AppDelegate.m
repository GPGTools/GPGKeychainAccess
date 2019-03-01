/*
 Copyright © Roman Zechmeister, 2019
 
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
#import "GKFieldEditor.h"


@implementation GPGKeychainAppDelegate

- (NSWindow *)window {
    return mainWindow;
}
- (void)setWindow:(NSWindow *)value {
	mainWindow = value;
}


- (BOOL)inspectorVisible {
	return self.inspectorWindow.visible;
}
- (void)setInspectorVisible:(BOOL)inspectorVisible {
	[self showInspector:inspectorVisible];
}

- (void)showInspector:(int)show {
	static BOOL displayedAlready = NO;
	BOOL isVisible = self.inspectorWindow.visible;
	
	if (show == -1) {
		show = !isVisible;
	}

	if (show) {
		if (!isVisible) {
			if (!displayedAlready) {
				displayedAlready = YES;
				NSRect mainFrame = self.window.frame;
				NSRect inspectorFrame = self.inspectorWindow.frame;
				NSPoint origin;
				origin.x = mainFrame.origin.x + mainFrame.size.width;
				origin.y = mainFrame.origin.y + mainFrame.size.height - inspectorFrame.size.height;
				[self.inspectorWindow setFrameOrigin:origin];
			}
			
			[self.window addChildWindow:self.inspectorWindow ordered:NSWindowAbove];
			[self.inspectorWindow makeKeyAndOrderFront:nil];
		}
	} else {
		[self.inspectorWindow close];
	}
}
- (IBAction)toggleInspector:(id)sender {
	[self showInspector:-1];
}
- (void)openInspector:(id)sender {
	[self showInspector:1];
}



- (IBAction)singleClick:(NSTableView *)sender {
	rowWasSelected = [_keyTable clickedRowWasSelected];
}
- (IBAction)doubleClick:(NSTableView *)sender {
	if (_keyTable.clickedRow >= 0) {
		if (_keyTable.selectedRowIndexes.count > 1 ? [_keyTable clickedRowWasSelected] : rowWasSelected) {
			[self showInspector:-1];
		} else {
			[self showInspector:1];
		}
	}
}
- (IBAction)showKeyDetails:(id)sender {
	[self showInspector:-1];
}


- (id)init {
	self = [super init];
	appDelegate = self;
	self.fieldEditor = [GKFieldEditor new];
	return self;
}

- (void)awakeFromNib {
	GPGDebugLog(@"GPGKeychainAppDelegate awakeFromNib");
	
	[self generateContextMenuForTable:_keyTable];
	[self generateContextMenuForTable:_subkeyTable];
	[self generateContextMenuForTable:_userIDTable];
	[self generateContextMenuForTable:_signatureTable];
		
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
			dispatch_async(dispatch_get_main_queue(), ^{
				[[ActionController sharedInstance] importFromURLs:filesToImport];
			});
			return YES;
		}
	} else if ([pboardType isEqualToString:NSStringPboardType]) {
		NSString *string = [pboard stringForType:NSStringPboardType];
		if (couldContainPGPKey(string)) {
			dispatch_async(dispatch_get_main_queue(), ^{
				[[ActionController sharedInstance] importFromData:string.UTF8Data];
			});
			return YES;
		}
	}
	return NO;
}


- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)awindow {
	return [[ActionController sharedInstance] undoManager];
}

- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)client {
	return self.fieldEditor;
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

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	if (_shouldTerminate) {
		[NSApp terminate:nil];
	}
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames {
	if (![NSApp modalWindow]) {
		BOOL onlyGPGServicesUsed = [[ActionController sharedInstance] importFromURLs:filenames askBeforeOpen:NO];
		if (onlyGPGServicesUsed) {
			_shouldTerminate = YES;
		}
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
	systemPrefs.timeout = EV_TICKS_PER_SEC * 3;
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
