//
//  GPGPrettyInfo.m
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

#include <MacGPGME/GPGPrettyInfo.h>
#include <MacGPGME/LocalizableStrings.h>
#include <MacGPGME/GPGInternals.h>


#define GPGLocalizedString(string)	(string != nil ? NSLocalizedStringFromTableInBundle(string, nil, [NSBundle bundleForClass: [GPGObject class]], ""):nil)


NSString * GPGLocalizedPublicKeyAlgorithmDescription(GPGPublicKeyAlgorithm value)
{
    NSString	*aString = GPGPublicKeyAlgorithmDescription(value);

    return GPGLocalizedString(aString);
}

NSString * GPGPublicKeyAlgorithmDescription(GPGPublicKeyAlgorithm value)
{
    const char	*aCString = gpgme_pubkey_algo_name(value); // statically allocated string or NULL

    return GPGStringFromChars(aCString);
}

NSString * GPGSymmetricKeyAlgorithmDescription(GPGSymmetricKeyAlgorithm value)
{
    NSString *return_value;

    switch (value)	{
        case GPG_NoAlgorithm:
            return_value = GPGLocalizedString(GPGNoAlgorithmString);
            break;
        case GPG_IDEAAlgorithm:
            return_value = GPGLocalizedString(GPGIDEAAlgorithmString);
            break;
        case GPG_TripleDESAlgorithm:
            return_value = GPGLocalizedString(GPGTripleDESAlgorithmString);
            break;
        case GPG_CAST5Algorithm:
            return_value = GPGLocalizedString(GPGCAST5AlgorithmString);
            break;
        case GPG_BlowfishAlgorithm:
            return_value = GPGLocalizedString(GPGBlowfishAlgorithmString);
            break;
        case GPG_SAFER_SK128Algorithm:
            return_value = GPGLocalizedString(GPGSAFERSK128AlgorithmString);
            break;
        case GPG_DES_SKAlgorithm:
            return_value = GPGLocalizedString(GPGDESSKAlgorithmString);
            break;
        case GPG_AES128Algorithm:
            return_value = GPGLocalizedString(GPGAES128AlgorithmString);
            break;
        case GPG_AES192Algorithm:
            return_value = GPGLocalizedString(GPGAES192AlgorithmString);
            break;
        case GPG_AES256Algorithm:
            return_value = GPGLocalizedString(GPGAES256AlgorithmString);
            break;
        case GPG_TwoFishAlgorithm:
            return_value = GPGLocalizedString(GPGTwoFishAlgorithmString);
            break;
        case GPG_SkipjackAlgorithm:
            return_value = GPGLocalizedString(GPGSkipjackAlgorithmString);
            break;
        case GPG_TwoFish_OldAlgorithm:
            return_value = GPGLocalizedString(GPGTwoFishOldAlgorithmString);
            break;
        case GPG_DummyAlgorithm:
            return_value = GPGLocalizedString(GPGDummyAlgorithmString);
            break;
        default:
            return_value = nil;
            break;
    }

    return return_value;    
}

NSString * GPGLocalizedHashAlgorithmDescription(GPGHashAlgorithm value)
{
    NSString	*aString = GPGHashAlgorithmDescription(value);

    return GPGLocalizedString(aString);
}

NSString * GPGHashAlgorithmDescription(GPGHashAlgorithm value)
{
    const char	*aCString = gpgme_hash_algo_name(value); // statically allocated string or NULL

    return GPGStringFromChars(aCString);
}

NSString * GPGValidityDescription(GPGValidity value)
{
    NSString *return_value;

    switch (value)	{
        case GPGValidityUndefined:
            return_value = GPGLocalizedString(GPGValidityUndefinedString);
            break;
        case GPGValidityNever:
            return_value = GPGLocalizedString(GPGValidityNeverString);
            break;
        case GPGValidityMarginal:
            return_value = GPGLocalizedString(GPGValidityMarginalString);
            break;
        case GPGValidityFull:
            return_value = GPGLocalizedString(GPGValidityFullString);
            break;
        case GPGValidityUltimate:
            return_value = GPGLocalizedString(GPGValidityUltimateString);
            break;
        case GPGValidityUnknown:
            return_value = GPGLocalizedString(GPGUnknownString);
            break;
        default:
            return_value = nil;
            break;
    }
    
    return return_value;
}

NSString *GPGLocalizedProtocolDescription(GPGProtocol protocol)
{
    NSString	*aString = GPGProtocolDescription(protocol);

    return GPGLocalizedString(aString);
}

NSString *GPGProtocolDescription(GPGProtocol protocol)
{
    const char	*aCString = gpgme_get_protocol_name(protocol); // statically allocated string or NULL

    return GPGStringFromChars(aCString);
}
