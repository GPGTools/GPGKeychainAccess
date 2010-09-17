//
//  GPGData.m
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

#include <MacGPGME/GPGData.h>
#include <MacGPGME/GPGExceptions.h>
#include <MacGPGME/GPGInternals.h>
#include <Foundation/Foundation.h>
#include <gpgme.h>


#define _data		((gpgme_data_t)_internalRepresentation)


@implementation GPGData

- (id) init
{
    gpgme_data_t	aData;
    gpgme_error_t	anError = gpgme_data_new(&aData);

    if(anError != GPG_ERR_NO_ERROR){
        [self release];
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
    }
    self = [self initWithInternalRepresentation:aData];
    
    return self;
}

- (id) initWithData:(NSData *)someData
{
    gpgme_data_t	aData;
    gpgme_error_t	anError = gpgme_data_new_from_mem(&aData, [someData bytes], [someData length], 1);

    if(anError != GPG_ERR_NO_ERROR){
        [self release];
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
    }
    self = [self initWithInternalRepresentation:aData];

    return self;
}

- (id) initWithDataNoCopy:(NSData *)someData
{
    gpgme_data_t	aData;
    gpgme_error_t	anError = gpgme_data_new_from_mem(&aData, ([someData respondsToSelector:@selector(mutableBytes)] ? [(NSMutableData *)someData mutableBytes]:[someData bytes]), [someData length], 0);

    if(anError != GPG_ERR_NO_ERROR){
        [self release];
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
    }
    self = [self initWithInternalRepresentation:aData];
    ((GPGData *)self)->_objectReference = [someData retain];
    
    return self;
}

static ssize_t readCallback(void *object, void *destinationBuffer, size_t destinationBufferSize)
{
    // Returns the number of bytes read, or -1 on error. Sets errno in case of error.
    NSData	*readData = nil;
    ssize_t	readLength = 0;
    
    NSCParameterAssert(destinationBufferSize != 0 && destinationBuffer != NULL);

    NS_DURING
        readData = [((GPGData *)object)->_objectReference data:((GPGData *)object) readDataOfLength:destinationBufferSize];
    NS_HANDLER
        if([[localException name] isEqualToString:GPGException]){
            NSNumber	*errorNumber = [[localException userInfo] objectForKey:GPGErrorKey];
            int			errorCodeAsErrno;
            
            NSCAssert(errorNumber != nil, @"### GPGException raised by GPGData dataSource has no error");
            errorCodeAsErrno = gpg_err_code_to_errno(gpgme_err_code([errorNumber intValue]));
            NSCAssert2(errorCodeAsErrno != 0, @"### GPGException raised by GPGData dataSource has not a system error errorCode (%@: %@)", errorNumber, GPGErrorDescription([errorNumber intValue]));

            errno = errorCodeAsErrno;
            
            return -1;
        }
        else
            [localException raise];
    NS_ENDHANDLER

    if(readData != nil){
        readLength = [readData length];

        if(readLength > 0){
            NSCAssert(((size_t)readLength) <= destinationBufferSize, @"### GPGData dataSource may not return more bytes than given capacity!");
            [readData getBytes:destinationBuffer];
        }
    }
    
    return readLength;
}

static ssize_t writeCallback(void *object, const void *buffer, size_t size)
{
    // Returns the number of bytes written, or -1 on error. Sets errno in case of error.
    ssize_t writeLength = 0;
    NSData	*data = [NSData dataWithBytesNoCopy:(void *)buffer length:size freeWhenDone:NO];

    NS_DURING
        writeLength = [((GPGData *)object)->_objectReference data:((GPGData *)object) writeData:data];
    NS_HANDLER
        if([[localException name] isEqualToString:GPGException]){
            NSNumber	*errorNumber = [[localException userInfo] objectForKey:GPGErrorKey];
            int			errorCodeAsErrno;

            NSCAssert(errorNumber != nil, @"### GPGException raised by GPGData dataSource has no error");
            errorCodeAsErrno = gpg_err_code_to_errno(gpgme_err_code([errorNumber intValue]));
            NSCAssert2(errorCodeAsErrno != 0, @"### GPGException raised by GPGData dataSource has not a system error errorCode (%@: %@)", errorNumber, GPGErrorDescription([errorNumber intValue]));

            errno = errorCodeAsErrno;

            return -1;
        }
        else
            [localException raise];
    NS_ENDHANDLER

    return writeLength;
}

