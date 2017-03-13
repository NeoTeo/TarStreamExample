//
//  main.swift
//  TarStreamTmp
//
//  Created by Teo Sartori on 13/12/2016.
//  Copyright © 2016 Matteo Sartori. All rights reserved.
//

import Foundation
import CallbackStreams
import TarStream
import HttpStream


let host = "127.0.0.1"
let port = 5001
//let hash = "QmYtvgR9Ckk8k26JPv5fT73tSxdSi4nh4Qd5XNLNmZ8B8L" /// Big mp4 file
//let hash = "QmT78zSuBmuS4z925WZfrqQ1qHaJ56DQaTfyMUF7F8ff5o"	/// hello world
//let hash = "QmSaxNHpo1t843tV6we4rZy527vzqZvrLCk5iUwjnj2pm6"		/// Sherlock Holmes txt
let hash = "QmdScyjK1F8fuoLyW8wyV4rD64dLduUXb2sbRudxWf9Kwj"	/// B Russell txt
//let hash = "QmW5HrjrmU9R2twGiq9praCtGJTLou323ufPJpUogu5kuM" /// directory with two text files
//let hash = "QmbTUKre4rFZUCvksbhAKbbMfzGKyb6Kxb9hT342Q9sTBo" /// dir containing dir

let query = "/api/v0/get?arg=\(hash)"
var myStreamer: HttpStream!
var teoStream: InputStream!

func main() {
    
//    tarStreamReader()
//    teotest()
//    tarStreamWriter()
//    testy()
    testUntarFile()
    CFRunLoopRun()
}

func testUntarFile() {
 
    let path = "/users/teo/source/apple/osx/tarstreamexample/arch.tar"
    guard FileManager.default.fileExists(atPath: path) == true else {
        fatalError("file does not exist!")
    }
    let url = URL(fileURLWithPath: path)
    guard let readStream = InputStream(url: url) else {
        return
    }
    
    let tarParser = TarStream()
    
    /// The entry handler is called with the found header and a stream containing the
    /// data the header refers to. The nextEntry callback is called when the entry handler
    /// is done and wants to initiate the reading of any next entries.
    tarParser.setEntryHandler { (header: TarHeader, stream: InputStream, nextEntry: @escaping () -> Void) in
        print("Hello! The header is \(header)")
        
        /// Check if we're dealing with a file or a directory
        switch header.fileType {
        case String(TarHeader.FileTypes.directory.rawValue):
            print("This is a directory named \(header.fileName)")
            break
        default:
            print("This is not a directory")
        }
        
        /// set handler to be called on end of stream.
        stream.on(event: .endOfStream) {
            stream.close()
            stream.remove(from: .main, forMode: .defaultRunLoopMode)
            nextEntry()
        }
        
        stream.schedule(in: .main, forMode: .defaultRunLoopMode)
        stream.open()
        
        /// Here we can read the data from the passed in stream.
        if stream.hasBytesAvailable {
            let maxLen = Int(header.fileByteSize, radix: 8)!
            let streamBuf: [UInt8] = Array(repeating: 0, count: maxLen)
            let buf = UnsafeMutablePointer<UInt8>(mutating: streamBuf)
            
            let bytesRead = stream.read(buf, maxLength: maxLen)
            
            print("Hello!! The data (\(bytesRead)) is: \(String(bytes: streamBuf, encoding: String.Encoding.utf8))")
        }
    }
    
    tarParser.endHandler = {
        exit(EXIT_SUCCESS)
    }
    
    /// Hook up the streams.
    tarParser.setInputStream(tarStream: readStream)
    
    readStream.schedule(in: .main, forMode: .defaultRunLoopMode)
    readStream.open()
}

func teotest() {
    guard let dat = "teotest".data(using: .ascii) else { return }
    teoStream = InputStream(data: dat)
    teoStream.on(event: .openCompleted) {
        print("opan")
    }
    
    teoStream.on(event: .hasBytesAvailable) {
        print("haz")
    }
    
    let oc = teoStream.on(event: .errorOccurred) {
        print("baz")
    }
    
    teoStream.on(event: .endOfStream) {
        print("bar")
    }
    
    teoStream.schedule(in: .main, forMode: .defaultRunLoopMode)
    teoStream.open()
    ppipe(stream: teoStream)
    
    teoStream.on(event: .endOfStream, handlerUuid: oc, handler: nil)
    //    wtfStream.on(event: .openCompleted, handler: nil)
    
}

