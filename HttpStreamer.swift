//
//  HttpStreamer.swift
//  TarStream
//
//  Created by Teo Sartori on 29/09/2016.
//  Copyright © 2016 Matteo Sartori. All rights reserved.
//

import Foundation
//: Exploration of streaming from an http request (using a local IPFS node)

/** For a simpler solution see my StreamHttpIo playground at
 https://github.com/NeoTeo/StreamHttpIo or QmUkcBW76gzr1zWwXrNKkCqRFF7yL5KKXNTtegoVAH8d44
 
 This version parses the html response header and the chunking thus
 providing a stream of the data (in this case a tar stream from IPFS).
 **/

class HttpStreamer : NSObject, URLSessionDataDelegate {
    
    var inputStream: InputStream?
    internal var outputStream: OutputStream?
    
    var session: URLSession!
    
    var serialDataCacheQ = DispatchQueue(label: "serialDataCacheQ")
    var dataCache: Data?
    /*{
     get {
     var d: Data? = nil
     serialDataCacheQ.sync {
     d = _dataCache
     }
     return d
     }
     set {
     serialDataCacheQ.sync {
     _dataCache = newValue
     }
     }
     }
     var _dataCache: Data?
     */
    var currentBufferSize = 256//5120
    
    //    var readHandler: ((InputStream) -> Void)? = nil
    //    var endHandler: (() -> Void)?
    
    /// debug vars - remove
    var bytesWrittenToOutputStream = 0
    var totalSessionByteCount: Int?
    var sessionByteCount: Int = 0
    
    init(url: URL) {
        
        super.init()
        
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: url)
        
        
        
        dataCache = Data()
        
        task.resume()
        
        /// Connect the output stream to the input stream using a given buffer size.
        Stream.getBoundStreams(withBufferSize: currentBufferSize, inputStream: &inputStream, outputStream: &outputStream)
        
        inputStream?.delegate = self
        outputStream?.delegate = self
        
        inputStream?.schedule(in: .main, forMode: .defaultRunLoopMode)
        outputStream?.schedule(in: .main, forMode: .defaultRunLoopMode)
        
        inputStream?.open()
        outputStream?.open()
        
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("urlSession completed")
        totalSessionByteCount = sessionByteCount
        checkForEnd()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print("urlSession received : \(data.count) bytes")
        sessionByteCount += data.count
        /** We have to access the dataCache through a queue to allow concurrent write access by both
         this method, when it needs to add to the end of the cache, and the stream event handler, when it
         needs to remove data from the front of the cache.
         **/
        serialDataCacheQ.sync {
            dataCache?.append(data)
        }
        
        if outputStream?.hasSpaceAvailable == true {
            //            fillStream(data: &dataCache!)
            serialDataCacheQ.sync {
                dataCache = fillStream(data: dataCache!)
            }
        }
    }
}

extension HttpStreamer : StreamDelegate {
    
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        
        let isInputStream = aStream.isEqual(inputStream)
        //let streamTypeDescription = isInputStream ? "ReadStream" : "WriteStream"
        
        switch eventCode {
        case Stream.Event.openCompleted:
            break
            
            //        case Stream.Event.hasBytesAvailable:
            //            guard isInputStream == true else { break }
            //            readHandler?(inputStream!)
            
        case Stream.Event.hasSpaceAvailable:
            guard isInputStream == false else { break }
            //            fillStream(data: &dataCache!)
            serialDataCacheQ.sync {
                dataCache = fillStream(data: dataCache!)
            }
            //        case Stream.Event.endEncountered:
            //            guard isInputStream == true else { break }
            //            endHandler?()
            //            inputStream?.close()
            
        case Stream.Event.errorOccurred:
            print("Error! \(aStream.streamError?.localizedDescription)")
            
        default:
            print("We got nuffink.\(eventCode.rawValue)")
        }
    }
    
    func checkForEnd() {
        //		print("total is \(totalSessionByteCount)")
        //		print("bytes written to output stream \(bytesWrittenToOutputStream)")
        if let total = totalSessionByteCount, total == bytesWrittenToOutputStream {
            outputStream?.close()
        }
    }
    
    func fillStream(data: Data) -> Data {
        
        /// Sanity checks
        guard let out = outputStream, out.hasSpaceAvailable == true else { return data } /// change this to a throw
        
        var bytesWritten = data.count
        
        if data.count > 0 {
            /// The number of bytes we would like to write to the stream.
            let writeByteCount = min(currentBufferSize, data.count)
            
            /// Turn the data into a byte array
            let bytes = data.withUnsafeBytes { [UInt8](UnsafeBufferPointer(start: $0, count: writeByteCount)) }
            
            /// Attempt to write the bytes to the stream and register how many actually got through.
            bytesWritten = out.write(bytes, maxLength: writeByteCount)
            
            guard bytesWritten != -1 else {
                print("Error writing: \(out.streamError)")
                return data
            }
            /// Debug: Track total bytes written out.
            bytesWrittenToOutputStream += bytesWritten
        }
        checkForEnd()
        return data.subdata(in: bytesWritten ..< data.count)
        //		return data.subdata(in: 0 ..< bytesWritten)
    }
}
