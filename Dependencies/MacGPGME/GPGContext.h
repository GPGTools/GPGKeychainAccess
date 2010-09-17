//
//  GPGContext.h
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

#ifndef GPGCONTEXT_H
#define GPGCONTEXT_H

#include <MacGPGME/GPGObject.h>
#include <MacGPGME/GPGEngine.h>
#include <MacGPGME/GPGSignatureNotation.h>

#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif


@class NSArray;
@class NSCalendarDate;
@class NSEnumerator;
@class NSMutableDictionary;
@class NSMutableSet;
@class GPGData;
@class GPGKey;
@class GPGOptions;


/*!
 *  @typedef    GPGSignatureMode
 *  @abstract   The GPGSignatureMode type is used to specify the desired type of
 *              a signature.
 *  @constant   GPGSignatureModeNormal A normal signature is made, the output
 *                                     includes the plaintext and the signature.
 *  @constant   GPGSignatureModeDetach A detached signature is made.
 *  @constant   GPGSignatureModeClear  A clear text signature is made. The
 *                                     <i>ASCII armor</i> and <i>text mode</i>
 *                                     settings of the context are ignored.
 *  @seealso    //macgpg/occ/instm/GPGContext/signedData:signatureMode: signedData:signatureMode: (GPGContext)
 */
typedef enum {
    GPGSignatureModeNormal = 0,
    GPGSignatureModeDetach = 1,
    GPGSignatureModeClear  = 2
} GPGSignatureMode;


/*!
 *  @typedef    GPGKeyListMode
 *  @abstract   The key listing mode is a combination of one or multiple bit
 *              values.
 *  @constant   GPGKeyListModeLocal              Specifies that the local 
 *                                               <i>key ring</i> should be
 *                                               searched for keys in the key
 *                                               listing operation. This is the
 *                                               default.
 *  @constant   GPGKeyListModeExtern             Specifies that an external
 *                                               source should be searched for 
 *                                               keys in the key listing
 *                                               operation. The type of external
 *                                               source is dependant on the
 *                                               crypto engine used. For 
 *                                               example, it can be a remote
 *                                               <i>key server</i> or LDAP
 *                                               certificate server. Currently
 *                                               only implemented for the S/MIME 
 *                                               back-end and ignored for other
 *                                               back-ends.
 *  @constant   GPGKeyListModeSignatures         Specifies that signatures on
 *                                               keys shall be retrieved too. 
 *                                               This is a time-consuming 
 *                                               operation, and that mode should
 *                                               not be used when retrieving all
 *                                               keys, but only a key per key
 *                                               basis, like when using
 *                                               <code>@link refreshKey: refreshKey:@/link</code>
 *                                               (GPGContext).
 *  @constant   GPGKeyListModeSignatureNotations Specifies that the signature
 *                                               notations on key signatures
 *                                               should be included in the
 *                                               listed keys. This only works if
 *                                               <code>GPGKeyListModeSignatures</code>
 *                                               is also enabled.
 *  @constant   GPGKeyListModeValidate           Specifies that the back-end
 *                                               should do key or certificate 
 *                                               validation and not just get the
 *                                               validity information from an
 *                                               internal cache. This might be
 *                                               an expensive operation and is 
 *                                               in general not useful.
 *                                               Currently only implemented for
 *                                               the S/MIME back-end and ignored
 *                                               for other back-ends.
 *  @seealso    //macgpg/occ/instm/GPGContext/keyListMode keyListMode (GPGContext)
 *  @seealso    //macgpg/occ/instm/GPGContext/setKeyListMode: setKeyListMode: (GPGContext)
 */
typedef unsigned int GPGKeyListMode;

#define GPGKeyListModeLocal                 1
#define GPGKeyListModeExtern                2
#define GPGKeyListModeSignatures            4
#define GPGKeyListModeSignatureNotations    8
#define GPGKeyListModeValidate            256


/*!
 *  @typedef    GPGCertificatesInclusion
 *  @abstract   Certificates inclusion (S/MIME only).
 *  @constant   GPGDefaultCertificatesInclusion       Use whatever the default
 *                                                    of the back-end crypto
 *                                                    engine is.
 *  @constant   GPGAllExceptRootCertificatesInclusion Include all certificates
 *                                                    except the root
 *                                                    certificate.
 *  @constant   GPGAllCertificatesInclusion           Include all certificates.
 *  @constant   GPGNoCertificatesInclusion            Include no certificates.
 *  @constant   GPGOnlySenderCertificateInclusion     Include the sender's
 *                                                    certificate only.
 *  @constant   n&nbsp;&gt;&nbsp;1                    Include the first n
 *                                                    certificates of the
 *                                                    certificates path,
 *                                                    starting from the sender's
 *                                                    certificate. The
 *                                                    number <i>n</i> must be
 *                                                    positive.
 *  @seealso    //macgpg/occ/instm/GPGContext/certificatesInclusion certificatesInclusion (GPGContext)
 *  @seealso    //macgpg/occ/instm/GPGContext/setCertificatesInclusion: setCertificatesInclusion: (GPGContext)
 */
typedef enum {
    GPGDefaultCertificatesInclusion       = -256,
    GPGAllExceptRootCertificatesInclusion =   -2,
    GPGAllCertificatesInclusion           =   -1,
    GPGNoCertificatesInclusion            =   -0,
    GPGOnlySenderCertificateInclusion     =    1
}GPGCertificatesInclusion;


/*!
 *  @typedef    GPGImportStatus
 *  @abstract   The 'status' value of a key import is a combination of bit
 *              values.
 *  @constant   GPGImportDeletedKeyMask Key has been removed from the
 *                                      <i>key ring</i>
 *  @constant   GPGImportNewKeyMask     Key is new in the <i>key ring</i>
 *  @constant   GPGImportNewUserIDMask  Some new userIDs has been imported, or
 *                                      updated
 *  @constant   GPGImportSignatureMask  Some new key signatures have been
 *                                      imported, or updated
 *  @constant   GPGImportSubkeyMask     Some new subkeys have been imported, or
 *                                      updated
 *  @constant   GPGImportSecretKeyMask  Key is a secret key, and is new in the
 *                                      secret <i>key ring</i>
 *  @seealso    GPGKeyringChangedNotification
 */
typedef unsigned int GPGImportStatus;

#define GPGImportDeletedKeyMask  0
#define GPGImportNewKeyMask      1
#define GPGImportNewUserIDMask   2
#define GPGImportSignatureMask   4
#define GPGImportSubkeyMask      8
#define GPGImportSecretKeyMask  16


/*!
 *  @constant   GPGKeyringChangedNotification
 *  @abstract   Posted after a modification to a <i>key ring</i> has been done.
 *  @discussion Posted after a modification to a <i>key ring</i> has been done. 
 *              For example, after an import or delete operation.
 *
 *              Object is (currently) nil.
 *
 *              This notification is also posted by the distributed notification
 *              center. object is also nil.
 *
 *              UserInfo:<dl>
 *              <dt><code>@link GPGContextKey GPGContextKey@/link</code></dt>
 *              <dd>The <code>@link //macgpg/occ/cl/GPGContext GPGContext@/link</code>
 *               object in which the operation was executed. Not available in
 *               distributed notifications.</dd>
 *              <dt><code>@link GPGChangesKey GPGChangesKey@/link</code></dt>
 *              <dd>An <code>@link //apple_ref/occ/cl/NSDictionary NSDictionary@/link</code>
 *               object whose keys are <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code> 
 *               objects (secret and public keys) and whose values are 
 *               <code>@link //apple_ref/occ/cl/NSDictionary NSDictionary@/link</code> 
 *               objects containing key-value pair <code>\@"status"</code> with
 *               a <code>@link GPGImportStatus GPGImportStatus@/link</code> (as 
 *               <code>@link //apple_ref/occ/cl/NSNumber NSNumber@/link</code>),
 *               and possibly <code>\@"error"</code> with a <code>@link //macgpg/c/tdef/GPGError GPGError@/link</code>
 *               (as <code>@link //apple_ref/occ/cl/NSNumber NSNumber@/link</code>).
 *               For distributed notifications, <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code>
 *               objects are replaced by <code>@link //apple_ref/occ/cl/NSString NSString@/link</code>
 *               objects representing the key fingerprints.</dd></dl>
 *  @seealso     //macgpg/occ/instm/GPGContext(GPGSynchronousOperations)/generateKeyFromDictionary:secretKey:publicKey: generateKeyFromDictionary:secretKey:publicKey: (GPGContext)
 *  @seealso     //macgpg/occ/instm/GPGContext(GPGSynchronousOperations)/importKeyData: importKeyData: (GPGContext)
 *  @seealso     //macgpg/occ/instm/GPGContext(GPGExtendedKeyManagement)/asyncDownloadKeys:serverOptions: asyncDownloadKeys:serverOptions: (GPGContext)
 */
GPG_EXPORT NSString	* const GPGKeyringChangedNotification;

/*!
 *  @const      GPGContextKey
 *  @abstract   Key of a <i>userInfo</i> entry in some 
 *              <code>@link //macgpg/c/data/GPGException GPGException@/link</code> 
 *              exceptions and some notifications.
 */
GPG_EXPORT NSString	* const GPGContextKey;

/*!
 *  @const      GPGChangesKey
 *  @abstract   Key of a <i>userInfo</i> entry in a
 *              <code>@link GPGKeyringChangedNotification GPGKeyringChangedNotification@/link</code>
 *              local notification and in <code>@link operationResults operationResults@/link</code>
 *              (GPGContext).
 */
GPG_EXPORT NSString	* const GPGChangesKey;


