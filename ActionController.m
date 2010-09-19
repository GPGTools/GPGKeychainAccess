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

#import "ActionController.h"
#import "KeyInfo.h"
#import "KeychainController.h"
#import "SheetController.h"

@implementation ActionController

@synthesize allowSecretKeyExport;
@synthesize useASCIIForExport;


- (IBAction)importKey:(id)sender {
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	
	[openPanel setAllowsMultipleSelection:YES];
	[openPanel setTitle:localized(@"Import")];
	
	if ([openPanel runModalForTypes:[NSArray arrayWithObjects:@"gpgkey", @"key", nil]] == NSOKButton) {
		[self importFromFiles:[openPanel filenames]];
	}
	[keychainController asyncUpdateKeyInfos:nil];
}
- (void)importFromFiles:(NSArray *)files {
	//TODO: Rückmeldung über importierte Schlüssel.
	NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:[files count] + 1];
	[arguments addObject:@"--import"];

	for (NSString *file in files) {
		[arguments addObject:file];
	}
	
	if (runGPGCommandWithArray(nil, nil, nil, arguments, YES) != 0) {
		NSLog(@"importFromFiles: --import fehlgeschlagen.");	
	}	
}

- (IBAction)exportKey:(id)sender {
	NSSet *keyInfos = KeyInfoSet([keysController selectedObjects]);
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	
	[savePanel setAccessoryView:exportKeyOptionsView];
	[savePanel setTitle:localized(@"Export")];
	
	NSMutableString *filename = [NSMutableString string];
	if ([keyInfos count] == 1) {
		[filename appendString:[[keyInfos anyObject] shortKeyID]];
	} else {
		[filename appendString:localized(@"untitled")];
	}
	[filename appendString:@".gpgkey"];
	
	if([savePanel runModalForDirectory:nil file:filename] == NSOKButton){
		[self exportKeys:keyInfos toFile:[savePanel filename] armored:useASCIIForExport allowSecret:allowSecretKeyExport];
	}
}
- (void)exportKeys:(NSSet *)keys toFile:(NSString *)path armored:(BOOL)armored allowSecret:(BOOL)allowSec {
	BOOL hasSecKeys = NO;
	NSMutableArray *arguments;
	NSSet *pubKeys;
	NSData *exportedSecretData, *exportedData = nil;
	KeyInfo *keyInfo;
	
	if (allowSec) {
		arguments = [NSMutableArray array];
		pubKeys = [NSMutableSet set];
		[arguments addObject:armored ? @"--armor" : @"--no-armor"];
		[arguments addObject:@"--export-secret-keys"];
		
		for (keyInfo in keys) {
			if ([keyInfo isSecret]) {
				[arguments addObject:[keyInfo fingerprint]];
				hasSecKeys = YES;
			} else {
				[(NSMutableSet*)pubKeys addObject:keyInfo];
			}
		}
		
		if (hasSecKeys || [keys count] == 0) {
			hasSecKeys = YES;
			if (runGPGCommandWithArray(nil, &exportedSecretData, nil, arguments, YES) != 0) {
				NSLog(@"exportKeys: --export-secret-keys fehlgeschlagen.");
			}
		}
	} else {
		pubKeys = keys;
	}
	
	
	if (!([keys count] > 0 && [pubKeys count] == 0)) {
		arguments = [NSMutableArray array];
		[arguments addObject:armored ? @"--armor" : @"--no-armor"];
		[arguments addObject:@"--export"];
		
		for (keyInfo in pubKeys) {
			[arguments addObject:[keyInfo fingerprint]];
		}
		
		if (runGPGCommandWithArray(nil, &exportedData, nil, arguments, YES) != 0) {
			NSLog(@"exportKeys: --export fehlgeschlagen.");	
		}		
	}
	
	if (hasSecKeys) {
		if (exportedData) {
			exportedData = [NSMutableData dataWithData:exportedData];
			[(NSMutableData*)exportedData appendData:exportedSecretData];
		} else {
			exportedData = exportedSecretData;
		}
	}
	
	[exportedData writeToFile:path atomically:NO];
}

