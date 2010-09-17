//
//  GPGData.h
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

#ifndef GPGDATA_H
#define GPGDATA_H

#include <MacGPGME/GPGObject.h>

#ifdef __cplusplus
extern "C" {
#if 0 /* just to make Emacs auto-indent happy */
}
#endif
#endif


@class NSData;
@class NSFileHandle;
@class NSMutableData;
@class NSString;


/*!
 *  @typedef    GPGDataEncoding
 *  @abstract   Specifies the encoding of a <code>@link //macgpg/occ/cl/GPGData GPGData@/link</code>
 *              object.
 *  @discussion The GPGDataEncoding type specifies the encoding of a
 *              <code>@link //macgpg/occ/cl/GPGData GPGData@/link</code> object.
 *              This encoding is useful to give the back-end a hint on the type
 *              of data.
 *  @constant   GPGDataEncodingNone   This specifies that the encoding is not
 *                                    known. This is the default for a new data
 *                                    object. The back-end will try its best to
 *                                    detect the encoding automatically.
 *  @constant   GPGDataEncodingBinary This specifies that the data is encoding
 *                                    in binary form; i.e. there is no special 
 *                                    encoding.
 *  @constant   GPGDataEncodingBase64 This specifies that the data is encoded
 *                                    using the Base-64 encoding scheme as used
 *                                    by MIME and other protocols.
 *  @constant   GPGDataEncodingArmor  This specifies that the data is encoded in 
 *                                    an armored form as used by OpenPGP and
 *                                    PEM.
 */
typedef enum {
    GPGDataEncodingNone   = 0,
    GPGDataEncodingBinary = 1,
    GPGDataEncodingBase64 = 2,
    GPGDataEncodingArmor  = 3
} GPGDataEncoding;


/*!
 *  @typedef    GPGDataOffsetType
 *  @abstract   Specifies how the offset should be interpreted when
 *              repositioning read/write, like in <code>@link seekToFileOffset:offsetType: seekToFileOffset:offsetType:@/link</code>
 *              (GPGData) and <code>@link data:seekToFileOffset:offsetType: data:seekToFileOffset:offsetType:@/link</code>
 *              (GPGDataSource informal protocol).
 *  @constant   GPGDataStartPosition   Offset is a count of characters from the
 *                                     beginning of the data object.
 *  @constant   GPGDataCurrentPosition Offset is a count of characters from the 
 *                                     current file position. This count may be
 *                                     positive or negative.
 *  @constant   GPGDataEndPosition     Offset is a count of characters from the
 *                                     end of the data object. A negative count
 *                                     specifies a position within the current
 *                                     extent of the data object; a positive 
 *                                     count specifies a position past the
 *                                     current end. If you set the position past
 *                                     the current end, and actually write data, 
 *                                     you will extend the data object with 
 *                                     zeros up to that position.
 */
typedef enum {
    GPGDataStartPosition    = 0,
    GPGDataCurrentPosition  = 1,
    GPGDataEndPosition      = 2
} GPGDataOffsetType;

/*!
 *  @class      GPGData
 *  @abstract   Encapsulates data exchanged with MacGPGME crypto engines.
 *  @discussion A lot of data has to be exchanged between the user and the
 *              crypto engine, like plaintext messages, ciphertext, signatures
 *              and information about the keys. The technical details about
 *              exchanging the data information are completely abstracted by
 *              GPGME. The user provides and receives the data via
 *              GPGData objects, regardless of the communication protocol
 *              between GPGME and the crypto engine in use. GPGData contains
 *              both data and meta-data, e.g. file name.
 *
 *              Data objects can be based on memory, files, or callback methods
 *              provided by the user (data source). Not all operations are
 *              supported by all objects.
 *              <h2>Memory Based Data Buffers</h2>
 *              Memory based data objects store all data in allocated memory.
 *              This is convenient, but only practical for an amount of data
 *              that is a fraction of the available physical memory. The data
 *              has to be copied from its source and to its destination, which
 *              can often be avoided by using one of the other data object.
 *
 *              Here are the methods to initialize memory based data buffers:
 *              <ul>
 *              <li><code>@link //macgpg/occ/instm/GPGData/init init@/link</code></li>
 *              <li><code>@link initWithData: initWithData:@/link</code></li>
 *              <li><code>@link initWithDataNoCopy: initWithDataNoCopy:@/link</code></li>
 *              <li><code>@link initWithContentsOfFile: initWithContentsOfFile:@/link</code></li>
 *              <li><code>@link initWithContentsOfFile:atOffset:length: initWithContentsOfFile:atOffset:length:@/link</code></li></ul>
 *              <h2>File Based Data Buffers</h2>
 *              File based data objects operate directly on file descriptors
 *              or streams. Only a small amount of data is stored in core at any
 *              time, so the size of the data objects is not limited by GPGME.
 *
 *              Here are the methods to initialize file based data buffers:<ul>
 *              <li><code>@link initWithFileHandle: initWithFileHandle:@/link</code></li></ul>
 *              <h2>Callback Based Data Buffers</h2>
 *              If neither memory nor file based data objects are a good fit for
 *              your application, you can provide a data source implementing
 *              <code>@link //macgpg/occ/cat/NSObject(GPGDataSource) NSObject(GPGDataSource)@/link</code>
 *              methods and create a data object with this data source.
 *
 *              Here are the methods to initialize callback based data buffers:
 *              <ul>
 *              <li><code>@link initWithDataSource: initWithDataSource:@/link</code></li>
 *              </ul>
 */