static off_t seekCallback(void *object, off_t offset, int whence)
{
    // Returns the number of bytes written, or -1 on error. Sets errno in case of error.
    off_t	newPosition = 0;

    NS_DURING
        newPosition = [((GPGData *)object)->_objectReference data:((GPGData *)object) seekToFileOffset:offset offsetType:whence];
    NS_HANDLER
        if([[localException name] isEqualToString:GPGException]){
            NSNumber	*errorNumber = [[localException userInfo] objectForKey:GPGErrorKey];
            int			errorCodeAsErrno;

            NSCAssert(errorNumber != nil, @"### GPGException raised by GPGData dataSource has no error");
            errorCodeAsErrno = gpg_err_code_to_errno(gpgme_err_code([errorNumber intValue]));
            NSCAssert2(errorCodeAsErrno != 0, @"### GPGException raised by GPGData dataSource has not a system error errorCode (%@: %@)", errorNumber, GPGErrorDescription([errorNumber intValue]));

            errno = errorCodeAsErrno;

            return -1;
        }
        else
            [localException raise];
    NS_ENDHANDLER

    return newPosition;
}

static void releaseCallback(void *object)
{
    [((GPGData *)object)->_objectReference dataRelease:((GPGData *)object)];
}

- (id) initWithDataSource:(id)dataSource
{
    gpgme_data_t		aData;
    gpgme_error_t		anError;
    gpgme_data_cbs_t	callbacks;

    NSParameterAssert(dataSource != nil);

    callbacks = (gpgme_data_cbs_t)NSZoneCalloc([self zone], 1, sizeof(struct gpgme_data_cbs));
    if([dataSource respondsToSelector:@selector(data:readDataOfLength:)])
        callbacks->read = readCallback;
    if([dataSource respondsToSelector:@selector(data:writeData:)])
        callbacks->write = writeCallback;
    if([dataSource respondsToSelector:@selector(data:seekToFileOffset:offsetType:)])
        callbacks->seek = seekCallback;
    if([dataSource respondsToSelector:@selector(data:dataRelease:)])
        callbacks->release = releaseCallback;
    
    NSParameterAssert(callbacks->read != NULL || callbacks->write != NULL);

    anError = gpgme_data_new_from_cbs(&aData, callbacks, self);

    if(anError != GPG_ERR_NO_ERROR){
        NSZoneFree([self zone], callbacks);
        [self release];
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
    }
    NSAssert(self == [self initWithInternalRepresentation:aData], @"Tried to change self! Impossible due to callback registration.");
    _objectReference = dataSource; // We don't retain dataSource
    _callbacks = callbacks;
    
    return self;
}

- (id) initWithContentsOfFile:(NSString *)filename
{
    gpgme_data_t	aData;
    gpgme_error_t	anError = gpgme_data_new_from_file(&aData, [filename fileSystemRepresentation], 1);

    if(anError != GPG_ERR_NO_ERROR){
        [self release];
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
    }
    self = [self initWithInternalRepresentation:aData];
    [self setFilename:[filename lastPathComponent]];
    
    return self;
}

- (id) initWithContentsOfFileNoCopy:(NSString *)filename
#warning Not yet supported as of 1.1.x
// Can raise a GPGException; in this case, a release is sent to self
{
    gpgme_data_t	aData;
    gpgme_error_t	anError = gpgme_data_new_from_file(&aData, [filename fileSystemRepresentation], 0);

    if(anError != GPG_ERR_NO_ERROR){
        [self release];
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
    }
    self = [self initWithInternalRepresentation:aData];
    [self setFilename:[filename lastPathComponent]];
    
    return self;
}

- (id) initWithContentsOfFile:(NSString *)filename atOffset:(off_t)offset length:(size_t)length
{
    // We don't provide a method to match the case where filename is NULL
    // and filePtr (FILE *) is not NULL (both arguments are exclusive),
    // because we generally don't manipulate FILE * types in Cocoa.
    gpgme_data_t	aData;
    gpgme_error_t	anError = gpgme_data_new_from_filepart(&aData, [filename fileSystemRepresentation], NULL, offset, length);

    if(anError != GPG_ERR_NO_ERROR){
        [self release];
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
    }
    self = [self initWithInternalRepresentation:aData];
    [self setFilename:[filename lastPathComponent]];

    return self;
}

