//
//  GPGAsyncHelper.m
//  MacGPGME
//
//  Created by davelopper at users.sourceforge.net on Mon Apr 12 2004.
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

#include "GPGAsyncHelper.h"
#include <MacGPGME/GPGContext.h>
#include <MacGPGME/GPGInternals.h>
#include <MacGPGME/GPGTrustItem.h>
#include <sys/types.h>
#include <sys/time.h>
#include <unistd.h>
#include <gpgme.h>


static gpgme_error_t addCallback(void *data, int fd, int dir, gpgme_io_cb_t fnc, void *fnc_data, void **tag);
static void removeCallback(void *tag);
static void eventCallback(void *data, gpgme_event_io_t type, void *type_data);

@interface GPGAsyncHelper(Private)
- (gpgme_error_t) addCallbackForContext:(GPGContext *)context fileDescriptor:(int)fd direction:(int)dir function:(void *)fnc functionData:(void *)fnc_data;
- (void) removeCallbacksForFileDescriptor:(int)fd;
- (void) eventOfType:(gpgme_event_io_t)type forContext:(GPGContext *)context eventData:(void *)type_data;
@end

@implementation GPGAsyncHelper

+ (GPGAsyncHelper *) sharedInstance
{
    static GPGAsyncHelper	*_sharedInstance = nil;

    if(_sharedInstance == nil)
        _sharedInstance = [[self alloc] init];

    return _sharedInstance;
}

- (id) init
{
    if(self = [super init]){
        NSZone	*aZone = [self zone];
        
        _dataLock = [[NSLock allocWithZone:aZone] init];
        _runSemaphore = [[NSConditionLock allocWithZone:aZone] initWithCondition:0];
#if defined(MAC_OS_X_VERSION_10_5) && (MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5)
        _paramsPerFd = NSCreateMapTableWithZone(NSIntegerMapKeyCallBacks, NSObjectMapValueCallBacks, 10, aZone);
#else
        _paramsPerFd = NSCreateMapTableWithZone(NSIntMapKeyCallBacks, NSObjectMapValueCallBacks, 10, aZone);
#endif
        _contexts = [[NSMutableSet allocWithZone:aZone] initWithCapacity:3];
        [NSThread detachNewThreadSelector:@selector(run) toTarget:self withObject:nil];
    }

    return self;
}

- (void) dealloc
{
    [_dataLock release];
    [_runSemaphore release];
    if(_paramsPerFd != NULL)
        NSFreeMapTable(_paramsPerFd);
    [_contexts release];
    
    [super dealloc];
}

- (void) prepareAsyncOperationInContext:(GPGContext *)context
{
    [_dataLock lock];
    NS_DURING
        gpgme_io_cbs_t	callbacks;

        NSParameterAssert(context != nil && ![_contexts containsObject:context]); // TODO: allow queueing operations for same context? How to?
        callbacks = (gpgme_io_cbs_t)NSZoneMalloc(NSDefaultMallocZone(), sizeof(struct gpgme_io_cbs));
        callbacks->add = addCallback;
        callbacks->add_priv = context;
        callbacks->remove = removeCallback;
        callbacks->event = eventCallback;
        callbacks->event_priv = context;

        gpgme_set_io_cbs([context gpgmeContext], callbacks);
        [_contexts addObject:context];
        NSZoneFree(NSDefaultMallocZone(), callbacks);
    NS_HANDLER
        [_dataLock unlock];
        [localException raise];
    NS_ENDHANDLER
    [_dataLock unlock];
}

