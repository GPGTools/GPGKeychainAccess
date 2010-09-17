//
//  GPGPrettyInfo.h
//  MacGPGME
//
//  Created by Gordon Worley on Tue Jun 18 2002.
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

#ifndef GPGPRETTYINFO_H
#define GPGPRETTYINFO_H

#include <Foundation/Foundation.h>

#include <MacGPGME/GPGDefines.h>
#include <MacGPGME/GPGKey.h>

#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif


/*!
 *  @function   GPGLocalizedPublicKeyAlgorithmDescription
 *  @abstract   Returns a localized human readable string describing the
 *              public key algorithm input value.
 *  @discussion Returns nil if <i>value</i> is not a valid public key algorithm.
 *  @param      value Public key algorithm
 *  @seealso    GPGPublicKeyAlgorithmDescription
 */
GPG_EXPORT NSString * GPGLocalizedPublicKeyAlgorithmDescription(GPGPublicKeyAlgorithm value);


/*!
 *  @function   GPGPublicKeyAlgorithmDescription
 *  @abstract   Returns a non-localized human readable string describing the
 *              public key algorithm input value.
 *  @discussion Returns nil if <i>value</i> is not a valid public key algorithm.
 *  @param      value Public key algorithm
 *  @seealso    GPGLocalizedPublicKeyAlgorithmDescription
 */
GPG_EXPORT NSString * GPGPublicKeyAlgorithmDescription(GPGPublicKeyAlgorithm value);


/*!
 *  @function   GPGSymmetricKeyAlgorithmDescription
 *  @abstract   Returns a localized human readable string describing the 
 *              symmetric key algorithm input value.
 *  @discussion Returns a localized human readable string that corresponds to 
 *              the <i>gcrypt</i> input value. Returns nil if 
 *              <i>value</i> is not a valid symmetric key algorithm.
 *  @param      value Symmetric key algorithm
 */
GPG_EXPORT NSString * GPGSymmetricKeyAlgorithmDescription(GPGSymmetricKeyAlgorithm value);


/*!
 *  @function   GPGLocalizedHashAlgorithmDescription
 *  @abstract   Returns a localized human readable string describing the hash
 *              algorithm input value.
 *  @discussion Returns nil if <i>value</i> is not a valid hash algorithm.
 *  @param      value Hash algorithm
 *  @seealso    GPGHashAlgorithmDescription
 */
GPG_EXPORT NSString * GPGLocalizedHashAlgorithmDescription(GPGHashAlgorithm value);


/*!
 *  @function   GPGHashAlgorithmDescription
 *  @abstract   Returns a non-localized human readable string describing the
 *              hash algorithm input value.
 *  @discussion This string can be used to output the name of the hash algorithm
 *              to the user. Returns nil if <i>value</i> is not a valid hash
 *              algorithm.
 *  @param      value Hash algorithm
 *  @seealso    GPGLocalizedHashAlgorithmDescription
 */
GPG_EXPORT NSString * GPGHashAlgorithmDescription(GPGHashAlgorithm value);


/*!
 *  @function   GPGValidityDescription
 *  @abstract   Returns a localized human readable string describing the 
 *              validity (of a key, a signature, etc.).
 *  @discussion Returns a localized human readable string that corresponds to 
 *              the <i>gcrypt</i> input value. Returns nil if 
 *              <i>value</i> is not a known validity value.
 *  @param      value Validity (of a key, a signature, etc.)
 */
GPG_EXPORT NSString * GPGValidityDescription(GPGValidity value);


/*!
 *  @function   GPGProtocolDescription
 *  @abstract   Returns a non-localized human readable string describing the 
 *              protocol input value.
 *  @discussion Returns nil if <i>protocol</i> is not valid.
 *  @param      protocol MacGPGME-supported protocol
 *  @seealso    GPGLocalizedProtocolDescription
 */
GPG_EXPORT NSString * GPGProtocolDescription(GPGProtocol protocol);


/*!
 *  @function   GPGLocalizedProtocolDescription
 *  @abstract   Returns a localized human readable string describing the 
 *              protocol input value.
 *  @discussion Returns nil if <i>protocol</i> is not valid.
 *  @param      protocol MacGPGME-supported protocol
 *  @seealso    GPGProtocolDescription
 */
GPG_EXPORT NSString * GPGLocalizedProtocolDescription(GPGProtocol protocol);

#ifdef __cplusplus
}
#endif
#endif /* GPGPRETTYINFO_H */
