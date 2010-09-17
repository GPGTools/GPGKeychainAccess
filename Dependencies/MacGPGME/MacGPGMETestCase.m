//
//  MacGPGMETestCase.m
//  MacGPGME
//
//  Created by davelopper at users.sourceforge.net on Tue Dec 7 2006.
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

#import "MacGPGMETestCase.h"

#import <MacGPGME/MacGPGME.h>


@implementation MacGPGMETestCase

- (void) testData2String
{
    NSString    *testString = @"testString";
    GPGData     *data = [[GPGData alloc] initWithString:testString];
    NSString    *outputString = [data string];
    
    [data autorelease];
    STAssertEqualObjects(testString, outputString, @"Not the same string!");
}

/* TODO: pass correct arguments to dictionary; currently incomplete
- (void) testKeyCreation
{
    NSDictionary    *params = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:GPG_DSAAlgorithm], @"type", [NSNumber numberWithInt:1024], @"length", nil];
    NSDictionary    *result;
    NSArray         *keys;
    GPGContext      *context;
    GPGKey          *secretKey;
    GPGKey          *publicKey;
    
    context = [[GPGContext alloc] init];
    @try{
        STAssertNoThrow(result = [context generateKeyFromDictionary:params secretKey:nil publicKey:nil], @"Unable to generate key from dictionary %@", params);
        keys = [[result objectForKey:GPGChangesKey] allKeys];
        STAssertEquals([keys count], 2, @"Invalid key count (%u instead of 2) in GPGChangesKey dictionary", [keys count]);
        if([[keys objectAtIndex:0] isSecret]){
            secretKey = [keys objectAtIndex:0];
            publicKey = [keys objectAtIndex:1];
        }
        else{
            secretKey = [keys objectAtIndex:1];
            publicKey = [keys objectAtIndex:0];
        }
        [context deleteKey:secretKey evenIfSecretKey:YES];
    }
    @finally{
        [context release];
    }
}
*/
@end