- (IBAction)addSignature:(id)sender { //TODO: Nach dem geheimen Schlüssel zum Signieren fragen. (Irgendwann...)
	if ([sender tag] != 1 || [userIDsController selectionIndex] != NSNotFound) {
		KeyInfo *keyInfo = [[[keysController selectedObjects] objectAtIndex:0] primaryKeyInfo];
		SheetController *sheetController = [SheetController sharedInstance];
		
		NSString *userID;
		if ([sender tag] == 1) {
			userID = [[[userIDsController selectedObjects] objectAtIndex:0] userID];
		} else {
			userID = nil;
		}
		
		[sheetController addSignature:keyInfo userID:userID];
	}
}
- (void)addSignatureForKeyInfo:(KeyInfo *)keyInfo andUserID:(NSString *)userID type:(NSInteger)type local:(BOOL)local daysToExpire:(NSInteger)daysToExpire {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSString *fingerprint = [keyInfo fingerprint];
	
	NSString *sigType = local ? @"lsign" : @"sign";	
	NSString *uid = userID ? [NSString stringWithFormat:@"%i", getIndexForUserID(fingerprint, userID)] : @"uid *";
	
	NSString *cmdText = [NSString stringWithFormat:@"%@\n%@\n%i\n%i\ny\nsave\n", uid, sigType, daysToExpire, type];
	NSArray *arguments = [NSArray arrayWithObjects:@"--ask-cert-level", @"--ask-cert-expire", @"--edit-key", fingerprint, nil];
	
	if (runGPGCommandWithArray(cmdText, nil, nil, arguments, NO) != 0) {
		NSLog(@"addSignature: --edit-key:%@ für Schlüssel %@ fehlgeschlagen.", sigType, fingerprint);	
	}
	[keychainController updateKeyInfos:[NSArray arrayWithObject:keyInfo]];

	[pool drain];
}

- (IBAction)addSubkey:(NSButton *)sender {
	if ([[keysController selectedObjects] count] == 1) {
		KeyInfo *keyInfo = [[[keysController selectedObjects] objectAtIndex:0] primaryKeyInfo];
		SheetController *sheetController = [SheetController sharedInstance];
		
		[sheetController addSubkey:keyInfo];
	}
}
- (void)addSubkeyForKeyInfo:(KeyInfo *)keyInfo type:(NSInteger)type length:(NSInteger)length daysToExpire:(NSInteger)daysToExpire {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	
	NSString *cmdText = [NSString stringWithFormat:@"addkey\n%i\n%i\n%i\nsave\n", type, length, daysToExpire];
	if (runGPGCommand(cmdText, nil, nil, @"--edit-key", [keyInfo fingerprint], nil) != 0) {
		NSLog(@"generateSubkey: --edit-key:addkey für Schlüssel %@ fehlgeschlagen.", [keyInfo keyID]);
	}
	[keychainController updateKeyInfos:[NSArray arrayWithObject:keyInfo]];
	
	[pool drain];
}

- (IBAction)addUserID:(NSButton *)sender {
	if ([[keysController selectedObjects] count] == 1) {
		KeyInfo *keyInfo = [[[keysController selectedObjects] objectAtIndex:0] primaryKeyInfo];
		SheetController *sheetController = [SheetController sharedInstance];
		
		[sheetController addUserID:keyInfo];
	}
}
- (void)addUserIDForKeyInfo:(KeyInfo *)keyInfo name:(NSString *)name email:(NSString *)email comment:(NSString *)comment{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSString *cmdText = [NSString stringWithFormat:@"adduid\n%@\n%@\n%@\nsave\n", name, email, comment];
	if (runGPGCommand(cmdText, nil, nil, @"--edit-key", [keyInfo fingerprint], nil) != 0) {
		NSLog(@"generateUserID: --edit-key:adduid für Schlüssel %@ fehlgeschlagen.", [keyInfo keyID]);
	}
	[keychainController updateKeyInfos:[NSArray arrayWithObject:keyInfo]];

	[pool drain];
}

- (IBAction)changeExpirationDate:(NSButton *)sender {
	BOOL aKeyIsSelected = NO;
	KeyInfo_Subkey *subkey;
	
	if ([sender tag] == 1 && [[subkeysController selectedObjects] count] == 1) {
		subkey = [[subkeysController selectedObjects] objectAtIndex:0];
		aKeyIsSelected = YES;
	} else if ([sender tag] == 0 && [[keysController selectedObjects] count] == 1) {
		subkey = nil;
		aKeyIsSelected = YES;
	}
	
	if (aKeyIsSelected) {
		KeyInfo *keyInfo = [[[keysController selectedObjects] objectAtIndex:0] primaryKeyInfo];
		SheetController *sheetController = [SheetController sharedInstance];
		
		[sheetController changeExpirationDate:keyInfo subkey:subkey];		
	}
	
}
- (void)changeExpirationDateForKeyInfo:(KeyInfo *)keyInfo subkey:(KeyInfo_Subkey *)subkey daysToExpire:(NSInteger)daysToExpire {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSString *cmdText;
	
	if (subkey) {
		NSInteger index = getIndexForSubkey([subkey fingerprint], [subkey keyID]);
		if (index == 0) {
			return;
		}		
		cmdText = [NSString stringWithFormat:@"key %i\nexpire\n%i\ny\nsave\n", index, daysToExpire];
	} else {
		cmdText = [NSString stringWithFormat:@"expire\n%i\ny\nsave\n", daysToExpire];
	}

	
	if (runGPGCommand(cmdText, nil, nil, @"--edit-key", [keyInfo fingerprint], nil) != 0) {
		NSLog(@"editExpirationDate: --edit-key:expire für Schlüssel %@ fehlgeschlagen.", [keyInfo keyID]);
	}
	[keychainController updateKeyInfos:[NSArray arrayWithObject:keyInfo]];
	
	[pool drain];
}