/*!
 *  @const      GPGProgressNotification
 *  @abstract   Name of the notification posted when progress information about
 *              a cryptographic operation is available, for example during key
 *              generation.
 *  @discussion For details on the progress events, see the entry for the
 *              PROGRESS status in the file doc/DETAILS of the GnuPG
 *              distribution.
 *
 *              Currently it is used only during key generation.
 *
 *              Notification is always posted in the main thread.
 *
 *              UserInfo:<dl>
 *              <dt><code>\@"description"</code></dt>
 *              <dd><code>@link //apple_ref/occ/cl/NSString NSString@/link</code>
 *               object</dd>
 *              <dt><code>\@"type"</code></dt>
 *              <dd><code>@link //apple_ref/occ/cl/NSString NSString@/link</code>
 *               object containing the letter printed during key generation.</dd>
 *              <dt><code>\@"current"</code></dt>
 *              <dd>Amount done, as <code>@link //apple_ref/occ/cl/NSNumber NSNumber@/link</code>
 *               object.</dd>
 *              <dt><code>\@"total"</code></dt>
 *              <dd>Amount to be done, as <code>@link //apple_ref/occ/cl/NSNumber NSNumber@/link</code>
 *               object. 0 means that the total amount is not known.</dd></dl>
 * current/total = 100/100 may be used to detect the end of operation.
 *  @seealso     //macgpg/occ/instm/GPGContext(GPGSynchronousOperations)/generateKeyFromDictionary:secretKey:publicKey: generateKeyFromDictionary:secretKey:publicKey: (GPGContext)
 */
GPG_EXPORT NSString	* const GPGProgressNotification;


/*!
 *  @const      GPGAsynchronousOperationDidTerminateNotification
 *  @abstract   Name of the notification posted when an asynchronous operation 
 *              on a context has been terminated.
 *  @discussion For example during extended key search, or key upload. Object is
 *              the context whose operation has just terminated, successfully or
 *              not.
 *
 *              Notification is always posted in the main thread.
 *
 *              UserInfo:<dl>
 *              <dt><code>@link //macgpg/c/data/GPGErrorKey GPGErrorKey@/link</code></dt>
 *              <dd>A <code>@link //macgpg/c/tdef/GPGError GPGError@/link</code>
 *               wrapped in a <code>@link //apple_ref/occ/cl/NSNumber NSNumber@/link</code>
 *               object</dd>
 *              <dt><code>@link //macgpg/c/data/GPGAdditionalReasonKey GPGAdditionalReasonKey@/link</code></dt>
 *              <dd>An optional <code>@link //apple_ref/occ/cl/NSString NSString@/link</code>
 *               object containing an additional unlocalized error message</dd>
 *              </dl>
 *  @seealso     //macgpg/occ/instm/GPGContext/operationResults operationResults (GPGContext)
 */
GPG_EXPORT NSString	* const GPGAsynchronousOperationDidTerminateNotification;


GPG_EXPORT NSString	* const GPGNextKeyNotification;
GPG_EXPORT NSString	* const GPGNextKeyKey;


GPG_EXPORT NSString	* const GPGNextTrustItemNotification;
GPG_EXPORT NSString	* const GPGNextTrustItemKey;


/*!
 *  @class      GPGContext 
 *  @abstract   Main object for all cryptographic operations in MacGPGME.
 *  @discussion All cryptographic operations in MacGPGME are performed within a
 *              context, which contains the internal state of the operation as
 *              well as configuration parameters. By using several contexts you
 *              can run several cryptographic operations in parallel, with
 *              different configuration.
 *              <h2>UserID search patterns (for OpenPGP protocol)</h2>
 *              For search pattern, you can give:<ul>
 *              <li>a key ID, in short or long form, prefixed or not by
 *               <code>0x</code></li>
 *              <li>a key fingerprint</li>
 *              <li>using <code>"=aString"</code>, where aString must be an
 *               exact match like
 *               <code>"=Heinrich Heine &lt;heinrichh\@uni-duesseldorf.de&gt;"</code></li>
 *              <li>using the email address part, matching exactly:
 *               <code>"&lt;heinrichh\@uni-duesseldorf.de&gt;"</code></li>
 *              <li>using a format like this: <code>"+Heinrich Heine duesseldorf"</code>.
 *               All words must match exactly (not case sensitive) but can
 *               appear in any order in the user ID. Words are any sequences of
 *               letters, digits, the underscore and all characters with bit 7
 *               set.</li>
 *              <li>or a substring matching format like that: <code>"Heine"</code>
 *               or <code>"*Heine"</code>. By case insensitive substring
 *               matching. This is the default mode but applications may want to
 *               explicitely indicate this by putting the asterisk in front.</li>
 *              </ul>
 *              <h2>Notations</h2>
 *              You can attach arbitrary notation data to a signature. This
 *              information is then available to the user when the signature is
 *              verified. Use method
 *              <code>@link addSignatureNotationWithName:value:flags: addSignatureNotationWithName:value:flags:@/link</code>
 *              to set notation data to a signature the context will create.
 */
@interface GPGContext : GPGObject <NSCopying>
{     
    id					_passphraseDelegate; // Passphrase delegate, not retained.
    int					_operationMask;
    NSMutableDictionary	*_operationData;
    id					_userInfo; // Object set by user; not used by GPGContext itself.
    NSMutableSet		*_signerKeys;
    NSArray             *_engines;
}

/*!
 *  @method     copyWithZone:
 *  @abstract   <code>@link //apple_ref/occ/intf/NSCopying NSCopying@/link</code>
 *              protocol implementation.
 *  @discussion Copies engine configurations, as well as all context attributes 
 *              except passphrase delegate, user info dictionary and 
 *              signature notations.
 *  @param      zone Memory zone.
 *  @result     A new retained context with the same parameters.
 */
- (id) copyWithZone:(NSZone *)zone;


/*!
 *  @methodgroup Initializer
 */

/*!
 *  @method     init
 *  @abstract   Designated initializer
 *  @discussion Designated initializer. Creates a new context used to hold the
 *              configuration, status and result of cryptographic operations.
 *
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception; in this case, a <code>@link //apple_ref/occ/intfm/NSObject/release release@/link</code>
 *              is sent to self.
 */
- (id) init;


/*!
 * @methodgroup ASCII armor
 */

/*!
 *  @method     setUsesArmor:
 *  @abstract   Enables or disables the use of an <i>ASCII armor</i> for all
 *              output.
 *  @discussion Default value is <code>NO</code>.
 *  @param      armor <code>YES</code> or <code>NO</code>.
 */
- (void) setUsesArmor:(BOOL)armor;

/*!
 *  @method     usesArmor
 *  @abstract   Returns whether context uses <i>ASCII armor</i> or not.
 *  @discussion Default value is <code>NO</code>.
 */
- (BOOL) usesArmor;


/*!
 * @methodgroup Text mode
 */
/*!
 *  @method     setUsesTextMode:
 *  @abstract   Enables or disables the use of the special <i>text mode</i>.
 *  @discussion <i>Text mode</i> is for example used for MIME (RFC2015)
 *              signatures; note that the updated RFC 3156 mandates that the
 *              mail user agent does some preparations so that <i>text mode</i>
 *              is not needed anymore.
 *
 *              This option is only relevant to the OpenPGP crypto engine, and
 *              ignored by all other engines.
 * 
 *              Default value is <code>NO</code>.
 *  @param      mode <code>YES</code> or <code>NO</code>.
 */
- (void) setUsesTextMode:(BOOL)mode;

/*!
 *  @method     usesTextMode
 *  @abstract   Returns whether context uses <i>text mode</i> or not.
 *  @discussion Default value is <code>NO</code>.
 */
- (BOOL) usesTextMode;


/*!
 * @methodgroup Key listing mode
 */

/*!
 *  @method     setKeyListMode:
 *  @abstract   Changes the default behaviour of the key listing methods.
 *  @discussion The value in <i>mask</i> is a bitwise-OR combination of one or
 *              multiple bit values like 
 *              <code>@link GPGKeyListModeLocal GPGKeyListModeLocal@/link</code>
 *              and <code>@link GPGKeyListModeExtern GPGKeyListModeExtern@/link</code>.
 *
 *              At least <code>@link GPGKeyListModeLocal GPGKeyListModeLocal@/link</code>
 *              or <code>@link GPGKeyListModeExtern GPGKeyListModeExtern@/link</code>
 *              must be specified. For future binary compatibility, you should
 *              get the current mode with <code>@link //macgpg/occ/instm/GPGContext/keyListMode keyListMode@/link</code>
 *              and modify it by setting or clearing the appropriate bits, 
 *              and then using that calculated value in 
 *              <code>@link setKeyListMode: setKeyListMode:@/link</code>. This
 *              will leave all other bits in the mode value intact (in
 *              particular those that are not used in the current version of the
 *              library).
 *  @param      mask Bit field
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              (<code>@link //macgpg/c/econst/GPGErrorInvalidValue GPGErrorInvalidValue@/link</code>) 
                exception in case <i>mask</i> is not a valid mode.
 */
- (void) setKeyListMode:(GPGKeyListMode)mask;

/*!
 *  @method     keyListMode
 *  @abstract   Returns the current key listing mode of the context.
 *  @discussion Returns the current key listing mode of the context. This value
 *              can then be modified and used in a subsequent 
 *              <code>@link setKeyListMode: setKeyListMode:@/link</code>
 *              invocation to only affect the desired bits (and leave all others
 *              intact).
 *
 *              <code>@link GPGKeyListModeLocal GPGKeyListModeLocal@/link</code>
 *              is the default mode.
 */
- (GPGKeyListMode) keyListMode;


/*!
 * @methodgroup Protocol selection
 */

/*!
 *  @method     setProtocol:
 *  @abstract   Sets the protocol and thus the crypto engine to be used by the 
 *              context.
 *  @discussion All crypto operations will be performed by the crypto engine
 *              configured for that protocol.
 *
 *              Currently, the OpenPGP and the CMS protocols are supported. A
 *              new context uses the OpenPGP engine by default.
 *
 *              Setting the protocol with <code>@link setProtocol: setProtocol:@/link</code>
 *              does not check if the crypto engine for that protocol is
 *              available and installed correctly.
 *  @param      protocol MacGPGME protocol.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception.
 */
- (void) setProtocol:(GPGProtocol)protocol;

/*!
 *  @method     protocol
 *  @abstract   Returns the protocol currently used by the context.
 */
- (GPGProtocol) protocol;


/*!
 * @methodgroup Passphrase delegate
 */

