//
//  GPGEngine.h
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

#ifndef GPGENGINE_H
#define GPGENGINE_H

#include <MacGPGME/GPGObject.h>
#include <MacGPGME/GPGExceptions.h>

#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif


@class NSString;
@class NSArray;
@class GPGContext;


/*!
 *  @typedef    GPGProtocol
 *  @abstract   Specifies the set of possible protocol values that are
 *              supported by MacGPGME.
 *  @constant   GPGOpenPGPProtocol Default protocol. OpenPGP is implemented by
 *                                 GnuPG, the GNU Privacy Guard. This is the
 *                                 first protocol that was supported by
 *                                 MacGPGME.
 *  @constant   GPGCMSProtocol     CMS (Cryptographic Message Syntax) is 
 *                                 implemented by GpgSM, the S/MIME
 *                                 implementation for GnuPG.
 *                                 <strong>WARNING:</strong> currently 
 *                                 unsupported on MacOS X.
 */
typedef enum {
    GPGOpenPGPProtocol = 0,
    GPGCMSProtocol     = 1
} GPGProtocol;


/*!
 *  @class      GPGEngine
 *  @abstract   Represents the back-end engine providing cryptographic 
 *              functionalities.
 *  @discussion MacGPGME supports several cryptographic protocols, however, it 
 *              does not implement them. Rather it uses back-ends (also called 
 *              engines) which implement the protocol. MacGPGME uses 
 *              inter-process communication to pass data back and forth between
 *              the application and the back-end, but the details of the
 *              communication protocol and invocation of the back-end is 
 *              completely hidden by the interface. All complexity is handled by
 *              MacGPGME. Where an exchange of information between the
 *              application and the back-end is necessary, MacGPGME provides the
 *              necessary callback method hooks and further interfaces.
 *
 *              You can modify some parameters of the engines, like their
 *              executable path and their home directory. This can be done
 *              either on the default engines, or the engines proper to a
 *              <code>@link //macgpg/occ/cl/GPGContext GPGContext@/link</code>
 *              (see GPGContext's <code>@link //macgpg/occ/instm/GPGContext/engine engine@/link</code>).
 */
@interface GPGEngine : GPGObject
{
    GPGContext  *_context; // Not retained
}

/*!
 *  @method     checkVersionForProtocol:
 *  @abstract   Checks that the engine implementing the protocol <i>protocol</i> 
 *              is installed in the expected path and meets the version
 *              requirement of MacGPGME.
 *  @discussion This method returns <code>@link //macgpg/c/econst/GPGErrorNoError GPGErrorNoError@/link</code>
 *              if the engine is available and an error with code
 *              <code>@link //macgpg/c/econst/GPGErrorInvalidEngine GPGErrorInvalidEngine@/link</code>
 *              if it is not.
 *  @param      protocol The engine protocol
 */
+ (GPGError) checkVersionForProtocol:(GPGProtocol)protocol;

/*!
 *  @method     checkFrameworkVersion:
 *  @abstract   Checks that the version of the framework is at minimum the 
 *              requested one and returns the version string.
 *  @discussion Returns nil if the condition is not met or 
 *              <i>requiredVersion</i> is not a valid version number. If
 *              <i>requiredVersion</i> is nil, no check is done and the version
 *              string is simply returned.
 *
 *              Note that this check is automatically performed before any 
 *              MacGPGME object/function is used; it is called from 
 *              <code>@link //macgpg/occ/clm/GPGObject/initialize initialize@/link</code>
 *              (GPGObject).
 *  @param      requiredVersion Version number or nil
 */
+ (NSString *) checkFrameworkVersion:(NSString *)requiredVersion;

/*!
 *  @method     defaultHomeDirectoryForProtocol:
 *  @abstract   Returns the default home directory (constant) for 
 *              <i>protocol</i>.
 *  @discussion <strong>WARNING:</strong> currently implemented only for
 *              OpenPGP.
 *  @param      protocol The engine protocol
 */
+ (NSString *) defaultHomeDirectoryForProtocol:(GPGProtocol)protocol;

/*!
 *  @method     availableEngines
 *  @abstract   Returns an array of GPGEngine objects.
 *  @discussion Each engine in the array describes one configured back-end.
 */
+ (NSArray *) availableEngines;

/*!
 *  @method     engineForProtocol:
 *  @abstract   Returns the engine for the given protocol.
 *  @discussion Convenience method.
 *  @param      protocol The engine protocol
 */
+ (GPGEngine *) engineForProtocol:(GPGProtocol)protocol;

/*!
 *  @method     setDefaultExecutablePath:forProtocol:
 *  @abstract   Sets the default executable path for the given protocol.
 *  @discussion You can reset the value by passing nil. Path is stored in defaults.
 */
+ (void) setDefaultExecutablePath:(NSString *)path forProtocol:(GPGProtocol)protocol;

/*!
 *  @method     engineProtocol
 *  @abstract   Returns the protocol for which the crypto engine is used.
 *  @discussion You can convert this to a string with 
 *              <code>@link //macgpg/c/func/GPGProtocolDescription GPGProtocolDescription@/link</code>
 *              or <code>@link //macgpg/c/func/GPGLocalizedProtocolDescription GPGLocalizedProtocolDescription@/link</code> for printing.
 */
- (GPGProtocol) engineProtocol;

/*!
 *  @method     version
 *  @abstract   Returns the crypto engine version.
 *  @discussion This is a string containing the version number of the crypto 
 *              engine. It might be nil if the version number can not be
 *              determined, for example because the executable doesn't exist or
 *              is invalid.
 */
- (NSString *) version;