- (IBAction)searchKeys:(id)sender {
	SheetController *sheetController = [SheetController sharedInstance];
	[sheetController searchKeys];
}
- (NSString *)searchKeysWithPattern:(NSString *)pattern {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSString *outText;
	searchKeysOnServer(pattern, &outText);
	
	
	NSMutableString *foundText = [NSMutableString string];
	NSString *returnText;
	
	NSArray *lines = [outText componentsSeparatedByString:@"\n"];
	NSArray *splitedLine;
	NSString *pubKeyText = nil;
	KeyAlgorithmTransformer *algorithmTransformer = [[[KeyAlgorithmTransformer alloc] init] autorelease];
	
	NSUInteger i, count = [lines count];
	for (i = 0; i < count; i++) {
		splitedLine = [[lines objectAtIndex:i] componentsSeparatedByString:@":"];
		if ([[splitedLine objectAtIndex:0] isEqualToString:@"pub"]) {
			if (pubKeyText) {
				[foundText appendString:pubKeyText];
			}
			pubKeyText = [NSString stringWithFormat:localized(@"  %@ bit %@ key %@, created: %@\n\n"), 
						  [splitedLine objectAtIndex:3], 
						  [algorithmTransformer transformedValue:[splitedLine objectAtIndex:2]], 
						  [splitedLine objectAtIndex:1], 
						  [splitedLine objectAtIndex:4]];			
		} else if (pubKeyText && [[splitedLine objectAtIndex:0] isEqualToString:@"uid"]) {
			[foundText appendFormat:localized(@"%@\n"), 
			 [splitedLine objectAtIndex:1]];
		}
	}
	if (pubKeyText) {
		[foundText appendString:pubKeyText];
		returnText = [foundText stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	} else {
		returnText = localized(@"No keys Found!");
	}
	[returnText retain];
	
	[pool drain];
	return [returnText autorelease];
}

- (IBAction)receiveKeys:(id)sender {
	SheetController *sheetController = [SheetController sharedInstance];
	[sheetController receiveKeys];
}
- (void)receiveKeysWithPattern:(NSString *)pattern {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSMutableArray *arguments = [NSMutableArray arrayWithObject:@"--recv-keys"];
	NSArray *keyIDs = [pattern componentsSeparatedByString:@" "];
	
	NSCharacterSet *hexCharSet = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"] invertedSet];
	NSInteger stringLength;
	NSString *stringToCheck;
	
	for (NSString *aKeyID in keyIDs) {
		stringLength = [aKeyID length];
		stringToCheck = nil;
		switch (stringLength) {
			case 8:
			case 16:
			case 32:
			case 40:
				stringToCheck = aKeyID;
				break;
			case 9:
			case 17:
			case 33:
			case 41:
				if ([aKeyID hasPrefix:@"0"]) {
					stringToCheck = [aKeyID substringFromIndex:1];
				}
				break;
			case 10:
			case 18:
			case 34:
			case 42:
				if ([aKeyID hasPrefix:@"0x"]) {
					stringToCheck = [aKeyID substringFromIndex:2];
				}
				break;
		}
		if (stringToCheck && [stringToCheck rangeOfCharacterFromSet:hexCharSet].length == 0) {
			[arguments addObject:stringToCheck];
		}
	}
	
	if (runGPGCommandWithArray(nil, nil, nil, arguments, YES) != 0) {
		NSLog(@"receiveKeys_Selector: --recv-keys für \"%@\" fehlgeschlagen.", pattern);	
	}
	[keychainController updateKeyInfos:nil];
	[pool drain];
}

- (IBAction)sendKeysToServer:(id)sender {
	NSSet *keyInfos = KeyInfoSet([keysController selectedObjects]);
	if ([keyInfos count] > 0) {
		NSMutableArray *arguments = [NSMutableArray arrayWithObject:@"--send-key"];
		for (KeyInfo *keyInfo in keyInfos) {
			[arguments addObject:[keyInfo fingerprint]];
		}
		if (runGPGCommandWithArray(nil, nil, nil, arguments, YES) != 0) {
			NSLog(@"sendKeysToServer: --send-key fehlgeschlagen.");
		}						
	}	
}

- (IBAction)refreshKeysFromServer:(id)sender {
	NSSet *keyInfos = KeyInfoSet([keysController selectedObjects]);
	NSMutableArray *arguments = [NSMutableArray arrayWithObject:@"--refresh-keys"];
	for (KeyInfo *keyInfo in keyInfos) {
		[arguments addObject:[keyInfo fingerprint]];
	}
	if (runGPGCommandWithArray(nil, nil, nil, arguments, YES) != 0) {
		NSLog(@"refreshKeysFromServer: --refresh-keys fehlgeschlagen.");
	}
	[keychainController asyncUpdateKeyInfos:[keysController selectedObjects]];
}

- (IBAction)changePassphrase:(NSButton *)sender {
	if ([[keysController selectedObjects] count] == 1) {
		KeyInfo *keyInfo = [[[keysController selectedObjects] objectAtIndex:0] primaryKeyInfo];
		
		if (runGPGCommand(@"passwd\ny\nsave\n", nil, nil, @"--edit-key", [keyInfo fingerprint], nil) != 0) {
			NSLog(@"changePassphrase: --edit-key:passwd für Schlüssel %@ fehlgeschlagen.", [keyInfo keyID]);	
		}
		[keychainController asyncUpdateKeyInfos:[keysController selectedObjects]];
	}
}

- (IBAction)removeSignature:(NSButton *)sender { //Diese Funktion ist äusserst ineffizient, mir ist allerdings kein besserer Weg bekannt.
	if ([signaturesController selectionIndex] != NSNotFound) {
		GPGKeySignature *gpgKeySignature = [[signaturesController selectedObjects] objectAtIndex:0];
		KeyInfo_UserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
		NSArray *signatures = [userID signatures];
		KeyInfo *keyInfo = [[[keysController selectedObjects] objectAtIndex:0] primaryKeyInfo];
		NSString *fingerprint = [keyInfo fingerprint];
		NSInteger uid = getIndexForUserID(fingerprint, [userID userID]);
		NSMutableString *cmdText = [NSMutableString stringWithCapacity:4];
		
		for (GPGKeySignature *aSignature in signatures) {
			if (aSignature == gpgKeySignature) {
				[cmdText appendString:@"y\n"];
				if ([[gpgKeySignature signerKeyID] isEqualToString:[keyInfo keyID]]) {
					[cmdText appendString:@"y\n"];
				}
			} else {
				[cmdText appendString:@"n\n"];
			}
		}
				
		if (runGPGCommand(cmdText, nil, nil, @"--edit-key", fingerprint, [NSString stringWithFormat:@"%i", uid], @"delsig", @"save", nil) != 0) {
			NSLog(@"removeSignature: --edit-key:delsig für Schlüssel %@ fehlgeschlagen.", fingerprint);	
		}
		[keychainController asyncUpdateKeyInfos:[keysController selectedObjects]];
	}	
}

- (IBAction)removeSubkey:(NSButton *)sender {
	if ([[subkeysController selectedObjects] count] == 1) {
		KeyInfo_Subkey *subkey = [[subkeysController selectedObjects] objectAtIndex:0];
		NSInteger index = getIndexForSubkey([subkey fingerprint], [subkey keyID]);
		if (index > 0) {
			NSString *cmdText = [NSString stringWithFormat:@"key %i\ndelkey\ny\nsave\n", index];
			if (runGPGCommand(cmdText, nil, nil, @"--edit-key", [subkey fingerprint], nil) != 0) {
				NSLog(@"removeSubkey: --edit-key:delkey für Schlüssel %@ fehlgeschlagen.", [subkey keyID]);
			}
			[keychainController asyncUpdateKeyInfos:[keysController selectedObjects]];
		}
	}	
}

- (IBAction)removeUserID:(NSButton *)sender {
	if ([userIDsController selectionIndex] != NSNotFound) {
		KeyInfo *keyInfo = [[[keysController selectedObjects] objectAtIndex:0] primaryKeyInfo];
		NSString *fingerprint = [keyInfo fingerprint];
		NSInteger uid = getIndexForUserID(fingerprint, [[[userIDsController selectedObjects] objectAtIndex:0] userID]);
				
		NSString *cmdText = [NSString stringWithFormat:@"%i\ndeluid\ny\nsave\n", uid];
		if (runGPGCommand(cmdText, nil, nil, @"--edit-key", fingerprint, nil) != 0) {
			NSLog(@"removeUserID: --edit-key:deluid für Schlüssel %@ fehlgeschlagen.", fingerprint);	
		}
		[keychainController asyncUpdateKeyInfos:[keysController selectedObjects]];
	}
}

- (IBAction)revokeSignature:(NSButton *)sender { //Diese Funktion ist äusserst ineffizient, mir ist allerdings kein besserer Weg bekannt.
	if ([signaturesController selectionIndex] != NSNotFound) {
		GPGKeySignature *gpgKeySignature = [[signaturesController selectedObjects] objectAtIndex:0];
		KeyInfo_UserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
		NSArray *signatures = [userID signatures];
		NSString *fingerprint = [[[[keysController selectedObjects] objectAtIndex:0] primaryKeyInfo] fingerprint];
		NSInteger uid = getIndexForUserID(fingerprint, [userID userID]);
		NSMutableString *cmdText = [NSMutableString stringWithCapacity:9];
		NSMutableArray *secKeyIDs = [NSMutableArray arrayWithCapacity:1];
		NSEnumerator *keyEnum = [[keychainController keychain] objectEnumerator];
		KeyInfo *keyInfo;
		NSString *signerKeyID1 = [gpgKeySignature signerKeyID];
		NSString *signerKeyID2;
		BOOL isSigFromMe;
		NSUInteger i, count;
		
		while (keyInfo = [keyEnum nextObject]) {
			if ([keyInfo isSecret]) {
				[secKeyIDs addObject:[keyInfo keyID]];
			}
		}
		count = [secKeyIDs count];
		
		for (GPGKeySignature *aSignature in signatures) {
			if (![aSignature isRevocationSignature]) {
				isSigFromMe = NO;
				signerKeyID2 = [aSignature signerKeyID];
				for (i = 0; i < count; i++) {
					if ([signerKeyID2 isEqualToString:[secKeyIDs objectAtIndex:i]]) {
						isSigFromMe = YES;
						break;
					}
				}
				if (isSigFromMe) {
					if ([signerKeyID1 isEqualToString:signerKeyID2]) {
						[cmdText appendString:@"y\ny\n0\n\ny\n"]; //Eigensignatur
					} else {
						[cmdText appendString:@"n\n"]; //Normale Signatur
					}
				}
			}
		}
		if ([cmdText length] > 0) {
			if (runGPGCommand(cmdText, nil, nil, @"--edit-key", fingerprint, [NSString stringWithFormat:@"%i", uid], @"revsig", @"save", nil) != 0) {
				NSLog(@"revokeSignature: --edit-key:revsig für Schlüssel %@ fehlgeschlagen.", fingerprint);	
			}
			[keychainController asyncUpdateKeyInfos:[keysController selectedObjects]];
		}
	}	
}

- (IBAction)revokeSubkey:(NSButton *)sender {
	if ([[subkeysController selectedObjects] count] == 1) {
		KeyInfo_Subkey *subkey = [[subkeysController selectedObjects] objectAtIndex:0];
		NSInteger index = getIndexForSubkey([subkey fingerprint], [subkey keyID]);
		if (index > 0) {
			NSString *cmdText = [NSString stringWithFormat:@"key %i\nrevkey\ny\n0\n\ny\nsave\n", index];
			if (runGPGCommand(cmdText, nil, nil, @"--edit-key", [subkey fingerprint], nil) != 0) {
				NSLog(@"revokeSubkey: --edit-key:revkey für Schlüssel %@ fehlgeschlagen.", [subkey keyID]);
			}
			[keychainController asyncUpdateKeyInfos:[keysController selectedObjects]];
		}
	}	
	
}

- (IBAction)setDisabled:(NSButton *)sender {
	NSSet *keyInfos = KeyInfoSet([keysController selectedObjects]);
	if ([keyInfos count] > 0) {
		NSString *enOrDisable = [sender state] == NSOnState ? @"disable" : @"enable";
		for (KeyInfo *keyInfo in keyInfos) {
			if (runGPGCommand(nil, nil, nil, @"--edit-key", [keyInfo fingerprint], enOrDisable, nil) != 0) {
				NSLog(@"setDisabled: --edit-key:%@ für Schlüssel %@ fehlgeschlagen.", enOrDisable, [keyInfo keyID]);
			}						
		}
		[keychainController asyncUpdateKeyInfos:[keysController selectedObjects]];
	}
}

- (IBAction)setPhoto:(NSImageView *)sender {
    //TODO: Irgendwann...
}

- (IBAction)setPrimaryUserID:(NSButton *)sender {
	if ([userIDsController selectionIndex] != NSNotFound) {
		KeyInfo *keyInfo = [[[keysController selectedObjects] objectAtIndex:0] primaryKeyInfo];
		NSString *fingerprint = [keyInfo fingerprint];
		NSInteger uid = getIndexForUserID(fingerprint, [[[userIDsController selectedObjects] objectAtIndex:0] userID]);
		if (runGPGCommand(nil, nil, nil, @"--edit-key", fingerprint, [NSString stringWithFormat:@"%i", uid], @"primary", @"save", nil) != 0) {
			NSLog(@"setPrimaryUserID: --edit-key:primary für Schlüssel %@ fehlgeschlagen.", fingerprint);	
		}
		[keychainController asyncUpdateKeyInfos:[keysController selectedObjects]];
	}
}

- (IBAction)setTrsut:(NSPopUpButton *)sender {
	NSSet *keyInfos = KeyInfoSet([keysController selectedObjects]);
	if ([keyInfos count] > 0) {
		NSString *cmdText = [NSString stringWithFormat:@"trust\n%i\ny\n", [sender selectedTag]];
		for (KeyInfo *keyInfo in keyInfos) {
			if (runGPGCommand(cmdText, nil, nil, @"--edit-key", [keyInfo fingerprint], nil) != 0) {
				NSLog(@"setTrsut: --edit-key:trust für Schlüssel %@ fehlgeschlagen.", [keyInfo keyID]);
			}						
		}
		[keychainController asyncUpdateKeyInfos:[keysController selectedObjects]];
	}
}

- (IBAction)generateNewKey:(id)sender {
	SheetController *sheetController = [SheetController sharedInstance];
	[sheetController generateNewKey];
}
- (void)generateNewKeyWithName:(NSString *)name email:(NSString *)email comment:(NSString *)comment type:(NSInteger)type length:(NSInteger)length daysToExpire:(NSInteger)daysToExpire {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSInteger keyType, subkeyType;
	
	switch (type) {
		default:
		case 1: //RSA und RSA
			keyType = GPG_RSAAlgorithm;
			subkeyType = GPG_RSAAlgorithm;
			break;
		case 2: //DSA und Elgamal
			keyType = GPG_DSAAlgorithm;
			subkeyType = GPG_ElgamalEncryptOnlyAlgorithm;
			break;
		case 3: //DSA
			keyType = GPG_DSAAlgorithm;
			subkeyType = 0;
			break;
		case 4: //RSA
			keyType = GPG_RSAAlgorithm;
			subkeyType = 0;
			break;
	}
	
	
	NSMutableString *cmdText = [NSMutableString string];
	
	[cmdText appendString:@"%ask-passphrase\n"];
	
	[cmdText appendFormat:@"Key-Type: %i\n", keyType];
	[cmdText appendFormat:@"Key-Length: %i\n", length];
	if (subkeyType) {
		[cmdText appendFormat:@"Subkey-Type: %i\n", subkeyType];
		[cmdText appendFormat:@"Subkey-Length: %i\n", length];
	}
	[cmdText appendFormat:@"Name-Real: %@\n", name];
	[cmdText appendFormat:@"Name-Email: %@\n", email];
	if ([comment length] > 0) {
		[cmdText appendFormat:@"Name-Comment: %@\n", comment];
	}
	[cmdText appendFormat:@"Expire-Date: %i\n", daysToExpire];
	
	[cmdText appendString:@"%commit\n"];
	
	
	if (runGPGCommand(cmdText, nil, nil, @"--gen-key", nil) != 0) {
		NSLog(@"generateNewKeyWithName: --gen-key fehlgeschlagen.");
	}
	
	
	[keychainController updateKeyInfos:nil];
	[pool drain];
}


- (IBAction)deleteKey:(id)sender { 
	//TODO: Bessere Dialoge mit der auswahl "Für alle".
	NSSet *keyInfos = KeyInfoSet([keysController selectedObjects]);
	if ([keyInfos count] > 0) {
		NSInteger retVal;
		NSString *cmd;
		
		for (KeyInfo *keyInfo in keyInfos) {
			
			if (keyInfo.isSecret) {
				retVal = NSRunAlertPanel(localized(@"DeleteSecretKey_Title"), 
								localized(@"DeleteSecretKey_Msg"), 
								localized(@"Delete secret key only"), 
								localized(@"Delete both"), 
								localized(@"Cancel"), 
								[keyInfo userID], 
								[keyInfo shortKeyID]);
				switch (retVal) {
					case NSAlertDefaultReturn:
						cmd = @"--delete-secret-keys";
						break;
					case NSAlertAlternateReturn:
						cmd = @"--delete-secret-and-public-key";
						break;
					default:
						cmd = nil;
				}
			} else {
				retVal = NSRunAlertPanel(localized(@"DeleteKey_Title"), 
										 localized(@"DeleteKey_Msg"), 
										 localized(@"Delete key"), 
										 localized(@"Cancel"), 
										 nil, 
										 [keyInfo userID], 
										 [keyInfo shortKeyID]);				
				switch (retVal) {
					case NSAlertDefaultReturn:
						cmd = @"--delete-keys";
						break;
					default:
						cmd = nil;
				}
			}
			if (cmd) {
				if (runGPGCommand(nil, nil, nil, cmd, [keyInfo fingerprint], nil) != 0) {
					NSLog(@"deleteKey: %@ für Schlüssel %@ fehlgeschlagen.", cmd, [keyInfo keyID]);
				}						
			}
		}
		[keychainController asyncUpdateKeyInfos:[keysController selectedObjects]];
	}
}


- (id)init {
	self = [super init];
	actionController = self;
	return self;
}




//Führt GPG mit den übergebenen Argumenten, aus.
//Wenn inText nicht nil ist, wird es gpg als stdin übergeben.
//Wenn outData nicht nil ist, wird Stdout in diesem NSData zurückgegeben. Gleiches für errData.
//Rückgabewert ist der Exitcode von GPG.
int runGPGCommandWithArray(NSString *inText, NSData **outData, NSData **errData, NSArray *args, BOOL batchMode) {
	NSMutableArray *arguments = [[NSMutableArray alloc] initWithCapacity:6];
	int exitcode;
		
	
	if (inText) {
		[arguments addObject:@"--command-fd"];
		[arguments addObject:@"0"];
	}
	
	[arguments addObject:@"--no-greeting"];
	[arguments addObject:@"--with-colons"];
	[arguments addObject:@"--yes"];
	[arguments addObject:batchMode ? @"--batch" : @"--no-batch"];
	[arguments addObject:@"--no-tty"];
	[arguments addObjectsFromArray:args];

	
	exitcode = runCommandWithArray(GPG_PATH, inText, outData, errData, arguments);
	
	
	[arguments release];
	
	return exitcode;
}
int runGPGCommand(NSString *inText, NSString **outText, NSString **errText, NSString *firstArg, ...) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:5];
	va_list args;
	NSString *tempArg;
	
	[arguments addObject:firstArg];
	va_start(args, firstArg);
	while (tempArg = va_arg(args, NSString*)) {
		[arguments addObject:tempArg];
	}
	
	NSData *outData, **outDataPointer = nil;
	NSData *errData, **errDataPointer = nil;
	
	if (outText) {
		outDataPointer = &outData;
	}
	if (errText) {
		errDataPointer = &errData;
	}
	
	int exitcode = runGPGCommandWithArray(inText, outDataPointer, errDataPointer, arguments, YES);
	
	
	if (outText) {
		*outText = [[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding];
		if (*outText == nil) {
			*outText = [[NSString alloc] initWithData:outData encoding:NSISOLatin1StringEncoding];
		}
	}
	if (errText) {
		*errText = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding];
		if (*errText == nil) {
			*errText = [[NSString alloc] initWithData:errData encoding:NSISOLatin1StringEncoding];
		}
	}
	
	[pool drain];
	
	if (outText) {
		[*outText autorelease];
	}
	if (errText) {
		[*errText autorelease];
	}
	
	
	return exitcode;
}

