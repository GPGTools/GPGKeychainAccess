//
//  Controller.m
//  GPGTester
//
//  Created by davelopper at users.sourceforge.net on Tue Aug 14 2001.
//
//
//  Copyright (C) 2001-2006 Mac GPG Project.
//  
//  This code is free software; you can redistribute it and/or modify it under
//  the terms of the GNU Lesser General Public License as published by the Free
//  Software Foundation; either version 2.1 of the License, or (at your option)
//  any later version.
//  
//  This code is distributed in the hope that it will be useful, but WITHOUT ANY
//  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
//  FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
//  details.
//  
//  You should have received a copy of the GNU Lesser General Public License
//  along with this program; if not, visit <http://www.gnu.org/> or write to the
//  Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, 
//  MA 02111-1307, USA.
//  
//  More info at <http://macgpg.sourceforge.net/> or
//  <davelopper at users.sourceforge.net>.
//

#include "Controller.h"
#include <MacGPGME/MacGPGME.h>


@interface Controller(Private)
+ (GPGContext *) keySignatureBrowserContext;
+ (NSMutableDictionary *) signerPerUserIDCache;
- (void) reloadSelectedKeyUserIDsWithSignaturesFromKey:(GPGKey *)key;
@end

@implementation Controller

- (id)init
{
	[super init];
    selectedDownloadedKeys = [[NSMutableSet alloc] init];

	return self;
}

- (void) awakeFromNib
{
    NSString	*aString;
    GPGContext	*aContext = [[GPGContext alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyringChanged:) name:GPGKeyringChangedNotification object:nil];
    aString = [NSString stringWithFormat:@"Available engines:\n%@\nGroups:\n%@", [[GPGEngine availableEngines] valueForKey:@"debugDescription"], [[aContext keyGroups] valueForKey:@"name"]];
    [xmlTextView setString:aString];
    [progressIndicator setDisplayedWhenStopped:NO];
    [progressIndicator setUsesThreadedAnimation:YES];
    [progressIndicator setStyle:NSProgressIndicatorSpinningStyle];
    [supportMatrix retain];
    [supportMatrix removeFromSuperview];
    [aContext release];
}

- (void) dealloc
{
    [[keyTableView window] release];
    [passphrasePanel release];
    [encryptionPanel release];
    [signingPanel release];
    [keys release];
    [supportMatrix release];
    [[downloadOutlineView window] release];
    [downloadedKeys release];
    [selectedKeyUserIDsWithSignatures release];
    
    [super dealloc];
}

- (NSArray *) selectedRecipients
{
    if([keyTableView numberOfSelectedRows] <= 0)
        return nil;
    else{
        NSMutableArray	*recipients = [[NSMutableArray alloc] init];
        NSEnumerator	*anEnum = [keyTableView selectedRowEnumerator];
        NSNumber		*aRow;

        while(aRow = [anEnum nextObject]){
            GPGKey	*aKey = [keys objectAtIndex:[aRow intValue]];

            [recipients addObject:aKey];
        }

        return [recipients autorelease];
    }
}

- (void) searchKeysLocally
{
    GPGContext	*aContext = [[GPGContext alloc] init];
    
    [keys release];
    keys = nil;
#if 0
    keys = [[[aContext keyEnumeratorForSearchPattern:[searchPatternTextField stringValue] secretKeysOnly:[secretKeySwitch state]] allObjects] retain];
#else
    keys = [[[aContext keyEnumeratorForSearchPatterns:[NSArray arrayWithObject:[searchPatternTextField stringValue]] secretKeysOnly:[secretKeySwitch state]] allObjects] retain];
#endif
    [aContext stopKeyEnumeration];
    [aContext release];
    [keyTableView noteNumberOfRowsChanged];
    [keyTableView reloadData];
}

- (void) searchKeysExternally
{
    GPGContext		*aContext = [[GPGContext alloc] init];
    NSString		*aString = [searchPatternTextField stringValue];
    NSDictionary	*options = nil;
    NSString		*aKeyserver = [keyServerTextField stringValue];

    if([aString length] == 0)
        return;

//    [[aContext engine] setExecutablePath:[NSString stringWithFormat:@"/tmp/g%Cp%Cg%C", 0x00e9, 0x00e9, 0x00e9]];
//    [[aContext engine] setExecutablePath:@"/sw/bin/gpg"];
    [progressIndicator startAnimation:nil];
    if([aKeyserver length] > 0)
        options = [NSDictionary dictionaryWithObject:aKeyserver forKey:@"keyserver"];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(foundKeys:) name:GPGAsynchronousOperationDidTerminateNotification object:aContext];
    NS_DURING
//      [aContext asyncSearchForKeysMatchingPatterns:[NSArray arrayWithObject:aString] serverOptions:options];
        [aContext asyncSearchForKeysMatchingPatterns:[aString componentsSeparatedByString:@","] serverOptions:options];
    NS_HANDLER
        [progressIndicator stopAnimation:nil];
        NSBeginAlertSheet(@"Error during key search", nil, nil, nil, [keyTableView window], nil, NULL, NULL, NULL, @"%@", [localException reason]);
    NS_ENDHANDLER
}

- (IBAction) searchKeys:(id)sender
{
    if([searchTypeMatrix selectedRow] == 0)
        [self searchKeysLocally];
    else
        [self searchKeysExternally];
}

- (id) outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
    if(item == nil)
        return [downloadedKeys objectAtIndex:index];
    else
        return [[item userIDs] objectAtIndex:index];
}

- (BOOL) outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    return [item isKindOfClass:[GPGKey class]];
}

- (int) outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if(item == nil)
        return [downloadedKeys count];
    else
        return [[item userIDs] count];
}

- (id) outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    if([[tableColumn identifier] isEqualToString:@"selection"])
        return [NSNumber numberWithBool:[selectedDownloadedKeys containsObject:item]];
    else if([item isKindOfClass:[GPGKey class]]){
        return [NSString stringWithFormat:@"0x%@, %@%@, created on %@, expires on %@", [item keyID], [item algorithmDescription], ([(GPGKey *)item length] > 0 ? [NSString stringWithFormat:@" (%d bits)", [(GPGKey *)item length]]:@""), [item creationDate], [item expirationDate]];
    }
    else{
        return [item userID];
    }
}

