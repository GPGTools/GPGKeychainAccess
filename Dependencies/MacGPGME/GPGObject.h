//
//  GPGObject.h
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

#ifndef GPGOBJECT_H
#define GPGOBJECT_H

#include <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif


/*!
 *  @class      GPGObject
 *  @abstract   Abstract base class for most MacGPGME classes.
 *  @discussion This abstract class takes care of uniquing objects against
 *              <i>gpgme</i> internal structures. It is the base class for all
 *              classes wrapping <i>gpgme</i> structures.
 */
@interface GPGObject : NSObject
{
    void	*_internalRepresentation; // Pointer to the gpgme internal structure wrapped by this object
}

/*!
 *  @method     initialize
 *  @abstract   Initializes <i>gpgme</i> library sub-systems.
 *  @discussion Initializes <i>gpgme</i> library sub-systems and insures that 
 *              Cocoa is ready for multithreading.
 *
 *              Can be invoked multiple times, initialization is done only once.
 *              Note that it will be invoked automatically by Objective-C 
 *              runtime as soon as you use GPGObject class or one of its
 *              subclasses; you don't need to invoke it manually.
 */
+ (void) initialize;

/*!
 *  @method     initWithInternalRepresentation:
 *  @abstract   Default initializer.
 *  @discussion All subclasses must call this method. Can return another object 
 *              than the one which received the message! In this case the
 *              original object is released. 
 *  @param      aPtr Pointer to a <i>gpgme</i> structure.
 */
- (id) initWithInternalRepresentation:(void *)aPtr;

/*!
 *  @method     dealloc
 *  @abstract   Standard deallocator.
 *  @discussion <strong>WARNING:</strong> <i>_internalRepresentation</i> pointer 
 *              MUST still be valid when GPGObject's <code>@link dealloc dealloc@/link</code>
 *              implementation is called!!! It can be NULL though.
 */
- (void) dealloc;

@end

#ifdef __cplusplus
}
#endif
#endif /* GPGOBJECT_H */