/*!
 *  @method     setPassphraseDelegate:
 *  @abstract   Allows a delegate to be used to pass a passphrase to the
 *              engine.
 *  @discussion For OpenPGP, the preferred way to handle passphrases is by using
 *              the <code>gpg-agent</code>, but because that beast is not ready
 *              for real use, you can use this passphrase thing.
 *
 *              Not all crypto engines require this callback to retrieve the
 *              passphrase. It is better if the engine retrieves the passphrase
 *              from a trusted agent (a daemon process), rather than having each
 *              user to implement their own passphrase query. Some engines do
 *              not even support an external passphrase callback at all, in this
 *              case a <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception with error code <code>@link //macgpg/c/econst/GPGErrorNotSupported GPGErrorNotSupported@/link</code>
 *              is returned.
 *
 *              <i>delegate</i> must respond to
 *              <code>@link context:passphraseForKey:again: context:passphraseForKey:again:@/link</code> (<code>@link NSObject(GPGContextDelegate) GPGContextDelegate@/link</code>
 *              informal protocol). <i>delegate</i> is not retained.
 *
 *              The user can disable the use of a passphrase callback by calling
 *              <code>@link setPassphraseDelegate: setPassphraseDelegate:@/link</code>
 *              with nil as argument.
 *  @param      delegate Object implementing
 *              <code>@link NSObject(GPGContextDelegate) GPGContextDelegate@/link</code>
 *              informal protocol
 */
- (void) setPassphraseDelegate:(id)delegate;

/*!
 *  @method     passphraseDelegate
 *  @abstract   Returns the delegate providing the passphrase.
 *  @discussion Initially nil.
 */
- (id) passphraseDelegate;


/*!
 * @methodgroup Selecting signers
 */

/*!
 *  @method     clearSignerKeys
 *  @abstract   Removes the list of signers from the context.
 *  @discussion Every context starts with an empty list.
 */
- (void) clearSignerKeys;

/*!
 *  @method     addSignerKey:
 *  @abstract   Adds <i>key</i> to the list of signers in the context.
 *  @discussion <i>key</i> is retained.
 *  @param      key Key used for sign operations (retained).
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception.
 */
- (void) addSignerKey:(GPGKey *)key;

/*!
 *  @method     signerKeyEnumerator
 *  @abstract   Returns an enumerator of 
 *              <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code> objects,
 *              from the list of signers.
 */
- (NSEnumerator *) signerKeyEnumerator;

/*!
 *  @method     signerKeys
 *  @abstract   Convenience method. Returns <code>[[self signerKeyEnumerator] allObjects]</code>.
 */
- (NSArray *) signerKeys;


/*!
 * @methodgroup Including certificates (S/MIME only)
 */

/*!
 *  @method     setCertificatesInclusion:
 *  @abstract   Specifies how many certificates should be included in an S/MIME
 *              signed message.
 *  @discussion By default, only the sender's certificate is included. The
 *              possible values of <i>includedCertificatesNumber</i> are defined
 *              in <code>@link GPGCertificatesInclusion GPGCertificatesInclusion@/link</code>
 *              enum type.
 *
 *              This option is only relevant to the CMS crypto engine, and
 *              ignored by all other engines.
 *  @param      includedCertificatesNumber Number of certificates
 */
- (void) setCertificatesInclusion:(int)includedCertificatesNumber;

/*!
 *  @method     certificatesInclusion
 *  @abstract   Returns the number of certificates to include in an S/MIME 
 *              message.
 */
- (int) certificatesInclusion;


/*!
 * @methodgroup Operation results
 */

/*!
 *  @method     operationResults
 *  @abstract   Returns a dictionary containing results of last operation on 
 *              context.
 *  @discussion Contents of the dictionary depends on last operation type
 *              (signing, decrypting, etc.), and method can be called even after
 *              last operation failed and raised an exception: method could
 *              return partial valid data. Dictionary always contains the result
 *              error of the last operation under key <code>@link //macgpg/c/data/GPGErrorKey GPGErrorKey@/link</code>.
 *
 *              If last operation was an <b>encryption</b> operation, dictionary
 *              can contain:<dl>
 *              <dt><code><code>\@"keyErrors"</code></code></dt>
 *              <dd>Dictionary containing <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code>
 *               objects as keys, and <code>@link //apple_ref/occ/cl/NSNumber NSNumber@/link</code>
 *               objects wrapping <code>@link //macgpg/c/tdef/GPGError GPGError@/link</code>
 *               as values.</dd>
 *              <dt><code>\@"cipher"</code></dt>
 *              <dd><code>@link //macgpg/occ/cl/GPGData GPGData@/link</code> object
 *               with encrypted data; only valid keys were used.</dd></dl>
 *
 *              If last operation was a <b>signing</b> operation, dictionary can 
 *              contain:<dl>
 *              <dt><code>\@"signedData"</code></dt>
 *              <dd><code>@link //macgpg/occ/cl/GPGData GPGData@/link</code>
 *               object with signed data; only valid secret keys were used.</dd>
 *              <dt><code>\@"newSignatures"</code></dt>
 *              <dd>Array of <code>@link //macgpg/occ/cl/GPGSignature GPGSignature@/link</code>
 *               objects.</dd>
 *              <dt><code>\@"keyErrors"</code></dt>
 *              <dd>Dictionary containing <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code>
 *               objects as keys, and <code>@link //apple_ref/occ/cl/NSNumber NSNumber@/link</code>
 *               objects wrapping <code>@link //macgpg/c/tdef/GPGError GPGError@/link</code>
 *               as values.</dd></dl>
 *
 *              If last operation was a <b>verification</b> operation, 
 *              dictionary can contain:<dl>
 *              <dt><code>\@"signatures"</code></dt>
 *              <dd>An array of <code>@link //macgpg/occ/cl/GPGSignature GPGSignature@/link</code>
 *               object. Same result is returned by
 *               <code>@link //macgpg/occ/instm/GPGContext(GPGSynchronousOperations)/signatures signatures@/link</code>.</dd>
 *              <dt><code>\@"filename"</code></dt>
 *              <dd>The original file name of the plaintext message, if
 *               available.</dd></dl>
 *
 *              If last operation was a <b>decryption</b> operation, dictionary 
 *              can contain:<dl>
 *              <dt><code>\@"unsupportedAlgorithm"</code></dt>
 *              <dd>A string describing the algorithm used for encryption, 
 *               which is not known by the engine for decryption.</dd>
 *              <dt><code>\@"wrongKeyUsage"</code></dt>
 *              <dd>A boolean result as a <code>@link //apple_ref/occ/cl/NSNumber NSNumber@/link</code>
 *               object indicating that the key should not have been used for
 *               encryption.</dd>
 *              <dt><code>\@"filename"</code></dt>
 *              <dd>The original file name of the plaintext message, if 
 *               available.</dd>
 *              <dt><code>\@"keyErrors"</code></dt>
 *              <dd>A dictionary containing <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code>
 *               objects as keys, and <code>@link //apple_ref/occ/cl/NSNumber NSNumber@/link</code>
 *               objects wrapping <code>@link //macgpg/c/tdef/GPGError GPGError@/link</code> 
 *               as values. Contains all keys used for encryption.</dd></dl>
 *
 *              If last operation was an <b>import</b> operation, dictionary can
 *              contain:<dl>
 *              <dt><code>@link GPGChangesKey GPGChangesKey@/link</code></dt>
 *              <dd>See <code>@link GPGKeyringChangedNotification GPGKeyringChangedNotification@/link</code>
 *               notification for more information about <code>@link GPGChangesKey GPGChangesKey@/link</code>.</dd>
 *              <dt><code>\@"consideredKeyCount"</code></dt>
 *              <dd>Total number of considered keys</dd>
 *              <dt><code>\@"keysWithoutUserIDCount"</code></dt>
 *              <dd>Number of keys without user ID</dd>
 *              <dt><code>\@"importedKeyCount"</code></dt>
 *              <dd>Total number of imported keys</dd>
 *              <dt><code>\@"importedRSAKeyCount"</code></dt>
 *              <dd>Number of imported RSA keys</dd>
 *              <dt><code>\@"unchangedKeyCount"</code></dt>
 *              <dd>Number of unchanged keys</dd>
 *              <dt><code>\@"newUserIDCount"</code></dt>
 *              <dd>Number of new user IDs</dd>
 *              <dt><code>\@"newSubkeyCount"</code></dt>
 *              <dd>Number of new subkeys</dd>
 *              <dt><code>\@"newSignatureCount"</code></dt>
 *              <dd>Number of new signatures</dd>
 *              <dt><code>\@"newRevocationCount"</code></dt>
 *              <dd>Number of new revocations</dd>
 *              <dt><code>\@"readSecretKeyCount"</code></dt>
 *              <dd>Total number of secret keys read</dd>
 *              <dt><code>\@"importedSecretKeyCount"</code></dt>
 *              <dd>Number of imported secret keys</dd>
 *              <dt><code>\@"unchangedSecretKeyCount"</code></dt>
 *              <dd>Number of unchanged secret keys</dd>
 *              <dt><code>\@"skippedNewKeyCount"</code></dt>
 *              <dd>Number of new keys skipped</dd>
 *              <dt><code>\@"notImportedKeyCount"</code></dt>
 *              <dd>Number of keys not imported</dd></dl>
 *
 *              If last operation was a <b>key generation</b> operation,
 *              dictionary can contain:<dl>
 *              <dt><code>@link GPGChangesKey GPGChangesKey@/link</code></dt>
 *              <dd>See <code>@link GPGKeyringChangedNotification GPGKeyringChangedNotification@/link</code>
 *               notification for more information about <code>@link GPGChangesKey GPGChangesKey@/link</code>.</dd></dl>
 *
 *              If last operation was a <b>key deletion</b> operation, 
 *              dictionary can contain:<dl>
 *              <dt><code>\@"deletedKeyFingerprints"</code></dt>
 *              <dd>An array of strings representing the fingerprints of the 
 *               deleted keys.</dd></dl>
 *
 *              If last operation was a <b>key enumeration</b> operation, 
 *              dictionary can contain:<dl>
 *              <dt><code>\@"truncated"</code></dt>
 *              <dd>A boolean result as a <code>@link //apple_ref/occ/cl/NSNumber NSNumber@/link</code>
 *               object indicating whether all matching keys were listed or
 *               not.</dd></dl>
 *
 *              If last operation was a <b>remote key search</b> operation, 
 *              dictionary can contain:<dl>
 *              <dt><code>\@"keys"</code></dt>
 *              <dd>An array of <code>@link //macgpg/occ/cl/GPGRemoteKey GPGRemoteKey@/link</code>
 *               objects: these are not usable keys, they contain no other
 *               information than key ID, algorithm, algorithm description, 
 *               length, creation date, expiration date, user IDs, revocation;
 *               user IDs are also <code>@link //macgpg/occ/cl/GPGRemoteUserID GPGRemoteUserID@/link</code>
 *               objects that contain no other information than user ID
 *               description. Returned information depends on servers.</dd>
 *              <dt><code>\@"hostName"</code></dt>
 *              <dd>Contacted server's host name</dd>
 *              <dt><code>\@"port"</code></dt>
 *              <dd>Port used to contact server, if not default one</dd>
 *              <dt><code>\@"protocol"</code></dt>
 *              <dd>Protocol used to contact server (ldap, x-hkp, hkp, http,
 *               finger)</dd>
 *              <dt><code>\@"options"</code></dt>
 *              <dd>Options used to contact server</dd></dl>
 *
 *              If last operation was a <b>key download</b> operation,
 *              dictionary can contain:<dl>
 *              <dt><code>\@"hostName"</code></dt>
 *              <dd>Contacted server's host name</dd>
 *              <dt><code>\@"port"</code></dt>
 *              <dd>Port used to contact server, if not default one</dd>
 *              <dt><code>\@"protocol"</code></dt>
 *              <dd>Protocol used to contact server (ldap, x-hkp, hkp, http,
 *               finger)</dd>
 *              <dt><code>\@"options"</code></dt>
 *              <dd>Options used to contact server</dd></dl>
 *              and additional results from the import operation.
 */