- (void) outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    if([object intValue])
        [selectedDownloadedKeys addObject:item];
    else
        [selectedDownloadedKeys removeObject:item];
}

- (void) showImportResults:(NSDictionary *)importResults
{
    NSBeginInformationalAlertSheet(@"Import results", nil, nil, nil, [keyTableView window], nil, NULL, NULL, NULL, @"Total number of considered keys: %@\nNumber of keys without user ID: %@\nTotal number of imported keys: %@\nNumber of imported RSA keys: %@\nNumber of unchanged keys: %@\nNumber of new user IDs: %@\nNumber of new subkeys: %@\nNumber of new signatures: %@\nNumber of new revocations: %@\nTotal number of secret keys read: %@\nNumber of imported secret keys: %@\nNumber of unchanged secret keys: %@\nNumber of new keys skipped: %@\nNumber of keys not imported: %@", [importResults objectForKey:@"consideredKeyCount"], [importResults objectForKey:@"keysWithoutUserIDCount"], [importResults objectForKey:@"importedKeyCount"], [importResults objectForKey:@"importedRSAKeyCount"], [importResults objectForKey:@"unchangedKeyCount"], [importResults objectForKey:@"newUserIDCount"], [importResults objectForKey:@"newSubkeyCount"], [importResults objectForKey:@"newSignatureCount"], [importResults objectForKey:@"newRevocationCount"], [importResults objectForKey:@"readSecretKeyCount"], [importResults objectForKey:@"importedSecretKeyCount"], [importResults objectForKey:@"unchangedSecretKeyCount"], [importResults objectForKey:@"skippedNewKeyCount"], [importResults objectForKey:@"notImportedKeyCount"]);
}

- (void) uploadedKeys:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:[notification name] object:[notification object]];
    NSLog(@"uploadedKeys -> operation results = %@", [[notification object] operationResults]);
    [[notification object] release]; // the GPGContext
}

- (void) downloadedKeys:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:[notification name] object:[notification object]];
    [progressIndicator stopAnimation:nil];
    [keys release];
    keys = [[[[[notification object] operationResults] objectForKey:GPGChangesKey] allKeys] retain];
/*    if([keys count] > 0){ // only for tests
        GPGContext  *aContext = [[GPGContext alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uploadedKeys:) name:GPGAsynchronousOperationDidTerminateNotification object:aContext];
        [aContext asyncUploadKeys:keys serverOptions:nil];
    }*/
    [keyTableView noteNumberOfRowsChanged];
    [keyTableView reloadData];
    [self showImportResults:[[notification object] operationResults]];
    [[notification object] release]; // the GPGContext
}

- (void) downloadSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
    NSNotification	*aNotif = (NSNotification *)contextInfo;
    GPGContext		*aContext = [aNotif object];
    
    if(returnCode == NSOKButton && [selectedDownloadedKeys count] > 0){
        [progressIndicator startAnimation:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadedKeys:) name:GPGAsynchronousOperationDidTerminateNotification object:aContext];
        [aContext asyncDownloadKeys:[selectedDownloadedKeys allObjects] serverOptions:[aNotif userInfo]];
    }
    [aNotif release];
}

- (void) foundKeys:(NSNotification *)notification
{
    GPGError	anError = [[[notification userInfo] objectForKey:GPGErrorKey] intValue];

    [progressIndicator stopAnimation:nil];
    if(GPGErrorCodeFromError(anError) != GPGErrorNoError){
        NSRunAlertPanel(@"Search Error", @"%@\n%@", nil, nil, nil, GPGErrorDescription(anError), [[notification userInfo] objectForKey:GPGAdditionalReasonKey]);
        [[notification object] release]; // the context
    }
    else{
        NSWindow		*aWindow = [downloadOutlineView window];
        NSDictionary	*aDict = [[notification object] operationResults];

        [downloadServerTextField setStringValue:[NSString stringWithFormat:@"%@://%@%@ %@", [aDict objectForKey:@"protocol"], [aDict objectForKey:@"hostName"], ([aDict objectForKey:@"port"] ? [NSString stringWithFormat:@":%@", [aDict objectForKey:@"port"]]:@""), ([aDict objectForKey:@"options"] ? [[aDict objectForKey:@"options"] componentsJoinedByString:@","]:@"")]];
        [downloadedKeys release];
        downloadedKeys = [[aDict objectForKey:@"keys"] retain];
        [selectedDownloadedKeys removeAllObjects];
        [selectedDownloadedKeys addObjectsFromArray:downloadedKeys];
        [downloadOutlineView reloadData];
        [NSApp beginSheet:aWindow modalForWindow:[keyTableView window] modalDelegate:self didEndSelector:@selector(downloadSheetDidEnd:returnCode:contextInfo:) contextInfo:[notification retain]];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:[notification name] object:[notification object]];
}

- (int) numberOfRowsInTableView:(NSTableView *)tableView
{
    if(tableView == keyTableView)
        return [keys count];
    else{
        int	selectedRow = [keyTableView selectedRow];

        if(selectedRow >= 0){
            GPGKey	*selectedKey = [keys objectAtIndex:selectedRow];

            if(tableView == userIDTableView)
                return [[selectedKey userIDs] count];
            else /* subkeyTableView */
                return [[selectedKey subkeys] count];
        }
        else
            return 0;
    }
}

- (id) tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    id	rowObject = nil;
    
    if(tableView == keyTableView)
        rowObject = [keys objectAtIndex:row];
    else{
        GPGKey	*selectedKey = [keys objectAtIndex:[keyTableView selectedRow]];
        
        if(tableView == userIDTableView)
            rowObject = [[selectedKey userIDs] objectAtIndex:row];
        else
            rowObject = [[selectedKey subkeys] objectAtIndex:row];
    }
    return [rowObject valueForKey:[tableColumn identifier]];
}

