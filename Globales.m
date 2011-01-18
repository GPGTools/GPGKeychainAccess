/*
 Copyright © Roman Zechmeister, 2011
 
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
#import "GKKey.h"
#import "ActionController.h"
#import "KeychainController.h"

NSString *GPG_PATH;
NSString *GPG_AGENT_PATH;
NSInteger GPG_VERSION;
KeychainController *keychainController;
ActionController *actionController;
NSWindow *mainWindow;
NSWindow *inspectorWindow;
NSUndoManager *undoManager;
BOOL useUndo;


NSSet* keyInfoSet(NSArray *keyInfos) {
	NSMutableSet *keyInfoSet = [NSMutableSet set];
	for (GKKey *keyInfo in keyInfos) {
		[keyInfoSet addObject:[keyInfo primaryKeyInfo]];
	}
	return keyInfoSet;
}

NSInteger getDaysToExpire(NSDate *expirationDate) {
	return ([expirationDate timeIntervalSinceNow] + 86399) / 86400;
}


NSString* dataToString(NSData *data) {
	NSString *retString;

	// Löschen aller ungültigen Zeichen, damit die umwandlung nach UTF-8 funktioniert.
	const unsigned char *inText = [data bytes];
	if (!inText) {
		return nil;
	}
	
	NSUInteger i = 0, c = [data length];
	
	unsigned char *outText = malloc(c + 1);
	if (outText) {
		unsigned char *outPos = outText;
		const unsigned char *startChar = nil;
		int multiByte = 0;
		
		for (; i < c; i++) {
			if (multiByte && (*inText & 0xC0) == 0x80) { // Fortsetzung eines Mehrbytezeichen
				multiByte--;
				if (multiByte == 0) {
					while (startChar <= inText) {
						*(outPos++) = *(startChar++);
					}
				}
			} else if ((*inText & 0x80) == 0) { // Normales ASCII Zeichen.
				*(outPos++) = *inText;
				multiByte = 0;
			} else if ((*inText & 0xC0) == 0xC0) { // Beginn eines Mehrbytezeichen.
				if (multiByte) {
					*(outPos++) = '?';
				}
				if (*inText <= 0xDF && *inText >= 0xC2) {
					multiByte = 1;
					startChar = inText;
				} else if (*inText <= 0xEF && *inText >= 0xE0) {
					multiByte = 2;
					startChar = inText;
				} else if (*inText <= 0xF4 && *inText >= 0xF0) {
					multiByte = 3;
					startChar = inText;
				} else {
					*(outPos++) = '?';
					multiByte = 0;
				}
			} else {
				*(outPos++) = '?';
			}

			inText++;
		}
		*outPos = 0;
		
		retString = [[NSString alloc] initWithUTF8String:(char*)outText];
		
		free(outText);
	} else {
		retString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	}

	
	if (retString == nil) {
		retString = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
	}
	return [retString autorelease];
}
NSData* stringToData(NSString *string) {
	return [string dataUsingEncoding:NSUTF8StringEncoding];
}


NSString* getShortKeyID(NSString *keyID) {
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


int hexToByte (const char *text) {
	int retVal = 0;
	int i;
	
	for (i = 0; i < 2; i++) {
		if (*text >= '0' && *text <= '9') {
			retVal += *text - '0';
		} else if (*text >= 'A' && *text <= 'F') {
			retVal += 10 + *text - 'A';
		} else if (*text >= 'a' && *text <= 'f') {
			retVal += 10 + *text - 'a';
		} else {
			return -1;
		}
		
		if (i == 0) {
			retVal *= 16;
		}
		text++;
    }
	return retVal;
}

//Wandelt "\\t" -> "\t", "\\x3a" -> ":" usw.
NSString *unescapeString(NSString *string) {
	const char *escapedText = [string UTF8String];
	char *unescapedText = malloc(strlen(escapedText) + 1);
	if (!unescapedText) {
		return nil;
	}
	char *unescapedTextPos = unescapedText;
	
	while (*escapedText) {
		if (*escapedText == '\\') {
			escapedText++;
			switch (*escapedText) {
				#define DECODE_ONE(match, result) \
				case match: \
					escapedText++; \
					*(unescapedTextPos++) = result; \
					break;
					
				DECODE_ONE ('\'', '\'');
				DECODE_ONE ('\"', '\"');
				DECODE_ONE ('\?', '\?');
				DECODE_ONE ('\\', '\\');
				DECODE_ONE ('a', '\a');
				DECODE_ONE ('b', '\b');
				DECODE_ONE ('f', '\f');
				DECODE_ONE ('n', '\n');
				DECODE_ONE ('r', '\r');
				DECODE_ONE ('t', '\t');
				DECODE_ONE ('v', '\v');
					
				case 'x': {
					escapedText++;
					int byte = hexToByte(escapedText);
					if (byte == -1) {
						*(unescapedTextPos++) = '\\';
						*(unescapedTextPos++) = 'x';
					} else {
						if (byte == 0) {
							*(unescapedTextPos++) = '\\';
							*(unescapedTextPos++) = '0';							
						} else {
							*(unescapedTextPos++) = byte;
						}
						escapedText += 2;
					}
					break; }
				default:
					*(unescapedTextPos++) = '\\';
					*(unescapedTextPos++) = *(escapedText++);
					break;
			}
		} else {
			*(unescapedTextPos++) = *(escapedText++);
		}
	}
	*unescapedTextPos = 0;
	
	NSString *retString = [NSString stringWithUTF8String:unescapedText];
	free(unescapedText);
	return retString;
}