- (NSDictionary *) operationResults;


/*!
 * @methodgroup Contextual information
 */

/*!
 *  @method     setUserInfo:
 *  @abstract   Sets the userInfo object, containing additional data the target
 *              may use in a callback.
 *  @discussion Sets the userInfo object, containing additional data the target
 *              may use in a callback, for example when delegate is asked for
 *              passphrase. <i>userInfo</i> is simply retained.
 *  @param      userInfo Object that is retained by the context.
 */
- (void) setUserInfo:(id)userInfo;

/*!
 *  @method     userInfo
 *  @abstract   Returns the userInfo object.
 *  @discussion Returns the userInfo object, containing additional data the
 *              target may use in a callback, for example when delegate is asked
 *              for passphrase.
 */
- (id) userInfo;


/*!
 * @methodgroup Signature notations    
 */

/*!
 *  @method     clearSignatureNotations
 *  @abstract   Clears all notation data from the context.
 *  @discussion Subsequent signing operations from this context will not include
 *              any notation data.
 *
 *              Every context starts with an empty notation data list.
 */
- (void) clearSignatureNotations;

/*!
 *  @method     addSignatureNotationWithName:value:flags:
 *  @abstract   Adds the human-readable notation data with <i>name</i> name and
 *              <i>value</i> value to the context, using the <i>flags</i> flags.
 *  @discussion If <i>name</i> is nil, then <i>value</i> must be a policy URL,
 *              as a <code>@link //apple_ref/occ/cl/NSString NSString@/link</code>;
 *              the notation data is forced not to be a human-readable notation
 *              data.
 *
 *              If <i>name</i> is not nil, then <i>value</i> may be a <code>@link //apple_ref/occ/cl/NSString NSString@/link</code>
 *              object (the notation data is forced to be a human-readable
                notation data). Else <i>value</i> has to be a
 *              <code>@link //apple_ref/occ/cl/NSData NSData@/link</code>
 *              object, and notation data is forced not to be a human-readable
 *              notation data. Note that a user notation name must contain the
 *              '<code>\@</code>' character and must have only printable
 *              characters or spaces.
 *
 *              Subsequent signing operations will include this notation data,
 *              as well as any other notation data that was added since the
 *              creation of the context or the last <code>@link clearSignatureNotations clearSignatureNotations@/link</code>
 *              invocation.
 *
 *              <strong>WARNING:</strong> Non-human-readable notation data is
 *              currently not supported.
 *
 *              <strong>WARNING:</strong> Notations are silently ignored if user
 *              configured <code>gpg</code> with <code>force-v3-sigs</code>
 *              option on.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception for any error that is reported by the crypto engine
 *              support routines.
 *  @param      name Notation data name
 *  @param      value Notation data value
 *  @param      flags Notation data flags
 */
- (void) addSignatureNotationWithName:(NSString *)name value:(id)value flags:(GPGSignatureNotationFlags)flags;

/*!
 *  @method     signatureNotations
 *  @abstract   Returns the signature notations (as <code>@link //macgpg/occ/cl/GPGSignatureNotation GPGSignatureNotation@/link</code>
 *              objects) for this context.
 */
- (NSArray *) signatureNotations;


/*!
 * @methodgroup Engines
 */

/*!
 *  @method     engines
 *  @abstract   Returns the engines (as <code>@link //macgpg/occ/cl/GPGEngine GPGEngine@/link</code>
 *              objects) used by the current context.
 */
- (NSArray *) engines;

/*!
 *  @method     engine
 *  @abstract   Convenience method. Returns the engine for the protocol 
 *              currently used.
 */
- (GPGEngine *) engine;

/*!
 *  @method     options
 *  @abstract   Convenience method. Returns the options file of currently used
 *              engine.
 *  @discussion Will return a new instance on each invocation. If you change the
 *              engine or its home directory, you need to ask for a new
 *              <code>@link //macgpg/occ/cl/GPGOptions GPGOptions@/link</code> 
 *              instance.
 */
- (GPGOptions *) options;

@end


/*!
 *  @category   GPGContext(GPGAsynchronousOperations)
 *  @abstract   Asynchronous operations (<strong>Note that asynchronous 
 *              operations don't work right now.</strong>)
 */
@interface GPGContext(GPGAsynchronousOperations)

/*!
 *  @method     waitOnAnyRequest:
 *  @abstract   Waits for any finished request.
 *  @discussion Waits for any finished request. When <i>hang</i> is <code>YES</code>
 *              the method will wait, otherwise it will return immediately when
 *              there is no pending finished request.
 *
 *              Returns the context of the finished request or nil if 
 *              <i>hang</i> is <code>NO</code> and no request has finished.
 *  @param      hang <code>NO</code> will return immediately, <code>YES</code>
 *              will wait.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception which reflects the termination status of the 
 *              operation (in case of error). The exception's userInfo
 *              dictionary contains the context (under <code>@link GPGContextKey GPGContextKey@/link</code>
 *              key) which terminated with the error. An exception without any
 *              context could also be raised.
 */
+ (GPGContext *) waitOnAnyRequest:(BOOL)hang;

/*!
 *  @method     wait:
 *  @abstract   Continues the pending operation within the context.
 *  @discussion Continues the pending operation within the context. In
 *              particular, it ensures the data exchange between MacGPGME and
 *              the crypto back-end and watches over the run time status of the
 *              back-end process.
 *
 *              If <i>hang</i> is <code>YES</code> the method does not return
 *              until the operation is completed or cancelled. Otherwise the
 *              method will not block for a long time.
 *
 *              Returns <code>YES</code> if there is a finished request for
 *              context or <code>NO</code> if <i>hang</i> is <code>NO</code> and
 *              no request (for context) has finished.
 *  @param      hang <code>NO</code> will return immediately, <code>YES</code> 
 *              will wait.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception which reflects the termination status of the 
 *              operation (in case of error). The exception's userInfo
 *              dictionary contains the context (under <code>@link GPGContextKey GPGContextKey@/link</code>
 *              key) which terminated with the error.
 */
- (BOOL) wait:(BOOL)hang;

/*!
 *  @method     cancel
 *  @abstract   Attempts to cancel a pending operation in the context.
 *  @discussion This only works if you use the global event loop or your own
 *              event loop.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception if the cancellation failed (in this case the state of
 *              context is not modified).
 */
- (void) cancel;
@end


/*!
 *  @category   GPGContext(GPGSynchronousOperations)
 *  @abstract   Synchronous operations
 */
@interface GPGContext(GPGSynchronousOperations)

/*!
 * @methodgroup Decrypt
 */

/*!
 *  @method     decryptedData:
 *  @abstract   Decrypts the ciphertext in the <i>inputData</i> data and returns
 *              the plain data.
 *  @discussion Returned data's filename is set automatically, when available.
 *  @param      inputData Encrypted data.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception with error code:<dl>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorNoData GPGErrorNoData@/link</code></dt>
 *              <dd><i>inputData</i> does not contain any data to decrypt.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorDecryptionFailed GPGErrorDecryptionFailed@/link</code></dt>
 *              <dd><i>inputData</i> is not a valid cipher text.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorBadPassphrase GPGErrorBadPassphrase@/link</code></dt>
 *              <dd>The passphrase for the secret key could not be retrieved.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorCancelled GPGErrorCancelled@/link</code></dt>
 *              <dd>User cancelled operation, e.g. when asked for passphrase</dd></dl>
 *              Other exceptions could be raised too.
 */
- (GPGData *) decryptedData:(GPGData *)inputData;


/*!
 * @methodgroup Verify
 */

/*!
 *  @method     verifySignatureData:againstData:
 *  @abstract   Performs a signature check on the <i>detached</i> signature
 *              given in <i>signatureData</i> (plaintext). Returns an array of
 *              <code>@link //macgpg/occ/cl/GPGSignature GPGSignature@/link</code>
 *              objects, by invoking <code>@link //macgpg/occ/instm/GPGContext(GPGSynchronousOperations)/signatures signatures@/link</code>.
 *  @param      signatureData Detached signature data
 *  @param      inputData Signed data
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              (<code>@link //macgpg/c/econst/GPGErrorNoData GPGErrorNoData@/link</code>)
 *              exception when <i>inputData</i> does not contain any data to
 *              verify. Other exceptions could be raised too.
 */
- (NSArray *) verifySignatureData:(GPGData *)signatureData againstData:(GPGData *)inputData;

/*!
 *  @method     verifySignedData:
 *  @abstract   Performs a signature check on <i>signedData</i>.
 *  @discussion This methods invokes <code>@link verifySignedData:originalData: verifySignedData:originalData:@/link</code>
 *              with <i>originalDataPtr</i> set to NULL.
 *  @param      signedData Signed data
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              (<code>@link //macgpg/c/econst/GPGErrorNoData GPGErrorNoData@/link</code>)
 *              exception when <i>signedData</i> does not contain any data to
 *              verify. Other exceptions could be raised too.
 */