@interface GPGData : GPGObject
{
    id		_objectReference;
    void	*_callbacks;
}

/*!
 *  @methodgroup Creating memory based data buffers
 */

/*!
 *  @method     init
 *  @abstract   Returns data without content and memory-based.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception; in this case, a <code>@link //apple_ref/occ/intfm/NSObject/release release@/link</code>
 *              is sent to self.
 */
- (id) init;

/*!
 *  @method     initWithData:
 *  @abstract   Returns data with a copy of <i>someData</i>'s bytes.
 *  @param      someData Data whose bytes are copied
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception; in this case, a <code>@link //apple_ref/occ/intfm/NSObject/release release@/link</code>
 *              is sent to self.
 */
- (id) initWithData:(NSData *)someData;

/*!
 *  @method     initWithDataNoCopy:
 *  @abstract   Returns data referencing (retaining) <i>someData</i>.
 *  @param      someData Data which is retained
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception; in this case, a <code>@link //apple_ref/occ/intfm/NSObject/release release@/link</code>
 *              is sent to self.
 */
- (id) initWithDataNoCopy:(NSData *)someData;

/*!
 *  @method     initWithContentsOfFile:
 *  @abstract   Returns data initialized with content of file <i>filename</i>.
 *  @discussion Immediately opens file named <i>filename</i> (which must be an
 *              absolute path) and copies content into memory; then it closes
 *              file. File name is also saved in data.
 *  @param      filename Absolute path to file whose content is immediately
 *              read
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception; in this case, a <code>@link //apple_ref/occ/intfm/NSObject/release release@/link</code>
 *              is sent to self.
 */
- (id) initWithContentsOfFile:(NSString *)filename;

//- (id) initWithContentsOfFileNoCopy:(NSString *)filename;

/*!
 *  @method     initWithContentsOfFile:atOffset:length:
 *  @abstract   Returns data initialized with partial content of file 
 *              <i>filename</i>.
 *  @discussion Immediately opens file and copies partial content into memory; 
 *              then it closes file. File name is also saved in data.
 *  @param      filename Absolute path to file whose content is immediately
 *              read
 *  @param      offset Offset at which to start reading file, in bytes
 *  @param      length Number of bytes to read
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception; in this case, a <code>@link //apple_ref/occ/intfm/NSObject/release release@/link</code>
 *              is sent to self.
 */
- (id) initWithContentsOfFile:(NSString *)filename atOffset:(off_t)offset length:(size_t)length;


/*!
 *  @methodgroup Creating file based data buffers
 */

/*!
 *  @method     initWithFileHandle:
 *  @abstract   Returns data that will read/write passed file handle.
 *  @discussion Uses <i>fileHandle</i> to read from (if used as an input data 
 *              object) and write to (if used as an output data object).
 *              <i>fileHandle</i> is retained.
 *
 *              When using the data object as an input buffer, the method might
 *              read a bit more from the file handle than is actually needed by
 *              the crypto engine in the desired operation because of internal
 *              buffering.
 *  @param      fileHandle Retained file handle.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception; in this case, a <code>@link //apple_ref/occ/intfm/NSObject/release release@/link</code>
 *              is sent to self.
 */
- (id) initWithFileHandle:(NSFileHandle *)fileHandle;


/*!
 *  @methodgroup Creating callback based data buffers
 */

