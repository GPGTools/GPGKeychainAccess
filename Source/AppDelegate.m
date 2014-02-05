/*
 Copyright © Roman Zechmeister, 2013
 
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

#import "AppDelegate.h"
#import "KeychainController.h"
#import "ActionController.h"
#import "PreferencesController.h"


@implementation GPGKeychainAccessAppDelegate
@synthesize keyTable, userIDTable, subkeyTable, signatureTable;

- (NSWindow *)window {
    return mainWindow;
}
- (void)setWindow:(NSWindow *)value {
	mainWindow = value;
}

- (NSWindow *)inspectorWindow {
    return inspectorWindow;
}
- (void)setInspectorWindow:(NSWindow *)value {
	inspectorWindow = value;
}


- (id)init {
	self = [super init];
	appDelegate = self;
	return self;
}

- (void)awakeFromNib {
	GPGDebugLog(@"GPGKeychainAccessAppDelegate awakeFromNib");
	[keyTable setDoubleAction:@selector(showInspector:)];
	[keyTable setTarget:[ActionController sharedInstance]];
	
	[self generateContextMenuForTable:keyTable];
	[self generateContextMenuForTable:subkeyTable];
	[self generateContextMenuForTable:userIDTable];
	[self generateContextMenuForTable:signatureTable];
	
	[inspectorWindow bind:@"hidesOnDeactivate" toObject:[GPGOptions sharedOptions] withKeyPath:@"inspectorStayVisible" options:@{NSValueTransformerNameBindingOption: @"NSNegateBoolean"}];
	
	NSArray *draggedTypes = [NSArray arrayWithObjects:NSFilenamesPboardType, NSStringPboardType, nil];
	[mainWindow registerForDraggedTypes:draggedTypes];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	// Process command line arguments
	NSArray *arguments = [[NSProcessInfo processInfo] arguments];
	if ([arguments containsObject:@"--gen-key"]) {
		[[ActionController sharedInstance] generateNewKey:self];
	}
}

- (NSString *)feedURLStringForUpdater:(SUUpdater *)updater {
	NSString *updateSourceKey = @"UpdateSource";
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	
	NSString *feedURLKey = @"SUFeedURL";
	NSString *appcastSource = [[GPGOptions sharedOptions] stringForKey:updateSourceKey];
	if ([appcastSource isEqualToString:@"nightly"]) {
		feedURLKey = @"SUFeedURL_nightly";
	} else if ([appcastSource isEqualToString:@"prerelease"]) {
		feedURLKey = @"SUFeedURL_prerelease";
	} else {
		NSString *version = [bundle objectForInfoDictionaryKey:@"CFBundleVersion"];
		if ([version rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"nN"]].length > 0) {
			feedURLKey = @"SUFeedURL_nightly";
		} else if ([version rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"abAB"]].length > 0) {
			feedURLKey = @"SUFeedURL_prerelease";
		}
	}
	
	NSString *appcastURL = [bundle objectForInfoDictionaryKey:feedURLKey];
	if (!appcastURL) {
		appcastURL = [bundle objectForInfoDictionaryKey:@"SUFeedURL"];
	}
	return appcastURL;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
	if ([NSApp modalWindow]) {
		return NSDragOperationNone;
	}
	NSPasteboard *pboard = [sender draggingPasteboard];
	NSString *pboardType = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType, NSStringPboardType, nil]];
	
	if ([pboardType isEqualToString:NSFilenamesPboardType]) {
		NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
		for (NSString *fileName in fileNames) {
			
			//TODO: Check if any key to import are available.
			
			/*NSString *extension = [fileName pathExtension];
			if ([extension isEqualToString:@"asc"] || [extension isEqualToString:@"gpgkey"] || [extension isEqualToString:@"gpg"]) {*/
			return NSDragOperationCopy;
			/*}*/
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
		if (containsPGPKeyBlock(string)) {
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
	NSMenu *contextMenu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
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
		[[ActionController sharedInstance] importFromURLs:filenames];
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
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://support.gpgtools.org/kb/faq-gpg-keychain-access"]];
}
- (IBAction)showSupport:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://support.gpgtools.org/home"]];
}



@end
