//
//  GPGObject.m
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

#include <MacGPGME/GPGObject.h>
#include <MacGPGME/GPGInternals.h>
#include <MacGPGME/GPGOptions.h>
#include <Foundation/Foundation.h>
#include <gpgme.h>
#include <libintl.h>


@implementation GPGObject

static NSMapTable       *mapTable = NULL;
static NSRecursiveLock	*mapTableLock = nil;

+ (void) initialize
{
    // Do not call super - see +initialize documentation
    if(mapTable == NULL){
        NSString    *aPath;
        GPGEngine   *openPGPEngine;
        
        mapTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks, NSNonRetainedObjectMapValueCallBacks, 100);
        mapTableLock = [[NSRecursiveLock alloc] init];
    
        // gpgme library uses pthreads; to avoid any problems with
        // Foundation's NSThreads, we must ensure that at least
        // one NSThread has been created, that's why we create a dummy
        // thread before doing anything with gpgme.
        if(![NSThread isMultiThreaded]){
            NSObject	*aThreadStarter = [[NSObject alloc] init];	
            
            [NSThread detachNewThreadSelector:@selector(release) toTarget:aThreadStarter withObject:nil];
        }

        const char    *localeIdentifier = [[[NSLocale currentLocale] localeIdentifier] UTF8String];
        
        setlocale (LC_ALL, localeIdentifier);
        // Let's initialize libgpgme sub-systems now.
        NSAssert(gpgme_check_version(NULL) != NULL, @"### Unable to initialize gpgme sub-systems.");
        // Let's initialize default locale; we don't use that possibility in MacGPGME.framework yet
        gpgme_set_locale(NULL, LC_CTYPE, setlocale(LC_CTYPE, localeIdentifier));
        gpgme_set_locale(NULL, LC_MESSAGES, setlocale(LC_MESSAGES, localeIdentifier));
        
        // Let's tell gettext where is the locale directory
        const char  *localeDirectory = [[[[NSBundle bundleForClass:self] resourcePath] stringByAppendingPathComponent:@"locale"] fileSystemRepresentation];
        bindtextdomain("libgpg-error", localeDirectory);
        bindtextdomain("gettext-runtime", localeDirectory);
        
        // Let's add new user defaults suite, the one containing global prefs
        // for all MacGPGME-based apps
        [[NSUserDefaults standardUserDefaults] addSuiteNamed:GPGUserDefaultsSuiteName];
        // TODO: remove following code, later; client app should do the test itself.
        openPGPEngine = [GPGEngine engineForProtocol:GPGOpenPGPProtocol];
        aPath = [[NSUserDefaults standardUserDefaults] stringForKey:[openPGPEngine executablePathDefaultsKey]];
        if(aPath == nil){
            NSArray *availableExecutablePaths = [openPGPEngine availableExecutablePaths];
            
            if([availableExecutablePaths count] > 0)
                aPath = [availableExecutablePaths objectAtIndex:0];
        }
        if(aPath != nil){
            NS_DURING
                [[GPGEngine engineForProtocol:GPGOpenPGPProtocol] setExecutablePath:aPath];
            NS_HANDLER
                // Ignore error and log it
                NSLog(@"No valid gpg engine at '%@'; you need to change default engine path", aPath);
            NS_ENDHANDLER
        }
        [[NSDistributedNotificationCenter defaultCenter] addObserver:[GPGOptions class] selector:@selector(defaultsDidChange:) name:GPGDefaultsDidChangeNotification object:nil];
    }
}

+ (BOOL) needsPointerUniquing
{
    return NO;
}

+ (NSRecursiveLock *) pointerUniquingTableLock
{
    return mapTableLock;
}

- (id) initWithInternalRepresentation:(void *)aPtr
{
    BOOL	needsPointerUniquing = [[self class] needsPointerUniquing];

    NSAssert(!needsPointerUniquing || aPtr != NULL, @"### Cannot map wrapper to a NULL pointer");
    
    if(self = [super init]){
        id	anExistingObject = nil;

        if(needsPointerUniquing){
            [mapTableLock lock];
            anExistingObject = NSMapGet(mapTable, aPtr);
            [mapTableLock unlock];
        }

        if(anExistingObject != nil){
            [self release];
            self = [anExistingObject retain]; // We MUST call -retain, because there was an +alloc, and retainCount must augment
        }
        else{
            _internalRepresentation = aPtr;
            if(needsPointerUniquing)
                [self registerUniquePointer];
        }
    }

    return self;
}

- (void) registerUniquePointer
{
    NSAssert(_internalRepresentation != NULL, @"### Unable to register NULL pointer!");
    [mapTableLock lock];
    NSMapInsertKnownAbsent(mapTable, _internalRepresentation, self);
    [mapTableLock unlock];
}

- (void) unregisterUniquePointer
{
    NSAssert(_internalRepresentation != NULL, @"### Unable to unregister NULL pointer!");
    [mapTableLock lock];
    NSMapRemove(mapTable, _internalRepresentation);
    [mapTableLock unlock];
}

- (void) dealloc
{
    if([[self class] needsPointerUniquing]){
        if(_internalRepresentation != NULL){
            [self unregisterUniquePointer];
        }
    }
    else{
        if(_internalRepresentation != NULL){
            // Free pointer? No. Subclasses should take care of it, when necessary.
        }
    }
    
    [super dealloc];
}

+ (BOOL) accessInstanceVariablesDirectly
{
    return NO;
}

@end
