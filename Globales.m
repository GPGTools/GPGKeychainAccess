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

#import "Globales.h"
#import "KeyInfo.h"
#import "ActionController.h"
#import "KeychainController.h"

NSString *GPG_PATH;
KeychainController *keychainController;
ActionController *actionController;
NSWindow *mainWindow;
NSWindow *inspectorWindow;
GPGContext *gpgContext;


NSSet* KeyInfoSet(NSArray *keyInfos) {
	NSMutableSet *keyInfoSet = [NSMutableSet set];
	for (KeyInfo *keyInfo in keyInfos) {
		[keyInfoSet addObject:[keyInfo primaryKeyInfo]];
	}
	return keyInfoSet;
}

NSInteger getDaysToExpire(NSDate *expirationDate) {
	return ([expirationDate timeIntervalSinceNow] + 86399) / 86400;
}


NSString* dataToString(NSData *data) {
	NSString *retString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (retString == nil) {
		retString = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
	}
	return [retString autorelease];
}