- (void) run
{
    // We should use a semaphore to show when running or not; set after adding/removing fds
    while(YES){
        int				nfds = 0;
        fd_set			aReadFdSet;
        fd_set			aWriteFdSet;
        fd_set			allFdSet;
        struct timeval	timeout = {0L, 100000L}; // 0.1s
        NSMapEnumerator	anEnum;
        void			*aKey;
        void			*aValue;
        NSAutoreleasePool	*localAP = [[NSAutoreleasePool alloc] init];

//        [_runSemaphore lockWhenCondition:1];

        FD_ZERO(&aReadFdSet);
        FD_ZERO(&aWriteFdSet);
        FD_ZERO(&allFdSet);
        
        [_dataLock lock];
        anEnum = NSEnumerateMapTable(_paramsPerFd);
        while(NSNextMapEnumeratorPair(&anEnum, &aKey, &aValue)){
            int				aFd = (int)aKey;
            NSDictionary	*aDict = (NSDictionary *)aValue;
            
            nfds = MAX(aFd, nfds);
            if([[aDict objectForKey:@"dir"] intValue] == 0)
                FD_SET(aFd, &aWriteFdSet);
            else
                FD_SET(aFd, &aReadFdSet);
            FD_SET(aFd, &allFdSet);
            NSLog(@"Checking %d", aFd);
        }
        NSEndMapTableEnumeration(&anEnum);
        [_dataLock unlock];

        if(nfds > 0){
            int	aResult = select(nfds, &aReadFdSet, &aWriteFdSet, &allFdSet, &timeout);
            
            switch(aResult){
                case 0: // timeout
                    break;
                case -1: // error
                    NSLog(@"### Error when surveying fds; errno = %d ###", errno);
                    break;
                default: // something to read/write/exception
                    [_dataLock lock];
                    anEnum = NSEnumerateMapTable(_paramsPerFd);
                    while(NSNextMapEnumeratorPair(&anEnum, &aKey, &aValue)){
                        int				aFd = (int)aKey;
                        NSDictionary	*aDict = (NSDictionary *)aValue;

                        if(aFd <= nfds){
#warning Should we unlock _dataLock during function evaluation?
                            if(FD_ISSET(aFd, &aReadFdSet)){
                                NSLog(@"Reading %d", aFd);
                                (void)(*((gpgme_io_cb_t)[[aDict objectForKey:@"fnc"] pointerValue]))([[aDict objectForKey:@"fnc_data"] pointerValue], aFd); // We don't care (yet) about the result; it should always be 0
                            }
                            else if(FD_ISSET(aFd, &aWriteFdSet)){
                                NSLog(@"Writing %d", aFd);
                                (void)(*((gpgme_io_cb_t)[[aDict objectForKey:@"fnc"] pointerValue]))([[aDict objectForKey:@"fnc_data"] pointerValue], aFd); // We don't care (yet) about the result; it should always be 0
                            }
                            else if(FD_ISSET(aFd, &allFdSet)){
                                NSLog(@"### Exception on fd %d when surveying fds ###", aFd);
                            }
                        }
                    }
                    NSEndMapTableEnumeration(&anEnum);
                    [_dataLock unlock];
            }
        }
        else
            [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
//        [_runSemaphore unlock];
        [localAP release];
    }
}

static gpgme_error_t addCallback(void *data, int fd, int dir, gpgme_io_cb_t fnc, void *fnc_data, void **tag)
{
    gpgme_error_t	anError = [[GPGAsyncHelper sharedInstance] addCallbackForContext:data fileDescriptor:fd direction:dir function:fnc functionData:fnc_data];

    *tag = (void *)fd;

    return anError;
}

- (gpgme_error_t) addCallbackForContext:(GPGContext *)context fileDescriptor:(int)fd direction:(int)dir function:(void *)fnc functionData:(void *)fnc_data
{
    gpgme_error_t	result;
    NSValue			*fncValue = [NSValue valueWithPointer:fnc];
    NSValue			*fnc_dataValue = [NSValue valueWithPointer:fnc_data];
    NSNumber		*dirNumber = [NSNumber numberWithInt:dir];

    [_dataLock lock];
    NS_DURING
        NSDictionary	*newParams = [[NSDictionary alloc] initWithObjectsAndKeys:fncValue, @"fnc", fnc_dataValue, @"fnc_data", dirNumber, @"dir", nil];
        
        NSMapInsertKnownAbsent(_paramsPerFd, (void *)fd, newParams);
        [newParams release];
        NSLog(@"Added callback %d(%d)", fd, dir);
        result = GPG_ERR_NO_ERROR;
    NS_HANDLER
        NSLog(@"### Error when adding async callback: %@", localException);
        result = gpg_err_make(GPG_MacGPGMEFrameworkErrorSource, GPG_ERR_GENERAL);
    NS_ENDHANDLER
    [_dataLock unlock];
    if([_runSemaphore tryLockWhenCondition:0])
        [_runSemaphore unlockWithCondition:1];

    return result;
}

static void removeCallback(void *tag)
{
    [[GPGAsyncHelper sharedInstance] removeCallbacksForFileDescriptor:(int)tag];
}

- (void) removeCallbacksForFileDescriptor:(int)fd
{
    [_dataLock lock];
    NSMapRemove(_paramsPerFd, (void *)fd);
    NSLog(@"Removed callback %d", fd);
    if(NSCountMapTable(_paramsPerFd) == 0){
        [_dataLock unlock];
        if([_runSemaphore tryLockWhenCondition:1])
            [_runSemaphore unlockWithCondition:0];
    }
    else
        [_dataLock unlock];
}

static void eventCallback(void *data, gpgme_event_io_t type, void *type_data)
{
    [[GPGAsyncHelper sharedInstance] eventOfType:type forContext:data eventData:type_data];
}

- (void) postNotificationInMainThread:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] postNotification:notification];
}