int runCommandWithArray(NSString *command, NSString *inText, NSData **outData, NSData **errData, NSArray *arguments) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSTask *cmdTask = [[NSTask alloc] init];
	NSPipe *inPipe;
	NSPipe *outPipe = [NSPipe pipe];
	NSPipe *errPipe = [NSPipe pipe];
	NSMutableData *mOutData = [NSMutableData data];
	NSMutableData *mErrData = [NSMutableData data];
	NSFileHandle *outHandle = [outPipe fileHandleForReading];
	NSFileHandle *errHandle = [errPipe fileHandleForReading];
	
	int exitcode;
	
	[cmdTask setLaunchPath:command];
	[cmdTask setArguments:arguments];
	[cmdTask setStandardOutput:outPipe];
	[cmdTask setStandardError:errPipe];
	
	if (inText) {
		inPipe = [NSPipe pipe];
		[[inPipe fileHandleForWriting] writeData:[inText dataUsingEncoding:NSUTF8StringEncoding]];
		[[inPipe fileHandleForWriting] closeFile];
		[cmdTask setStandardInput:inPipe];
	}
	
	[cmdTask launch];
	
	while ([cmdTask isRunning]) {
		[mOutData appendData:[outHandle readDataToEndOfFile]];
		[mErrData appendData:[errHandle readDataToEndOfFile]];
	}
	[mOutData appendData:[outHandle readDataToEndOfFile]];
	[mErrData appendData:[errHandle readDataToEndOfFile]];
	
	exitcode = [cmdTask terminationStatus];
	
	if (outData) {
		*outData = [mOutData retain];
	}
	if (errData) {
		*errData = [mErrData retain];
	}
	
	[cmdTask release];
	[pool drain];
	
	if (outData) {
		[*outData autorelease];
	}
	if (errData) {
		[*errData autorelease];
	}
	return exitcode;
}