/*!
 *  @method     initWithDataSource:
 *  @abstract   Returns data that will ask <i>dataSource</i> for all read/write
 *              operations. <i>dataSource</i> must implement
 *              <code>@link NSObject(GPGDataSource) NSObject(GPGDataSource)@/link</code>
 *              informal protocol.
 *  @discussion <i>dataSource</i> must implement some of the methods declared in
 *              <code>@link NSObject(GPGDataSource) NSObject(GPGDataSource)@/link</code>
 *              informal protocol. <i>dataSource</i> is not retained. 
 *              <i>dataSource</i> is invoked to read/write data on-demand, and
 *              it can supply the data in any way it wants; this is the most
 *              flexible data type MacGPGME provides.
 *  @param      dataSource Object implementing <code>@link NSObject(GPGDataSource) NSObject(GPGDataSource)@/link</code> informal protocol
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception; in this case, a <code>@link //apple_ref/occ/intfm/NSObject/release release@/link</code>
 *              is sent to self.
 */
- (id) initWithDataSource:(id)dataSource;


/*!
 *  @methodgroup Encoding
 */

/*!
 *  @method     encoding
 *  @abstract   Returns the encoding of the data object.
 */
- (GPGDataEncoding) encoding;

/*!
 *  @method     setEncoding:
 *  @abstract   Sets the encoding of the data object.
 *  @param      encoding Data encoding hint
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception
 */
- (void) setEncoding:(GPGDataEncoding)encoding;


/*!
 *  @methodgroup Manipulating data buffers
 */

/*!
 *  @method     seekToFileOffset:offsetType:
 *  @abstract   Sets position for next read/write operation.
 *  @discussion Sets the current position from where the next read or write
 *              starts in the data object to <i>offset</i>, relative to 
 *              <i>offsetType</i>. Returns the resulting file position, measured
 *              in bytes from the beginning of the data object. You can use this
 *              feature together with
 *              <code>@link GPGDataCurrentPosition GPGDataCurrentPosition@/link</code>
 *              to read the current read/write position.
 *  @param      offset Offset to jump to
 *  @param      offsetType Offset type
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              (<code>@link //macgpg/c/econst/GPGError_E* GPGError_E*@/link</code>) exception.
 */
- (off_t) seekToFileOffset:(off_t)offset offsetType:(GPGDataOffsetType)offsetType;

/*!
 *  @method     readDataOfLength:
 *  @abstract   Reads up to <i>length</i> bytes and returns them wrapped in a
 *              <code>@link //apple_ref/occ/cl/NSData NSData@/link</code>
 *              object.
 *  @discussion Reading starts from the current position. Returned data has the
 *              appropriate size, smaller or equal to <i>length</i>. Returns nil
 *              when there isn't anything more to read (EOF).
 *  @param      length Maximum bytes to read.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              (<code>@link //macgpg/c/econst/GPGError_E* GPGError_E*@/link</code>)
 *              exception.
 */
- (NSData *) readDataOfLength:(size_t)length;

/*!
 *  @method     writeData:
 *  @abstract   Writes <i>data</i> bytes by copying them.
 *  @discussion Writing starts from the current position. Returns the number of
 *              bytes written.
 *  @param      data Data to write.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              (<code>@link //macgpg/c/econst/GPGError_E* GPGError_E*@/link</code>)
 *              exception.
 */
- (ssize_t) writeData:(NSData *)data;


/*!
 *  @methodgroup Manipulating meta-data
 */

/*!
 *  @method     filename
 *  @abstract   Returns the file name associated with the data object.
 *  @discussion Returns nil if there is no file name or if there is an error.
 */
- (NSString *) filename;

/*!
 *  @method     setFilename:
 *  @abstract   Sets the file name associated with the data object.
 *  @discussion The file name will be stored in the output when encrypting or
 *              signing the data and will be returned to the user when
 *              decrypting or verifying the output data.
 *  @param      filename File name associated with data.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              (<code>@link //macgpg/c/econst/GPGError_ENOMEM GPGError_ENOMEM@/link</code>)
 *              exception if not enough memory is available.
 */
- (void) setFilename:(NSString *)filename;

@end


/*!
 *  @category   GPGData(GPGExtensions)
 *  @abstract   Convenience methods.
 */
@interface GPGData(GPGExtensions)

/*!
 *  @methodgroup Convenience initializer
 */

/*!
 *  @method     initWithString:
 *  @abstract   Gets data from <i>string</i> using UTF8 encoding, and invokes
 *              <code>@link initWithData: initWithData:@/link</code>.
 *  @discussion Convenience method.
 *  @param      string String to read.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception; in this case, a <code>@link //apple_ref/occ/intfm/NSObject/release release@/link</code>
 *              is sent to self.
 */
- (id) initWithString:(NSString *)string;


/*!
 *  @methodgroup Convenience methods
 */

/*!
 *  @method     length
 *  @abstract   Returns length of all data.
 *  @discussion Convenience method. Returns length of all data. Though read
 *              pointer is changed during computing, it is left unchanged on 
 *              return.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception.
 */
