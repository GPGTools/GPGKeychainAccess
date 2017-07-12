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

#import "Globales.h"

@class GKPhotoPopoverController;


@interface ActionController ()

typedef enum {
	DescriptionNoKeyID = 8,
	DescriptionNoEmail = 16,
	DescriptionNoName = 32,
	DescriptionSingleLine = 64,
	DescriptionIndent = 128
	
} DescriptionOptions;


@property (weak) IBOutlet NSArrayController *keysController;
@property (weak) IBOutlet NSArrayController *signaturesController;
@property (weak) IBOutlet NSArrayController *subkeysController;
@property (weak) IBOutlet NSArrayController *userIDsController;
@property (weak) IBOutlet NSTableView *keyTable;
@property (weak) IBOutlet NSTableView *signaturesTable;
@property (weak) IBOutlet NSTableView *userIDsTable;
@property (weak) IBOutlet NSTableView *subkeysTable;

@property (weak) IBOutlet GKPhotoPopoverController *photoPopoverController;
@property (weak) IBOutlet NSPopover *photoPopover;


@property (strong) NSString *progressText, *errorText;
@property (strong, readonly) NSUndoManager *undoManager;
@property (strong) NSSet *revCertCache;

- (void)receiveKeysFromServer:(NSObject <EnumerationList> *)keys;
- (NSString *)descriptionForKeys:(NSObject <EnumerationList> *)keys maxLines:(NSUInteger)lines withOptions:(DescriptionOptions)options;

- (BOOL)warningSheetWithDefault:(BOOL)defaultValue string:(NSString *)string, ...;



@end

typedef void (^actionCallback)(GPGController *gc, id value, NSDictionary *userInfo);
typedef void (^cancelCallback)();



enum {
	NoAction = 0,
	ShowResultAction,
	SaveDataToURLAction,
	CallbackAction
};

enum {
	ImportOperation = 1,
	NewKeyOperation
};

