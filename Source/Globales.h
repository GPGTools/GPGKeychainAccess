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

#import <Libmacgpg/Libmacgpg.h>

@class GPGKeychainAppDelegate;

extern NSWindow *mainWindow;
extern GPGKeychainAppDelegate *appDelegate;
extern BOOL showExpertSettings;


BOOL couldContainPGPKey(NSString *string);
NSString *localized(NSString *key);
NSString *localizedStringWithFormat(NSString *key, ...);
NSString *filenameForExportedKeys(NSArray *keys, NSString **secFilename);


@interface GKAKeyColorTransformer : NSValueTransformer {}
@end

@interface GKAValidityInidicatorTransformer : NSValueTransformer {}
@end

@interface GKIsValidTransformer : NSValueTransformer {}
@end

@interface GKFingerprintTransformer : GPGFingerprintTransformer
@end

@interface GKFixedFingerprintTransformer : GKFingerprintTransformer
@end

@interface GKOnlyOneSelectionIndexTransformer : NSValueTransformer {}
@end

@interface GKNotOneSelectionIndexTransformer : NSValueTransformer {}
@end
