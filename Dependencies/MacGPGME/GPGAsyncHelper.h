//
//  GPGAsyncHelper.h
//  MacGPGME
//
//  Created by davelopper at users.sourceforge.net on Mon Apr 12 2004.
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

#ifndef GPGASYNCHELPER_H
#define GPGASYNCHELPER_H

#include <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif


@class GPGContext;


@interface GPGAsyncHelper : NSObject
{
    NSLock			*_dataLock;
    NSConditionLock	*_runSemaphore;
    NSMapTable		*_paramsPerFd;
    NSMutableSet	*_contexts;
}

+ (GPGAsyncHelper *) sharedInstance;

- (void) prepareAsyncOperationInContext:(GPGContext *)context;

@end

#ifdef __cplusplus
}
#endif
#endif /* GPGASYNCHELPER_H */