- (NSArray *) verifySignedData:(GPGData *)signedData;

/*!
 *  @method     verifySignedData:originalData:
 *  @abstract   Performs a signature check on <i>signedData</i>.
 *  @discussion Returns an array of <code>@link //macgpg/occ/cl/GPGSignature GPGSignature@/link</code>
 *              objects. <i>originalDataPtr</i> will contain (on success) the
 *              data that has been signed, with eventually the original file
 *              name. It can be NULL.
 *  @param      signedData Signed data
 *  @param      originalDataPtr Data without signature, on return.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              (<code>@link //macgpg/c/econst/GPGErrorNoData GPGErrorNoData@/link</code>)
 *              exception when <i>signedData</i> does not contain any data to
 *              verify. Other exceptions could be raised too.
 */
- (NSArray *) verifySignedData:(GPGData *)signedData originalData:(GPGData **)originalDataPtr;

/*!
 *  @method     signatures
 *  @abstract   Returns an array of <code>@link //macgpg/occ/cl/GPGSignature GPGSignature@/link</code> 
 *              objects
 *  @discussion Returns an array of <code>@link //macgpg/occ/cl/GPGSignature GPGSignature@/link</code> 
 *              objects after <code>@link verifySignedData: verifySignedData:@/link</code>,
 *              <code>@link verifySignedData:originalData: verifySignedData:originalData:@/link</code>,
 *              <code>@link verifySignatureData:againstData: verifySignatureData:againstData:@/link</code> or
 *              <code>@link decryptedData:signatures: decryptedData:signatures:@/link</code>
 *              has been called. A single detached signature can contain
 *              signatures by more than one key. Returns nil if operation was
 *              not a verification.
 *
 *              After <code>@link decryptedData:signatures: decryptedData:signatures:@/link</code>,
 *              a <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception with error code <code>@link //macgpg/c/econst/GPGErrorNoData GPGErrorNoData@/link</code>
 *              counts as successful in this case.
 */
- (NSArray *) signatures;

    
/*!
 * @methodgroup Decrypt and verify
 */

/*!
 *  @method     decryptedData:signatures:
 *  @abstract   Decrypts the ciphertext in <i>inputData</i> and returns it as
 *              plain.
 *  @discussion If cipher contains signatures, they will be verified and
 *              returned in *<i>signaturesPtr</i>, if <i>signaturesPtr</i> is
 *              not NULL, by invoking
 *              <code>@link //macgpg/occ/instm/GPGContext(GPGSynchronousOperations)/signatures signatures@/link</code>.
 *              Returned data's file name is set automatically, when available.
 *
 *              With OpenPGP engine, user has 3 attempts for passphrase in case
 *              of public key encryption, else only 1 attempt, before raising an
 *              exception.
 *  @param      inputData Encrypted (and eventually signed) data
 *  @param      signaturesPtr Array of <code>@link //macgpg/occ/cl/GPGSignature GPGSignature@/link</code>
 *              objects on return
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception with error code:<dl>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorNoData GPGErrorNoData@/link</code></dt>
 *              <dd><i>inputData</i> does not contain any data to decrypt.
 *               However, it might still be signed. The information about 
 *               detected signatures is available with
 *               <code>@link //macgpg/occ/instm/GPGContext(GPGSynchronousOperations)/signatures signatures@/link</code>
 *               in this case.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorDecryptionFailed GPGErrorDecryptionFailed@/link</code></dt>
 *              <dd><i>inputData</i> is not a valid cipher text.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorBadPassphrase GPGErrorBadPassphrase@/link</code></dt>
 *              <dd>The passphrase for the secret key could not be retrieved.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorCancelled GPGErrorCancelled@/link</code></dt>
 *              <dd>User cancelled operation, e.g. when asked for passphrase</dd></dl>
 *              Other exceptions could be raised too.
 */
- (GPGData *) decryptedData:(GPGData *)inputData signatures:(NSArray **)signaturesPtr;


/*!
 * @methodgroup Sign
 */

/*!
 *  @method     signedData:signatureMode:
 *  @abstract   Creates a signature for the text in <i>inputData</i> and returns
 *              either the signed data or a detached signature, depending on
 *              <i>mode</i>.
 *  @discussion Data will be signed using either the default key (defined in
 *              engine configuration file) or the ones defined in context. The
 *              type of the signature created is determined by the
 *              <i>ASCII armor</i> and <i>text mode</i> attributes set for the
 *              context and the requested signature mode <i>mode</i>.
 *
 *              A signature can contain signatures by one or more keys. The set
 *              of keys used to create a signatures is contained in the context,
 *              and is applied to all following signing operations in the 
 *              context (until the set is changed).
 *
 *              If an S/MIME signed message is created using the CMS crypto
 *              engine, the number of certificates to include in the message can
 *              be specified with <code>@link setCertificatesInclusion: setCertificatesInclusion:@/link</code>.
 * 
 *              Note that settings done by <code>@link setUsesArmor: setUsesArmor:@/link</code>
 *              and <code>@link setUsesTextMode: setUsesTextMode:@/link</code>
 *              are ignored for <code>@link GPGSignatureModeClear GPGSignatureModeClear@/link</code>
 *              mode.
 *
 *              With OpenPGP engine, user has 3 attempts for passphrase, before
 *              method raises an exception.
 *  @param      inputData Data to sign
 *  @param      mode Signature mode
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception with error code:<dl>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorNoData GPGErrorNoData@/link</code></dt>
 *              <dd>The signature could not be created.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorBadPassphrase GPGErrorBadPassphrase@/link</code></dt>
 *              <dd>The passphrase for the secret key could not be retrieved.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorUnusableSecretKey GPGErrorUnusableSecretKey@/link</code></dt>
 *              <dd>There are invalid signers.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorCancelled GPGErrorCancelled@/link</code></dt>
 *              <dd>User cancelled operation, e.g. when asked for passphrase.</dd></dl>
 *              Other exceptions could be raised too.
 */
- (GPGData *) signedData:(GPGData *)inputData signatureMode:(GPGSignatureMode)mode;


/*!
 * @methodgroup Encrypt
 */

/*!
 *  @method     encryptedData:withKeys:trustAllKeys:
 *  @abstract   Encrypts the plaintext in <i>inputData</i> with the keys and
 *              returns the ciphertext.
 *  @discussion The type of the ciphertext created is determined by the
 *              <i>ASCII armor</i> and <i>text mode</i> attributes set for the 
 *              context.
 *
 *              The <i>recipientKeys</i> parameters may not be nil, nor be an
 *              empty array. It can contain
 *              <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code> objects
 *              and <code>@link //macgpg/occ/cl/GPGKeyGroup GPGKeyGroup@/link</code>
 *              objects; you can mix them.
 *
 *              If the <i>trustAllKeys</i> parameter is set to <code>YES</code>,
 *              then all passed keys will be trusted, even if the keys do not
 *              have a high enough validity in the <i>key ring</i>. This flag
 *              should be used with care; in general it is not a good idea to
 *              use any untrusted keys.
 *  @param      inputData Data to encrypt
 *  @param      recipientKeys Keys and key groups to use for encryption
 *  @param      trustAllKeys Ignore <i>key ring</i> trust validities when <code>YES</code>
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception with error code:<dl>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorUnusablePublicKey GPGErrorUnusablePublicKey@/link</code></dt>
 *              <dd>Some recipients in <i>recipientKeys</i> are invalid, but not
 *               all. In this case the plaintext might be encrypted for all
 *               valid recipients and returned in <code>@link operationResults operationResults@/link</code>,
 *               for key <code>\@"cipher"</code> (if this happens depends on the
 *               crypto engine). More information about the invalid recipients
 *               is available in <code>@link operationResults operationResults@/link</code>,
 *               under key <code>\@"keyErrors"</code> which has a dictionary as
 *               value; that dictionary uses <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code>
 *               objects as keys, and <code>@link //apple_ref/occ/cl/NSNumber NSNumber@/link</code>
 *               objects wrapping 
 *               <code>@link //macgpg/c/tdef/GPGError GPGError@/link</code> as
 *               values.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorGeneralError GPGErrorGeneralError@/link</code></dt>
 *              <dd>For example, some keys were not trusted. See
 *               <code>@link operationResults operationResults@/link</code>,
 *               under key <code>\@"keyErrors"</code>.</dd></dl>
 *              Other exceptions could be raised too.
 */
- (GPGData *) encryptedData:(GPGData *)inputData withKeys:(NSArray *)recipientKeys trustAllKeys:(BOOL)trustAllKeys;


/*!
 * @methodgroup Encrypt and Sign
 */

/*!
 *  @method     encryptedSignedData:withKeys:trustAllKeys:
 *  @abstract   Signs then encrypts, in one operation, the plaintext in 
 *              <i>inputData</i> for the recipients and returns the ciphertext.
 *  @discussion The type of the ciphertext created is determined by the
 *              <i>ASCII armor</i> and <i>text mode</i> attributes set for the
 *              context. The signers are set using 
 *              <code>@link addSignerKey: addSignerKey:@/link</code>.
 *
 *              This combined encrypt and sign operation is currently only
 *              available for the OpenPGP crypto engine.
 *
 *              The <i>keys</i> array can contain <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code>
 *              objects and <code>@link //macgpg/occ/cl/GPGKeyGroup GPGKeyGroup@/link</code>
 *              objects; you can mix them.
 *  @param      inputData Data to sign and encrypt
 *  @param      keys Keys and key groups to use for encryption
 *  @param      trustAllKeys Ignore <i>key ring</i> trust validities when <code>YES</code>
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception with error code:<dl>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorNoData GPGErrorNoData@/link</code></dt>
 *              <dd>The signature could not be created.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorBadPassphrase GPGErrorBadPassphrase@/link</code></dt>
 *              <dd>The passphrase for the secret key could not be retrieved.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorUnusableSecretKey GPGErrorUnusableSecretKey@/link</code></dt>
 *              <dd>There are invalid signers.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorCancelled GPGErrorCancelled@/link</code></dt>
 *              <dd>User cancelled operation, e.g. when asked for passphrase.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorUnusablePublicKey GPGErrorUnusablePublicKey@/link</code></dt>
 *              <dd>Some recipients in <i>keys</i> are invalid, but not
 *               all. In this case the plaintext might be encrypted for all
 *               valid recipients and returned in <code>@link operationResults operationResults@/link</code>,
 *               for key <code>\@"cipher"</code> (if this happens depends on the
 *               crypto engine). More information about the invalid recipients
 *               is available in <code>@link operationResults operationResults@/link</code>,
 *               under key <code>\@"keyErrors"</code> which has a dictionary as
 *               value; that dictionary uses <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code>
 *               objects as keys, and <code>@link //apple_ref/occ/cl/NSNumber NSNumber@/link</code> objects wrapping 
 *               <code>@link //macgpg/c/tdef/GPGError GPGError@/link</code> as
 *               values.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorGeneralError GPGErrorGeneralError@/link</code></dt>
 *              <dd>For example, some keys were not trusted. See
 *               <code>@link operationResults operationResults@/link</code>,
 *               under key <code>\@"keyErrors"</code>.</dd></dl>
 *              Other exceptions could be raised too.
 */
