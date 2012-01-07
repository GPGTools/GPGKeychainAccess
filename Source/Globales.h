/*
 Copyright © Roman Zechmeister, 2011
 
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


extern NSWindow *mainWindow;
extern NSWindow *inspectorWindow;




BOOL containsPGPKeyBlock(NSString *string);



#define NotImplementedAlert NSRunAlertPanel(@"Noch nicht implementiert", @"", @"OK", nil, nil)

#define localized(key) [[NSBundle mainBundle] localizedStringForKey:(key) value:nil table:nil]


@interface NSDate (GKA_Extension)
- (NSInteger)daysSinceNow;
@end

@interface NSString (GKA_Extension)
- (NSSet *)keyIDs;
- (NSString *)shortKeyID;
@end

@interface GKAKeyColorTransformer : NSValueTransformer {}
@end