int searchKeysOnServer(NSString *searchPattern, NSString **outText) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	GPGOptions *gpgOptions = [gpgContext options];
	
	NSRange aRange;
	NSArray *tempArray;
	NSFileManager *fileManager;
	
	NSData *outData;
	NSMutableString *cmdText;
	NSString *hostName, *hostProtocol, *hostPort = nil;
	NSString *helperName, *basePath, *helperPath;

	BOOL passHostArgument = YES;

	
	
	tempArray = [gpgOptions activeOptionValuesForName:@"keyserver"];
	if ([tempArray count] == 0) {
		[pool drain];
		return RunCmdNoKeyserverFound;
	}
	hostName = [tempArray objectAtIndex:0];
	
	
	aRange = [hostName rangeOfString:@"://"];
    if (aRange.length == 0){
        if ([hostName hasPrefix:@"finger:"]){
            aRange = [hostName rangeOfString:@":"];
            passHostArgument = NO;
        } else {
            hostName = [@"x-hkp://" stringByAppendingString:hostName];
            aRange = [hostName rangeOfString:@"://"];
        }
    }
	hostProtocol = [hostName substringToIndex:aRange.location];

	if ([hostProtocol isEqualToString:@"ldap"]) {
        helperName = @"gpg2keys_ldap";
    } else if ([hostProtocol isEqualToString:@"x-hkp"]) {
        helperName = @"gpg2keys_hkp";
    } else if ([hostProtocol isEqualToString:@"hkp"]) {
        helperName = @"gpg2keys_hkp";
    } else if ([hostProtocol isEqualToString:@"http"]) {
        helperName = @"gpg2keys_curl";
    } else if ([hostProtocol isEqualToString:@"https"]) {
        helperName = @"gpg2keys_curl";
    } else if ([hostProtocol isEqualToString:@"ftp"]) {
        helperName = @"gpg2keys_curl";
    } else if ([hostProtocol isEqualToString:@"ftps"]) {
        helperName = @"gpg2keys_curl";
    } else if ([hostProtocol isEqualToString:@"finger"]) {
        helperName = @"gpg2keys_finger";
    } else {
		[pool drain];
		return RunCmdIllegalProtocolType;
    }
    hostName = [hostName substringFromIndex:aRange.location + aRange.length];
	
	
	//Pfad zu gpg2keys_XXX ermitteln.
	basePath = [[GPG_PATH stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
	
	fileManager = [NSFileManager defaultManager];
	
	helperPath = [[basePath stringByAppendingPathComponent:@"libexec"] stringByAppendingPathComponent:helperName];
	if (![fileManager fileExistsAtPath:helperPath]) {
		helperPath = [[basePath stringByAppendingPathComponent:@"lib/gnupg"] stringByAppendingPathComponent:helperName];
		if (![fileManager fileExistsAtPath:helperPath]) {
			[pool drain];
			return RunCmdNoKeyserverHelperFound;
		}
	}
	
	
	
	aRange = [hostName rangeOfString:@":"];
    if (aRange.length != 0) {
        hostPort = [hostName substringFromIndex:aRange.location + 1];
        hostName = [hostName substringToIndex:aRange.location];
    }
	
    cmdText = [NSMutableString stringWithFormat:@"SCHEME %@\nOPAQUE %@\nCOMMAND search\n", hostProtocol, hostName];
    
    if (passHostArgument) {
        [cmdText appendFormat:@"HOST %@\n", hostName];
        if (hostPort) {
            [cmdText appendFormat:@"PORT %@\n", hostPort];
		}
    }
	
	if ([gpgOptions optionStateForName:@"keyserver-options"]) {
		tempArray = [[gpgOptions optionValueForName:@"keyserver-options"] componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@", "]];
		
		for (NSString *aOption in tempArray) {
			if (![aOption isEqualToString:@""]) {
				[cmdText appendFormat:@"OPTION %@\n", aOption];
			}
		}
	}
	
	[cmdText appendFormat:@"\n%@\n", searchPattern];

	
	int exitcode = runCommandWithArray(helperPath, cmdText, &outData, nil, [NSArray array]);

	*outText = [[NSString alloc] initWithData:outData encoding:NSASCIIStringEncoding];
	
	
	[pool drain];
	[*outText autorelease];
	return exitcode;
}