- (void) tableViewSelectionDidChange:(NSNotification *)notification
{
    if([notification object] == keyTableView){
        int	selectedRow = [keyTableView selectedRow];
        
        if(selectedRow >= 0){
            GPGKey			*selectedKey = [keys objectAtIndex:selectedRow];
            GPGContext		*aContext = [[GPGContext alloc] init];
            GPGTrustItem	*trustItem;
            NSData			*imageData;
    
            [xmlTextView setString:[[selectedKey dictionaryRepresentation] description]];
    
            [mainKeyBox setTitle:[selectedKey userID]];

#if 0
            [algorithmTextField setIntValue:[selectedKey algorithm]];
#else
            [algorithmTextField setStringValue:[selectedKey algorithmDescription]];
#endif
            [lengthTextField setIntValue:[selectedKey length]];
            [validityTextField setIntValue:[selectedKey validity]];
    
            [hasSecretSwitch setState:[selectedKey isSecret]];
            [canExcryptSwitch setState:[selectedKey canEncrypt]];
            [canSignSwitch setState:[selectedKey canSign]];
            [canCertifySwitch setState:[selectedKey canCertify]];
    
            [isRevokedSwitch setState:[selectedKey isKeyRevoked]];
            [isInvalidSwitch setState:[selectedKey isKeyInvalid]];
            [hasExpiredSwitch setState:[selectedKey hasKeyExpired]];
            [isDisabledSwitch setState:[selectedKey isKeyDisabled]];

            trustItem = [[[aContext trustItemEnumeratorForSearchPattern:[selectedKey fingerprint] maximumLevel:100] allObjects] lastObject];
            [aContext release];

            if(trustItem != nil){
                [ownerTrustField setStringValue:[trustItem ownerTrustDescription]];
                [trustLevelField setIntValue:[trustItem level]];
                [trustTypeTextField setIntValue:[trustItem type]];
            }
            else{
                [ownerTrustField setStringValue:@"-"];
                [trustLevelField setIntValue:-1];
                [trustTypeTextField setIntValue:-1];
            }
            [deleteButton setEnabled:YES];
            imageData = [selectedKey photoData];
            if(imageData != nil){
                NSImage	*anImage = [[NSImage alloc] initWithData:imageData];
                
                [imageView setImage:anImage];
                [anImage release];
            }
            else
                [imageView setImage:nil];
            [self reloadSelectedKeyUserIDsWithSignaturesFromKey:selectedKey];
        }
        else{
            [xmlTextView setString:@""];
            [mainKeyBox setTitle:@""];
#if 0
            [algorithmTextField setIntValue:0];
#else
            [algorithmTextField setStringValue:@""];
#endif
            [lengthTextField setIntValue:0];
            [validityTextField setIntValue:0];
    
            [hasSecretSwitch setState:NO];
            [canExcryptSwitch setState:NO];
            [canSignSwitch setState:NO];
            [canCertifySwitch setState:NO];
    
            [isRevokedSwitch setState:NO];
            [isInvalidSwitch setState:NO];
            [hasExpiredSwitch setState:NO];
            [isDisabledSwitch setState:NO];
            
            [ownerTrustField setIntValue:0];
            [trustLevelField setIntValue:0];
            [trustTypeTextField setIntValue:0];
            [deleteButton setEnabled:NO];
            [imageView setImage:nil];
        }
        [subkeyTableView noteNumberOfRowsChanged];
        [subkeyTableView reloadData];
        [userIDTableView noteNumberOfRowsChanged];
        [userIDTableView reloadData];
    }
}

- (BOOL)tableView:(NSTableView *)tv writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard
{
    if(tv == keyTableView && [rows count] == 1){
        GPGContext	*aContext = [[GPGContext alloc] init];
        GPGData		*exportedKeyData;

        [pboard declareTypes:[NSArray arrayWithObjects:/*@"application/pgp-keys",*/ NSStringPboardType/*, NSFileContentsPboardType*/, nil] owner:nil];
        //    	[pboard addTypes:[NSArray arrayWithObject:@"application/pgp-keys"] owner:nil];

        [aContext setUsesArmor:YES];
        exportedKeyData = [aContext exportedKeys:[NSArray arrayWithObject:[keys objectAtIndex:[[rows lastObject] intValue]]]];
//        [pboard setData:[exportedKeyData data] forType:@"application/pgp-keys"];
        [pboard setString:[exportedKeyData string] forType:NSStringPboardType];
//        [pboard setData:[exportedKeyData data] forType:NSFileContentsPboardType];
//        NSLog(@"[%@]", [exportedKeyData data]);
        [aContext release];

        return YES;
    }

    return NO;
}
- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op
{
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op
{
    return NO;
}

- (IBAction) ok:(id)sender
{
    [[sender window] orderOut:sender];
    [NSApp stopModalWithCode:NSAlertDefaultReturn];
}

- (IBAction) cancel:(id)sender
{
    [[sender window] orderOut:sender];
    [NSApp stopModalWithCode:NSAlertAlternateReturn];
}

- (IBAction) okSheet:(id)sender
{
    [[sender window] orderOut:sender];
    [NSApp endSheet:[sender window] returnCode:NSOKButton];
}

- (IBAction) cancelSheet:(id)sender
{
    [[sender window] orderOut:sender];
    [NSApp endSheet:[sender window] returnCode:NSCancelButton];
}

- (NSString *) context:(GPGContext *)context passphraseForKey:(GPGKey *)key again:(BOOL)again
{
    if(key == nil)
        [passphraseDescriptionTextField setStringValue:@"Symetric encryption: enter a passphrase (no key is used)"];
    else
        [passphraseDescriptionTextField setStringValue:[key userID]];
    [passphraseTextField setStringValue:@""];
    [passphrasePanel orderFront:nil];

    if([NSApp runModalForWindow:passphrasePanel] == NSAlertDefaultReturn){
        NSString	*passphrase = [[passphraseTextField stringValue] copy];

        [passphraseTextField setStringValue:@""];
        return [passphrase autorelease];
    }
    else
        return nil;
}

- (void) decryptFile:(NSString *)inputFilename
{
    GPGContext			*aContext = [[GPGContext alloc] init];
    volatile GPGData	*decryptedData = nil, *inputData = nil;
    NSSavePanel			*savePanel;

    [aContext setPassphraseDelegate:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contextOperationIsProgressing:) name:GPGProgressNotification object:aContext];
    NS_DURING
        inputData = [[GPGData alloc] initWithContentsOfFile:inputFilename];
        
        decryptedData = [[aContext decryptedData:(GPGData *)inputData] retain];

        [(GPGData *)inputData release];
        NSLog(@"Keys used for encryption: %@", [[[aContext operationResults] objectForKey:@"keyErrors"] allKeys]);
    NS_HANDLER
        NSLog(@"Exception userInfo: %@", [localException userInfo]);
        NSRunAlertPanel(@"Error", @"%@", nil, nil, nil, [localException reason]);
        [aContext release];
        [(GPGData *)inputData release];
        [(GPGData *)decryptedData release];
        return;
    NS_ENDHANDLER

    savePanel = [NSSavePanel savePanel];
    [savePanel setTreatsFilePackagesAsDirectories:YES];

    if([savePanel runModalForDirectory:nil file:[decryptedData filename]] == NSOKButton){
        [[(GPGData *)decryptedData data] writeToFile:[savePanel filename] atomically:NO];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:GPGProgressNotification object:aContext];
    [aContext release];
    [(GPGData *)decryptedData release];
}

