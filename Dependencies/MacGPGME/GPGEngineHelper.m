//
//  GPGEngineHelper.m
//  MacGPGME
//
//  Created by davelopper at users.sourceforge.net on Sat Apr 12 2008.
//
//
//  Copyright (C) 2001-2008 Mac GPG Project.
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

#include "GPGEngineHelper.h"
#include "GPGInternals.h"


#define NOTHING_READ	0
#define READ_STDOUT		(1 << 0)
#define READ_STDERR		(1 << 1)
#define READ_ALL		(READ_STDOUT | READ_STDERR)


@implementation GPGEngineHelper

- (void) dealloc
{
    [stderrData release];
    [stdoutData release];

    [super dealloc];
}

- (void) readStderr:(NSNotification *)notification
{
	[readLock lock];
    stderrData = [[[notification userInfo] objectForKey:NSFileHandleNotificationDataItem] retain];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:[notification name] object:[notification object]];
    [readLock unlockWithCondition:[readLock condition] | READ_STDERR];
}

- (void) readStdout:(NSNotification *)notification
{
    [readLock lock];
    stdoutData = [[[notification userInfo] objectForKey:NSFileHandleNotificationDataItem] retain];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:[notification name] object:[notification object]];
    [readLock unlockWithCondition:[readLock condition] | READ_STDOUT];
}

- (NSString *) executeWithArguments:(NSArray *)arguments localizedOutput:(BOOL)localizedOutput error:(NSError **)errorPtr
{
    NSTask		*aTask = [[NSTask alloc] init];
    NSPipe		*stdoutPipe = [NSPipe pipe];
    NSPipe		*stderrPipe = (errorPtr != NULL ? [NSPipe pipe] : nil);
    NSString	*outputString = nil;
    
    [aTask setLaunchPath:[engine executablePath]];
    arguments = [[NSArray arrayWithObjects:@"--utf8-strings", @"--charset", @"utf8", @"--no-verbose", @"--batch", @"--no-tty", nil] arrayByAddingObjectsFromArray:arguments]; // FIXME: this is engine-dependant
    [aTask setArguments:arguments];
    if(!localizedOutput){
        // If we don't want localized output, we set language environment to English; that allows us to parse output more easily
        NSMutableDictionary		*environment = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]]; // We MUST add current environment!!
        
        [environment setObject:@"en_US.UTF-8" forKey:@"LANG"];
        [environment setObject:@"en_US.UTF-8" forKey:@"LANGUAGE"];
        [environment setObject:@"en_US.UTF-8" forKey:@"LC_ALL"];
        [environment setObject:@"en_US.UTF-8" forKey:@"LC_MESSAGE"];
        [aTask setEnvironment:environment];
    }
    [aTask setStandardOutput:stdoutPipe];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readStdout:) name:NSFileHandleReadToEndOfFileCompletionNotification object:[stdoutPipe fileHandleForReading]];
    if(errorPtr != NULL){
        [aTask setStandardError:stderrPipe];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readStderr:) name:NSFileHandleReadToEndOfFileCompletionNotification object:[stderrPipe fileHandleForReading]];
        readLock = [[NSConditionLock alloc] initWithCondition:NOTHING_READ];
    }
    else
        readLock = [[NSConditionLock alloc] initWithCondition:READ_STDERR];
    
    NS_DURING
        [aTask launch];
        [[stderrPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
        [[stdoutPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
        while([readLock tryLockWhenCondition:READ_ALL] == NO)
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        
        // Rendez-vous
        [readLock unlockWithCondition:NOTHING_READ];
        
        [aTask waitUntilExit];
        
        outputString = [GPGStringFromChars([stdoutData bytes]) retain];
        if([aTask terminationStatus] != 0){
            if(errorPtr != NULL){
                *errorPtr = [NSError errorWithDomain:@"GPGEngineHelper" code:[aTask terminationStatus] userInfo:[NSDictionary dictionaryWithObjectsAndKeys:GPGStringFromChars([stderrData bytes]), @"stderr", outputString, @"stdout", nil]];
            }
            else{
                NSLog(@"Unhandled error %d during execution of '%@ %@'", [aTask terminationStatus], [aTask launchPath], [[aTask arguments] componentsJoinedByString:@" "]);
            }
        }
        else{
            if(errorPtr != NULL)
                *errorPtr = nil;
        }
    NS_HANDLER
        NSLog(@"### %s: exception during execution of '%@ %@': %@ %@", __PRETTY_FUNCTION__, [aTask launchPath], [[aTask arguments] componentsJoinedByString:@" "], localException, [localException userInfo]);
        [aTask release];
        [readLock release];
        [localException raise];
    NS_ENDHANDLER
    
    [aTask release];
    [readLock release];
    
    return [outputString autorelease];
}

+ (NSString *) executeEngine:(GPGEngine *)engine withArguments:(NSArray *)arguments localizedOutput:(BOOL)localizedOutput error:(NSError **)errorPtr
{
    GPGEngineHelper *helper = [[self alloc] init];
    NSString        *outputString;
    
    helper->engine = engine;
    outputString = [helper executeWithArguments:arguments localizedOutput:localizedOutput error:errorPtr];
    [helper release];
    
    return outputString;
}

@end
