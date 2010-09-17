//
//  GPGSignatureNotation.h
//  MacGPGME
//
//  Created by davelopper at users.sourceforge.net on Sun Oct 9 2005.
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

#ifndef GPGSIGNATURENOTATION_H
#define GPGSIGNATURENOTATION_H

#include <MacGPGME/GPGObject.h>

#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif


/*!
 *  @typedef    GPGSignatureNotationFlags
 *  @abstract   Flags set on a signature notation.
 *  @discussion The flags of a <code>@link //macgpg/occ/cl/GPGSignatureNotation GPGSignatureNotation@/link</code>
 *              is a combination of bit values.
 *  @constant   GPGSignatureNotationHumanReadableMask Specifies that the
 *              notation data is in human-readable form; not valid for policy
 *              URLs.
 *  @constant   GPGSignatureNotationCriticalMask Specifies that the notation
 *              data is critical.
 */
typedef unsigned int GPGSignatureNotationFlags;

#define GPGSignatureNotationHumanReadableMask	1
#define GPGSignatureNotationCriticalMask		2



/*!
 *  @class      GPGSignatureNotation 
 *  @abstract   Represents an arbitrary notation data attached to a signature.
 *  @discussion You can attach arbitrary notation data to a signature. This
 *              information is then available to the user when the signature is 
 *              verified.
 *
 *              To attach notation data to a signature, you use
 *              <code>@link //macgpg/occ/instm/GPGContext/addSignatureNotationWithName:value:flags: addSignatureNotationWithName:value:flags:@/link</code> (GPGContext).
 *              To retrieve a notation data from a signature, returned as a 
 *              GPGSignatureNotation object, you invoke
 *              <code>@link //macgpg/occ/instm/GPGSignature/signatureNotations signatureNotations@/link</code> 
 *              (GPGSignature).
 *
 *              GPGSignatureNotation objects are immutable objects.
 */
@interface GPGSignatureNotation : GPGObject
{
    NSString                    *_name;
    id                          _value;
    GPGSignatureNotationFlags   _flags;
    BOOL                        _isHumanReadable;
    BOOL                        _isCritical;
}

/*!
 *  @method     name
 *  @abstract   Returns the name of the notation field.
 *  @discussion The name of the notation field. If this is nil, then the value 
 *              will contain a policy URL (string).
 */
- (NSString *) name;

/*!
 *  @method     value
 *  @abstract   Returns the value of the notation field.
 *  @discussion If <code>@link //macgpg/occ/instm/GPGSignatureNotation/name name@/link</code> returns nil, then value is
 *              a policy URL (string). Else, if value is human-readable, a 
 *              <code>@link //apple_ref/occ/cl/NSString NSString@/link</code> is
 *              returned, else a <code>@link //apple_ref/occ/cl/NSData NSData@/link</code>
 *              is returned.
 */
- (id) value;

/*!
 *  @method     flags
 *  @abstract   Returns the accumulated flags field.
 *  @discussion This field contains the flags associated with the notation data
 *              in an accumulated form which can be used as an argument to
 *              GPGContext's <code>@link //macgpg/occ/instm/GPGContext/addSignatureNotationWithName:value:flags: addSignatureNotationWithName:value:flags:@/link</code>.
 *              The value flags is a bitwise-OR combination of one or multiple 
 *              of the following bit values: <code>@link GPGSignatureNotationHumanReadableMask GPGSignatureNotationHumanReadableMask@/link</code> and 
 *              <code>@link GPGSignatureNotationCriticalMask GPGSignatureNotationCriticalMask@/link</code>.
 */
- (GPGSignatureNotationFlags) flags;

/*!
 *  @method     isHumanReadable
 *  @abstract   Returns whether flags indicates that notation data is 
 *              human-readable or not.
 *  @discussion Convenience method. Policy URL notation data always returns <code>NO</code>. 
 *              When returns <code>YES</code>, value is a <code>@link //apple_ref/occ/cl/NSString NSString@/link</code>,
 *              else value is a <code>@link //apple_ref/occ/cl/NSData NSData@/link</code>
 *              (except for policy URLs which are always strings).
 */
- (BOOL) isHumanReadable;

/*!
 *  @method     isCritical
 *  @abstract   Returns whether flags indicates that notation data is critical
 *              or not.
 *  @discussion Convenience method.
 *
 *              <strong>WARNING:</strong> with <code>gpg</code> &lt;= 1.4,
 *              always returns <code>NO</code>.
 */
- (BOOL) isCritical;

@end


#ifdef __cplusplus
}
#endif
#endif /* GPGSIGNATURENOTATION_H */