- (IBAction) decrypt:(id)sender
{
    NSOpenPanel	*openPanel = [NSOpenPanel openPanel];

    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setTreatsFilePackagesAsDirectories:YES];

    if([openPanel runModalForTypes:nil] == NSOKButton){
        [self decryptFile:[openPanel filename]];
    }
}

- (void) contextOperationIsProgressing:(NSNotification *)notification
{
    NSDictionary	*userInfo = [notification userInfo];
    
    NSLog(@"%@ (%@): %@/%@", [userInfo objectForKey:@"description"], [userInfo objectForKey:@"type"], [userInfo objectForKey:@"current"], [userInfo objectForKey:@"total"]);
}

- (IBAction) encrypt:(id)sender
{
    if([NSApp runModalForWindow:encryptionPanel] == NSOKButton){
        GPGContext			*aContext;
        GPGData				*inputData;
        volatile GPGData	*outputData;
        NSString            *filePath = [encryptionInputFilenameTextField stringValue];

        if([filePath length] == 0 || [[encryptionOutputFilenameTextField stringValue] length] == 0){
            NSRunAlertPanel(@"Error", @"You need to give a filename for input and output files.", nil, nil, nil);
            return;
        }

        aContext = [[GPGContext alloc] init];
        [aContext setUsesArmor:[encryptionArmoredSwitch state]];
        inputData = [[GPGData alloc] initWithContentsOfFile:filePath];

        NS_DURING
            NSArray	*selectedRecipients = [self selectedRecipients];

            if(selectedRecipients != nil)
                outputData = [aContext encryptedData:inputData withKeys:[self selectedRecipients] trustAllKeys:[trustSwitch state]];
            else{
                // Symmetric encryption
                [aContext setPassphraseDelegate:self];
                outputData = [aContext encryptedData:inputData];
            }
        NS_HANDLER
            outputData = nil;
            NSLog(@"Exception userInfo: %@", [localException userInfo]);
            NSLog(@"Operation results: %@", [[[localException userInfo] objectForKey:GPGContextKey] operationResults]);
            NSRunAlertPanel(@"Error", @"%@", nil, nil, nil, [localException reason]);
        NS_ENDHANDLER

        if(outputData != nil){
            [[(GPGData *)outputData data] writeToFile:[encryptionOutputFilenameTextField stringValue] atomically:NO];
        }
        [inputData release];
        [aContext release];
    }
}

- (IBAction) askInputFileForEncryption:(id)sender
{
    NSOpenPanel	*openPanel = [NSOpenPanel openPanel];

    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setTreatsFilePackagesAsDirectories:YES];

    if([openPanel runModalForTypes:nil] == NSOKButton){
        [encryptionInputFilenameTextField setStringValue:[openPanel filename]];
    }
}

- (IBAction) askOutputFileForEncryption:(id)sender
{
    NSSavePanel	*savePanel = [NSSavePanel savePanel];
    
    [savePanel setTreatsFilePackagesAsDirectories:YES];

    if([savePanel runModal] == NSOKButton){
        [encryptionOutputFilenameTextField setStringValue:[savePanel filename]];
    }
}

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
    if([menuItem action] == @selector(export:) || /*[menuItem action] == @selector(encrypt:) ||*/ [menuItem action] == @selector(sign:))
        return [keyTableView numberOfSelectedRows] > 0;
    else
        return YES;
}

- (IBAction) export:(id)sender
{
    volatile GPGContext	*aContext = nil;

    NS_DURING
        NSSavePanel	*savePanel;
        GPGData		*exportedData;

        aContext = [[GPGContext alloc] init];
        [(GPGContext *)aContext setUsesArmor:YES];
        exportedData = [(GPGContext *)aContext exportedKeys:[self selectedRecipients]];
        
        savePanel = [NSSavePanel savePanel];

        [savePanel setTreatsFilePackagesAsDirectories:YES];

        if([savePanel runModal] == NSOKButton){
            [[exportedData data] writeToFile:[savePanel filename] atomically:NO];
        }
    NS_HANDLER
        NSLog(@"Exception userInfo: %@", [localException userInfo]);
        NSRunAlertPanel(@"Error", @"%@", nil, nil, nil, [localException reason]);
    NS_ENDHANDLER
    [(GPGContext *)aContext release];
}

