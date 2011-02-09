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

#import "ImportExportController.h"
#import "KeychainController.h"
#import "ActionController.h"


@implementation ImportExportController
@synthesize allowSecretKeyExport;
@synthesize useASCII;


- (IBAction)exportKey:(id)sender {
	NSSet *keyInfos = KeyInfoSet([keysController selectedObjects]);
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	[savePanel setAccessoryView:exportKeyOptionsView];
	
	NSMutableString *filename = [NSMutableString string];
	if ([keyInfos count] == 1) {
		[filename appendString:[[keyInfos anyObject] shortKeyID]];
	} else {
		[filename appendString:localized(@"untitled")];
	}
	[filename appendString:@".gpgkey"];
	
	if([savePanel runModalForDirectory:nil file:filename] == NSOKButton){
		[actionController exportKeys:keyInfos toFile:[savePanel filename] useASCII:useASCII allowSecret:allowSecretKeyExport];
	}
}
- (IBAction)importKey:(id)sender {
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	
	[openPanel setAllowsMultipleSelection:YES];
	
	if ([openPanel runModalForTypes:[NSArray arrayWithObjects:@"gpgkey", @"key", nil]] == NSOKButton) {
		[actionController importFromFiles:[openPanel filenames]];
	}
	[keychainController asyncUpdateKeyInfos:nil];
}



@end
