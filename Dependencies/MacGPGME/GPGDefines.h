//
//  GPGDefines.h
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

#ifndef GPGDEFINES_H
#define GPGDEFINES_H

#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif

#if defined(__WIN32__)
    #undef GPG_EXPORT
    #if defined(BUILDING_MAC_GPGME)
    #define GPG_EXPORT __declspec(dllexport) extern
    #else
    #define GPG_EXPORT __declspec(dllimport) extern
    #endif
    #if !defined(GPG_IMPORT)
    #define GPG_IMPORT __declspec(dllimport) extern
    #endif
#endif

#if !defined(GPG_EXPORT)
    #define GPG_EXPORT extern
#endif

#if !defined(GPG_IMPORT)
    #define GPG_IMPORT extern
#endif

#if !defined(GPG_STATIC_INLINE)
#define GPG_STATIC_INLINE static __inline__
#endif

#if !defined(GPG_EXTERN_INLINE)
#define GPG_EXTERN_INLINE extern __inline__
#endif


#ifdef __cplusplus
}
#endif
#endif /* GPGDEFINES_H */