- (GPGData *) encryptedSignedData:(GPGData *)inputData withKeys:(NSArray *)keys trustAllKeys:(BOOL)trustAllKeys;


/*!
 * @methodgroup Symmetric Encryption (no key needed)
 */

/*!
 *  @method     encryptedData:
 *  @abstract   Encrypts the plaintext in <i>inputData</i> using symmetric 
 *              encryption (rather than public key encryption) and returns the
 *              ciphertext.
 *  @discussion The type of the ciphertext created is determined by the
 *              <i>ASCII armor</i> and <i>text mode</i> attributes set for the
 *              context.
 *
 *              Symmetrically encrypted cipher text can be deciphered with
 *              <code>@link decryptedData: decryptedData:@/link</code>. Note
 *              that in this case the crypto back-end needs to retrieve a
 *              passphrase from the user. Symmetric encryption is currently only
 *              supported for the OpenPGP crypto back-end.
 *
 *              With OpenPGP engine, only one attempt for passphrase is allowed.
 *  @param      inputData Data to encrypt
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              (<code>@link //macgpg/c/econst/GPGErrorBadPassphrase GPGErrorBadPassphrase@/link</code>) exception when the passphrase for the
 *              symmetric key could not be retrieved. Other exceptions could be
 *              raised too.
 */
- (GPGData *) encryptedData:(GPGData *)inputData;


/*!
 * @methodgroup Managing <i>key ring</i>
 */

/*!
 *  @method     exportedKeys:
 *  @abstract   Extracts the public key data from <i>recipientKeys</i> and 
 *              returns them.
 *  @discussion The type of the public keys returned is determined by the
 *              <i>ASCII armor</i> attribute set for the context, by invoking
 *              <code>@link setUsesArmor: setUsesArmor:@/link</code>.
 *
 *              If <i>recipientKeys</i> is nil, then all available keys are
 *              exported.
 * 
 *              Keys are exported from standard <i>key ring</i>.
 *  @param      recipientKeys Public keys (as <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code> objects)
 *              to export
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception
 */
- (GPGData *) exportedKeys:(NSArray *)recipientKeys;

/*!
 *  @method     importKeyData:
 *  @abstract   Adds the keys in <i>keyData</i> to the <i>key ring</i> of the
 *              crypto engine used by the context.
 *  @discussion The format of <i>keyData</i> content can be 
 *              <i>ASCII armored</i>, for example, but the details are specific
 *              to the crypto engine.
 *
 *              See <code>@link operationResults operationResults@/link</code>
 *              for information about returned dictionary.
 *
 *              If <i>key ring</i> changed, a 
 *              <code>@link GPGKeyringChangedNotification GPGKeyringChangedNotification@/link</code>
 *              notification is posted.
 *  @param      keyData Data containing exported keys.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              (<code>@link //macgpg/c/econst/GPGErrorNoData GPGErrorNoData@/link</code>)
 *              exception when <i>keyData</i> is an empty buffer. Other
 *              exceptions could be raised too.
 */
- (NSDictionary *) importKeyData:(GPGData *)keyData;

/*!
 *  @method     generateKeyFromDictionary:secretKey:publicKey:
 *  @abstract   Generates a new key pair and puts it into the standard 
 *              <i>key ring</i> if both <i>publicKeyData</i> and 
 *              <i>secretKeyData</i> are nil.
 *  @discussion Generates a new key pair and puts it into the standard
 *              <i>key ring</i> if both <i>publicKeyData</i> and 
 *              <i>secretKeyData</i> are nil.
 *              In this case method returns immediately after starting the
 *              operation, and does not wait for it to complete. If 
 *              <i>publicKeyData</i> is not nil, the newly created data object,
 *              upon successful completion, will contain the public key. If
 *              <i>secretKeyData</i> is not nil, the newly created data object,
 *              upon successful completion, will contain the secret key.
 *
 *              Note that not all crypto engines support this interface equally.
 *
 *              GnuPG does not support <i>publicKeyData</i> and
 *              <i>secretKeyData</i>, they should be both nil. GnuPG will
 *              generate a key pair and add it to the standard <i>key ring</i>.
 *
 *              GpgSM requires <i>publicKeyData</i> to be a writable data
 *              object. GpgSM will generate a secret key (which will be stored
 *              by <code>gpg-agent</code>), and return a certificate request in
 *              public, which then needs to be signed by the certification
 *              authority and imported before it can be used.
 *
 *              The <i>params</i> dictionary specifies parameters for the key.
 *              The details about the format of <i>params</i> are specific to
 *              the crypto engine used by the context. Here's an example for
 *              GnuPG as the crypto engine:<dl>
 *              <dt><code>\@"type"</code></dt>
 *              <dd>Algorithm number or name. See <code>@link //macgpg/c/tdef/GPGPublicKeyAlgorithm GPGPublicKeyAlgorithm@/link</code></dd>
 *              <dt><code>\@"length"</code></dt>
 *              <dd>Key length in bits as a <code>@link //apple_ref/occ/cl/NSNumber NSNumber@/link</code></dd>
 *              <dt><code>\@"subkeyType"</code></dt>
 *              <dd>NSString (ELG-E, etc.) or <code>@link //apple_ref/occ/cl/NSNumber NSNumber@/link</code>. Optional.</dd>
 *              <dt><code>\@"subkeyLength"</code></dt>
 *              <dd>Subkey length in bits as a <code>@link //apple_ref/occ/cl/NSNumber NSNumber@/link</code>. Optional.</dd>
 *              <dt><code>\@"name"</code></dt>
 *              <dd><code>@link //apple_ref/occ/cl/NSString NSString@/link</code>.
 *               Optional.</dd>
 *              <dt><code>\@"comment"</code></dt>
 *              <dd><code>@link //apple_ref/occ/cl/NSString NSString@/link</code>.
 *               Optional.</dd>
 *              <dt><code>\@"email"</code></dt>
 *              <dd><code>@link //apple_ref/occ/cl/NSString NSString@/link</code>. 
 *               Optional.</dd>
 *              <dt><code>\@"expirationDate"</code></dt>
 *              <dd><code>@link //apple_ref/occ/cl/NSCalendarDate NSCalendarDate@/link</code>.
 *               Optional.</dd>
 *              <dt><code>\@"passphrase"</code></dt>
 *              <dd><code>@link //apple_ref/occ/cl/NSString NSString@/link</code>.
 *               Optional.</dd></dl>
 *              Here's an example for GpgSM as the crypto engine:
 *              <dt><code>\@"type"</code></dt>
 *              <dd><code>@link //apple_ref/occ/cl/NSString NSString@/link</code>
 *               (<code>RSA</code>, etc.) or <code>@link //apple_ref/occ/cl/NSNumber NSNumber@/link</code></dd>
 *              <dt><code>\@"length"</code></dt>
 *              <dd>Key length in bits as a <code>@link //apple_ref/occ/cl/NSNumber NSNumber@/link</code></dd>
 *              <dt><code>\@"name"</code></dt>
 *              <dd><code>@link //apple_ref/occ/cl/NSString NSString@/link</code>
 *               (<code>C=de,O=g10 code,OU=Testlab,CN=Joe 2 Tester</code>)</dd>
 *              <dt><code>\@"email"</code></dt>
 *              <dd><code>@link //apple_ref/occ/cl/NSString NSString@/link</code> 
 *               (<code>joe\@foo.bar</code>)</dd></dl>
 *              Key is generated in standard secring/pubring files if both
 *              <i>secretKeyData</i> and <i>publicKeyData</i> are nil, else
 *              newly created key is returned but not stored.
 *
 *              See <code>@link operationResults operationResults@/link</code>
 *              for more information about returned dictionary.
 *
 *              A <code>@link GPGKeyringChangedNotification GPGKeyringChangedNotification@/link</code>
 *              notification is posted, containing the new <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code>
 *              objects (secret and public, for OpenPGP only).
 *  @param      params Dictionary containing generation parameters
 *  @param      secretKeyData Data containing the secret key, on return, or nil
 *  @param      publicKeyData Data containing the public key, on return, or nil
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception with error code:<dl>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorInvalidValue GPGErrorInvalidValue@/link</code></dt>
 *              <dd><i>params</i> is not a valid dictionary.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorNotSupported GPGErrorNotSupported@/link</code></dt>
 *              <dd><i>publicKeyData</i> or <i>secretKeyData</i> is not nil.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorGeneralError GPGErrorGeneralError@/link</code></dt>
 *              <dd>No key was created by the engine.</dd></dl>
 *              Other exceptions could be raised too.
 */
- (NSDictionary *) generateKeyFromDictionary:(NSDictionary *)params secretKey:(GPGData *)secretKeyData publicKey:(GPGData *)publicKeyData;

/*!
 *  @method     deleteKey:evenIfSecretKey:
 *  @abstract   Deletes the given <i>key</i> from the standard <i>key ring</i> 
 *              of the crypto engine used by the context.
 *  @discussion To delete a secret key along with the public key,
 *              <i>allowSecret</i> must be <code>YES</code>, else only the public key is
 *              deleted, if that is supported.
 *  @param      key Key to delete
 *  @param      allowSecret Delete also matching secret key when <code>YES</code>
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception with error code:<dl>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorNoPublicKey GPGErrorNoPublicKey@/link</code></dt>
 *              <dd><i>key</i> could not be found in the <i>key ring</i>.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorAmbiguousName GPGErrorAmbiguousName@/link</code></dt>
 *              <dd><i>key</i> was not specified unambiguously.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorConflict GPGErrorConflict@/link</code></dt>
 *              <dd>Secret key for <i>key</i> is available, but 
 *               <i>allowSecret</i> is <code>NO</code>.</dd></dl>
 *              Other exceptions could be raised too.
 */