- (IBAction) import:(id)sender
{
    NSOpenPanel	*openPanel = [NSOpenPanel openPanel];

    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setTreatsFilePackagesAsDirectories:YES];

    if([openPanel runModalForTypes:nil] == NSOKButton){
        volatile GPGContext	*aContext = nil;
        volatile GPGData	*importedData = nil;

        NS_DURING
            NSDictionary	*importResults;
            
            aContext = [[GPGContext alloc] init];
            importedData = [[GPGData alloc] initWithContentsOfFile:[openPanel filename]];
            importResults = [(GPGContext *)aContext importKeyData:(GPGData *)importedData];
            [(GPGContext *)aContext release];
            aContext = nil;
            [(GPGData *)importedData release];
            [self showImportResults:importResults];
        NS_HANDLER
            [(GPGContext *)aContext release];
            NSLog(@"Exception userInfo: %@", [localException userInfo]);
            NSRunAlertPanel(@"Error", @"%@", nil, nil, nil, [localException reason]);
        NS_ENDHANDLER
    }
}

- (IBAction) askInputFileForSigning:(id)sender
{
    NSOpenPanel	*openPanel = [NSOpenPanel openPanel];

    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setTreatsFilePackagesAsDirectories:YES];

    if([openPanel runModalForTypes:nil] == NSOKButton){
        [signingInputFilenameTextField setStringValue:[openPanel filename]];
    }
}

- (IBAction) askOutputFileForSigning:(id)sender
{
    NSSavePanel	*savePanel = [NSSavePanel savePanel];

    [savePanel setTreatsFilePackagesAsDirectories:YES];

    if([savePanel runModal] == NSOKButton){
        [signingOutputFilenameTextField setStringValue:[savePanel filename]];
    }
}

- (IBAction) sign:(id)sender
{
    if([NSApp runModalForWindow:signingPanel] == NSOKButton){
        GPGContext			*aContext;
        GPGData				*inputData;
        volatile GPGData	*outputData = nil;

        if([[signingInputFilenameTextField stringValue] length] == 0 || [[signingOutputFilenameTextField stringValue] length] == 0){
            NSRunAlertPanel(@"Error", @"You need to give a filename for input and output files.", nil, nil, nil);
            return;
        }

        aContext = [[GPGContext alloc] init];
        [aContext setPassphraseDelegate:self];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contextOperationIsProgressing:) name:GPGProgressNotification object:aContext];
        [aContext setUsesArmor:[signingArmoredSwitch state]];
        inputData = [[GPGData alloc] initWithContentsOfFile:[signingInputFilenameTextField stringValue]];

        NS_DURING
            NSEnumerator	*anEnum = [keyTableView selectedRowEnumerator];
            NSNumber		*aRow;
//            unsigned        deadBeef = 0xdeadbeef;
            
            while(aRow = [anEnum nextObject])
                [aContext addSignerKey:[keys objectAtIndex:[aRow intValue]]];

            [aContext addSignatureNotationWithName:@"me@TEST_HUMAN_READABLE_NOTATION" value:@"My human-readable notation" flags:GPGSignatureNotationCriticalMask];
//            [aContext addSignatureNotationWithName:@"TEST_HUMAN_READABLE_NOTATION" value:@"My human-readable notation" flags:GPGSignatureNotationCriticalMask];
//            [aContext addSignatureNotationWithName:@"@@" value:@"My human-readable notation" flags:GPGSignatureNotationCriticalMask];
//            [aContext addSignatureNotationWithName:@"" value:@"My human-readable notation" flags:GPGSignatureNotationCriticalMask];
//            [aContext addSignatureNotationWithName:[NSString stringWithFormat:@"%C", 0x00e9] value:@"My human-readable notation" flags:GPGSignatureNotationCriticalMask];
//            [aContext addSignatureNotationWithName:@"TEST_DATA_NOTATION" value:[NSData dataWithBytes:&deadBeef length:sizeof(deadBeef)] flags:GPGSignatureNotationCriticalMask]; // Not yet implemented
            [aContext addSignatureNotationWithName:nil value:@"http://macgpg.sf.net/" flags:0];
//            [aContext addSignatureNotationWithName:nil value:[NSString stringWithFormat:@"%C", 0x00e9] flags:0];
//            [aContext addSignatureNotationWithName:nil value:@"http://macgpg.sf.net/" flags:GPGSignatureNotationCriticalMask];
            outputData = [aContext signedData:inputData signatureMode:[signingDetachedSwitch state]];
        NS_HANDLER
            outputData = nil;
            NSLog(@"Exception userInfo: %@", [localException userInfo]);
            NSRunAlertPanel(@"Error", @"%@", nil, nil, nil, [localException reason]);
        NS_ENDHANDLER

        if(outputData != nil){
            [[(GPGData *)outputData data] writeToFile:[signingOutputFilenameTextField stringValue] atomically:NO];
        }
        [[NSNotificationCenter defaultCenter] removeObserver:self name:GPGProgressNotification object:aContext];
        [inputData release];
        [aContext release];
    }
}

- (NSString *) stringFromSignatureStatus:(GPGError)status
{
    return GPGErrorDescription(status);
}

- (void) authenticateFile:(NSString *)inputFilename againstSignatureFile:(NSString *)signatureFilename
{
    GPGContext			*aContext = [[GPGContext alloc] init];
    volatile GPGData	*inputData = nil, *signatureData = nil;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contextOperationIsProgressing:) name:GPGProgressNotification object:aContext];
    NS_DURING
        NSArray		*signatures;
        NSString	*statusString = nil;
        
        inputData = [[GPGData alloc] initWithContentsOfFile:inputFilename];
        if(signatureFilename != nil)
            signatureData = [[GPGData alloc] initWithContentsOfFile:signatureFilename];
