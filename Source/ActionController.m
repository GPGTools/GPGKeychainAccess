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

#import "ActionController.h"
#import "GKKey.h"
#import "KeychainController.h"
#import "SheetController.h"
#import "GPGOptions.h"
#import "GPGDefaults.h"


@implementation ActionController


//TODO: Fotos die auf mehrere Subpakete aufgeteilt sind.
//TODO: Fehlermeldungen wenn eine Aktion fehlschlägt.
//TODO: Geschätzte Sicherheit - Genauere Informationen.
//TODO: runGPGCommandWithArray - Pipes asynchron ansprechen.
//TODO: Algorithmus Preferänzen
//TODO: "…" zu manchen Französischen Menüeinträgen hinzufügen.


+ (NSString *)findExecutableWithName:(NSString *)executable {
	NSString *foundPath;
	NSArray *searchPaths = [NSMutableArray arrayWithObjects:@"/usr/local/bin", @"/usr/local/MacGPG2/bin", @"/usr/local/MacGPG1/bin", @"/usr/bin", @"/bin", @"/opt/local/bin", @"/sw/bin", nil];
	
	foundPath = [self findExecutableWithName:executable atPaths:searchPaths];
	if (foundPath) {
		return foundPath;
	}
	
	NSString *envPATH = [[[NSProcessInfo processInfo] environment] objectForKey:@"PATH"];
	if (envPATH) {
		NSArray *searchPaths = [envPATH componentsSeparatedByString:@":"];
		foundPath = [self findExecutableWithName:executable atPaths:searchPaths];
		if (foundPath) {
			return foundPath;
		}		
	}
	
	return nil;
}
+ (NSString *)findExecutableWithName:(NSString *)executable atPaths:(NSArray *)paths {
	NSString *searchPath, *foundPath;
	for (searchPath in paths) {
		foundPath = [searchPath stringByAppendingPathComponent:executable];
		if ([[NSFileManager defaultManager] isExecutableFileAtPath:foundPath]) {
			return [foundPath stringByStandardizingPath];
		}
	}
	return nil;
}


- (NSSet *)selectedKeyInfos {
	NSInteger clickedRow = [keyTable clickedRow];
	if (clickedRow != -1 && ![keyTable isRowSelected:clickedRow]) {
		return [NSSet setWithObject:[[keyTable itemAtRow:clickedRow] representedObject]];
	} else {
		return keyInfoSet([keysController selectedObjects]);
	}
}


- (BOOL)validateUserInterfaceItem:(id)anItem {
    SEL selector = [anItem action];
	
    if (selector == @selector(copy:)) {
		if ([[self selectedKeyInfos] count] >= 1) {
			return YES;
		}
		return NO;
    } else if (selector == @selector(paste:)) {
		NSPasteboard *pboard = [NSPasteboard generalPasteboard];
		if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]] != nil) {
			NSString *string = [pboard stringForType:NSStringPboardType];
			if (containsPGPKeyBlock(string)) {
				return YES;
			} else {
				return NO;
			}
		}
    } else if (selector == @selector(genRevokeCertificate:)) {
		NSSet *keyInfos = [self selectedKeyInfos];
		if ([keyInfos count] == 1 && ((GKKey*)[keyInfos anyObject]).secret) {
			return YES;
		}
		return NO;
    } else if (selector == @selector(editAlgorithmPreferences:)) {
		NSSet *keyInfos = [self selectedKeyInfos];
		if ([keyInfos count] == 1) {
			return YES;
		}
		return NO;
	}
	return YES;
}