/*!
 *  @method     requestedVersion
 *  @abstract   Returns the minimum required version of the crypto engine.
 *  @discussion Returns a string containing the minimum required version number
 *              of the crypto engine for MacGPGME to work correctly. This is the
 *              version number that <code>@link checkVersionForProtocol: checkVersionForProtocol:@/link</code>
 *              verifies against. Currently, it is never nil, but using nil is
 *              reserved for future use, so always check before you use it.
 */
- (NSString *) requestedVersion;

/*!
 *  @method     executablePath
 *  @abstract   Returns a string holding the path to the executable of the 
 *              crypto engine.
 *  @discussion Currently, never returns nil, but using nil is reserved for
 *              future use, so always check before you use it.
 *
 *              At startup, for OpenPGP, the default path is set according to 
 *              user defaults, when available. MacGPGME reads user defaults 
 *              domain <code>@link //macgpg/c/data/GPGUserDefaultsSuiteName GPGUserDefaultsSuiteName@/link</code>,
 *              and default executable path is extracted from key
 *              <code>@link //macgpg/c/data/GPGOpenPGPExecutablePathKey GPGOpenPGPExecutablePathKey@/link</code>. When not available in defaults,
 *              value is <code>/usr/local/bin/gpg</code>.
 */
- (NSString *) executablePath;

/*!
 *  @method     setExecutablePath:
 *  @abstract   Sets the path to the executable of the crypto engine.
 *  @discussion Currently may never be nil.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              (<code>@link //macgpg/c/econst/GPGErrorInvalidEngine GPGErrorInvalidEngine@/link</code>)
 *              when no engine is found at <i>executablePath</i>.
 *  @param      executablePath The path to the engine executable.
 */
- (void) setExecutablePath:(NSString *)executablePath;

/*!
 *  @method     homeDirectory
 *  @abstract   Returns the directory name of the crypto engine's configuration 
 *              directory.
 *  @discussion Never returns nil.
 */
- (NSString *) homeDirectory;

/*!
 *  @method     customHomeDirectory
 *  @abstract   Returns the customized directory name of the crypto engine's 
 *              configuration directory, when not set to default.
 *  @discussion If it is nil, then the default directory is used; for the 
 *              OpenPGP engine, it is <code>$HOME/.gnupg</code>, or 
 *              <code>$GNUPGHOME</code> if environment variable is set.
 */
- (NSString *) customHomeDirectory;

/*!
 *  @method     setCustomHomeDirectory:
 *  @abstract   Customizes the directory name of the crypto engine's 
 *              configuration directory.
 *  @discussion Sets the directory name of the crypto engine's configuration
 *              directory. If it is nil, then the default directory is used; for 
 *              the OpenPGP engine, it is <code>$HOME/.gnupg</code>, or
 *              <code>$GNUPGHOME</code> if environment variable is set.
 *  @param      homeDirectory Path to engine home directory.
 */
- (void) setCustomHomeDirectory:(NSString *)homeDirectory;

/*!
 *  @method     executablePathDefaultsKey
 *  @abstract   Returns the key used to store the user-defined executable path
 *              in user's defaults.
 *  @discussion Returns a user defaults's key.
 *
 *              Implemented only for the OpenPGP engine.
 */
- (NSString *) executablePathDefaultsKey;

/*!
 *  @method     userHasSelectedExecutablePath
 *  @abstract   Informs whether user has defined the path where the crypto
 *              engine executable is located.
 *  @discussion We store in user defaults the location where the crypto engine
 *              executable is located. If that location has never been set in
 *              defaults, returns <code>NO</code>.
 *
 *              Implemented only for the OpenPGP engine.
 */
- (BOOL) userHasSelectedExecutablePath;

/*!
 *  @method     knownExecutablePaths
 *  @abstract   Returns potential crypto engine executable paths.
 *  @discussion For the OpenPGP engine, searches for gpg2, then gpg, in 
 *              well-known locations: <code>/usr/local/bin</code>, 
 *              <code>/opt/local/bin</code>, <code>/sw/bin</code>.
 *
 *              Implemented only for the OpenPGP engine.
 */
- (NSArray *) knownExecutablePaths;

/*!
 *  @method     availableExecutablePaths
 *  @abstract   Returns all existing crypto engine executable paths.
 *
 *              Implemented only for the OpenPGP engine.
 */
- (NSArray *) availableExecutablePaths;

/*! 
 *  @method     executeWithArguments:localizedOutput:error:
 *  @abstract   Launches engine's executable with passed arguments and gets
 *              output synchronously.
 *  @discussion
 *  @param      arguments Array of <code>@link //apple_ref/occ/cl/NSString NSString@/link</code>
 *              parameters, appended to default parameters.
 *  @param      localizedOutput When <code>NO</code>, executable is launched in
 *              English locale, to allow easy parsing of output.
 *  @param      errorPtr Optional output error argument.
 */
- (NSString *) executeWithArguments:(NSArray *)arguments localizedOutput:(BOOL)localizedOutput error:(NSError **)errorPtr;

/*!
 *  @method     optionsFilename
 *  @abstract   Returns the full path name to engine's configuration file.
 *  @discussion It may depend on the engine's version. If user changed engine's
 *              home directory without logging out and in, returned value might
 *              be not yet valid.
 *
 *              Implemented only for the OpenPGP engine.
 *  @exception  Raises an exception when engine version cannot be found out.
 */
- (NSString *) optionsFilename;

/*!
 *  @method     extensionsPath
 *  @abstract   Returns the default directory name where extensions are stored.
 *
 *              Implemented only for the OpenPGP engine version 1.x.
 *  @exception  Raises an exception when engine version cannot be found out.
 */
- (NSString *) extensionsPath;

@end

#ifdef __cplusplus
}
#endif
#endif /* GPGENGINE_H */