- (void) eventOfType:(gpgme_event_io_t)type forContext:(GPGContext *)context eventData:(void *)type_data
{
    switch(type){
        case GPGME_EVENT_START:
#warning Add context fds to select FD_SET
            NSLog(@"eventCallback: GPGME_EVENT_START");
            break;
        case GPGME_EVENT_DONE:{
            GPGError		anError = *((GPGError *)type_data);
            NSNotification	*aNotification = [NSNotification notificationWithName:GPGAsynchronousOperationDidTerminateNotification object:context userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:anError] forKey:GPGErrorKey]];

            [_dataLock lock];
            gpgme_set_io_cbs([context gpgmeContext], NULL);
            [_contexts removeObject:context];
            [_dataLock unlock];
            [self performSelectorOnMainThread:@selector(postNotificationInMainThread:) withObject:aNotification waitUntilDone:NO];
            // Post notification in main thread
            NSLog(@"eventCallback: GPGME_EVENT_DONE");
            NSLog(@"Termination status: %@ (%d)", GPGErrorDescription(anError), anError);
            break;
        }
        case GPGME_EVENT_NEXT_KEY:{
            GPGKey			*aKey = [[GPGKey alloc] initWithInternalRepresentation:((gpgme_key_t)type_data)];
            NSNotification	*aNotification = [NSNotification notificationWithName:GPGNextKeyNotification object:context userInfo:[NSDictionary dictionaryWithObject:aKey forKey:GPGNextKeyKey]];

            gpgme_key_unref((gpgme_key_t)type_data);
            [self performSelectorOnMainThread:@selector(postNotificationInMainThread:) withObject:aNotification waitUntilDone:NO];
            // Post notification in main thread
            NSLog(@"eventCallback: GPGME_EVENT_NEXT_KEY");
            NSLog(@"Next key: %@", [aKey userID]);
            [aKey release];
            break;
        }
        case GPGME_EVENT_NEXT_TRUSTITEM:{
            GPGTrustItem	*aTrustItem = [[GPGTrustItem alloc] initWithInternalRepresentation:((gpgme_trust_item_t)type_data)];
            NSNotification	*aNotification = [NSNotification notificationWithName:GPGNextTrustItemNotification object:context userInfo:[NSDictionary dictionaryWithObject:aTrustItem forKey:GPGNextTrustItemKey]];

            gpgme_trust_item_unref((gpgme_trust_item_t)type_data);
            [self performSelectorOnMainThread:@selector(postNotificationInMainThread:) withObject:aNotification waitUntilDone:NO];
            // Post notification in main thread
            NSLog(@"eventCallback: GPGME_EVENT_NEXT_TRUSTITEM");
            NSLog(@"Next trustItem: %@", aTrustItem);
            [aTrustItem release];
            break;
        }
        default:
            NSLog(@"-[%@ %@]: unknown event type %d; ignored", [self class], NSStringFromSelector(_cmd), type);
    }
}

@end