- (IBAction)copy:(id)sender {
	NSSet *keyInfos = [self selectedKeyInfos];
	if ([keyInfos count] > 0) {
		NSString *exportedKeys = dataToString([self exportKeys:keyInfos armored:YES allowSecret:NO fullExport:NO]);
		if ([exportedKeys length] > 0) {
			NSPasteboard *pboard = [NSPasteboard generalPasteboard];
			[pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
			[pboard setString:exportedKeys forType:NSStringPboardType];
		}
	}
}
- (IBAction)paste:(id)sender {
	NSPasteboard *pboard = [NSPasteboard generalPasteboard];
	NSData *data = [pboard dataForType:NSStringPboardType];
	
	if (data) {
		[self importFromData:data];
	}
}



- (IBAction)editAlgorithmPreferences:(id)sender {
	NSSet *keyInfos = [self selectedKeyInfos];
	if ([keyInfos count] == 1) {
		GKKey *keyInfo = [keyInfos anyObject];
		SheetController *sheetController = [SheetController sharedInstance];
		[sheetController algorithmPreferences:keyInfo editable:[keyInfo secret]];
	}	
}
- (void)editAlgorithmPreferencesForKey:(GKKey *)keyInfo preferences:(NSArray *)userIDs {
	NSMutableString *cmdText = [NSMutableString stringWithCapacity:[userIDs count] * 100];
	NSString *fingerprint = [keyInfo fingerprint];
	BOOL doEdit = NO;
	
	for (NSDictionary *userID in userIDs) {
		NSInteger uid = getIndexForUserID(fingerprint, [userID objectForKey:@"userID"]);
		if (uid > 0) {
			[cmdText appendFormat:@"%i\nsetpref %@ %@ %@\ny\n0\n", uid, 
			 [[userID objectForKey:@"cipherPreferences"] componentsJoinedByString:@" "], 
			 [[userID objectForKey:@"digestPreferences"] componentsJoinedByString:@" "], 
			 [[userID objectForKey:@"compressPreferences"] componentsJoinedByString:@" "]];
			doEdit = YES;
		}
	}
	if (doEdit) {
		[self registerUndoForKey:keyInfo withName:@"Undo_AlgorithmPreferences"];
		
		[cmdText appendString:@"save\n"];
		runGPGCommand(cmdText, nil, nil, @"--edit-key", fingerprint, nil);
		
		[keychainController asyncUpdateKeyInfo:keyInfo];
	}
}



- (NSString *)importResultWithStatusData:(NSData *)data {
	NSMutableString *retString = [NSMutableString string];
	NSString *statusText = dataToString(data);
	NSScanner *scanner = [NSScanner scannerWithString:statusText];
	NSCharacterSet *hexCharSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"];
	NSUInteger length = [statusText length];
	
	NSInteger flags;
	NSString *fingerprint;
	NSString *userID;
	NSString *keyID;
	
	NSRange range = {0, length};
	
	
	while ((range = [statusText rangeOfString:@"[GNUPG:] IMPORT_OK " options:NSLiteralSearch range:range]).length > 0) {
		[scanner setScanLocation:range.location + 19];
		[scanner scanInteger:&flags];
		
		if (flags > 0) {
			[scanner scanCharactersFromSet:hexCharSet intoString:&fingerprint];
			userID = [[[keychainController keychain] objectForKey:fingerprint] userID];
			keyID = getShortKeyID(fingerprint);

			if (flags & 1) {
				if (flags & 16) {
					[retString appendFormat:localized(@"key %@: secret key imported\n"), keyID];
				} else {
					[retString appendFormat:localized(@"key %@: public key \"%@\" imported\n"), keyID, userID];
				}
			}
			if (flags & 2) {
				[retString appendFormat:localized(@"key %@: \"%@\" new user ID(s)\n"), keyID, userID];
			}
			if (flags & 4) {
				[retString appendFormat:localized(@"key %@: \"%@\" new signature(s)\n"), keyID, userID];
			}
			if (flags & 8) {
				[retString appendFormat:localized(@"key %@: \"%@\" new subkey(s)\n"), keyID, userID];
			}
		}
		
		range.location += range.length;
		range.length = length - range.location;
	}
		
	if ([retString length] == 0) {
		[retString setString:localized(@"Nothing imported!")];
	}
	
	return retString;
}



- (IBAction)cleanKey:(id)sender {
	NSSet *keyInfos = [self selectedKeyInfos];
	if ([keyInfos count] > 0) {
		[self registerUndoForKeys:keyInfos withName:@"Undo_Clean"];
		
		for (GKKey *keyInfo in keyInfos) {
			if (runGPGCommand(nil, nil, nil, @"--edit-key", [keyInfo fingerprint], @"clean", @"save", nil) != 0) {
				NSLog(@"cleanKey: --edit-key:clean für Schlüssel %@ fehlgeschlagen.", [keyInfo keyID]);
			}
		}
		[keychainController asyncUpdateKeyInfos:keyInfos];
	}
}
- (IBAction)minimizeKey:(id)sender {
	NSSet *keyInfos = [self selectedKeyInfos];
	if ([keyInfos count] > 0) {
		[self registerUndoForKeys:keyInfos withName:@"Undo_Minimize"];

		for (GKKey *keyInfo in keyInfos) {
			if (runGPGCommand(nil, nil, nil, @"--edit-key", [keyInfo fingerprint], @"minimize", @"save", nil) != 0) {
				NSLog(@"minimizeKey: --edit-key:minimize für Schlüssel %@ fehlgeschlagen.", [keyInfo keyID]);
			}
		}
		[keychainController asyncUpdateKeyInfos:keyInfos];
	}
}


- (IBAction)addPhoto:(NSButton *)sender {
	NSSet *keyInfos = [self selectedKeyInfos];
	if ([keyInfos count] == 1) {
		GKKey *keyInfo = [[keyInfos anyObject] primaryKeyInfo];
		SheetController *sheetController = [SheetController sharedInstance];
		
		[sheetController addPhoto:keyInfo];
	}
}
- (void)addPhotoForKeyInfo:(GKKey *)keyInfo photoPath:(NSString *)path {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[self registerUndoForKey:keyInfo withName:@"Undo_AddPhoto"];
	
	unsigned long long filesize = [[[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] objectForKey:NSFileSize] unsignedLongLongValue];
	
	NSString *cmdText = [NSString stringWithFormat:@"addphoto\n%@\n%@save\n", path, filesize > 6144 ? @"y\n" : @""];
	if (runGPGCommand(cmdText, nil, nil, @"--edit-key", [keyInfo fingerprint], nil) != 0) {
		NSLog(@"addPhotoForKeyInfo: --edit-key:adduid für Schlüssel %@ fehlgeschlagen.", [keyInfo keyID]);
	}
	[keychainController updateKeyInfos:[NSArray arrayWithObject:keyInfo]];
	
	[pool drain];
}

- (IBAction)removePhoto:(NSButton *)sender {
	if ([photosController selectionIndex] != NSNotFound) {
		NSSet *keyInfos = [self selectedKeyInfos];		
		GKKey *keyInfo = [[keyInfos anyObject] primaryKeyInfo];

		[self registerUndoForKey:keyInfo withName:@"Undo_RemovePhoto"];

		NSString *fingerprint = [keyInfo fingerprint];
		NSInteger uid = getIndexForUserID(fingerprint, [[[photosController selectedObjects] objectAtIndex:0] hashID]);
		if (uid > 0) {
			NSString *cmdText = [NSString stringWithFormat:@"%i\ndeluid\ny\nsave\n", uid];
			if (runGPGCommand(cmdText, nil, nil, @"--edit-key", fingerprint, nil) != 0) {
				NSLog(@"removePhoto: --edit-key:deluid für Schlüssel %@ fehlgeschlagen.", fingerprint);
			}
		}
		[keychainController asyncUpdateKeyInfos:keyInfos];
	}
}
- (IBAction)revokePhoto:(NSButton *)sender {
	if ([photosController selectionIndex] != NSNotFound) {
		NSSet *keyInfos = [self selectedKeyInfos];		
		GKKey *keyInfo = [[keyInfos anyObject] primaryKeyInfo];

		[self registerUndoForKey:keyInfo withName:@"Undo_RevokePhoto"];

		NSString *fingerprint = [keyInfo fingerprint];
		NSInteger uid = getIndexForUserID(fingerprint, [[[photosController selectedObjects] objectAtIndex:0] hashID]);
		if (uid > 0) {
			NSString *cmdText = [NSString stringWithFormat:@"%i\nrevuid\ny\n0\n\ny\nsave\n", uid];
			if (runGPGCommand(cmdText, nil, nil, @"--edit-key", fingerprint, nil) != 0) {
				NSLog(@"removePhoto: --edit-key:deluid für Schlüssel %@ fehlgeschlagen.", fingerprint);
			}
		}
		[keychainController asyncUpdateKeyInfos:keyInfos];
	}
}

- (IBAction)setPrimaryPhoto:(NSButton *)sender {
	if ([photosController selectionIndex] != NSNotFound) {
		NSSet *keyInfos = [self selectedKeyInfos];		
		GKKey *keyInfo = [[keyInfos anyObject] primaryKeyInfo];

		[self registerUndoForKey:keyInfo withName:@"Undo_PrimaryPhoto"];
		
		NSString *fingerprint = [keyInfo fingerprint];
		NSInteger uid = getIndexForUserID(fingerprint, [[[photosController selectedObjects] objectAtIndex:0] hashID]);
		if (uid > 0) {
			if (runGPGCommand(nil, nil, nil, @"--edit-key", fingerprint, [NSString stringWithFormat:@"%i", uid], @"primary", @"save", nil) != 0) {
				NSLog(@"setPrimaryPhoto: --edit-key:primary für Schlüssel %@ fehlgeschlagen.", fingerprint);
			}
		}
		[keychainController asyncUpdateKeyInfos:keyInfos];
	}
}



- (IBAction)importKey:(id)sender {
	SheetController *sheetController = [SheetController sharedInstance];
	[sheetController importKey];
}
- (void)importFromURLs:(NSArray *)urls {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSMutableData *dataToImport = [NSMutableData dataWithCapacity:100000];

	for (NSObject *url in urls) {
		if ([url isKindOfClass:[NSURL class]]) {
			[dataToImport appendData:[NSData dataWithContentsOfURL:(NSURL*)url]];
		} else if ([url isKindOfClass:[NSString class]]) {
			[dataToImport appendData:[NSData dataWithContentsOfFile:(NSString*)url]];
		}
	}
	[self importFromData:dataToImport];
	[pool drain];
}
- (void)importFromData:(NSData *)data {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSData *statusData;
	

	NSSet *keys = [self keysInExportedData:data];
	
	[self registerUndoForKeys:keys withName:@"Undo_Import"];
	
	if (runGPGCommandWithArray(data, nil, nil, &statusData, nil, [NSArray arrayWithObject:@"--import"]) != 0) {
		NSLog(@"importFromData: --import fehlgeschlagen."); //Tritt auch auf, wenn einer der zu importierenden Schlüssel bereits vorhanden ist. Muss also nichts besonderes bedeuten.
	}
	
	[keychainController updateKeyInfos:keys];
	
	SheetController *sheetController = [SheetController sharedInstance];
	[sheetController showResult:[self importResultWithStatusData:statusData]];
	
	[pool drain];
}


- (void)restoreKeys:(NSSet *)keys withData:(NSData *)data { //Löscht die übergebenen Schlüssel und importiert data.
	//TODO: Auswahl der Schlüsselliste wiederherstellen.
	[self registerUndoForKeys:keys withName:nil];
	[undoManager disableUndoRegistration];
	[self deleteKeys:keys withMode:GKDeletePublicAndSecretKey];
	
	if (data && [data length] > 0) {
		NSArray *arguments = [NSArray arrayWithObjects:@"--import", @"--import-options", @"import-local-sigs", @"--allow-non-selfsigned-uid", nil];
		if (runGPGCommandWithArray(data, nil, nil, nil, nil, arguments) != 0) {
			NSLog(@"restoreKeys: --import fehlgeschlagen."); //Tritt auch auf, wenn einer der zu importierenden Schlüssel bereits vorhanden ist. Muss also nichts besonderes bedeuten.
		}		
	}
	
	[keychainController updateKeyInfos:keys];
	[undoManager enableUndoRegistration];
}
- (void)registerUndoForKeys:(NSSet *)keys withName:(NSString *)actionName {
	if (useUndo && [undoManager isUndoRegistrationEnabled]) {
		[[undoManager prepareWithInvocationTarget:self] restoreKeys:keys withData:[self exportKeys:keys armored:NO allowSecret:YES fullExport:YES]];
		if (actionName && ![undoManager isUndoing] && ![undoManager isRedoing]) {
			[undoManager setActionName:localized(actionName)];
		}
	}
}
- (void)registerUndoForKey:(NSObject *)key withName:(NSString *)actionName { //key ist entweder GKKey oder NSString.
	[self registerUndoForKeys:[NSSet setWithObject:key] withName:actionName];
}


- (IBAction)exportKey:(id)sender {
	NSSet *keyInfos = [self selectedKeyInfos];
	SheetController *sheetController = [SheetController sharedInstance];
	
	[sheetController exportKeys:keyInfos];
}
- (NSData *)exportKeys:(NSSet *)keys armored:(BOOL)armored allowSecret:(BOOL)allowSec fullExport:(BOOL)fullExport {
	NSMutableArray *arguments = [NSMutableArray array];;
	NSData *exportedSecretData = nil, *exportedData = nil;
	GKKey *keyInfo;
	
	[arguments addObject:@"--export"];
	[arguments addObject:armored ? @"--armor" : @"--no-armor"];
	if (fullExport) {
		[arguments addObject:@"--export-options"];
		[arguments addObject:@"export-local-sigs,export-sensitive-revkeys"];
	}
	for (keyInfo in keys) {
		[arguments addObject:[keyInfo description]];
	}
	
	if (runGPGCommandWithArray(nil, &exportedData, nil, nil, nil, arguments) != 0) {
		NSLog(@"exportKeys: --export fehlgeschlagen.");
		return nil;
	}
	
	if (allowSec) {
		[arguments replaceObjectAtIndex:0 withObject:@"--export-secret-keys"];
		if (runGPGCommandWithArray(nil, &exportedSecretData, nil, nil, nil, arguments) != 0) {
			NSLog(@"exportKeys: --export-secret-keys fehlgeschlagen.");
			return nil;
		}
		exportedData = [NSMutableData dataWithData:exportedData];
		[(NSMutableData*)exportedData appendData:exportedSecretData];
	}
	
	return exportedData;
}

- (NSSet *)keysInExportedData:(NSData *)data {
	NSData *outData;
	
	
	if (runGPGCommandWithArray(data, &outData, nil, nil, nil, [NSArray arrayWithObject:@"--with-fingerprint"]) != 0) {
		NSLog(@"keysInExportedData fehlgeschlagen.");
	}
	NSArray *lines = [dataToString(outData) componentsSeparatedByString:@"\n"];
	NSMutableSet *keys = [NSMutableSet setWithCapacity:[lines count] / 3];
	
	for (NSString *line in lines) {
		NSArray *splitedLine = [line componentsSeparatedByString:@":"];
		if ([[splitedLine objectAtIndex:0] isEqualToString:@"fpr"]) {
			[keys addObject:[splitedLine objectAtIndex:9]];
		}
	}
	return keys;
}


- (IBAction)genRevokeCertificate:(id)sender {
	NSSet *keyInfos = [self selectedKeyInfos];
	if ([keyInfos count] == 1) {
		SheetController *sheetController = [SheetController sharedInstance];
		[sheetController genRevokeCertificateForKey:[keyInfos anyObject]];
	}
}
- (NSData *)genRevokeCertificateForKey:(GKKey *)keyInfo {
	NSData *exportedData = nil;
	NSArray *arguments = [NSArray arrayWithObjects:@"--armor",@"--no-batch", @"--gen-revoke", [keyInfo description], nil];
	
	if (runGPGCommandWithArray(stringToData(@"y\n0\n\ny\n"), &exportedData, nil, nil, nil, arguments) != 0) {
		NSLog(@"genRevokeCertificateForKey: --gen-revoke fehlgeschlagen.");
		return nil;
	}
	
	return exportedData;
}



- (IBAction)addSignature:(id)sender {
	if ([sender tag] != 1 || [userIDsController selectionIndex] != NSNotFound) {
		NSSet *keyInfos = [self selectedKeyInfos];		
		GKKey *keyInfo = [[keyInfos anyObject] primaryKeyInfo];
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
- (void)addSignatureForKeyInfo:(GKKey *)keyInfo andUserID:(NSString *)userID signKey:(NSString *)signFingerprint type:(NSInteger)type local:(BOOL)local daysToExpire:(NSInteger)daysToExpire {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[self registerUndoForKey:keyInfo withName:@"Undo_AddSignature"];

	NSString *fingerprint = [keyInfo fingerprint];
	
	NSString *sigType = local ? @"lsign" : @"sign";
	NSString *uid;
	if (!userID) {
		uid = @"uid *";
	} else {
		int uidIndex = getIndexForUserID(fingerprint, userID);
		if (uidIndex > 0) {
			uid = [NSString stringWithFormat:@"%i", uidIndex];
		} else {
			//UserID konnte nicht gefunden werden. Der Schlüssel wird aktualisiert, um wieder aktuell zu sein.
			[keychainController updateKeyInfos:[NSArray arrayWithObject:keyInfo]];
			[pool drain];
			return;
		}
	}
	
	NSString *cmdText = [NSString stringWithFormat:@"%@\n%@\n%i\ny\nsave\n", uid, sigType, daysToExpire];
	NSArray *arguments = [NSArray arrayWithObjects:@"-u", signFingerprint, @"--no-ask-cert-level", @"--default-cert-level", [NSString stringWithFormat:@"%i", type], @"--ask-cert-expire", @"--edit-key", fingerprint, nil];
	
	if (runGPGCommandWithArray(stringToData(cmdText), nil, nil, nil, nil, arguments) != 0) {
		NSLog(@"addSignature: --edit-key:%@ für Schlüssel %@ fehlgeschlagen.", sigType, fingerprint);
	}
	[keychainController updateKeyInfos:[NSArray arrayWithObject:keyInfo]];

	[pool drain];
}

- (IBAction)addSubkey:(NSButton *)sender {
	NSSet *keyInfos = [self selectedKeyInfos];		
	if ([keyInfos count] == 1) {
		GKKey *keyInfo = [[keyInfos anyObject] primaryKeyInfo];
		SheetController *sheetController = [SheetController sharedInstance];
		
		[sheetController addSubkey:keyInfo];
	}
}
- (void)addSubkeyForKeyInfo:(GKKey *)keyInfo type:(NSInteger)type length:(NSInteger)length daysToExpire:(NSInteger)daysToExpire {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[self registerUndoForKey:keyInfo withName:@"Undo_AddSubkey"];

	NSString *cmdText = [NSString stringWithFormat:@"addkey\n%i\n%i\n%i\nsave\n", type, length, daysToExpire];
	if (runGPGCommand(cmdText, nil, nil, @"--edit-key", [keyInfo fingerprint], nil) != 0) {
		NSLog(@"generateSubkey: --edit-key:addkey für Schlüssel %@ fehlgeschlagen.", [keyInfo keyID]);
	}
	[keychainController updateKeyInfos:[NSArray arrayWithObject:keyInfo]];
	
	[pool drain];
}

- (IBAction)addUserID:(NSButton *)sender {
	NSSet *keyInfos = [self selectedKeyInfos];		
	if ([keyInfos count] == 1) {
		GKKey *keyInfo = [[keyInfos anyObject] primaryKeyInfo];
		SheetController *sheetController = [SheetController sharedInstance];
		
		[sheetController addUserID:keyInfo];
	}
}
- (void)addUserIDForKeyInfo:(GKKey *)keyInfo name:(NSString *)name email:(NSString *)email comment:(NSString *)comment{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[self registerUndoForKey:keyInfo withName:@"Undo_AddUserID"];

	NSString *cmdText = [NSString stringWithFormat:@"adduid\n%@\n%@\n%@\nsave\n", name, email, comment];
	if (runGPGCommand(cmdText, nil, nil, @"--edit-key", [keyInfo fingerprint], nil) != 0) {
		NSLog(@"addUserIDForKeyInfo: --edit-key:adduid für Schlüssel %@ fehlgeschlagen.", [keyInfo keyID]);
	}
	[keychainController updateKeyInfos:[NSArray arrayWithObject:keyInfo]];

	[pool drain];
}

- (IBAction)changeExpirationDate:(NSButton *)sender {
	BOOL aKeyIsSelected = NO;
	GKSubkey *subkey;
	
	NSSet *keyInfos = [self selectedKeyInfos];			
	if ([sender tag] == 1 && [[subkeysController selectedObjects] count] == 1) {
		subkey = [[subkeysController selectedObjects] objectAtIndex:0];
		aKeyIsSelected = YES;
	} else if ([sender tag] == 0 && [keyInfos count] == 1) {
		subkey = nil;
		aKeyIsSelected = YES;
	}
	
	if (aKeyIsSelected) {
		GKKey *keyInfo = [[keyInfos anyObject] primaryKeyInfo];
		SheetController *sheetController = [SheetController sharedInstance];
		
		[sheetController changeExpirationDate:keyInfo subkey:subkey];
	}
	
}
- (void)changeExpirationDateForKeyInfo:(GKKey *)keyInfo subkey:(GKSubkey *)subkey daysToExpire:(NSInteger)daysToExpire {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[self registerUndoForKey:keyInfo withName:@"Undo_ChangeExpirationDate"];
	
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
		NSLog(@"changeExpirationDateForKeyInfo: --edit-key:expire für Schlüssel %@ fehlgeschlagen.", [keyInfo keyID]);
	}
	[keychainController updateKeyInfos:[NSArray arrayWithObject:keyInfo]];
	
	[pool drain];
}

- (IBAction)searchKeys:(id)sender {
	SheetController *sheetController = [SheetController sharedInstance];
	[sheetController searchKeys];
}
- (NSMutableArray *)searchKeysWithPattern:(NSString *)pattern errorText:(NSString **)errText {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSString *outText;
	NSArray *returnArray = nil;
	*errText = nil;
	
	switch (searchKeysOnServer(pattern, &outText)) {
		case 0: {
			KeyAlgorithmTransformer *algorithmTransformer = [[[KeyAlgorithmTransformer alloc] init] autorelease];
			NSArray *lines = [outText componentsSeparatedByString:@"\n"];
			NSArray *splitedLine;
			NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
			[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
			[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
			
			NSUInteger i, count = [lines count];
	
			
			NSMutableArray *foundKeys = [NSMutableArray arrayWithCapacity:count / 2];
			NSMutableDictionary *foundKey = nil;
			NSMutableAttributedString *keyDescription = nil;
			NSString *tempDescription;
			NSInteger countTextLines;
			NSDictionary *attrsDictionary;
			
			
			for (i = 0; i < count; i++) {
				splitedLine = [[lines objectAtIndex:i] componentsSeparatedByString:@":"];
				NSString *lineType = [splitedLine objectAtIndex:0];
				if ([lineType isEqualToString:@"pub"]) {
					if (foundKey) {
						[foundKey setObject:[NSNumber numberWithInteger:countTextLines] forKey:@"lines"];
					}
					countTextLines = 1;
					
					NSNumber *checkState;
					NSString *keyState = [splitedLine objectAtIndex:6];
					//TODO: Expired keys.
					if (keyState && [keyState length] > 0) {
						checkState = [NSNumber numberWithBool:NO];
						attrsDictionary = [NSDictionary dictionaryWithObject:[NSColor redColor] forKey:NSForegroundColorAttributeName];
					} else {
						checkState = [NSNumber numberWithBool:YES];
						attrsDictionary = nil;
					}
					
					
					NSDate *created = [NSDate dateWithTimeIntervalSince1970:[[splitedLine objectAtIndex:4] integerValue]];
					
					NSString *keyID = [splitedLine objectAtIndex:1];
					
					
					tempDescription = [NSString stringWithFormat:localized(@"%@, %@ (%@ bit), created: %@"), 
									  keyID, //Schlüssel ID
									  [algorithmTransformer transformedValue:[splitedLine objectAtIndex:2]], //Algorithmus
									  [splitedLine objectAtIndex:3], //Länge
									  [dateFormatter stringFromDate:created]]; //Erstellt
					tempDescription = [tempDescription stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
					
					
					keyDescription = [[[NSMutableAttributedString alloc] initWithString:tempDescription attributes:attrsDictionary] autorelease];

					
					foundKey = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								keyDescription, @"description",
								checkState, @"selected",
								keyID, @"keyID", nil];
					[foundKeys addObject:foundKey];
					
				} else if (foundKey && [lineType isEqualToString:@"uid"]) {
					tempDescription = [NSString stringWithFormat:@"\n	%@", [[splitedLine objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
					[keyDescription appendAttributedString:[[[NSAttributedString alloc] initWithString:tempDescription] autorelease]];
					countTextLines++;
				}
			}
			if (foundKey) {
				[foundKey setObject:[NSNumber numberWithInteger:countTextLines] forKey:@"lines"];
				returnArray = foundKeys;
			} else {
				*errText = localized(@"No keys Found!");
			}			
			break; }
		case RunCmdNoKeyserverFound:
			NSRunAlertPanel(localized(@"Error"), localized(@"No keyserver found!"), nil, nil, nil);
			*errText = [NSString stringWithFormat:@"%@\n\n%@", localized(@"Error!"), localized(@"No keyserver found!")];
			break;
		case RunCmdIllegalProtocolType:
			NSRunAlertPanel(localized(@"Error"), localized(@"Illegal protocol!"), nil, nil, nil);
			*errText = [NSString stringWithFormat:@"%@\n\n%@", localized(@"Error!"), localized(@"Illegal protocol!")];
			break;
		case RunCmdNoKeyserverHelperFound:
			NSRunAlertPanel(localized(@"Error"), localized(@"No keyserver-helper found!"), nil, nil, nil);
			*errText = [NSString stringWithFormat:@"%@\n\n%@", localized(@"Error!"), localized(@"No keyserver-helper found!")];
			break;
		default:
			NSLog(@"searchKeysOnServer für pattern: \"%@\" fehlgeschlagen!", pattern);
			*errText = localized(@"Error!");
			break;
	}
	
	
	[returnArray retain];
	[*errText retain];
	
	[pool drain];
	
	[*errText autorelease];
	return [returnArray autorelease];
}




- (IBAction)receiveKeys:(id)sender {
	SheetController *sheetController = [SheetController sharedInstance];
	[sheetController receiveKeys];
}
- (NSString *)receiveKeysWithIDs:(NSSet *)keyIDs {
	
	BOOL undoNameNeeded = NO;
	if (useUndo && [undoManager isUndoRegistrationEnabled]) {
		NSSet *fingerprints = [keychainController fingerprintsForKeyIDs:keyIDs];
		if ([fingerprints count] > 0) {
			[undoManager beginUndoGrouping];
			[self registerUndoForKeys:fingerprints withName:@"Undo_Receive"];
			undoNameNeeded = YES;
		}
	}
	
	NSMutableArray *arguments = [NSMutableArray arrayWithObject:@"--recv-keys"];
	
	NSString *keyserver = [[GPGDefaults gpgDefaults] stringForKey:@"Keyserver"];
	if (keyserver) {
		[arguments addObject:@"--keyserver"];
		[arguments addObject:keyserver];
	}
	
	[arguments addObjectsFromArray:[keyIDs allObjects]];
	
	NSData *statusData;
	
	if (runGPGCommandWithArray(nil, nil, nil, &statusData, nil, arguments) != 0) {
		NSLog(@"receiveKeysWithIDs: --recv-keys für \"%@\" fehlgeschlagen.", keyIDs);
	}
	[keychainController updateKeyInfos:nil];
	
	if (useUndo && [undoManager isUndoRegistrationEnabled]) {
		NSSet *fingerprints = [keychainController fingerprintsForKeyIDs:keyIDs];
		if ([fingerprints count] > 0) {
			if (!undoNameNeeded) {
				[undoManager beginUndoGrouping];
				undoNameNeeded = YES;
			}
			[[undoManager prepareWithInvocationTarget:self] restoreKeys:fingerprints withData:nil];
		}
		if (undoNameNeeded) {
			[undoManager endUndoGrouping];
			[undoManager setActionName:localized(@"Undo_Receive")];
		}
	}
	
	
	return [self importResultWithStatusData:statusData];
}

- (IBAction)sendKeysToServer:(id)sender {
	NSSet *keyInfos = [self selectedKeyInfos];
	if ([keyInfos count] > 0) {
		NSMutableArray *arguments = [NSMutableArray arrayWithObject:@"--send-key"];
		NSString *keyserver = [[GPGDefaults gpgDefaults] stringForKey:@"Keyserver"];
		if (keyserver) {
			[arguments addObject:@"--keyserver"];
			[arguments addObject:keyserver];
		}
		for (GKKey *keyInfo in keyInfos) {
			[arguments addObject:[keyInfo fingerprint]];
		}
		if (runGPGCommandWithArray(nil, nil, nil, nil, nil, arguments) != 0) {
			NSLog(@"sendKeysToServer: --send-key fehlgeschlagen.");
		}
	}
}

- (IBAction)refreshKeysFromServer:(id)sender {
	NSSet *keyInfos = [self selectedKeyInfos];
	
	[self registerUndoForKeys:keyInfos withName:@"Undo_Refresh"];
	
	NSMutableArray *arguments = [NSMutableArray arrayWithObject:@"--refresh-keys"];
	
	NSString *keyserver = [[GPGDefaults gpgDefaults] stringForKey:@"Keyserver"];
	if (keyserver) {
		[arguments addObject:@"--keyserver"];
		[arguments addObject:keyserver];
	}
	
	for (GKKey *keyInfo in keyInfos) {
		[arguments addObject:[keyInfo fingerprint]];
	}
	if (runGPGCommandWithArray(nil, nil, nil, nil, nil, arguments) != 0) {
		NSLog(@"refreshKeysFromServer: --refresh-keys fehlgeschlagen.");
	}
	[keychainController asyncUpdateKeyInfos:keyInfos];
}

- (IBAction)changePassphrase:(NSButton *)sender {
	NSSet *keyInfos = [self selectedKeyInfos];	
	if ([keyInfos count] == 1) {
		GKKey *keyInfo = [[keyInfos anyObject] primaryKeyInfo];
		
		[self registerUndoForKey:keyInfo withName:@"Undo_ChangePassphrase"];
		
		if (runGPGCommand(@"passwd\ny\nsave\n", nil, nil, @"--edit-key", [keyInfo fingerprint], nil) != 0) {
			NSLog(@"changePassphrase: --edit-key:passwd für Schlüssel %@ fehlgeschlagen.", [keyInfo keyID]);
		}
		[keychainController asyncUpdateKeyInfos:keyInfos];
	}
}

- (IBAction)removeSignature:(NSButton *)sender { //Diese Funktion ist äusserst ineffizient, mir ist allerdings kein besserer Weg bekannt.
	if ([signaturesController selectionIndex] != NSNotFound) {
		GKKeySignature *gpgKeySignature = [[signaturesController selectedObjects] objectAtIndex:0];
		GKUserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
		NSArray *signatures = [userID signatures];
		NSSet *keyInfos = [self selectedKeyInfos];		
		GKKey *keyInfo = [[keyInfos anyObject] primaryKeyInfo];

		[self registerUndoForKey:keyInfo withName:@"Undo_RemoveSignature"];

		NSString *fingerprint = [keyInfo fingerprint];
		NSInteger uid = getIndexForUserID(fingerprint, [userID userID]);
		if (uid > 0) {
			NSMutableString *cmdText = [NSMutableString stringWithCapacity:4];
			
			for (GKKeySignature *aSignature in signatures) {
				if (aSignature == gpgKeySignature) {
					[cmdText appendString:@"y\n"];
					if ([[gpgKeySignature keyID] isEqualToString:[keyInfo keyID]]) {
						[cmdText appendString:@"y\n"];
					}
				} else {
					[cmdText appendString:@"n\n"];
				}
			}
			
			if (runGPGCommand(cmdText, nil, nil, @"--edit-key", fingerprint, [NSString stringWithFormat:@"%i", uid], @"delsig", @"save", nil) != 0) {
				NSLog(@"removeSignature: --edit-key:delsig für Schlüssel %@ fehlgeschlagen.", fingerprint);
			}
		}
		[keychainController asyncUpdateKeyInfos:keyInfos];
	}
}

- (IBAction)removeSubkey:(NSButton *)sender {
	if ([[subkeysController selectedObjects] count] == 1) {
		GKSubkey *subkey = [[subkeysController selectedObjects] objectAtIndex:0];
		GKKey *keyInfo = [subkey primaryKeyInfo];
		
		[self registerUndoForKey:keyInfo withName:@"Undo_RemoveSubkey"];

		NSInteger index = getIndexForSubkey([subkey fingerprint], [subkey keyID]);
		if (index > 0) {
			NSString *cmdText = [NSString stringWithFormat:@"key %i\ndelkey\ny\nsave\n", index];
			if (runGPGCommand(cmdText, nil, nil, @"--edit-key", [subkey fingerprint], nil) != 0) {
				NSLog(@"removeSubkey: --edit-key:delkey für Schlüssel %@ fehlgeschlagen.", [subkey keyID]);
			}
			[keychainController asyncUpdateKeyInfo:keyInfo];
		}
	}
}

- (IBAction)removeUserID:(NSButton *)sender {
	if ([userIDsController selectionIndex] != NSNotFound) {
		GKUserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
		GKKey *keyInfo = [userID primaryKeyInfo];

		[self registerUndoForKey:keyInfo withName:@"Undo_RemoveUserID"];
		
		NSString *fingerprint = [keyInfo fingerprint];
		NSInteger uid = getIndexForUserID(fingerprint, [[[userIDsController selectedObjects] objectAtIndex:0] userID]);
		if (uid > 0) {
			NSString *cmdText = [NSString stringWithFormat:@"%i\ndeluid\ny\nsave\n", uid];
			if (runGPGCommand(cmdText, nil, nil, @"--edit-key", fingerprint, nil) != 0) {
				NSLog(@"removeUserID: --edit-key:deluid für Schlüssel %@ fehlgeschlagen.", fingerprint);
			}
		}
		[keychainController asyncUpdateKeyInfo:keyInfo];
	}
}

- (IBAction)revokeSignature:(NSButton *)sender { //Diese Funktion ist äusserst ineffizient, mir ist allerdings kein besserer Weg bekannt.
	if ([signaturesController selectionIndex] != NSNotFound) {
		GKKeySignature *gpgKeySignature = [[signaturesController selectedObjects] objectAtIndex:0];
		GKUserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
		GKKey *keyInfo = [userID primaryKeyInfo];
		NSArray *signatures = [userID signatures];
		NSString *fingerprint = [keyInfo fingerprint];
		NSInteger uid = getIndexForUserID(fingerprint, [userID userID]);
		if (uid > 0) {
			[self registerUndoForKey:fingerprint withName:@"Undo_RevokeSignature"];
			
			NSMutableString *cmdText = [NSMutableString stringWithCapacity:9];
			NSMutableArray *secKeyIDs = [NSMutableArray arrayWithCapacity:1];
			NSString *signerKeyID1 = [gpgKeySignature keyID];
			NSString *signerKeyID2;
			
			NSDictionary *keychain = [keychainController keychain];
			NSSet *secKeyInfos = [keychainController secretKeys];
			for (NSString *fingerprint in secKeyInfos) {
				[secKeyIDs addObject:[[keychain objectForKey:fingerprint] keyID]];
			}
			
			for (GKKeySignature *aSignature in signatures) {
				if (![aSignature revocationSignature]) {
					signerKeyID2 = [aSignature keyID];
					if ([secKeyIDs containsObject:signerKeyID2]) {
						if ([signerKeyID1 isEqualToString:signerKeyID2]) {
							[cmdText appendString:@"y\n"]; //Gesuchte Beglaubigung
						} else {
							[cmdText appendString:@"n\n"]; //Andere Beglaubigung
						}
					}
				}
			}
			if ([cmdText length] > 0) {
				[cmdText appendString:@"y\n0\n\ny\n"];
				if (runGPGCommand(cmdText, nil, nil, @"--edit-key", fingerprint, [NSString stringWithFormat:@"%i", uid], @"revsig", @"save", nil) != 0) {
					NSLog(@"revokeSignature: --edit-key:revsig für Schlüssel %@ fehlgeschlagen.", fingerprint);
				}
				[keychainController asyncUpdateKeyInfo:keyInfo];
			}
		}
	}
}

- (IBAction)revokeSubkey:(NSButton *)sender {
	if ([[subkeysController selectedObjects] count] == 1) {
		GKSubkey *subkey = [[subkeysController selectedObjects] objectAtIndex:0];
		GKKey *keyInfo = [subkey primaryKeyInfo];
		NSString *fingerprint = [keyInfo fingerprint];
		NSInteger index = getIndexForSubkey(fingerprint, [subkey keyID]);
		if (index > 0) {
			[self registerUndoForKey:keyInfo withName:@"Undo_RevokeSubkey"];

			NSString *cmdText = [NSString stringWithFormat:@"key %i\nrevkey\ny\n0\n\ny\nsave\n", index];
			if (runGPGCommand(cmdText, nil, nil, @"--edit-key", fingerprint, nil) != 0) {
				NSLog(@"revokeSubkey: --edit-key:revkey für Schlüssel %@ fehlgeschlagen.", fingerprint);
			}
			[keychainController asyncUpdateKeyInfo:keyInfo];
		}
	}
	
}

- (IBAction)revokeUserID:(NSButton *)sender {
	if ([userIDsController selectionIndex] != NSNotFound) {
		GKUserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
		GKKey *keyInfo = [userID primaryKeyInfo];
		NSString *fingerprint = [keyInfo fingerprint];
		NSInteger uid = getIndexForUserID(fingerprint, [userID userID]);
		
		if (uid > 0) {
			[self registerUndoForKey:keyInfo withName:@"Undo_RevokeUserID"];

			NSString *cmdText = [NSString stringWithFormat:@"%i\nrevuid\ny\n0\n\ny\nsave\n", uid];
			if (runGPGCommand(cmdText, nil, nil, @"--edit-key", fingerprint, nil) != 0) {
				NSLog(@"revokeUserID: --edit-key:revuid für Schlüssel %@ fehlgeschlagen.", fingerprint);
			}
		}
		[keychainController asyncUpdateKeyInfo:keyInfo];
	}
}

- (IBAction)setDisabled:(NSButton *)sender {
	NSSet *keyInfos = [self selectedKeyInfos];
	if ([keyInfos count] > 0) {
		[self setDisabled:[sender state] == NSOnState forKeyInfos:keyInfos];
	}
}
- (void)setDisabled:(BOOL)disabled forKeyInfos:(NSSet *)keys {
	if (useUndo && [undoManager isUndoRegistrationEnabled]) {
		NSMutableSet *editedKeys = [NSMutableSet setWithCapacity:[keys count]];
		for (GKKey *keyInfo in keys) {
			if (keyInfo.disabled != disabled) {
				[editedKeys addObject:keyInfo];
			}
		}
		if ([editedKeys count] > 0) {
			[[undoManager prepareWithInvocationTarget:self] setDisabled:!disabled forKeyInfos:editedKeys];
			if (![undoManager isUndoing] && ![undoManager isRedoing]) {
				[undoManager setActionName:localized(disabled ? @"Undo_DisableKey" : @"Undo_EnableKey")];
			}
		}
	}

	NSString *enOrDisable = disabled ? @"disable" : @"enable";
	for (GKKey *keyInfo in keys) {
		if (runGPGCommand(nil, nil, nil, @"--edit-key", [keyInfo fingerprint], enOrDisable, nil) != 0) {
			NSLog(@"setDisabled: --edit-key:%@ für Schlüssel %@ fehlgeschlagen.", enOrDisable, [keyInfo keyID]);
		}
	}
	[keychainController updateKeyInfos:keys];	
}

- (IBAction)setPrimaryUserID:(NSButton *)sender {
	if ([userIDsController selectionIndex] != NSNotFound) {
		GKUserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
		GKKey *keyInfo = [userID primaryKeyInfo];
		NSString *fingerprint = [keyInfo fingerprint];
		NSInteger uid = getIndexForUserID(fingerprint, [userID userID]);
		if (uid > 0) {
			[self registerUndoForKey:keyInfo withName:@"Undo_PrimaryUserID"];

			if (runGPGCommand(nil, nil, nil, @"--edit-key", fingerprint, [NSString stringWithFormat:@"%i", uid], @"primary", @"save", nil) != 0) {
				NSLog(@"setPrimaryUserID: --edit-key:primary für Schlüssel %@ fehlgeschlagen.", fingerprint);
			}
		}
		[keychainController asyncUpdateKeyInfo:keyInfo];
	}
}

- (IBAction)setTrsut:(NSPopUpButton *)sender {
	NSSet *keyInfos = [self selectedKeyInfos];
	if ([keyInfos count] > 0) {
		[self registerUndoForKeys:keyInfos withName:@"Undo_SetTrust"];
		
		NSString *cmdText = [NSString stringWithFormat:@"trust\n%i\ny\n", [sender selectedTag]];
		for (GKKey *keyInfo in keyInfos) {
			if (runGPGCommand(cmdText, nil, nil, @"--edit-key", [keyInfo fingerprint], nil) != 0) {
				NSLog(@"setTrsut: --edit-key:trust für Schlüssel %@ fehlgeschlagen.", [keyInfo keyID]);
			}
		}
		[keychainController asyncUpdateKeyInfos:keyInfos];
	}
}

- (IBAction)generateNewKey:(id)sender {
	SheetController *sheetController = [SheetController sharedInstance];
	[sheetController generateNewKey];
}
- (void)generateNewKeyWithName:(NSString *)name email:(NSString *)email comment:(NSString *)comment passphrase:(NSString *)passphrase type:(NSInteger)type length:(NSInteger)length daysToExpire:(NSInteger)daysToExpire {
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
	
	if (passphrase) {
		if (![passphrase isEqualToString:@""]) {
			[cmdText appendFormat:@"Passphrase: %@\n", passphrase];
		}
	} else {
		[cmdText appendString:@"%ask-passphrase\n"];
	}
	
	[cmdText appendString:@"%commit\n"];
	
	
	NSData *statusData;
	if (runGPGCommandWithArray(stringToData(cmdText), nil, nil, &statusData, nil, [NSArray arrayWithObject:@"--gen-key"]) != 0) {
		NSLog(@"generateNewKeyWithName: --gen-key fehlgeschlagen.");
	}
	
	
	if (useUndo) {
		NSString *statusText = dataToString(statusData);
		NSRange range = [statusText rangeOfString:@"[GNUPG:] KEY_CREATED "];
		if (range.length > 0) {
			range = [statusText lineRangeForRange:range];
			range.length--;
			NSString *fingerprint = [[[statusText substringWithRange:range] componentsSeparatedByString:@" "] objectAtIndex:3];
			[[undoManager prepareWithInvocationTarget:self] deleteKeys:[NSSet setWithObject:fingerprint] withMode:GKDeletePublicAndSecretKey];
			[undoManager setActionName:localized(@"Undo_NewKey")];
		}
	}
	
	
	[keychainController updateKeyInfos:nil];
	[pool drain];
}

- (IBAction)refreshDisplayedKeys:(id)sender {
	[keychainController asyncUpdateKeyInfos:nil];
}

- (IBAction)deleteKey:(id)sender { 	
	//TODO: Bessere Dialoge mit der auswahl "Für alle".
	NSSet *keyInfos = [self selectedKeyInfos];
	if ([keyInfos count] > 0) {
		NSInteger retVal;
		SheetController *sheetController = [SheetController sharedInstance];
		
		if (useUndo) {
			[undoManager beginUndoGrouping];
		}
		
		for (GKKey *keyInfo in keyInfos) {
			
			if (keyInfo.secret) {
				retVal = [sheetController alertSheetForWindow:mainWindow 
												  messageText:localized(@"DeleteSecretKey_Title") 
													 infoText:[NSString stringWithFormat:localized(@"DeleteSecretKey_Msg"), [keyInfo userID], [keyInfo shortKeyID]] 
												defaultButton:localized(@"Delete secret key only") 
											  alternateButton:localized(@"Cancel") 
												  otherButton:localized(@"Delete both")];
				switch (retVal) {
					case NSAlertFirstButtonReturn:
						[self deleteKeys:[NSSet setWithObject:keyInfo] withMode:GKDeleteSecretKey];
						break;
					case NSAlertThirdButtonReturn:
						[self deleteKeys:[NSSet setWithObject:keyInfo] withMode:GKDeletePublicAndSecretKey];
						break;
				}
			} else {
				retVal = [sheetController alertSheetForWindow:mainWindow 
												  messageText:localized(@"DeleteKey_Title") 
													 infoText:[NSString stringWithFormat:localized(@"DeleteKey_Msg"), [keyInfo userID], [keyInfo shortKeyID]] 
												defaultButton:localized(@"Delete key") 
											  alternateButton:localized(@"Cancel") 
												  otherButton:nil];
				if (retVal == NSAlertFirstButtonReturn) {
					[self deleteKeys:[NSSet setWithObject:keyInfo] withMode:GKDeletePublicKey];
				}
			}
		}
		
		if (useUndo) {
			[undoManager endUndoGrouping];
			[undoManager setActionName:localized(@"Undo_Delete")];
		}
	}
}

- (void)deleteKeys:(NSSet *)keys withMode:(GKDeleteKeyAction)mode {
	if ([keys count] == 0) {
		return;
	}
	[self registerUndoForKeys:keys withName:@"Undo_Delete"];
	
	NSMutableArray *arguments = [NSMutableArray array];
	switch (mode) {
		case GKDeleteSecretKey:
			[arguments addObject:@"--delete-secret-keys"];
			break;
		case GKDeletePublicAndSecretKey:
			[arguments addObject:@"--delete-secret-and-public-key"];
			break;
		default:
			[arguments addObject:@"--delete-keys"];
			break;
	}
	
	for (GKKey *keyInfo in keys) {
		[arguments addObject:[keyInfo description]];
	}
	
	if (runGPGCommandWithArray(nil, nil, nil, nil, nil, arguments) != 0) {
		NSLog(@"deleteTheKey: %@ fehlgeschlagen.", arguments);
	}
	if ([undoManager isUndoRegistrationEnabled]) {
		[keychainController asyncUpdateKeyInfos:keys];
	}
}


- (IBAction)showInspector:(id)sender {
	[inspectorWindow makeKeyAndOrderFront:sender];
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
int runGPGCommandWithArray(NSData *inData, NSData **outData, NSData **errData, NSData **statusData, NSData **attributeData, NSArray *args) {
	int pipes[5][2];
	int i;
	NSData **datas[4];
	
	datas[0] = outData;
	datas[1] = errData;
	datas[2] = statusData;
	datas[3] = attributeData;
	
	for (i = 0; i < 4; i++) {
		if (datas[i]) {
			pipe(pipes[i]);
		}
	}
	if (inData) {
		pipe(pipes[4]);
	}
	

	pid_t pid = fork();
	
	if (pid == 0) { //Kindprozess
		int numArgs, argPos = 1;
		if (GPG_VERSION == 2) {
			numArgs = 7 + [args count];
		} else {
			numArgs = 9 + [args count]; //GPG 1.4 braucht mehr Parameter.
		}
		
		int nullDescriptor = open("/dev/null", O_WRONLY);
		
		if (outData) {
			close(pipes[0][0]);
		} else {
			pipes[0][1] = nullDescriptor;
		}
		if (errData) {
			close(pipes[1][0]);
		} else {
			pipes[1][1] = nullDescriptor;
		}
		dup2(pipes[0][1], 1);
		dup2(pipes[1][1], 2);

		
		if (statusData) {
			close(pipes[2][0]);
			dup2(pipes[2][1], 3);
			numArgs += 2;
		}
		if (attributeData) {
			close(pipes[3][0]);
			dup2(pipes[3][1], 4);
			numArgs += 2;
		}
		
		if (inData) {
			close(pipes[4][1]);
			dup2(pipes[4][0], 0);
			numArgs += 2;
		}
	
		
		char* argv[numArgs];
		
		argv[0] = (char*)[GPG_PATH cStringUsingEncoding:NSUTF8StringEncoding];
		
		if (inData) {
			argv[argPos++] = "--command-fd";
			argv[argPos++] = "0";
		}
		if (statusData) {
			argv[argPos++] = "--status-fd";
			argv[argPos++] = "3";
		}
		if (attributeData) {
			argv[argPos++] = "--attribute-fd";
			argv[argPos++] = "4";
		}
		
		argv[argPos++] = "--no-greeting";
		argv[argPos++] = "--with-colons";
		argv[argPos++] = "--yes";
		if (![args containsObject:@"--no-batch"]) {
			argv[argPos++] = "--batch";
		}
		argv[argPos++] = "--no-tty";
		if (GPG_VERSION == 1) {
			argv[argPos++] = "--fixed-list-mode";
			argv[argPos++] = "--use-agent";
		}
		
		
		for (NSString *argument in args) {
			argv[argPos++] = (char*)[argument cStringUsingEncoding:NSUTF8StringEncoding];
		}
		argv[argPos] = nil;
		
		execv(argv[0], argv);
		
		//--command-fd 0 --no-greeting --with-colons --yes --batch --no-tty
		
		//Hier sollte das Programm NIE landen!
		NSLog(@"runGPGCommandWithArray: execv fehlgeschlagen!");
		exit(255);
	} else if (pid < 0) { //Fehler
		NSLog(@"runGPGCommandWithArray: fork fehlgeschlagen!");
		return -1;
	} else { //Elternprozess
		fd_set fds1, fds2;
		int maxfd = 0;
		FD_ZERO(&fds1);
		FD_ZERO(&fds2);
		
		
		char *tempData[4];
		BOOL doRead[4];
		int dataSize[4], readPos[4], dataRead;
		#define bufferSize 1000
		
		
		for (i = 0; i < 4; i++) {
			if (datas[i]) {
				close(pipes[i][1]);
				tempData[i] = malloc(bufferSize);
				dataSize[i] = bufferSize;
				readPos[i] = 0;
				doRead[i] = YES;
				FD_SET(pipes[i][0], &fds2);
				if (pipes[i][0] > maxfd) {
					maxfd = pipes[i][0];
				}
			} else {
				doRead[i] = NO;
			}
		}
		maxfd++;
		if (inData) {
			close(pipes[4][0]);
			[NSThread detachNewThreadSelector:@selector(writeDataToFD:) toTarget:actionController withObject:[NSArray arrayWithObjects:inData, [NSNumber numberWithInt:pipes[4][1]], nil]];
		}
		
		
		int i;
		while (doRead[0] || doRead[1] || doRead[2] || doRead[3]) {
			FD_COPY(&fds2, &fds1);
			if (select(maxfd, &fds1, NULL, NULL, NULL) <= 0) {
				break;
			}
			
			for (i = 0; i < 4; i++) {
				if (doRead[i] && FD_ISSET(pipes[i][0], &fds1)) {
					while ((dataRead = read(pipes[i][0], (tempData[i] + readPos[i]), dataSize[i] - readPos[i])) == dataSize[i] - readPos[i]) {
						readPos[i] = dataSize[i];
						dataSize[i] *= 2;
						tempData[i] = realloc(tempData[i], dataSize[i]);
					}
					if (dataRead > 0) {
						readPos[i] += dataRead;
					} else {
						FD_CLR(pipes[i][0], &fds2);
						doRead[i] = NO;
					}
				}
			}
		}
		
		for (i = 0; i < 4; i++) {
			if (datas[i]) {
				*datas[i] = [NSData dataWithBytes:tempData[i] length:readPos[i]];
				close(pipes[i][0]);
				free(tempData[i]);
			}
		}
		
		int exitcode, retval, loops = 0;
		while ((retval = waitpid(pid, &exitcode, 0)) != pid) {
			if (loops++ > 10) { //Solte zwar nicht dazu kommen, aber...
				NSLog(@"runGPGCommandWithArray: waitpid loops:%i!", loops);
			}
		}
		if (retval != pid) {
			NSLog(@"runGPGCommandWithArray: waitpid Fehler!");
		}
		exitcode = WEXITSTATUS(exitcode);
		
		return exitcode;
	}
}

- (void)writeDataToFD:(NSArray *)object {
	NSData *data = [object objectAtIndex:0];
	int fd = [[object objectAtIndex:1] intValue];
	write(fd, [data bytes], [data length]);
	close(fd);
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
	
	NSData *outData;
	NSData *errData;
	
	
	int exitcode = runGPGCommandWithArray(stringToData(inText), outText ? &outData : nil, errText ? &errData : nil, nil, nil, arguments);
	
	
	if (outText) {
		*outText = [dataToString(outData) retain];
	}
	if (errText) {
		*errText = [dataToString(errData) retain];
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
	GPGOptions *gpgOptions = [[[GPGOptions alloc] init] autorelease];
	
	NSRange aRange;
	NSArray *tempArray;
	
	NSData *outData;
	NSMutableString *cmdText;
	NSString *hostName, *hostProtocol, *hostPort = nil;
	NSString *helperName, *helperPath;

	BOOL passHostArgument = YES;

	
	
	
	hostName = [[GPGDefaults gpgDefaults] stringForKey:@"Keyserver"];
	if (!hostName) {
		tempArray = [gpgOptions activeOptionValuesForName:@"keyserver"];
		
		if ([tempArray count] > 0) {
			hostName = [tempArray objectAtIndex:0];
			[[GPGDefaults gpgDefaults] setObject:hostName forKey:@"Keyserver"];
		} else {
			tempArray = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Keyservers" ofType:@"plist"]];
			
			if ([tempArray count] > 0) {
				hostName = [tempArray objectAtIndex:0];
			} else {
				[pool drain];
				NSLog(@"searchKeysOnServer RunCmdNoKeyserverFound");
				return RunCmdNoKeyserverFound;			
			}
		}
	}	
	
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
        helperName = (GPG_VERSION == 2) ? @"gpg2keys_ldap" : @"gpgkeys_ldap";
    } else if ([hostProtocol isEqualToString:@"x-hkp"]) {
        helperName = (GPG_VERSION == 2) ? @"gpg2keys_hkp" : @"gpgkeys_hkp";
    } else if ([hostProtocol isEqualToString:@"hkp"]) {
        helperName = (GPG_VERSION == 2) ? @"gpg2keys_hkp" : @"gpgkeys_hkp";
    } else if ([hostProtocol isEqualToString:@"http"]) {
        helperName = (GPG_VERSION == 2) ? @"gpg2keys_curl" : @"gpgkeys_curl";
    } else if ([hostProtocol isEqualToString:@"https"]) {
        helperName = (GPG_VERSION == 2) ? @"gpg2keys_curl" : @"gpgkeys_curl";
    } else if ([hostProtocol isEqualToString:@"ftp"]) {
        helperName = (GPG_VERSION == 2) ? @"gpg2keys_curl" : @"gpgkeys_curl";
    } else if ([hostProtocol isEqualToString:@"ftps"]) {
        helperName = (GPG_VERSION == 2) ? @"gpg2keys_curl" : @"gpgkeys_curl";
    } else if ([hostProtocol isEqualToString:@"finger"]) {
        helperName = (GPG_VERSION == 2) ? @"gpg2keys_finger" : @"gpgkeys_finger";
    } else {
		[pool drain];
		NSLog(@"searchKeysOnServer RunCmdIllegalProtocolType");
		return RunCmdIllegalProtocolType;
    }
    hostName = [hostName substringFromIndex:aRange.location + aRange.length];
	
	
	//Pfad zu gpg2keys_XXX ermitteln.
	
	
	
	
	NSArray *helperSubPaths = [NSArray arrayWithObjects:@"../libexec", @"../libexec/gnupg", @"../lib/gnupg", nil];
	
	
	BOOL helperFound = NO;
	for (NSString *subPath in helperSubPaths) {
		if (helperPath = [ActionController findExecutableWithName:[subPath stringByAppendingPathComponent:helperName]]) {
			helperFound = YES;
			break;
		}
	}
	
	if (helperFound == NO) {
		[pool drain];
		NSLog(@"searchKeysOnServer RunCmdNoKeyserverHelperFound");
		return RunCmdNoKeyserverHelperFound;
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

	*outText = [dataToString(outData) retain];

	
	
	[pool drain];
	[*outText autorelease];
	return exitcode;
}


NSInteger getIndexForUserID(NSString *fingerprint, NSString *userID) {
	NSString *outText;
	if (runGPGCommand(nil, &outText, nil, @"-k", fingerprint, nil) == 0) {
		NSRange aRange = [outText rangeOfString:[NSString stringWithFormat:@":%@:", userID]];
		if (aRange.length != 0) {
			NSInteger uid = 0;
			NSArray *lines = [[outText substringToIndex:aRange.location] componentsSeparatedByString:@"\n"];
			for (NSString *line in lines) {
				 if ([line hasPrefix:@"uid:"] || [line hasPrefix:@"uat:"]) {
					 uid++;
				 }
			}
			return uid;
		}
	} else {
		NSLog(@"getIndexForUserID: -k für Schlüssel %@ fehlgeschlagen.", fingerprint);
	}
	return 0;
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




@end