- (off_t) length;

/*!
 *  @method     data
 *  @abstract   Returns a copy of all data.
 *  @discussion Convenience method. Returns a copy of all data. It rewinds
 *              receiver, then reads data until EOF, and returns it.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception.
 */
- (NSData *) data;

/*!
 *  @method     string
 *  @abstract   Returns a copy of all data as string, using UTF8 string
 *              encoding (or ISOLatin1 if it cannot be decoded as UTF8).
 *  @discussion Convenience method. Returns a copy of all data as string, using
 *              UTF8 string encoding (or ISOLatin1 if it cannot be decoded as
 *              UTF8). It rewinds receiver, then reads data until EOF, and 
 *              returns a string initialized with it.
 *
 *              Invoking this method makes sense only when you know that data 
 *              corresponds to a string!
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              exception.
 */
- (NSString *) string;

/*!
 *  @method     availableData
 *  @abstract   Returns a copy of data, read from current position, up to end of
 *              data.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              (<code>@link //macgpg/c/econst/GPGError_E* GPGError_E*@/link</code>)
 *              exception.
 */
- (NSData *) availableData;

/*!
 *  @method     isAtEnd
 *  @abstract   Returns <code>YES</code> if there are no more bytes to read
 *              (EOF).
 *  @discussion Convenience method. Though read pointer is changed during 
 *              computing, it is left unchanged on return.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              (<code>@link //macgpg/c/econst/GPGError_E* GPGError_E*@/link</code>)
 *              exception.
 */
- (BOOL) isAtEnd;

/*!
 *  @method     rewind
 *  @abstract   Prepares data in a way that the next call to 
 *              <code>@link readDataOfLength: readDataOfLength:@/link</code> or
 *              <code>@link writeData: writeData:@/link</code> starts at the
 *              beginning of the data.
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              (<code>@link //macgpg/c/econst/GPGError_E* GPGError_E*@/link</code>)
 *              exception.
 */
- (void) rewind;

@end


/*!
 *  @category   NSObject(GPGDataSource)
 *  @abstract   This category declares methods that need to be implemented by
 *              @link GPGData GPGData@/link data sources. Data sources can be
 *              readable or writable.
 */
@interface NSObject(GPGDataSource)

/*!
 *  @method     data:readDataOfLength:
 *  @abstract   Reads up to <i>maxLength</i> bytes of <i>data</i> and returns
 *              them in a <code>@link //apple_ref/occ/cl/NSData NSData@/link</code>
 *              object.
 *  @discussion Returning an empty data or nil means that there is nothing more
 *              to read (EOF). Only required for input data objects.
 *
 *              Reading must be performed from the current position.
 *
 *              Returned data will be copied by @link GPGData GPGData@/link 
 *              object.
 *  @param      data Caller
 *  @param      maxLength Maximum byte count to read
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              (<code>@link //macgpg/c/econst/GPGError_E* GPGError_E*@/link</code>)
 *              exception in case of error.
 */
- (NSData *) data:(GPGData *)data readDataOfLength:(unsigned long)maxLength;

/*!
 *  @method     data:writeData:
 *  @abstract   Writes <i>writeData</i> from the current position.
 *  @discussion Returns the number of bytes written. Only required for output 
 *              data objects.
 *  @param      data Caller
 *  @param      writeData Data to write
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              (<code>@link //macgpg/c/econst/GPGError_E* GPGError_E*@/link</code>)
 *              exception in case of error.
 */
- (unsigned long) data:(GPGData *)data writeData:(NSData *)writeData;

/*!
 *  @method     data:seekToFileOffset:offsetType:
 *  @abstract   Changes the read/write position according to <i>fileOffset</i> 
 *              and <i>offsetType</i>.
 *  @discussion Returns the new absolute position. Optional method.
 *  @param      data Caller
 *  @param      fileOffset Offset to jump to
 *  @param      offsetType Offset type
 *  @exception  <code>@link //macgpg/c/data/GPGException GPGException@/link</code>
 *              (<code>@link //macgpg/c/econst/GPGError_E* GPGError_E*@/link</code>)
 *              exception in case of error.
 */
- (long long) data:(GPGData *)data seekToFileOffset:(long long)fileOffset offsetType:(GPGDataOffsetType)offsetType;

/*!
 *  @method     dataRelease:
 *  @abstract   Releases internal resources owned by the data source.
 *  @discussion Optional method.
 *  @param      data Caller
 */
- (void) dataRelease:(GPGData *)data;
@end

#ifdef __cplusplus
}
#endif
#endif /* GPGDATA_H */
