//
//  GPGInternals.h
//  MacGPGME
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
//  More info at <http://macgpg.sourceforge.net/>
//

#ifndef GPGINTERNALS_H
#define GPGINTERNALS_H

#include <MacGPGME/GPGContext.h>
#include <MacGPGME/GPGData.h>
#include <MacGPGME/GPGKey.h>
#include <MacGPGME/GPGKeySignature.h>
#include <MacGPGME/GPGUserID.h>
#include <MacGPGME/GPGSubkey.h>
#include <MacGPGME/GPGDefines.h>
#include <MacGPGME/GPGKeyGroup.h>
#include <MacGPGME/GPGOptions.h>
#include <MacGPGME/GPGRemoteKey.h>
#include <MacGPGME/GPGRemoteUserID.h>
#include <MacGPGME/GPGSignatureNotation.h>
#include <gpgme.h>

#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif

@interface GPGRemoteUserID(GPGInternals)
- (id) initWithKey:(GPGRemoteKey *)key index:(int)index;
@end

@interface GPGRemoteKey(GPGInternals)
- (id) initWithColonOutputStrings:(NSArray *)strings version:(int)version;
- (id) initWithRecipient:(gpgme_recipient_t)recipient;
- (NSArray *) colonFormatStrings;
- (int) colonFormatStringsVersion;
- (NSString *) unescapedString:(NSString *)string;
- (GPGPublicKeyAlgorithm) algorithmFromName:(NSString *)name;
@end

@interface GPGContext(GPGInternals)
- (gpgme_ctx_t) gpgmeContext;
- (void) setOperationMask:(int)flags;
- (NSMutableDictionary *) operationData;
+ (NSDictionary *) parsedGroupDefinitionLine:(NSString *)groupDefLine;
@end


@interface GPGData(GPGInternals)
- (gpgme_data_t) gpgmeData;
@end


@interface GPGKey(GPGInternals)
- (gpgme_key_t) gpgmeKey;
+ (BOOL) usesReferencesCount;
@end


@interface GPGSignature(GPGInternals)
- (id) initWithSignature:(gpgme_signature_t)signature;
- (id) initWithNewSignature:(gpgme_new_signature_t)signature;
@end


@interface GPGKeySignature(GPGInternals)
- (id) initWithKeySignature:(gpgme_key_sig_t)keySignature userID:(GPGUserID *)userID;
@end


@interface GPGUserID(GPGInternals)
- (id) initWithInternalRepresentation:(void *)aPtr key:(GPGKey *)key;
- (NSDictionary *) dictionaryRepresentation;
@end


@interface GPGSubkey(GPGInternals)
- (id) initWithInternalRepresentation:(void *)aPtr key:(GPGKey *)key;
- (NSDictionary *) dictionaryRepresentation;
@end


@interface GPGKeyGroup(GPGInternals)
- (id) initWithName:(NSString *)name keys:(NSArray *)keys;
@end


@interface GPGSignatureNotation(GPGInternals)
- (id) initWithName:(NSString *)name value:(id)value flags:(GPGSignatureNotationFlags)flags;
@end


@interface GPGObject(GPGInternals)
+ (BOOL) needsPointerUniquing;
+ (NSRecursiveLock *) pointerUniquingTableLock;
- (void) registerUniquePointer;
- (void) unregisterUniquePointer;
@end

@interface GPGEngine(GPGInternals)
+ (NSArray *) enginesFromEngineInfo:(gpgme_engine_info_t)engineInfo context:(GPGContext *)context;
- (void) setContext:(GPGContext *)context;
- (void) invalidateContext;
- (void) reloadContextEngineInfo;
@end


@interface GPGOptions(GPGInternals)
- (NSArray *) _subOptionsForName:(NSString *)optionName;
@end


GPG_EXPORT NSString *GPGStringFromChars(const char * chars);

#ifdef __cplusplus
}
#endif
#endif /* GPGINTERNALS_H */
