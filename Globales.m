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
NSString *GPG_AGENT_PATH;
NSInteger GPG_VERSION;
KeychainController *keychainController;
ActionController *actionController;
NSWindow *mainWindow;
NSWindow *inspectorWindow;
GPGContext *gpgContext;
NSUndoManager *undoManager;
BOOL useUndo;


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

NSData* stringToData(NSString *string) {
	return [string dataUsingEncoding:NSUTF8StringEncoding];
}

NSString* shortKeyID(NSString *keyID) {
	return [keyID substringFromIndex:[keyID length] - 8];
}


NSSet* keyIDsFromString(NSString *string) {
	NSArray *substrings = [string componentsSeparatedByString:@" "];
	NSMutableSet *keyIDs = [NSMutableSet setWithCapacity:[substrings count]];
	BOOL found = NO;
	
	NSCharacterSet *noHexCharSet = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"] invertedSet];
	NSInteger stringLength;
	NSString *stringToCheck;
	
	for (NSString *substring in substrings) {
		stringLength = [substring length];
		stringToCheck = nil;
		switch (stringLength) {
			case 8:
			case 16:
			case 32:
			case 40:
				stringToCheck = substring;
				break;
			case 9:
			case 17:
			case 33:
			case 41:
				if ([substring hasPrefix:@"0"]) {
					stringToCheck = [substring substringFromIndex:1];
				}
				break;
			case 10:
			case 18:
			case 34:
			case 42:
				if ([substring hasPrefix:@"0x"]) {
					stringToCheck = [substring substringFromIndex:2];
				}
				break;
		}
		if (stringToCheck && [stringToCheck rangeOfCharacterFromSet:noHexCharSet].length == 0) {
			[keyIDs addObject:stringToCheck];
			found = YES;
		}
	}
	
	return found ? [[keyIDs copy] autorelease] : nil;
}



BOOL containsPGPKeyBlock(NSString *string) {
	return ([string rangeOfString:@"-----BEGIN PGP PUBLIC KEY BLOCK-----"].length > 0 && 
			[string rangeOfString:@"-----END PGP PUBLIC KEY BLOCK-----"].length > 0) || 
		([string rangeOfString:@"-----BEGIN PGP PRIVATE KEY BLOCK-----"].length > 0 && 
		 [string rangeOfString:@"-----END PGP PRIVATE KEY BLOCK-----"].length > 0);
}


BOOL isGpgAgentRunning() {
	if (!GPG_AGENT_PATH) {
		return NO;
	}
	NSFileHandle *nullFileHandle = [NSFileHandle fileHandleWithNullDevice];
	NSTask *agentTask = [[[NSTask alloc] init] autorelease];
	[agentTask setLaunchPath:GPG_AGENT_PATH];
	[agentTask setStandardOutput:nullFileHandle];
	[agentTask setStandardError:nullFileHandle];
	[agentTask launch];
	[agentTask waitUntilExit];
	return [agentTask terminationStatus] == 0;
}