//[[aContext engine] setExecutablePath:@"/Users/dave/Developer/gpgkeys_wrapper.sh"];
        if(signatureData != nil)
            signatures = [aContext verifySignatureData:(GPGData *)signatureData againstData:(GPGData *)inputData];
        else
            signatures = [aContext verifySignedData:(GPGData *)inputData];
        statusString = @"Signatures";
        NSLog(@"operation results = %@", [aContext operationResults]);
        {
            NSEnumerator	*anEnum = [[aContext signatures] objectEnumerator];
            GPGSignature	*aSig;

            while(aSig = [anEnum nextObject]){
                GPGKey	*signerKey = [aContext keyFromFingerprint:[aSig fingerprint] secretKey:NO];

                statusString = [statusString stringByAppendingFormat:@"\nStatus: %@,  Summary: 0x%04x, Signer: %@, Signature Date: %@, Expiration Date: %@, Validity: %@, Validity Error: %@, Notations/Policy URLs: %@", GPGErrorDescription([aSig status]), [aSig summary], (signerKey ? [signerKey userID]:[aSig fingerprint]), [aSig creationDate], [aSig expirationDate], [aSig validityDescription], GPGErrorDescription([aSig validityError]), [aSig signatureNotations]];
            }
        }
        NSLog(@"Signature notations/policies = %@", [aContext signatureNotations]);
        NSRunInformationalAlertPanel(@"Authentication result", statusString, nil, nil, nil);
    NS_HANDLER
        NSString		*statusString = @"Signatures";
        BOOL			hasSigs = NO;
        NSEnumerator	*anEnum = [[aContext signatures] objectEnumerator];
        GPGSignature	*aSig;

        NSLog(@"Exception userInfo: %@", [localException userInfo]);

        while(aSig = [anEnum nextObject]){
            GPGKey	*signerKey = [aContext keyFromFingerprint:[aSig fingerprint] secretKey:NO];

            hasSigs = YES;
            statusString = [statusString stringByAppendingFormat:@"\nStatus: %@,  Summary: 0x%04x, Signer: %@, Signature Date: %@, Expiration Date: %@, Validity: %@, Validity Error: %@, Notations: %@, Policy URLs: %@", GPGErrorDescription([aSig status]), [aSig summary], (signerKey ? [signerKey userID]:[aSig fingerprint]), [aSig creationDate], [aSig expirationDate], [aSig validityDescription], GPGErrorDescription([aSig validityError]), [aSig notations], [aSig policyURLs]];
        }

        if(hasSigs)
            NSRunInformationalAlertPanel(@"Authentication result", statusString, nil, nil, nil);
        else
            NSRunAlertPanel(@"Error", @"%@", nil, nil, nil, [localException reason]);
    NS_ENDHANDLER

    [[NSNotificationCenter defaultCenter] removeObserver:self name:GPGProgressNotification object:aContext];
    [aContext release];
    [(GPGData *)inputData release];
    [(GPGData *)signatureData release];
}

- (IBAction) verify:(id)sender
{
    NSOpenPanel	*openPanel = [NSOpenPanel openPanel];

    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setTreatsFilePackagesAsDirectories:YES];

    if([openPanel runModalForTypes:nil] == NSOKButton){
        [self authenticateFile:[openPanel filename] againstSignatureFile:nil];
    }
}

- (IBAction) verifyDetachedSignature:(id)sender
{
    NSOpenPanel	*openPanel = [NSOpenPanel openPanel];

    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setTreatsFilePackagesAsDirectories:YES];

    if([openPanel runModalForTypes:nil] == NSOKButton){
        NSString	*inputFilename = [[openPanel filename] copy];

        [openPanel setPrompt:@"Signature:"];

        if([openPanel runModalForTypes:nil] == NSOKButton){
            [self authenticateFile:inputFilename againstSignatureFile:[openPanel filename]];
        }
        [inputFilename release];
    }
}

- (IBAction) deleteKey:(id)sender
{
    GPGContext	*aContext = [[GPGContext alloc] init];

    NS_DURING
        NSEnumerator	*anEnum = [keyTableView selectedRowEnumerator];
        NSNumber		*aRow;

        while(aRow = [anEnum nextObject])
            [aContext deleteKey:[keys objectAtIndex:[aRow intValue]] evenIfSecretKey:[deleteSwitch state]];
    NS_HANDLER
        NSLog(@"Exception userInfo: %@", [localException userInfo]);
        NSRunAlertPanel(@"Error", @"%@", nil, nil, nil, [localException reason]);
    NS_ENDHANDLER
    [aContext release];
}

- (void) keyringChanged:(NSNotification *)notif
{
    NSLog(@"keyringChanged: %@", [notif userInfo]);
    [keyTableView noteNumberOfRowsChanged];
    [keyTableView reloadData];
}

+ (GPGContext *) keySignatureBrowserContext
{
    static GPGContext   *keySignatureBrowserContext = nil;
    
    if(keySignatureBrowserContext == nil){
        keySignatureBrowserContext = [[GPGContext alloc] init];
        [keySignatureBrowserContext setKeyListMode:GPGKeyListModeSignatures | GPGKeyListModeLocal | GPGKeyListModeSignatureNotations];
    }
    
    return keySignatureBrowserContext;
}

+ (NSMutableDictionary *) signerPerUserIDCache
{
    static NSMutableDictionary  *signerPerUserIDCache = nil;
    
    if(signerPerUserIDCache == nil){
        signerPerUserIDCache = [[NSMutableDictionary alloc] init];
    }
    
    return signerPerUserIDCache;
}

- (void) reloadSelectedKeyUserIDsWithSignaturesFromKey:(GPGKey *)key
{
    if(key != nil){
        GPGContext  *aContext = [[self class] keySignatureBrowserContext];
        
        key = [aContext keyFromFingerprint:[key fingerprint] secretKey:NO];
        [self willChangeValueForKey:@"selectedKeyUserIDsWithSignatures"];
        [selectedKeyUserIDsWithSignatures autorelease];
        if(key != nil)
            selectedKeyUserIDsWithSignatures = [[key userIDs] retain];
        else
            selectedKeyUserIDsWithSignatures = nil;
        [[[self class] signerPerUserIDCache] removeAllObjects];
        [self didChangeValueForKey:@"selectedKeyUserIDsWithSignatures"];
    }
}

- (NSArray *) selectedKeyUserIDsWithSignatures
{
    return selectedKeyUserIDsWithSignatures;
}