- (void) deleteKey:(GPGKey *)key evenIfSecretKey:(BOOL)allowSecret;


/*!
 * @methodgroup Finding/refreshing a single key
 */

/*!
 *  @method     keyFromFingerprint:secretKey:
 *  @abstract   Fetches a single key, given its fingerprint (or key ID).
 *  @discussion If <i>secretKey</i> is <code>YES</code>, returns a secret key,
 *              else returns a public key. You can set the key list mode if you
 *              want to retrieve key signatures too. Returns nil if no matching
 *              key is found.
 *  @param      fingerprint Fingerprint or key ID
 *  @param      secretKey Searches secret keys only
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception with error code:<dl>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorInvalidValue GPGErrorInvalidValue@/link</code></dt>
 *              <dd><i>fingerprint</i> is not a valid fingerprint, nor key ID.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorAmbiguousName GPGErrorAmbiguousName@/link</code></dt>
 *              <dd>the key ID was not a unique specifier for a key.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGError_EBUSY GPGError_EBUSY@/link</code></dt>
 *              <dd>Context is already performing an operation.</dd></dl>
 *              Other exceptions could be raised too.
 */
- (GPGKey *) keyFromFingerprint:(NSString *)fingerprint secretKey:(BOOL)secretKey;

/*!
 *  @method     refreshKey:
 *  @discussion Asks the engine for the key again, forcing a refresh of the key
 *              attributes. This method can be used to fetch key signatures, by
 *              setting corresponding mode in the context. A new
 *              <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code> object is
 *              returned; you shall no longer use the original key.
 *
 *              Invokes <code>@link keyFromFingerprint:secretKey: keyFromFingerprint:secretKey:@/link</code>.
 *  @param      key Key to refresh
 *  @result     New object which must be used instead of the one passed in
 *              argument, which is no longer valid.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              (<code>@link //macgpg/c/econst/GPGError_EBUSY GPGError_EBUSY@/link</code>)
 *              exception when context is already performing an operation. Other
 *              exceptions could be raised too.
 */
- (GPGKey *) refreshKey:(GPGKey *)key;

@end


/*!
 *  @category   GPGContext(GPGKeyManagement)
 *  @abstract   Key management
 */
@interface GPGContext(GPGKeyManagement)

/*!
 * @methodgroup Listing keys
 */

/*!
 *  @method     keyEnumeratorForSearchPattern:secretKeysOnly:
 *  @abstract   Convenience method. See <code>@link keyEnumeratorForSearchPatterns:secretKeysOnly: keyEnumeratorForSearchPatterns:secretKeysOnly:@/link</code>.
 *  @discussion Passing nil will return all keys. 
 *  @param      searchPattern Pattern string
 *  @param      secretKey Searches secret keys only
 *  @seealso    keyEnumeratorForSearchPatterns:secretKeysOnly:
 */
- (NSEnumerator *) keyEnumeratorForSearchPattern:(NSString *)searchPattern secretKeysOnly:(BOOL)secretKeysOnly;

/*!
 *  @method     keyEnumeratorForSearchPatterns:secretKeysOnly:
 *  @abstract   Returns an enumerator of <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code> 
 *              objects.
 *  @discussion It starts a key listing operation inside the context; the
 *              context will be busy until either all keys are received, or
*               <code>@link stopKeyEnumeration stopKeyEnumeration@/link</code> 
 *              is invoked, or the enumerator has been deallocated.
 *
 *              <i>searchPatterns</i> is an array containing engine specific
 *              expressions that are used to limit the list to all keys matching
 *              at least one pattern. <i>searchPatterns</i> can be empty; in
 *              this case all keys are returned. Note that the total length of
 *              the pattern string (i.e. the length of all patterns, sometimes
 *              quoted, separated by a space character) is restricted to an 
 *              engine-specific maximum (a couple of hundred characters are
 *              usually accepted). The patterns should be used to restrict the
 *              search to a certain common name or user, not to list many
 *              specific keys at once by listing their fingerprints or key IDs.
 *
 *              If <i>secretKeysOnly</i> is <code>YES</code>, searches only for 
 *              secret keys, else searches only for public keys.
 *
 *              This call also resets any pending key listing operation.
 *
 *              Can raise a <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception, even during enumeration.
 *
 *              <strong>WARNING:</strong> there is a bug in <code>gpg</code>:
 *              secret keys fetched in batch (i.e. with this method) have no
 *              capabilities and you need to invoke <code>@link refreshKey: refreshKey:@/link</code>
 *              on each to get full information for them.
 *  @param      searchPatterns Array of pattern strings
 *  @param      secretKeysOnly Searches secret keys only
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              (<code>@link //macgpg/c/econst/GPGErrorTruncatedKeyListing GPGErrorTruncatedKeyListing@/link</code>) exception during enumeration
 *              (i.e. when invoking <code>@link //apple_ref/occ/instm/NSEnumerator/nextObject nextObject@/link</code>
 *              on the enumerator) if the crypto back-end had to truncate the
 *              result, and less than the desired keys could be listed.
 */
- (NSEnumerator *) keyEnumeratorForSearchPatterns:(NSArray *)searchPatterns secretKeysOnly:(BOOL)secretKeysOnly;

/*!
 *  @method     stopKeyEnumeration
 *  @abstract   Ends the key listing operation and allows to use the context
 *              for some other operation next.
 *  @discussion This is not an error to invoke that method if there is no
 *              pending key listing operation.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception.
 */
- (void) stopKeyEnumeration;


/*!
 * @methodgroup Listing trust items
 */

/*!
 *  @method     trustItemEnumeratorForSearchPattern:maximumLevel:
 *  @abstract   Returns an enumerator of <code>@link //macgpg/occ/cl/GPGTrustItem GPGTrustItem@/link</code>
 *              objects, and initiates a trust item listing operation inside
 *              the context.
 *  @discussion <i>searchPattern</i> contains an engine specific expression that
 *              is used to limit the list to all trust items matching the
 *              pattern. It can not be the empty string or nil.
 *
 *              <i>maxLevel</i> is currently ignored.
 *
 *              Context will be busy until either all trust items are
 *              enumerated, or <code>@link stopTrustItemEnumeration stopTrustItemEnumeration@/link</code>
 *              is invoked, or the enumerator has been deallocated.
 *  @param      searchPattern Pattern string
 *  @param      maxLevel (currently ignored)
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception, even during enumeration.
 */
- (NSEnumerator *) trustItemEnumeratorForSearchPattern:(NSString *)searchPattern maximumLevel:(int)maxLevel;

/*!
 *  @method     stopTrustItemEnumeration
 *  @abstract   Ends the trust item listing operation and allows to use the
 *              context for some other operation next.
 *  @discussion This is not an error to invoke that method if there is no
 *              pending trust list operation.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception.
 */
- (void) stopTrustItemEnumeration;
@end


/*!
 *  @category   GPGContext(GPGExtendedKeyManagement)
 *  @abstract   Extended key management
 */
@interface GPGContext(GPGExtendedKeyManagement)

/*!
 * @methodgroup Searching keys on a key server
 */

/*!
 *  @method     asyncSearchForKeysMatchingPatterns:serverOptions:
 *  @abstract   Contacts a key server asynchronously and asks it for keys
 *              matching <i>searchPatterns</i>.
 *  @discussion The <i>options</i> dictionary can contain the following
 *              key-value pairs:<dl>
 *              <dt><code>\@"keyserver"</code></dt>
 *              <dd>A keyserver URL, e.g. <code>ldap://keyserver.pgp.com</code>
 *               or <code>x-hkp://keyserver.pgp.com:8000</code>; if keyserver is
 *               not set, the default keyserver, from gpg configuration, is
 *               used.</dd>
 *              <dt><code>\@"keyserver-options"</code></dt>
 *              <dd>An array which can contain the following string values:
 *               <code>\@"include-revoked"</code>,
 *               <code>\@"include-disabled"</code>, <code>\@"check-cert"</code>,
 *               <code>\@"try-dns-srv"</code>, <code>\@"include-subkeys"</code>
 *               options but prefixed by <code>\@"no-"</code>. You can also pass
 *               the following strings followed by an equal sign and a value:
 *               <code>\@"broken-http-proxy"</code> and a host name,
 *               <code>\@"http-proxy"</code> and a host name, 
 *               <code>\@"timeout"</code> and an integer value (seconds), 
 *               <code>\@"ca-cert-file"</code> and a full path to a SSL
 *               certificate file, <code>\@"tls"</code> and 
 *               <code>\@"try"</code>/<code>\@"require"</code>/<code>\@"warn"</code>
 *               or <code>\@"no-tls"</code>, <code>\@"basedn"</code> and a base
 *               DN, <code>\@"follow-redirects"</code> and an integer value.
 *               Passed options are merged with gpg configuration options, but
 *               are prioritary. Not all types of servers support all these
 *               options, but unsupported ones are silently ignored.</dd></dl>
 *
 *              A <code>@link GPGAsynchronousOperationDidTerminateNotification GPGAsynchronousOperationDidTerminateNotification@/link</code>
 *              notification will be sent on completion of the operation, be it
 *              successful or not. The object is the context, and the results
 *              can be retrieved from <code>@link operationResults operationResults@/link</code>.
 *
 *              Once you got results, you can invoke <code>@link asyncDownloadKeys:serverOptions: asyncDownloadKeys:serverOptions:@/link</code> 
 *              passing for example a subset of the keys returned from the
 *              search.
 *
 *              Method cannot be used yet to search CMS keys.
 *  @param      searchPatterns Array of pattern strings
 *  @param      options Dictionary of configuration options
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception with error code:<dl>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorKeyServerError GPGErrorKeyServerError@/link</code></dt>
 *              <dd><code>gpg</code> is not configured correctly. More
 *               information under
 *               <code>@link //macgpg/c/data/GPGAdditionalReasonKey GPGAdditionalReasonKey@/link</code>
 *               userInfo key.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorGeneralError GPGErrorGeneralError@/link</code></dt>
 *              <dd>An unknown error occurred during search. More information
 *               under <code>@link //macgpg/c/data/GPGAdditionalReasonKey GPGAdditionalReasonKey@/link</code>
 *               userInfo key.</dd></dl>
 */