func tarStreamWriter() {
    let path = "/Users/teo/tmp/hej.txt"
    //	let path = "/Users/teo/tmp/russell.txt"
    let url = URL(fileURLWithPath: path)
    print("streamwrite got url \(url)")
    
    guard let dat = "WTHFook".data(using: .ascii) else { return }
    let wtfStream = InputStream(data: dat)
    guard let readStream = InputStream(url: url) else { return }
    
    let tar = TarStream()
    let archive = tar.archive()
    
    // This will add an entry to the archive but won't finalize it.
    //	archive.addEntry(header: [TarHeader.Field.fileName : "ollah.txt"], dataStream: readStream)
    archive.addEntry(header: [TarHeader.Field.fileName : "wtf.txt"], dataStream: wtfStream)
    archive.closeArchive()
    /*
     var entry = archive.addEntry(header: [.fileName : "my-testes.txt", .fileByteSize : "11"]) {
     print("Well blimey")
     
     archive.closeArchive()
     }
     
     entry.write(data: "Hello")
     entry.write(data: " ")
     entry.write(data: "World")
     entry.end()
     */
    
    /// Now try to read from the archive.
    guard let tarStr = archive.tarReadStream else { return }
    print("tar stream has bytes available \(tarStr.hasBytesAvailable)")
    //	ppipe(stream: tarStr)
    
    if let writeStream = OutputStream(toFileAtPath: "/Users/teo/tmp/archive.tar", append: false) {
        tarStr.pipe(into: writeStream) { exit(EXIT_SUCCESS) }
    }
    
}

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx, ", $0) }.joined()
    }
}

func ppipe(stream: InputStream) {
    var data = [UInt8]()
    
    stream.on(event: .endOfStream) {
        print("Done with the stream")
        let hexdat = Data(data)
        print("The data (\(data.count)) is: \(hexdat.hexEncodedString())")
        exit(EXIT_SUCCESS)
    }
    
    stream.on(event: .hasBytesAvailable){
        
        let streamBuf: [UInt8] = Array(repeating: 0, count: 512)
        let buf = UnsafeMutablePointer<UInt8>(mutating: streamBuf)
        
        let bytesRead = stream.read(buf, maxLength: 512)
        data += streamBuf[0 ..< bytesRead]
        print("stream reader read \(bytesRead) bytes")
    }
}

func testy() {
    guard let dat = "Ooh yeah, this seems to work still!".data(using: .ascii) else { return }
    let readStream = InputStream(data: dat)
    
    if let writeStream = OutputStream(toFileAtPath: "/Users/teo/tmp/outstream.txt", append: true) {
        readStream.pipe(into: writeStream) { exit(EXIT_SUCCESS) }
    }
}

func tarStreamReader() {
    let source = "http://" + host + ":" + String(port) + query
    guard let url = URL(string: source) else {
        print("Invalid URL")
        return
    }
    let httpStreamer = HttpStream()
	guard let readStream = httpStreamer.getReadStream(for: url) else { fatalError("Could not get read stream.") }
    let tarParser = TarStream()
    
    /// The entry handler is called with the found header and a stream containing the
    /// data the header refers to. The nextEntry callback is called when the entry handler
    /// is done and wants to initiate the reading of any next entries.
    tarParser.setEntryHandler { (header: TarHeader, stream: InputStream, nextEntry: @escaping () -> Void) in
        print("Hello! The header is \(header)")
        
        /// Check if we're dealing with a file or a directory
        switch header.fileType {
        case String(TarHeader.FileTypes.directory.rawValue):
            print("This is a directory named \(header.fileName)")
            break
        default:
            print("This is not a directory")
        }
        
        /// set handler to be called on end of stream.
        stream.on(event: .endOfStream) {
            stream.close()
            stream.remove(from: .main, forMode: .defaultRunLoopMode)
            nextEntry()
        }
        
        stream.schedule(in: .main, forMode: .defaultRunLoopMode)
        stream.open()
        
        /// Here we can read the data from the passed in stream.
        if stream.hasBytesAvailable {
            let maxLen = Int(header.fileByteSize, radix: 8)! // crash for now ?? 0
            let streamBuf: [UInt8] = Array(repeating: 0, count: maxLen)
            let buf = UnsafeMutablePointer<UInt8>(mutating: streamBuf)
            
            let bytesRead = stream.read(buf, maxLength: maxLen)
            
            print("Hello!! The data (\(bytesRead)) is: \(String(bytes: streamBuf, encoding: String.Encoding.utf8))")
        }
    }
    
    tarParser.endHandler = {
        httpStreamer.finish()
        
        exit(EXIT_SUCCESS)
    }
    
    /// Hook up the streams.
    tarParser.setInputStream(tarStream: readStream)
}


main()