NSInteger getIndexForUserID(NSString *fingerprint, NSString *userID) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSInteger uid = 0;

	NSEnumerator *keyEnum = [gpgContext keyEnumeratorForSearchPattern:fingerprint secretKeysOnly:NO];
	GPGKey *gpgKey = [keyEnum nextObject];
	[gpgContext stopKeyEnumeration];
	
	NSArray *userIDs = [gpgKey userIDs];
	NSUInteger i, count = [userIDs count];
	for (i = 0; i < count; i++) {
		NSString *au = [[userIDs objectAtIndex:i] userID];
		if ([userID isEqualToString:au]) {
			uid = i + 1;
			break;
		}
	}	

	[pool drain];
	return uid;
}


NSInteger getIndexForSubkey(NSString *fingerprint, NSString *keyID) {
	NSString *outText;
	
	if (runGPGCommand(nil, &outText, nil, @"--edit-key", fingerprint, @"quit", nil) == 0) {
		NSRange aRange = [outText rangeOfString:[NSString stringWithFormat:@":%@:", keyID]];
		if (aRange.length != 0) {
			return [[[outText substringToIndex:aRange.location] componentsSeparatedByString:@"\nsub:"] count] - 1;
		}
	} else {
		NSLog(@"getIndexForSubkey: --edit-key für Schlüssel %@ fehlgeschlagen.", fingerprint);	
	}
	return 0;
}


/*NSString* unescape(NSString *string, NSString *escapeString) {
	NSInteger escapeLength = [escapeString length];
	NSInteger length = [string length];
	NSMutableString *unescapedString = [NSMutableString stringWithCapacity:length];
	char chars[3] = {'\0', '\0', '\0'};
	NSRange oldRange, newRange;
	oldRange.location = 0;
	oldRange.length = length;
	
	while ((newRange = [string rangeOfString:escapeString options:NSLiteralSearch range:oldRange]).length != 0) {
		oldRange.length = newRange.location - oldRange.location;
		[unescapedString appendString:[string substringWithRange:oldRange]];
		
		newRange.location += escapeLength;
		chars[0] = [string characterAtIndex:newRange.location];
		chars[1] = [string characterAtIndex:newRange.location + 1];
		[unescapedString appendFormat:@"%c", strtol(chars, NULL, 16)];
		
		oldRange.location = newRange.location + 2;
		oldRange.length = length - oldRange.location;
	}
	[unescapedString appendString:[string substringWithRange:oldRange]];
	
	return [[unescapedString copy] autorelease];
}*/


@end

