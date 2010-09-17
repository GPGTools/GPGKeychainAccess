//
//  GPGExceptions.m
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

#include <MacGPGME/GPGExceptions.h>
#include <MacGPGME/GPGInternals.h>
#include <Foundation/Foundation.h>
#include <gpgme.h>


NSString	* const GPGException = @"GPGException";
NSString	* const GPGErrorKey = @"GPGErrorKey";
NSString 	* const	GPGAdditionalReasonKey = @"GPGAdditionalReasonKey";


GPGErrorCode GPGErrorCodeFromError(GPGError error)
{
    return gpgme_err_code(error);
}

GPGErrorSource GPGErrorSourceFromError(GPGError error)
{
    return gpgme_err_source(error);
}

GPGError GPGMakeError(GPGErrorSource src, GPGErrorCode cde)
{
    return gpgme_err_make(src, cde);
}

GPGError GPGMakeErrorFromErrno(GPGErrorSource src, int cde)
{
    return gpgme_err_make_from_errno(src, cde);
}

GPGError GPGMakeErrorFromSystemError()
{
    return gpg_error_from_syserror();
}

NSString *GPGErrorDescription(GPGError error)
{
    const size_t	bufferIncrement = 128;
    size_t			bufferSize = 128;
    NSZone			*aZone = NSDefaultMallocZone();
    char			*buffer = NSZoneMalloc(aZone, bufferSize);
    int				status;
    NSString		*errorDescription;

    do{
        status = gpgme_strerror_r(error, buffer, bufferSize);
        if(status == ERANGE)
            buffer = NSZoneRealloc(aZone, buffer, (bufferSize += bufferIncrement));
    }while(status != ERANGE && status != 0);

    NSCAssert(buffer != NULL, @"### Unable to get memory buffer!?");

    errorDescription = GPGStringFromChars(buffer);
    NSZoneFree(aZone, buffer);

    return errorDescription;
}

NSString *GPGErrorSourceDescription(GPGErrorSource errorSource)
{
    const char	*aCString = gpgme_strsource(errorSource);

    return GPGStringFromChars(aCString);
}


@implementation NSException(GPGExceptions)

+ (NSException *) exceptionWithGPGError:(GPGError)error userInfo:(NSDictionary *)additionalUserInfo
{
    NSParameterAssert(error != GPG_ERR_NO_ERROR);

    if(additionalUserInfo != nil){
        additionalUserInfo = [NSMutableDictionary dictionaryWithDictionary:additionalUserInfo];
        [(NSMutableDictionary *)additionalUserInfo setObject:[NSNumber numberWithUnsignedInt:error] forKey:GPGErrorKey];
    }
    else
        additionalUserInfo = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:error] forKey:GPGErrorKey];

    return [NSException exceptionWithName:GPGException reason:GPGErrorDescription(error) userInfo:additionalUserInfo];
}

@end
