//
//  GPGSignatureNotation.m
//  MacGPGME
//
//  Created by davelopper at users.sourceforge.net on Oct 09 2005.
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

#include <MacGPGME/GPGSignatureNotation.h>
#include <Foundation/Foundation.h>
#include <gpgme.h>


@implementation GPGSignatureNotation

#define _notation		((gpgme_sig_notation_t)aPtr)
- (id) initWithInternalRepresentation:(void *)aPtr
{
    NSParameterAssert(aPtr != NULL);
    
    if(self = [super initWithInternalRepresentation:NULL]){
        const char  *aCString = _notation->name;
        
        if(aCString != NULL)
            _name = [[NSString alloc] initWithBytes:aCString length:_notation->name_len encoding:NSUTF8StringEncoding];
        
        aCString = _notation->value;
        
        if(aCString != NULL){
            if(_notation->name == NULL || !!_notation->human_readable)
                _value = [[NSString alloc] initWithBytes:aCString length:_notation->value_len encoding:NSUTF8StringEncoding];
        }
        else
            _value = [[NSData alloc] initWithBytes:aCString length:_notation->value_len];
        
        _flags = _notation->flags;
        _isHumanReadable = !!_notation->human_readable;
        _isCritical = !!_notation->critical;
    }
    
    return self;
}
#undef _notation

- (void) dealloc
{
    [_name release];
    [_value release];
    
    [super dealloc];
}

- (NSString *) name
{
    return _name;
}

- (id) value
{
    return _value;
}

- (GPGSignatureNotationFlags) flags
{
    return _flags;
}

- (BOOL) isHumanReadable
{
    return _isHumanReadable;
}

- (BOOL) isCritical
{
    return _isCritical;
}

- (NSString *) description
{
    NSString    *aName = [self name];
    
    if(aName != nil)
        return [NSString stringWithFormat:@"%@%@ = \"%@\"", ([self isCritical] ? @"!":@""), aName, ([self isHumanReadable] ? [self value]:[[self value] propertyList])];
    else
        return [NSString stringWithFormat:@"%@%@", ([self isCritical] ? @"!":@""), [self value]];
}

@end
