//
//  GPGController.h
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

#ifndef CONTROLLER_H
#define CONTROLLER_H

#include <AppKit/AppKit.h>

#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif

@interface Controller : NSObject
{
    NSArray					*keys;
    NSArray                 *selectedKeyUserIDsWithSignatures;
    
    IBOutlet NSTableView	*keyTableView;
    IBOutlet NSTableView	*userIDTableView;
    IBOutlet NSTableView	*subkeyTableView;
    IBOutlet NSTextField	*searchPatternTextField;
    IBOutlet NSTextView		*xmlTextView;
    IBOutlet NSBox			*mainKeyBox;
    IBOutlet NSTextField	*algorithmTextField;
    IBOutlet NSTextField	*lengthTextField;
    IBOutlet NSTextField	*validityTextField;
    IBOutlet NSButtonCell	*hasSecretSwitch;
    IBOutlet NSButtonCell	*canExcryptSwitch;
    IBOutlet NSButtonCell	*canSignSwitch;
    IBOutlet NSButtonCell	*canCertifySwitch;
    IBOutlet NSButtonCell	*isRevokedSwitch;
    IBOutlet NSButtonCell	*isInvalidSwitch;
    IBOutlet NSButtonCell	*hasExpiredSwitch;
    IBOutlet NSButtonCell	*isDisabledSwitch;
    IBOutlet NSTextFieldCell	*ownerTrustField;
    IBOutlet NSTextFieldCell	*trustLevelField;
    IBOutlet NSTextFieldCell	*trustTypeTextField;
    
    IBOutlet NSTextField	*passphraseDescriptionTextField;
    IBOutlet NSTextField	*passphraseTextField;
    IBOutlet NSPanel		*passphrasePanel;

    IBOutlet NSTextField	*encryptionInputFilenameTextField;
    IBOutlet NSButtonCell	*encryptionArmoredSwitch;
    IBOutlet NSTextField	*encryptionOutputFilenameTextField;
    IBOutlet NSPanel		*encryptionPanel;
    IBOutlet NSButtonCell	*trustSwitch;

    IBOutlet NSTextField	*signingInputFilenameTextField;
    IBOutlet NSButtonCell	*signingArmoredSwitch;
    IBOutlet NSButtonCell	*signingDetachedSwitch;
    IBOutlet NSTextField	*signingOutputFilenameTextField;
    IBOutlet NSPanel		*signingPanel;

    IBOutlet NSButton       *deleteSwitch;
    IBOutlet NSButton		*deleteButton;

    IBOutlet NSMatrix		*searchTypeMatrix;
    IBOutlet NSButton		*secretKeySwitch;
    IBOutlet NSTextField	*keyServerTextField;
    IBOutlet NSProgressIndicator	*progressIndicator;

    IBOutlet NSOutlineView	*downloadOutlineView;
    IBOutlet NSTextField	*downloadServerTextField;
    NSArray					*downloadedKeys;
    IBOutlet NSMatrix		*supportMatrix;
    NSMutableSet			*selectedDownloadedKeys;

    IBOutlet NSImageView	*imageView;
    IBOutlet NSTreeController   *signatureTreeController;
}

- (IBAction) searchKeys:(id)sender;

- (IBAction) encrypt:(id)sender;
- (IBAction) askInputFileForEncryption:(id)sender;
- (IBAction) askOutputFileForEncryption:(id)sender;

- (IBAction) decrypt:(id)sender;

- (IBAction) sign:(id)sender;
- (IBAction) askInputFileForSigning:(id)sender;
- (IBAction) askOutputFileForSigning:(id)sender;

- (IBAction) verify:(id)sender;
- (IBAction) verifyDetachedSignature:(id)sender;

- (IBAction) export:(id)sender;
- (IBAction) import:(id)sender;

- (IBAction) deleteKey:(id)sender;

- (IBAction) ok:(id)sender;
- (IBAction) cancel:(id)sender;

- (IBAction) okSheet:(id)sender;
- (IBAction) cancelSheet:(id)sender;

- (IBAction) testKeyFromFingerprintLeaks:(id)sender;

@end

#ifdef __cplusplus
}
#endif
#endif /* CONTROLLER_H */