// We don't support gpgme_data_new_from_stream(), because there is
// no STREAM handling in Cocoa, yet(?).
// Maybe in Panther with NSStream?

- (id) initWithFileHandle:(NSFileHandle *)fileHandle
{
    gpgme_data_t	aData;
    gpgme_error_t	anError = gpgme_data_new_from_fd(&aData, [fileHandle fileDescriptor]);

    if(anError != GPG_ERR_NO_ERROR){
        [self release];
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
    }
    self = [self initWithInternalRepresentation:aData];
    ((GPGData *)self)->_objectReference = [fileHandle retain];

    return self;
}

- (void) dealloc
{
    gpgme_data_t	cachedData = _data;

    if(_callbacks != NULL)
        NSZoneFree([self zone], _callbacks);
    // If _callbacks is not NULL, it means that _objectReference was a non-retained dataSource
    else if(_objectReference != nil)
        [_objectReference release];
    [super dealloc];

    // We could have a problem here if we set ourself as callback
    // and _data is deallocated later than us!!!
    // This shouldn't happen, but who knows...
    if(cachedData != NULL)
        gpgme_data_release(cachedData);
}

#if 0
- (id) copyWithZone:(NSZone *)zone
{
    GPGData	*aCopy = nil;
    
    switch([self type]){
        case GPGDataTypeNone:
            aCopy = [[[self class] allocWithZone:zone] init];
            break;
        case GPGDataTypeData:
            if(_retainedData != nil){
                NSMutableData	*copiedData = [_retainedData mutableCopyWithZone:zone];
                
                aCopy = [[[self class] allocWithZone:zone] initWithDataNoCopy:copiedData];
                [copiedData release];
            }
            else
                aCopy = [[[self class] allocWithZone:zone] initWithData:[self data]]; // WARNING: this rewinds myself and reads until EOF!
            break;
        case GPGDataTypeFileHandle:
            // We don't provide a way in GPGME to create such data types
            [NSException raise:NSInternalInconsistencyException format:@"### Unsupported GPGData type %d", [self type]];
            break;
        case GPGDataTypeFile:
            // There is no way to know which inititializer was called!
            [NSException raise:NSInternalInconsistencyException format:@"### Unsupported GPGData type %d", [self type]];
            break;
        case GPGDataTypeDataSource:
            aCopy = [[[self class] allocWithZone:zone] initWithDataSource:_dataSource];
            [aCopy rewind]; // This also rewinds myself!
            break;
        default:
            [NSException raise:NSInternalInconsistencyException format:@"### Unknown GPGData type %d", [self type]];
    }
    
    return aCopy;
}
#endif

- (GPGDataEncoding) encoding
{
    GPGDataEncoding	encoding = gpgme_data_get_encoding(_data);

    return encoding;
}

- (void) setEncoding:(GPGDataEncoding)encoding
{
    gpgme_error_t	anError = gpgme_data_set_encoding(_data, encoding);

    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
}

- (off_t) seekToFileOffset:(off_t)offset offsetType:(GPGDataOffsetType)offsetType
{
    off_t	newPosition = gpgme_data_seek(_data, offset, offsetType);

    if(newPosition < 0)
        [[NSException exceptionWithGPGError:gpgme_err_make_from_errno(GPG_MacGPGMEFrameworkErrorSource, errno) userInfo:nil] raise];

    return newPosition;
}

- (NSData *) readDataOfLength:(size_t)length
{
    NSMutableData	*readData = [NSMutableData dataWithLength:length];
    ssize_t			aReadLength = gpgme_data_read(_data, [readData mutableBytes], length);
    
    if(aReadLength == 0)
        return nil;
    if(aReadLength < 0)
        [[NSException exceptionWithGPGError:gpgme_err_make_from_errno(GPG_MacGPGMEFrameworkErrorSource, errno) userInfo:nil] raise];
    [readData setLength:aReadLength];

    return readData;
}

- (ssize_t) writeData:(NSData *)data
{
    ssize_t writtenByteCount = gpgme_data_write(_data, [data bytes], [data length]);
    
    if(writtenByteCount < 0)
        [[NSException exceptionWithGPGError:gpgme_err_make_from_errno(GPG_MacGPGMEFrameworkErrorSource, errno) userInfo:nil] raise];

    return writtenByteCount;
}

- (NSString *) filename
{
    const char	*aCString = gpgme_data_get_file_name(_data); // Returns original string -> make a copy
    
    return GPGStringFromChars(aCString);
}

