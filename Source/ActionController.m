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

#import "ActionController.h"
#import "KeychainController.h"
#import "SheetController.h"

@interface ActionController ()
@property (retain) NSString *progressText, *errorText;

@end


@implementation ActionController
@synthesize progressText, errorText;

//TODO: Fotos die auf mehrere Subpakete aufgeteilt sind.
//TODO: Fehlermeldungen wenn eine Aktion fehlschlägt.

- (NSUndoManager *)undoManager {
	if (!undoManager) {
		undoManager = [NSUndoManager new];
		[undoManager setLevelsOfUndo:50];
	}
	return [[undoManager retain] autorelease];
}


- (NSSet *)selectedKeys {
	NSInteger clickedRow = [keyTable clickedRow];
	if (clickedRow != -1 && ![keyTable isRowSelected:clickedRow]) {
		return [NSSet setWithObject:[[keyTable itemAtRow:clickedRow] representedObject]];
	} else {
		NSMutableSet *keySet = [NSMutableSet set];
		for (GPGKey *key in [keysController selectedObjects]) {
			[keySet addObject:[key primaryKey]];
		}
		return keySet;
	}
}


- (BOOL)validateUserInterfaceItem:(id)anItem {
    SEL selector = [anItem action];
	
    if (selector == @selector(copy:)) {
		if ([[self selectedKeys] count] >= 1) {
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
		NSSet *keys = [self selectedKeys];
		if ([keys count] == 1 && ((GPGKey*)[keys anyObject]).secret) {
			return YES;
		}
		return NO;
    } else if (selector == @selector(editAlgorithmPreferences:)) {
		NSSet *keys = [self selectedKeys];
		if ([keys count] == 1) {
			return YES;
		}
		return NO;
	}
	return YES;
}


- (IBAction)copy:(id)sender {
	NSSet *keys = [self selectedKeys];
	if ([keys count] > 0) {
		NSString *exportedKeys = [[self exportKeys:keys armored:YES allowSecret:NO fullExport:NO] gpgString];
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
	NSSet *keys = [self selectedKeys];
	if ([keys count] == 1) {
		GPGKey *key = [keys anyObject];
		[sheetController algorithmPreferences:key editable:[key secret]];
	}	
}
- (void)editAlgorithmPreferencesForKey:(GPGKey *)key preferences:(NSArray *)preferencesList {
	for (NSDictionary *preferences in preferencesList) {
		GPGUserID *userID = [preferences objectForKey:@"userID"];
		NSString *cipherPreferences = [[preferences objectForKey:@"cipherPreferences"] componentsJoinedByString:@" "];
		NSString *digestPreferences = [[preferences objectForKey:@"digestPreferences"] componentsJoinedByString:@" "];
		NSString *compressPreferences = [[preferences objectForKey:@"compressPreferences"] componentsJoinedByString:@" "];
		
		[gpgc setAlgorithmPreferences:[NSString stringWithFormat:@"%@ %@ %@", cipherPreferences, digestPreferences, compressPreferences] forUserID:[userID hashID] ofKey:key];
	}
	
	[[KeychainController sharedInstance] asyncUpdateKey:key];
}



- (NSString *)importResultWithStatusText:(NSString *)statusText {
	NSMutableString *retString = [NSMutableString string];
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
			userID = [[[[KeychainController sharedInstance] allKeys] member:fingerprint] userID];
			keyID = [fingerprint shortKeyID];

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
	NSSet *keys = [self selectedKeys];
	if ([keys count] > 0) {		
		for (GPGKey *key in keys) {
			[gpgc cleanKey:key];
		}
	}
}
- (IBAction)minimizeKey:(id)sender {
	NSSet *keys = [self selectedKeys];
	if ([keys count] > 0) {
		for (GPGKey *key in keys) {
			[gpgc minimizeKey:key];
		}
	}
}


- (IBAction)addPhoto:(NSButton *)sender {
	NSSet *keys = [self selectedKeys];
	if ([keys count] == 1) {
		GPGKey *key = [[keys anyObject] primaryKey];
		
		[sheetController addPhoto:key];
	}
}
- (void)addPhotoForKey:(GPGKey *)key photoPath:(NSString *)path {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[gpgc addPhotoFromPath:path toKey:key];
	
	[pool drain];
}

- (IBAction)removePhoto:(NSButton *)sender {
	if ([photosController selectionIndex] != NSNotFound) {
		NSSet *keys = [self selectedKeys];		
		GPGKey *key = [[keys anyObject] primaryKey];
		
		[gpgc removeUserID:[[[photosController selectedObjects] objectAtIndex:0] hashID] fromKey:key];
	}
}
- (IBAction)revokePhoto:(NSButton *)sender {
	if ([photosController selectionIndex] != NSNotFound) {
		NSSet *keys = [self selectedKeys];		
		GPGKey *key = [[keys anyObject] primaryKey];

		[gpgc revokeUserID:[[[photosController selectedObjects] objectAtIndex:0] hashID] fromKey:key reason:0 description:nil];
	}
}

- (IBAction)setPrimaryPhoto:(NSButton *)sender {
	if ([photosController selectionIndex] != NSNotFound) {
		NSSet *keys = [self selectedKeys];		
		GPGKey *key = [[keys anyObject] primaryKey];
		
		[gpgc setPrimaryUserID:[[[photosController selectedObjects] objectAtIndex:0] hashID] ofKey:key];
	}
}



- (IBAction)importKey:(id)sender {
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
	
	NSString *statusText = [gpgc importFromData:data fullImport:NO];
	
	[sheetController showResult:[self importResultWithStatusText:statusText]];
	
	[pool drain];
}



- (IBAction)exportKey:(id)sender {
	NSSet *keys = [self selectedKeys];
	
	[sheetController exportKeys:keys];
}
- (NSData *)exportKeys:(NSObject <EnumerationList> *)keys armored:(BOOL)armored allowSecret:(BOOL)allowSec fullExport:(BOOL)fullExport {
	gpgc.useArmor = armored;
	return [gpgc exportKeys:keys allowSecret:allowSec fullExport:fullExport];
}

- (NSSet *)keysInExportedData:(NSData *)data {
	NSMutableSet *keys = [NSMutableSet set];
	GPGPacket *packet = [GPGPacket packetWithData:data];
	
	while (packet) {
		if (packet.type == GPGPublicKeyPacket || packet.type == GPGSecretKeyPacket) {
			[keys addObject:packet.fingerprint];
		}
		packet = packet.nextPacket;
	}
	
	return keys;
}


- (IBAction)genRevokeCertificate:(id)sender {
	NSSet *keys = [self selectedKeys];
	if ([keys count] == 1) {
		[sheetController genRevokeCertificateForKey:[keys anyObject]];
	}
}
- (NSData *)genRevokeCertificateForKey:(GPGKey *)key {
	return [gpgc generateRevokeCertificateForKey:key reason:0 description:nil];
}



- (IBAction)addSignature:(id)sender {
	if ([sender tag] != 1 || [userIDsController selectionIndex] != NSNotFound) {
		NSSet *keys = [self selectedKeys];		
		GPGKey *key = [[keys anyObject] primaryKey];
		
		NSString *userID;
		if ([sender tag] == 1) {
			userID = [[[userIDsController selectedObjects] objectAtIndex:0] userID];
		} else {
			userID = nil;
		}
		
		[sheetController addSignature:key userID:userID];
	}
}
- (void)addSignatureForKey:(GPGKey *)key andUserID:(NSString *)userID signKey:(NSString *)signFingerprint type:(NSInteger)type local:(BOOL)local daysToExpire:(NSInteger)daysToExpire {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[gpgc signUserID:userID ofKey:key signKey:signFingerprint type:type local:local daysToExpire:daysToExpire];
	
	[pool drain];
}

- (IBAction)addSubkey:(NSButton *)sender {
	NSSet *keys = [self selectedKeys];		
	if ([keys count] == 1) {
		GPGKey *key = [[keys anyObject] primaryKey];
		
		[sheetController addSubkey:key];
	}
}
- (void)addSubkeyForKey:(GPGKey *)key type:(NSInteger)type length:(NSInteger)length daysToExpire:(NSInteger)daysToExpire {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	[gpgc addSubkeyToKey:key type:type length:length daysToExpire:daysToExpire];

	[pool drain];
}

- (IBAction)addUserID:(NSButton *)sender {
	NSSet *keys = [self selectedKeys];		
	if ([keys count] == 1) {
		GPGKey *key = [[keys anyObject] primaryKey];
		
		[sheetController addUserID:key];
	}
}
- (void)addUserIDForKey:(GPGKey *)key name:(NSString *)name email:(NSString *)email comment:(NSString *)comment{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	[gpgc addUserIDToKey:key name:name email:email comment:comment];
	
	[pool drain];
}

- (IBAction)changeExpirationDate:(NSButton *)sender {
	BOOL aKeyIsSelected = NO;
	GPGSubkey *subkey;
	
	NSSet *keys = [self selectedKeys];			
	if ([sender tag] == 1 && [[subkeysController selectedObjects] count] == 1) {
		subkey = [[subkeysController selectedObjects] objectAtIndex:0];
		aKeyIsSelected = YES;
	} else if ([sender tag] == 0 && [keys count] == 1) {
		subkey = nil;
		aKeyIsSelected = YES;
	}
	
	if (aKeyIsSelected) {
		GPGKey *key = [[keys anyObject] primaryKey];
		
		[sheetController changeExpirationDate:key subkey:subkey];
	}
	
}
- (void)changeExpirationDateForKey:(GPGKey *)key subkey:(GPGSubkey *)subkey daysToExpire:(NSInteger)daysToExpire {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[gpgc setExpirationDateForSubkey:subkey fromKey:key daysToExpire:daysToExpire];
	
	[pool drain];
}

- (IBAction)searchKeys:(id)sender {
	[sheetController searchKeys];
}
- (NSArray *)searchKeysWithPattern:(NSString *)pattern {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSArray *keys = [[gpgc searchKeysOnServer:pattern] retain];
	
	[pool drain];
	return [keys autorelease];
}




- (IBAction)receiveKeys:(id)sender {
	[sheetController receiveKeys];
}
- (NSString *)receiveKeysWithIDs:(NSSet *)keyIDs {
	NSString *statusText = [gpgc receiveKeysFromServer:keyIDs];
	return [self importResultWithStatusText:statusText];
}












// Für Libmacgpg überarbeitet //
- (IBAction)sendKeysToServer:(id)sender {
	NSSet *keys = [self selectedKeys];
	if ([keys count] > 0) {
		[gpgc sendKeysToServer:keys];
	}
}

- (IBAction)refreshKeysFromServer:(id)sender {
	NSSet *keys = [self selectedKeys];
	if ([keys count] > 0) {	
		[gpgc refreshKeysFromServer:keys];
	}
}

- (IBAction)changePassphrase:(NSButton *)sender {
	NSSet *keys = [self selectedKeys];	
	if ([keys count] == 1) {
		GPGKey *key = [[keys anyObject] primaryKey];
		
		[gpgc changePassphraseForKey:key];
	}
}

- (IBAction)removeSignature:(NSButton *)sender {
	if ([signaturesController selectionIndex] != NSNotFound) {
		GPGKeySignature *gpgKeySignature = [[signaturesController selectedObjects] objectAtIndex:0];
		GPGUserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
		GPGKey *key = [userID primaryKey];
		
		[gpgc removeSignature:gpgKeySignature fromUserID:userID ofKey:key];
		
		[[KeychainController sharedInstance] asyncUpdateKey:key];
	}
}

- (IBAction)removeSubkey:(NSButton *)sender {
	if ([[subkeysController selectedObjects] count] == 1) {
		GPGSubkey *subkey = [[subkeysController selectedObjects] objectAtIndex:0];
		GPGKey *key = [subkey primaryKey];
		
		[gpgc removeSubkey:subkey fromKey:key];
		
		[[KeychainController sharedInstance] asyncUpdateKey:key];
	}
}

- (IBAction)removeUserID:(NSButton *)sender {
	if ([userIDsController selectionIndex] != NSNotFound) {
		GPGUserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
		GPGKey *key = [userID primaryKey];
		
		[gpgc removeUserID:[userID hashID] fromKey:key];
		
		[[KeychainController sharedInstance] asyncUpdateKey:key];
	}
}

- (IBAction)revokeSignature:(NSButton *)sender {
	if ([signaturesController selectionIndex] != NSNotFound) {
		GPGKeySignature *gpgKeySignature = [[signaturesController selectedObjects] objectAtIndex:0];
		GPGUserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
		GPGKey *key = [userID primaryKey];
		
		[gpgc revokeSignature:gpgKeySignature fromUserID:userID ofKey:key reason:0 description:nil];
		
		[[KeychainController sharedInstance] asyncUpdateKey:key];
	}
}

- (IBAction)revokeSubkey:(NSButton *)sender {
	if ([[subkeysController selectedObjects] count] == 1) {
		GPGSubkey *subkey = [[subkeysController selectedObjects] objectAtIndex:0];
		GPGKey *key = [subkey primaryKey];
		
		[gpgc revokeSubkey:subkey fromKey:key reason:0 description:nil];		
		
		[[KeychainController sharedInstance] asyncUpdateKey:key];
	}
}

- (IBAction)revokeUserID:(NSButton *)sender {
	if ([userIDsController selectionIndex] != NSNotFound) {
		GPGUserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
		GPGKey *key = [userID primaryKey];
		
		[gpgc revokeUserID:[userID hashID] fromKey:key reason:0 description:nil]; 
		
		[[KeychainController sharedInstance] asyncUpdateKey:key];
	}
}


- (IBAction)setDisabled:(NSButton *)sender {
	NSSet *keys = [self selectedKeys];
	if ([keys count] > 0) {
		BOOL disabled = [sender state] == NSOnState;
		[self.undoManager beginUndoGrouping];
		for (GPGKey *key in keys) {
			[gpgc key:key setDisabled:disabled];
		}
		[self.undoManager endUndoGrouping];
		[self.undoManager setActionName:localized(disabled ? @"Undo_Disable" : @"Undo_Enable")];
	}
}


- (IBAction)setPrimaryUserID:(NSButton *)sender {
	if ([userIDsController selectionIndex] != NSNotFound) {
		GPGUserID *userID = [[userIDsController selectedObjects] objectAtIndex:0];
		GPGKey *key = [userID primaryKey];
	
		[gpgc setPrimaryUserID:[userID hashID] ofKey:key];

		[[KeychainController sharedInstance] asyncUpdateKey:key];
	}
}

- (IBAction)setTrsut:(NSPopUpButton *)sender {
	NSSet *keys = [self selectedKeys];
	if ([keys count] > 0) {
		for (GPGKey *key in keys) {
			[gpgc key:key setOwnerTrsut:[sender selectedTag]];
		}
	}
}

- (IBAction)refreshDisplayedKeys:(id)sender {
	[[KeychainController sharedInstance] asyncUpdateKeys:nil];
}


- (IBAction)deleteKey:(id)sender { 	
	NSSet *keys = [self selectedKeys];
	if (keys.count == 0) {
		return;
	}
	
	NSInteger returnCode;
	BOOL applyToAll = NO;
	NSMutableSet *keysToDelete = [NSMutableSet setWithCapacity:keys.count];
	NSMutableSet *secretKeysToDelete = [NSMutableSet setWithCapacity:keys.count];
	
	[self.undoManager beginUndoGrouping];
	
	
	BOOL (^secretKeyTest)(id, BOOL*) = ^BOOL(id obj, BOOL *stop) {
		return ((GPGKey *)obj).secret;
	};
	
	
	
	NSSet *secretKeys = [keys objectsWithOptions:NSEnumerationConcurrent passingTest:secretKeyTest];
	NSMutableSet *publicKeys = [keys mutableCopy];
	[publicKeys minusSet:secretKeys];
	
	
	
	for (GPGKey *key in secretKeys) {
		if (!applyToAll) {
			returnCode = [sheetController alertSheetForWindow:mainWindow 
												  messageText:localized(@"DeleteSecretKey_Title") 
													 infoText:[NSString stringWithFormat:localized(@"DeleteSecretKey_Msg"), [key userID], [key shortKeyID]] 
												defaultButton:localized(@"Delete secret key only") 
											  alternateButton:localized(@"Cancel") 
												  otherButton:localized(@"Delete both")
											suppressionButton:localized(@"Apply to all")];
			
			applyToAll = !!(returnCode & SheetSuppressionButton);
			returnCode = returnCode & ~SheetSuppressionButton;
			if (applyToAll && returnCode == NSAlertSecondButtonReturn) {
				break;
			}
		}
		
		switch (returnCode) {
			case NSAlertFirstButtonReturn:
				[secretKeysToDelete addObject:key];
				break;
			case NSAlertThirdButtonReturn:
				[keysToDelete addObject:key];
				break;
		}
	}
	
	
	if (applyToAll && returnCode == NSAlertThirdButtonReturn) {
		returnCode = NSAlertFirstButtonReturn;
	} else {
		applyToAll = NO;
	}
	
	for (GPGKey *key in publicKeys) {
		if (!applyToAll) {
			returnCode = [sheetController alertSheetForWindow:mainWindow 
												  messageText:localized(@"DeleteKey_Title") 
													 infoText:[NSString stringWithFormat:localized(@"DeleteKey_Msg"), [key userID], [key shortKeyID]] 
												defaultButton:localized(@"Delete key") 
											  alternateButton:localized(@"Cancel") 
												  otherButton:nil
											suppressionButton:localized(@"Apply to all")];
			
			applyToAll = !!(returnCode & SheetSuppressionButton);
			returnCode = returnCode & ~SheetSuppressionButton;
			if (applyToAll && returnCode == NSAlertSecondButtonReturn) {
				break;
			}
		}
		
		if (returnCode == NSAlertFirstButtonReturn) {
			[keysToDelete addObject:key];
		}
	}
	
	
	if (secretKeysToDelete.count > 0) {
		[gpgc deleteKeys:secretKeysToDelete withMode:GPGDeleteSecretKey];
	}
	
	if (keysToDelete.count > 0) {
		[gpgc deleteKeys:keysToDelete withMode:GPGDeletePublicAndSecretKey];
	}
	
	
	[self.undoManager endUndoGrouping];
	[self.undoManager setActionName:localized(@"Undo_Delete")];
	
}

- (IBAction)generateNewKey:(id)sender {
	sheetController.sheetType = SheetTypeNewKey;
	if ([sheetController runModalForWindow:mainWindow] == NSOKButton) {
		NSInteger keyType, subkeyType;
		
		switch (sheetController.keyType) {
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
		self.progressText = localized(@"GenerateEntropy_Msg");
		self.errorText = localized(@"GenerateKey_Error");
		
		[gpgc generateNewKeyWithName:sheetController.name 
							   email:sheetController.email 
							 comment:sheetController.comment 
							 keyType:keyType 
						   keyLength:sheetController.length 
						  subkeyType:subkeyType 
						subkeyLength:sheetController.length 
						daysToExpire:[sheetController.expirationDate daysSinceNow]
						 preferences:nil 
						  passphrase:sheetController.passphrase];

	}
	
}


- (IBAction)showInspector:(id)sender {
	if (![sender isKindOfClass:[NSTableView class]] || [sender clickedRow] > -1) {
		[inspectorWindow makeKeyAndOrderFront:sender];
	}
}



// Hilfsmethoden //
- (void)cancelOperation:(id)sender {
	[gpgc cancel];
}

- (void)gpgControllerOperationDidStart:(GPGController *)gpgc {
	sheetController.progressText = self.progressText;
	[sheetController performSelectorOnMainThread:@selector(showProgressSheet) withObject:nil waitUntilDone:NO];
}
- (void)gpgController:(GPGController *)gpgc operationThrownException:(NSException *)e {
	if ([e isKindOfClass:[GPGException class]]) {
		if ([(GPGException *)e errorCode] == GPGErrorCancelled) {
			return;
		}
	}
	sheetController.errorText = [NSString stringWithFormat:self.errorText, e.name /*TODO: Add description from errorCode*/];
	[sheetController showErrorSheet];
}
- (void)gpgController:(GPGController *)gpgc operationDidFinishWithReturnValue:(id)value {
	[sheetController performSelectorOnMainThread:@selector(endProgressSheet) withObject:nil waitUntilDone:NO];
}
- (void)gpgController:(GPGController *)gpgc keysDidChanged:(NSObject<EnumerationList> *)keys external:(BOOL)external {
	[(KeychainController *)[KeychainController sharedInstance] updateKeys:keys];
}


// Singleton: alloc, init etc. //
+ (id)sharedInstance {
	static id sharedInstance = nil;
    if (!sharedInstance) {
        sharedInstance = [[super allocWithZone:nil] init];
    }
    return sharedInstance;	
}
- (id)init {
	static BOOL initialized = NO;
	if (!initialized) {
		initialized = YES;
		self = [super init];
		
		gpgc = [[GPGController gpgController] retain];
		gpgc.delegate = self;
		gpgc.undoManager = self.undoManager;
		gpgc.async = YES;
		sheetController = [[SheetController sharedInstance] retain];
	}
	return self;
}
+ (id)allocWithZone:(NSZone *)zone {
    return [[self sharedInstance] retain];	
}
- (id)copyWithZone:(NSZone *)zone {
    return self;
}
- (id)retain {
    return self;
}
- (NSUInteger)retainCount {
    return NSUIntegerMax;
}
- (oneway void)release {
}
- (id)autorelease {
    return self;
}





@end