- (IBAction) testKeyFromFingerprintLeaks:(id)sender
{
    volatile int                i = 0;
    volatile NSAutoreleasePool  *localAP = nil;
    
    NS_DURING
        for(i = 0; i < 100; i++){
            localAP = [[NSAutoreleasePool alloc] init];
            
            (void)[[[self class] keySignatureBrowserContext] keyFromFingerprint:@"0x992020D4" secretKey:NO];
            [localAP release];
        }
    NS_HANDLER
        [localAP release];
        NSLog(@"Failed after %d attempts: %@", i, localException);
    NS_ENDHANDLER
}

@end

@implementation GPGKey(KeySignatureBrowser)

- (NSArray *) userIDsOrSignerKeys
{
    return [self userIDs];
}

- (unsigned) userIDsOrSignerKeysCount
{
    return [[self userIDs] count];
}

- (NSString *) keyIDOrUserID
{
    return [@"0x" stringByAppendingString:[self shortKeyID]];
}

- (BOOL) isNotInKeyring
{
    return NO;
}

@end

@implementation GPGUserID(KeySignatureBrowser)

- (BOOL) isNotInKeyring
{
    return NO;
}

- (NSArray *) uniqueSignerKeyIDs
{
    NSArray *signerKeyIDs = [self valueForKeyPath:@"signatures.signerKeyID"];
    
    return [[NSSet setWithArray:signerKeyIDs] allObjects];
}

static NSComparisonResult userIDsOrSignerKeysCompare(id firstObject, id secondObject, void *signedKey){
    if(firstObject == secondObject)
        return NSOrderedSame;

    if([firstObject isKindOfClass:[NSDictionary class]]){
        if([secondObject isKindOfClass:[NSDictionary class]])
            return NSOrderedSame;
        else
            return NSOrderedDescending;
    }
    else{
        if([secondObject isKindOfClass:[NSDictionary class]])
            return NSOrderedAscending;
        else{
            if([[(GPGKey *)signedKey shortKeyID] compare:[firstObject shortKeyID]] == NSOrderedSame)
                return NSOrderedAscending;
            if([[(GPGKey *)signedKey shortKeyID] compare:[secondObject shortKeyID]] == NSOrderedSame)
                return NSOrderedDescending;
            return [[firstObject shortKeyID] compare:[secondObject shortKeyID]];
        }
    }
}

- (NSArray *) userIDsOrSignerKeys
{
    NSArray *signerKeys = [[Controller signerPerUserIDCache] objectForKey:self];
    
    if(signerKeys == nil){
        NSArray         *signerKeyIDs = [self uniqueSignerKeyIDs];
        NSMutableArray  *userIDsOrSignerKeys = [[NSMutableArray alloc] init];
        NSEnumerator    *anEnum = [signerKeyIDs objectEnumerator];
        NSString        *aKeyID;
        GPGContext      *aContext = [Controller keySignatureBrowserContext];
        
        while(aKeyID = [anEnum nextObject]){
            NSLog(@"Looking for %@", aKeyID);
            GPGKey  *aKey = [aContext keyFromFingerprint:aKeyID secretKey:NO];
            
            if(aKey == nil){
                [userIDsOrSignerKeys addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"(0x%@)", aKeyID], @"keyIDOrUserID", [NSNumber numberWithBool:YES], @"isNotInKeyring", nil]];
            }
            else{
                [userIDsOrSignerKeys addObject:aKey];
            }
        }
        signerKeys = [userIDsOrSignerKeys sortedArrayUsingFunction:userIDsOrSignerKeysCompare context:[self key]];
        [[Controller signerPerUserIDCache] setObject:signerKeys forKey:self];
        [userIDsOrSignerKeys release];
    }
    
    return signerKeys;
}

- (unsigned) userIDsOrSignerKeysCount
{
    return [[self uniqueSignerKeyIDs] count];
}

- (NSString *) keyIDOrUserID
{
    return [self userID];
}

@end

@interface KeyTableView : NSTableView
{
}
@end

@implementation KeyTableView

- (unsigned int) draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
    return NSDragOperationEvery;
}

- (NSImage*)dragImageForRows:(NSArray*)dragRows event:(NSEvent*)dragEvent dragImageOffset:(NSPointPointer)dragImageOffset
{
    return [super dragImageForRows:dragRows event:dragEvent dragImageOffset:dragImageOffset];
}

@end

#if 0
// NOTE that works :-)
#include <gpg-error.h>
#include "/tmp/gpgme-C.h"

@class GPGAsyncHelper;

@implementation Controller(Async)

struct ioContext{
    gpgme_io_cb_t	fnc;
    void			*fnc_data;
    NSFileHandle	*fileHandle;
};

static struct {
    Controller			*controller;
    gpgme_ctx_t			context;
    struct ioContext	ioContexts[10];
} theContextParams; // Should be replaced by GPGContext; we need additional ivar, NSMapTable _ioContexts, keyed by fd, and value is dict containing gpgme_io_cb_t fnc as NSValue, void* fnc_data as NSValue, NSFileHandle *fileHandle

static gpgme_error_t addCallback(void *data, int fd, int dir, gpgme_io_cb_t fnc, void *fnc_data, void **tag)
{
    int	i;

    NSCParameterAssert(data == &theContextParams);
    NSLog(@"addCallback fd=%d, dir=%d", fd, dir);

    for(i = 0; i < 10; i++){
        if(theContextParams.ioContexts[i].fnc == NULL){
            theContextParams.ioContexts[i].fnc = fnc;
            theContextParams.ioContexts[i].fnc_data = fnc_data;
            theContextParams.ioContexts[i].fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd];
            if(dir == 1)
                // TODO: move this call in eventCallback:START
                [[NSNotificationCenter defaultCenter] addObserver:theContextParams.controller selector:@selector(fileHandleDataAvailable:) name:NSFileHandleDataAvailableNotification object:theContextParams.ioContexts[i].fileHandle]; // observer should be theContextParams.ioContexts[i]
            else{
                NSLog(@"WARNING: no way with NSFileHandle to write async!");
                // We should use low-level functions for fd:
                // We should create one (shared) thread responsible of calling select(),
                // to get informed when fd is writable. Thread exits when no more fd to check.
                // (we could also use that mechanism for both read and write)
                return gpg_err_make(GPG_ERR_SOURCE_USER_2, GPG_ERR_GENERAL);
            }
            *tag = (void *)i;
            // TODO: move this call in eventCallback:START
            [theContextParams.ioContexts[i].fileHandle waitForDataInBackgroundAndNotify];
            return GPG_ERR_NO_ERROR;
        }
    }
    return gpg_err_make(GPG_ERR_SOURCE_USER_2, GPG_ERR_GENERAL);
}