- (void) setFilename:(NSString *)filename
{
    const char      *aCString = (filename != nil ? [filename fileSystemRepresentation] : NULL);    
    gpgme_error_t	anError = gpgme_data_set_file_name(_data, aCString); // Will duplicate string
    
    if(anError != GPG_ERR_NO_ERROR)
        [[NSException exceptionWithGPGError:anError userInfo:nil] raise];
}

@end


@implementation GPGData(GPGExtensions)

- (id) initWithString:(NSString *)string
{
    NSData	*data = [string dataUsingEncoding:NSUTF8StringEncoding];

    return [self initWithData:data];
}

- (NSString *) string
{
    NSData      *data = [self data];
    unsigned    dataLength = [data length];
    
    if(dataLength > 0){
        // Ensure byte buffer is 0-terminated
        const char  *dataBytes = [data bytes];
        
        if(dataBytes[dataLength - 1] != 0){
            NSMutableData   *newData = [data mutableCopy];
            NSString        *aString;
            
            [newData setLength:dataLength + 1];
            ((char *)[newData mutableBytes])[dataLength] = 0;
            
            aString = GPGStringFromChars([newData bytes]);
            [newData release];
            
            return aString;
        }
        else
            return GPGStringFromChars(dataBytes);
    }
    else
        return @"";
}

- (off_t) length
{
    off_t   currentPos;
    off_t   length;
    
    currentPos = gpgme_data_seek(_data, 0, GPGDataCurrentPosition);    
    if(currentPos < 0)
        [[NSException exceptionWithGPGError:gpgme_err_make_from_errno(GPG_MacGPGMEFrameworkErrorSource, errno) userInfo:nil] raise];
    length = gpgme_data_seek(_data, 0, GPGDataEndPosition);
    if(length < 0)
        [[NSException exceptionWithGPGError:gpgme_err_make_from_errno(GPG_MacGPGMEFrameworkErrorSource, errno) userInfo:nil] raise];

    NSAssert(gpgme_data_seek(_data, currentPos, GPGDataStartPosition) == currentPos, @"Unable to go back to original position!");
    
    return length;
}

- (BOOL) isAtEnd
{
    off_t   currentPos;
    off_t   length;
    
    currentPos = gpgme_data_seek(_data, 0, GPGDataCurrentPosition);    
    if(currentPos < 0)
        [[NSException exceptionWithGPGError:gpgme_err_make_from_errno(GPG_MacGPGMEFrameworkErrorSource, errno) userInfo:nil] raise];
    length = gpgme_data_seek(_data, 0, GPGDataEndPosition);
    if(length < 0)
        [[NSException exceptionWithGPGError:gpgme_err_make_from_errno(GPG_MacGPGMEFrameworkErrorSource, errno) userInfo:nil] raise];

    NSAssert(gpgme_data_seek(_data, currentPos, GPGDataStartPosition) == currentPos, @"Unable to go back to original position!");
    
    return currentPos == length;
}

- (NSData *) availableData
{
    size_t			bufferSize = NSPageSize();
    NSZone			*aZone = NSDefaultMallocZone();
    char			*bufferPtr = (char *)NSZoneMalloc(aZone, bufferSize);
    NSMutableData	*readData = [NSMutableData dataWithCapacity:bufferSize];
    ssize_t			aReadLength;
    
    do{
        aReadLength = gpgme_data_read(_data, bufferPtr, bufferSize);
        
        if(aReadLength > 0)
            [readData appendBytes:bufferPtr length:aReadLength];
    }while(aReadLength > 0);

    NSZoneFree(aZone, bufferPtr);
    if(aReadLength < 0)
        [[NSException exceptionWithGPGError:gpgme_err_make_from_errno(GPG_MacGPGMEFrameworkErrorSource, errno) userInfo:nil] raise];

    return readData;
}

- (NSData *) data
{
    [self rewind];

    return [self availableData];
}

- (void) rewind
{
    off_t	newPosition = gpgme_data_seek(_data, 0, GPGDataStartPosition);

    if(newPosition < 0)
        [[NSException exceptionWithGPGError:gpgme_err_make_from_errno(GPG_MacGPGMEFrameworkErrorSource, errno) userInfo:nil] raise];
}

@end


@implementation GPGData(GPGInternals)

- (gpgme_data_t) gpgmeData
{
    return _data;
}

@end