- (void) asyncSearchForKeysMatchingPatterns:(NSArray *)searchPatterns serverOptions:(NSDictionary *)options;

/*!
 *  @method     asyncDownloadKeys:serverOptions:
 *  @abstract   Contacts a key server asynchronously and downloads keys from it.
 *  @discussion This method is usually invoked after having searched for keys on
 *              the server, and is passed a subset of the <code>@link //macgpg/occ/cl/GPGRemoteKey GPGRemoteKey@/link</code>
 *              objects returned by the search. Received keys are then
 *              automatically imported in default <i>key ring</i>. Note that you
 *              can also pass keys from user's <i>key ring</i>
 *              (<code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code> objects)
 *              to refresh them.
 *
 *              The <i>options</i> dictionary can contain the following 
 *              key-value pairs:<dl>
 *              <dt><code>\@"keyserver"</code></dt>
 *              <dd>A keyserver URL, e.g. <code>ldap://keyserver.pgp.com</code>
 *               or <code>x-hkp://keyserver.pgp.com:8000</code>; if keyserver is
 *               not set, the default keyserver, from gpg configuration, is
 *               used.</dd>
 *              <dt><code>\@"keyserver-options"</code></dt>
 *              <dd>An array which can contain the following string values:
 *               <code>\@"include-revoked"</code>,
 *               <code>\@"include-disabled"</code>, <code>\@"check-cert"</code>,
 *               <code>\@"try-dns-srv"</code>, <code>\@"include-subkeys"</code>
 *               options but prefixed by <code>\@"no-"</code>. You can also pass
 *               the following strings followed by an equal sign and a value:
 *               <code>\@"broken-http-proxy"</code> and a host name,
 *               <code>\@"http-proxy"</code> and a host name, 
 *               <code>\@"timeout"</code> and an integer value (seconds), 
 *               <code>\@"ca-cert-file"</code> and a full path to a SSL
 *               certificate file, <code>\@"tls"</code> and 
 *               <code>\@"try"</code>/<code>\@"require"</code>/<code>\@"warn"</code>
 *               or <code>\@"no-tls"</code>, <code>\@"basedn"</code> and a base
 *               DN, <code>\@"follow-redirects"</code> and an integer value.
 *               Passed options are merged with gpg configuration options, but
 *               are prioritary. Not all types of servers support all these
 *               options, but unsupported ones are silently ignored.</dd></dl>
 *
 *              A <code>@link GPGAsynchronousOperationDidTerminateNotification GPGAsynchronousOperationDidTerminateNotification@/link</code>
 *              notification will be sent on completion of the operation, be it
 *              successful or not. The object is the context. See
 *              <code>@link operationResults operationResults@/link</code> to 
 *              get imported keys.
 *
 *              Downloaded keys will be automatically imported in your default
 *              <i>key ring</i>, and a <code>@link GPGKeyringChangedNotification GPGKeyringChangedNotification@/link</code>
 *              notification will be posted, like for an import operation. See
 *              <code>@link importKeyData: importKeyData:@/link</code> for more
 *              information about this notification and how to get downloaded
 *              keys.
 *
 *              Method cannot be used yet to search CMS keys.
 *  @param      keys Array of <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code>/<code>@link //macgpg/occ/cl/GPGRemoteKey GPGRemoteKey@/link</code>
 *              keys to download
 *  @param      options Dictionary of configuration options
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception with error code:<dl>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorKeyServerError GPGErrorKeyServerError@/link</code></dt>
 *              <dd><code>gpg</code> is not configured correctly. More
 *               information under
 *               <code>@link //macgpg/c/data/GPGAdditionalReasonKey GPGAdditionalReasonKey@/link</code>
 *               userInfo key.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorGeneralError GPGErrorGeneralError@/link</code></dt>
 *              <dd>An unknown error occurred during search. More information
 *               under <code>@link //macgpg/c/data/GPGAdditionalReasonKey GPGAdditionalReasonKey@/link</code>
 *               userInfo key.</dd></dl>
 */
- (void) asyncDownloadKeys:(NSArray *)keys serverOptions:(NSDictionary *)options;


/*!
 * @methodgroup Uploading keys on a key server
 */

/*!
 *  @method     asyncUploadKeys:serverOptions:
 *  @abstract   Contacts a key server asynchronously to upload keys.
 *  @discussion Only public keys are uploaded: if you pass, by mistake, a secret
 *              key, method will upload the public key, not the secret one.
 *
 *              The <i>options</i> dictionary can contain the following 
 *              key-value pairs:<dl>
 *              <dt><code>\@"keyserver"</code></dt>
 *              <dd>A keyserver URL, e.g. <code>ldap://keyserver.pgp.com</code>
 *               or <code>x-hkp://keyserver.pgp.com:8000</code>; if keyserver is
 *               not set, the default keyserver, from gpg configuration, is 
 *               used.</dd>
 *              <dt><code>\@"keyserver-options"</code></dt>
 *              <dd>An array which can contain the following string values:
 *               <code>\@"include-revoked"</code>,
 *               <code>\@"include-disabled"</code>, <code>\@"check-cert"</code>,
 *               <code>\@"try-dns-srv"</code>, <code>\@"include-subkeys"</code>
 *               options but prefixed by <code>\@"no-"</code>. You can also pass
 *               the following strings followed by an equal sign and a value:
 *               <code>\@"broken-http-proxy"</code> and a host name,
 *               <code>\@"http-proxy"</code> and a host name, 
 *               <code>\@"timeout"</code> and an integer value (seconds), 
 *               <code>\@"ca-cert-file"</code> and a full path to a SSL
 *               certificate file, <code>\@"tls"</code> and 
 *               <code>\@"try"</code>/<code>\@"require"</code>/<code>\@"warn"</code>
 *               or <code>\@"no-tls"</code>, <code>\@"basedn"</code> and a base
 *               DN, <code>\@"follow-redirects"</code> and an integer value.
 *               Passed options are merged with gpg configuration options, but
 *               are prioritary. Not all types of servers support all these
 *               options, but unsupported ones are silently ignored.</dd></dl>
 *
 *              A <code>@link GPGAsynchronousOperationDidTerminateNotification GPGAsynchronousOperationDidTerminateNotification@/link</code>
 *              notification will be sent on completion of the operation, be it
 *              successful or not. The object is the context.
 *
 *              Method cannot be used yet to search CMS keys.
 *  @param      keys Array of <code>@link //macgpg/occ/cl/GPGKey GPGKey@/link</code>/<code>@link //macgpg/occ/cl/GPGRemoteKey GPGRemoteKey@/link</code>
 *              keys to upload
 *  @param      options Dictionary of configuration options
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception with error code:<dl>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorKeyServerError GPGErrorKeyServerError@/link</code></dt>
 *              <dd><code>gpg</code> is not configured correctly. More
 *                information under
 *               <code>@link //macgpg/c/data/GPGAdditionalReasonKey GPGAdditionalReasonKey@/link</code>
 *               userInfo key.</dd>
 *              <dt><code>@link //macgpg/c/econst/GPGErrorGeneralError GPGErrorGeneralError@/link</code></dt>
 *              <dd>An unknown error occurred during search. More information
 *               under <code>@link //macgpg/c/data/GPGAdditionalReasonKey GPGAdditionalReasonKey@/link</code>
 *               userInfo key.</dd></dl>
 */
- (void) asyncUploadKeys:(NSArray *)keys serverOptions:(NSDictionary *)options;


/*!
 * @methodgroup Interrupting async operations
 */

/*!
 *  @method     interruptAsyncOperation
 *  @abstract   Interrupts asynchronous operation.
 *  @discussion The <code>@link GPGAsynchronousOperationDidTerminateNotification GPGAsynchronousOperationDidTerminateNotification@/link</code>
 *              notification will be sent with the error code <code>@link //macgpg/c/econst/GPGErrorCancelled GPGErrorCancelled@/link</code>.
 *              This method can be used to interrupt only the
 *              <code>async*</code> methods. After interrupt, you can still ask
 *              the context for the operation results; you might get valid
 *              partial results. No error is returned when context is not 
 *              running an async operation, or operation has already finished.
 */
- (void) interruptAsyncOperation;


/*!
 * @methodgroup Context is busy with an async operation
 */

/*!
 *  @method     isPerformingAsyncOperation
 *  @abstract   Returns <code>YES</code> when the context is performing an  
 *              asynchronous operation.
 */
-(BOOL) isPerformingAsyncOperation;

@end


/*!
 *  @category   GPGContext(GPGKeyGroups)
 *  @abstract   Key groups
 */
@interface GPGContext(GPGKeyGroups)

/*!
 * @methodgroup Getting key groups
 */

/*!
 *  @method     keyGroups
 *  @abstract   Returns all groups defined in engine configuration file.
 *  @discussion Implemented only for OpenPGP protocol.
 */
- (NSArray *) keyGroups;
@end


/*!
 *  @category   NSObject(GPGContextDelegate)
 *  @abstract   Informal protocol implemented by <code>@link GPGContext GPGContext@/link</code>'s
 *              passphrase delegate.
 */
@interface NSObject(GPGContextDelegate)
/*!
 *  @method     context:passphraseForKey:again:
 *  @abstract   Callback method sent by a <code>@link GPGContext GPGContext@/link</code>
 *              object to its passphrase delegate when needing a passphrase.
 *  @discussion <i>key</i> is the secret key for which the user is asked a
 *              passphrase. <i>key</i> is nil only in case of symmetric
 *              signature/decryption. <i>again</i> is set to <code>YES</code>
 *              if user typed a wrong passphrase the previous time(s).
 *
 *              If you return nil, it means that user cancelled passphrase 
 *              request.
 *  @param      context Caller
 *  @param      key Secret key or nil
 *  @param      again Not the first attempt
 */
- (NSString *) context:(GPGContext *)context passphraseForKey:(GPGKey *)key again:(BOOL)again;
@end


#ifdef __cplusplus
}
#endif
#endif /* GPGCONTEXT_H */
