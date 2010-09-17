//
//  LocalizableStrings.h
//  MacGPGME
//
//  Created by Gordon Worley
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

#ifndef LOCALIZABLESTRINGS_H
#define LOCALIZABLESTRINGS_H

#include <Foundation/Foundation.h>
#include <MacGPGME/GPGDefines.h>

#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif


GPG_EXPORT NSString * const GPGUnknownString;
GPG_EXPORT NSString * const GPGValidityUndefinedString;
GPG_EXPORT NSString * const GPGValidityNeverString;
GPG_EXPORT NSString * const GPGValidityMarginalString;
GPG_EXPORT NSString * const GPGValidityFullString;
GPG_EXPORT NSString * const GPGValidityUltimateString;
GPG_EXPORT NSString * const GPGNoAlgorithmString;
GPG_EXPORT NSString * const GPGIDEAAlgorithmString;
GPG_EXPORT NSString * const GPGTripleDESAlgorithmString;
GPG_EXPORT NSString * const GPGCAST5AlgorithmString;
GPG_EXPORT NSString * const GPGBlowfishAlgorithmString;
GPG_EXPORT NSString * const GPGSAFERSK128AlgorithmString;
GPG_EXPORT NSString * const GPGDESSKAlgorithmString;
GPG_EXPORT NSString * const GPGAES128AlgorithmString;
GPG_EXPORT NSString * const GPGAES192AlgorithmString;
GPG_EXPORT NSString * const GPGAES256AlgorithmString;
GPG_EXPORT NSString * const GPGTwoFishAlgorithmString;
GPG_EXPORT NSString * const GPGSkipjackAlgorithmString;
GPG_EXPORT NSString * const GPGTwoFishOldAlgorithmString;
GPG_EXPORT NSString * const GPGDummyAlgorithmString;

#ifdef __cplusplus
}
#endif
#endif /* LOCALIZABLESTRINGS_H */
