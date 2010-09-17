//
//  GPGKeyGroup.m
//  MacGPGME
//
//  Created by davelopper at users.sourceforge.net on Wed Oct 6 2004.
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

#include "GPGKeyGroup.h"
#include "GPGContext.h"
#include "GPGOptions.h"
#include "GPGInternals.h"


@implementation GPGKeyGroup

- (void) dealloc
{
    [_name release];
    [_keys release];
    
    [super dealloc];
}

- (NSString *) name
{
    return _name;
}

- (NSArray *) keys
{
    return _keys;
}

- (NSString *) debugDescription
{
    return [NSString stringWithFormat:@"<%@: %p> name = %@, keys = %@", NSStringFromClass([self class]), self, [self name], [self keys]];
}

+ (id) createKeyGroupNamed:(NSString *)name withKeys:(NSArray *)keys
{
    GPGOptions      *options;
    NSArray         *optionNames;
    NSArray         *optionValues;
    NSCharacterSet  *forbiddenChars = [NSCharacterSet characterSetWithCharactersInString:@"=\n"];
    NSString        *newGroupDefValue;
    GPGKeyGroup     *newGroup;
    unsigned        i, aCount;
    BOOL            foundGroup = NO;
    
    name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSParameterAssert(name != nil && [name length] > 0 && [name rangeOfCharacterFromSet:forbiddenChars].location == NSNotFound);
    
    newGroupDefValue = [NSString stringWithFormat:@"%@=%@", name, [[keys valueForKey:@"keyID"] componentsJoinedByString:@" "]];
    
    options = [[GPGOptions alloc] init];
    optionNames = [options optionNames];
    optionValues = [options optionValues];
    aCount = [optionNames count];
    for(i = 0; i < aCount; i++){
        if([[optionNames objectAtIndex:i] isEqualToString:@"group"]){
            NSDictionary    *aDict = [GPGContext parsedGroupDefinitionLine:[optionValues objectAtIndex:i]];
        
            if([[aDict objectForKey:@"name"] isEqualToString:name]){
                if(!foundGroup){
                    [options setOptionValue:newGroupDefValue atIndex:i];
                    foundGroup = YES;
                }
                else{
                    [options removeOptionAtIndex:i];
                    aCount--;
                    i--;
                }
            }
        }
    }

    if(!foundGroup)
        [options addOptionNamed:@"group" value:newGroupDefValue state:YES];

    [options saveOptions];
    [options release];
    newGroup = [[GPGKeyGroup alloc] initWithName:name keys:keys];
    
    return [newGroup autorelease];
}

@end


@implementation GPGKeyGroup(GPGInternals)

- (id) initWithName:(NSString *)name keys:(NSArray *)keys
{
    if((self = [super init]) != nil){
        NSZone  *aZone = [self zone];
        
        _name = [name copyWithZone:aZone];
        _keys = [keys copyWithZone:aZone];
    }
    
    return self;
}

@end