- (void) fileHandleDataAvailable:(NSNotification *)notification
{
    NSLog(@"fileHandleDataAvailable: fd=%d", [[notification object] fileDescriptor]);
    int	i;
    for(i = 0; i < 10; i++){
        if(theContextParams.ioContexts[i].fileHandle == [notification object]){
            NSLog(@"Will do I/O op");
            (void)(*(theContextParams.ioContexts[i].fnc))(theContextParams.ioContexts[i].fnc_data, [[notification object] fileDescriptor]); // We don't care (yet) about the result; it should always be 0
            NSLog(@"Did");
            [theContextParams.ioContexts[i].fileHandle waitForDataInBackgroundAndNotify];
            return;
        }
    }
    NSLog(@"Unknown fd!");
}

static void removeCallback(void *tag)
{
    NSFileHandle	*fileHandle = theContextParams.ioContexts[(int)tag].fileHandle;

    NSLog(@"removeCallback fd=%d", [fileHandle fileDescriptor]);
    theContextParams.ioContexts[(int)tag].fnc = NULL;
    theContextParams.ioContexts[(int)tag].fnc_data = NULL;
    [[NSNotificationCenter defaultCenter] removeObserver:nil name:NSFileHandleDataAvailableNotification object:fileHandle];
    [fileHandle closeFile];
    [fileHandle release];
    theContextParams.ioContexts[(int)tag].fileHandle = nil;
}

static void eventCallback(void *data, gpgme_event_io_t type, void *type_data)
{
    NSCParameterAssert(data == &theContextParams);

    switch(type){
        case GPGME_EVENT_START:
            NSLog(@"eventCallback: GPGME_EVENT_START");
            break;
        case GPGME_EVENT_DONE:
            NSLog(@"eventCallback: GPGME_EVENT_DONE");
            NSLog(@"Termination status: %@ (%d = 0x%0.8x)", GPGErrorDescription(*((GPGError *)type_data)), *((GPGError *)type_data), *((GPGError *)type_data));
            break;
        case GPGME_EVENT_NEXT_KEY:
            NSLog(@"eventCallback: GPGME_EVENT_NEXT_KEY");
            NSLog(@"Next key: %@", [[[[GPGKey alloc] initWithInternalRepresentation:((gpgme_key_t)type_data)] autorelease] userID]);
            break;
        case GPGME_EVENT_NEXT_TRUSTITEM:
            NSLog(@"eventCallback: GPGME_EVENT_NEXT_TRUSTITEM");
            NSLog(@"Next trustItem: %@", [[[GPGTrustItem alloc] initWithInternalRepresentation:((gpgme_trust_item_t)type_data)] autorelease]);
            break;
        default:
            NSLog(@"eventCallback: unknown event %d", type);
    }
}

- (IBAction) searchKeys:(id)sender
{
    GPGContext	*aContext = [[GPGContext alloc] init];
    gpgme_error_t	anError;

    [[GPGAsyncHelper sharedInstance] prepareAsyncOperationInContext:aContext];
    anError = gpgme_op_keylist_start([aContext gpgmeContext], "", 0);
}

- (IBAction) searchKeys2:(id)sender
{
    gpgme_error_t	anError;
    gpgme_io_cbs_t	callbacks;

    [keys release];
    keys = nil;

    theContextParams.controller = self;

    callbacks = (gpgme_io_cbs_t)malloc(sizeof(struct gpgme_io_cbs));
    callbacks->add = addCallback;
    callbacks->add_priv = &theContextParams; // self
    callbacks->remove = removeCallback;
    callbacks->event = eventCallback;
    callbacks->event_priv = &theContextParams; // self

    anError = gpgme_new(&(theContextParams.context));
    gpgme_set_io_cbs((theContextParams.context), callbacks);
    anError = gpgme_op_keylist_start((theContextParams.context), "", 0);

    /*
     keys = [[[aContext keyEnumeratorForSearchPattern:[searchPatternTextField stringValue] secretKeysOnly:[deleteSwitch state]] allObjects] retain];
     [aContext release];
     [keyTableView noteNumberOfRowsChanged];
     [keyTableView reloadData];*/
}
/*
 struct my_gpgme_io_cb
 {
     GpgmeIOCb fnc;
     void *fnc_data;
     guint input_handler_id
 };

 void
 my_gpgme_io_cb (gpointer data, gint source, GdkInputCondition condition)
 {
     struct my_gpgme_io_cb *iocb = data;
     (*(iocb->fnc)) (iocb->data, source);
 }

 void
 my_gpgme_remove_io_cb (void *data)
 {
     struct my_gpgme_io_cb *iocb = data;
     gtk_input_remove (data->input_handler_id);
 }

 void
 my_gpgme_register_io_callback (void *data, int fd, int dir, GpgmeIOCb fnc,
                                void *fnc_data, void **tag)
 {
     struct my_gpgme_io_cb *iocb = g_malloc (sizeof (struct my_gpgme_io_cb));
     iocb->fnc = fnc;
     iocb->data = fnc_data;
     iocb->input_handler_id = gtk_input_add_full (fd, dir
                                                  ? GDK_INPUT_READ
                                                  : GDK_INPUT_WRITE,
                                                  my_gpgme_io_callback,
                                                  0, iocb, NULL);
     *tag = iocb;
     return 0;
 }*/
@end
#endif
