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

#import <Libmacgpg/Libmacgpg.h>

@class GPGKeychainAccessAppDelegate;

extern NSWindow *mainWindow, *inspectorWindow;
extern GPGKeychainAccessAppDelegate *appDelegate;



BOOL containsPGPKeyBlock(NSString *string);
NSString *localized(NSString *key);


@interface NSDate (GKA_Extension)
- (NSInteger)daysSinceNow;
@end

@interface NSString (GKA_Extension)
- (NSSet *)keyIDs;
- (NSString *)shortKeyID;
@end

@interface GKAKeyColorTransformer : NSValueTransformer {}
@end

