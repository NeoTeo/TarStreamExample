//
//  main.swift
//  TarStreamTmp
//
//  Created by Teo Sartori on 13/12/2016.
//  Copyright © 2016 Matteo Sartori. All rights reserved.
//

import Foundation
import TarStream
import HttpStream


let host = "127.0.0.1"
let port = 5001

let hash = "QmdScyjK1F8fuoLyW8wyV4rD64dLduUXb2sbRudxWf9Kwj" /// B Russell txt

let query = "/api/v0/get?arg=\(hash)"
var myStreamer: HttpStream!
var teoStream: InputStream!

func main() {
    
//    testUntarFile()

//  tarStreamReader(host: host, port: port, query: query)

//    addAndRemoveHandlers()
    
//    tarStreamWriter()
//    tarStreamWriter2()
//    tarStreamWriter3()
  tarStreamWriter4()
//      simplePipe()
    
    CFRunLoopRun()
}

/** This function shows how to load an existing tar archive from disk and how to deal with the contents.
    In this example it simply prints the data to stdout. **/
func testUntarFile() {
 
    let path = "/users/teo/tmp/archive2.tar"
    guard FileManager.default.fileExists(atPath: path) == true else {
        fatalError("file does not exist!")
    }
    let url = URL(fileURLWithPath: path)
    guard let readStream = InputStream(url: url) else {
        return
    }
    
    let tarParser = TarStream()
    
    /// Set up the TarStream's entry and end handlers:
    
    /** The entry handler is called with the found header and a stream containing the
        data the header refers to. We read from the given stream just as we would any stream.
     
        The nextEntry block is called when the entry handler is done and wants to
        initiate the reading of any next entries, which will call setEntryHandler with a new
        header and stream.
    **/
    tarParser.setEntryHandler { (header: TarHeader, stream: InputStream, nextEntry: @escaping () -> Void) in
        
        print("The header is \(header)")
        
        /// In here we can do specific stuff based on header info,
        /// eg. check if we're dealing with a file or a directory
        switch header.fileType {
        case String(TarHeader.FileTypes.directory.rawValue):
            print("This is a directory named \(header.fileName)")
            break
        default:
            print("This is not a directory")
        }
        
        /// set handler to be called on end of stream.
        stream.on(event: .endOfStream) {
            
            /// As with regular streams we need to close and remove them from the run loop.
            stream.close()
            stream.remove(from: .main, forMode: .defaultRunLoopMode)
            
            /// Signal we're ready to move on to the next entry.
            nextEntry()
        }

        stream.on(event: .hasBytesAvailable) {
            let maxLen = Int(header.fileByteSize, radix: 8)!
            let streamBuf: [UInt8] = Array(repeating: 0, count: maxLen)
            let buf = UnsafeMutablePointer<UInt8>(mutating: streamBuf)
            
            let bytesRead = stream.read(buf, maxLength: maxLen)
            
            print("The data (\(bytesRead) bytes) is: \(String(bytes: streamBuf, encoding: String.Encoding.utf8))")
            print("-----------------------------------------------")
        }
        
        stream.schedule(in: .main, forMode: .defaultRunLoopMode)
        stream.open()
    }
    
    tarParser.endHandler = {
        exit(EXIT_SUCCESS)
    }
    
    /// Pass the tar stream parser the input stream and...
    tarParser.setInputStream(tarStream: readStream)
    
    /// ...schedule & open the input stream.
    readStream.schedule(in: .main, forMode: .defaultRunLoopMode)
    readStream.open()
}

/**
    This function shows how multiple handlers can be associated with a given event.
    It also shows how a handler can be removed from a stream by setting its associated handler to nil.

    Note that ppipe exits as soon as it receives its endOfStream event. If it is the first to receive it
    it will be the only endOfStream event to be called despite multiple callbacks being registered.
**/
func addAndRemoveHandlers() {
    
    guard let dat = "teotest".data(using: .ascii) else { return }
    teoStream = InputStream(data: dat)
    teoStream.on(event: .openCompleted) {
        print("opan")
    }
    
    teoStream.on(event: .hasBytesAvailable) {
        print("haz")
    }
    
    teoStream.on(event: .errorOccurred) {
        print("baz")
    }
    
    /// Associate a callback with the endOfStream event on teoStream and store its uuid.
    let boo = teoStream.on(event: .endOfStream) {
        print("boo")
    }

    teoStream.on(event: .endOfStream) {
        print("bar")
    }
    
    /// remove boo handler again by setting its associated (via the uuid) handler to nil.
    teoStream.on(event: .endOfStream, handlerUuid: boo, handler: nil)
    
    teoStream.schedule(in: .main, forMode: .defaultRunLoopMode)
    teoStream.open()
    
    /// The ppipe function will add its own event handlers to teoStream without overriding
    /// the ones we've already added.
    //ppipe(stream: teoStream)
    printPipe(stream: teoStream) {
        exit(EXIT_SUCCESS)
    }
}

/**
    Create a tar archive from a stream containing a string. 
**/
func tarStreamWriter() {
    
    /// Set up a read stream and feed it a string as input.
    guard let dat = "Some string to stream.".data(using: .ascii) else { fatalError("Error: Invalid string!") }
    let readStream = InputStream(data: dat)
    
    /// Create a tar stream instance and get a new archive from it.
    let tar = TarStream()
    let archive = tar.archive()
    
    // Add an entry to the archive and finalize it.
    archive.addEntry(header: [TarHeader.Field.fileName : "file.txt"], dataStream: readStream)
    archive.closeArchive()
    
    
    /// Now try to read from the archive.
    guard let tarStr = archive.tarReadStream else { 
        fatalError("Error: cannot read archive.") 
    }

    print("tar stream has bytes available \(tarStr.hasBytesAvailable)")
    
    /// Create write stream to a file and pipe the archive to it.
    guard let writeStream = OutputStream(toFileAtPath: "/Users/teo/tmp/archive.tar", append: false) else { 
        fatalError("Error: cannot create output file") 
    }

    tarStr.pipe(into: writeStream) { exit(EXIT_SUCCESS) }
    
    /// Check the archive.tar file with an external tar utility for confirmation.
}


/** 
    Create a tar archive with multiple entries; from file stream and from direct entry.
**/
func tarStreamWriter2() {
    
    /// Path to some local file we want to read from.
    let path = "/Users/teo/tmp/hej.txt"
    
    let url = URL(fileURLWithPath: path)
    
    /// Make a read stream from the url.
    guard let readStream = InputStream(url: url) else { fatalError("Error: Invalid url!") }
    
    
    let tar = TarStream()
    let archive = tar.archive()
    
    // Add an entry to the archive and stream the content of the readStream into it.
    archive.addEntry(header: [.fileName : "ollah.txt"], dataStream: readStream)
    //archive.closeArchive()

    /// Add entry to archive and provide a block that is called when the entry is finalized with entry.end()
    /// Problematic that we need to provide the file size up front?
    /// Remember that the fileByteSize must be in octal, so ex. 11 bytes is 13
    var entry: TarEntry = archive.addEntry(header: [.fileName : "my-testes.txt", .fileByteSize : "13"]) {

        /// This is the entry end handler. 
        /// In this case we use it to close the archive completely.
        print("TSE: Closing archive.")
        archive.closeArchive()
    }
    
    entry.write(data: "Hello")
    entry.write(data: " ")
    entry.write(data: "World")
    entry.end()
  
    /// Now try to read from the archive.
    guard let tarStr = archive.tarReadStream else { 
        fatalError("Error: not able to get a tar read stream from archive.")
    }
    print("TSE: tar stream has bytes available \(tarStr.hasBytesAvailable)")
    //ppipe(stream: tarStr)

    guard let writeStream = OutputStream(toFileAtPath: "/Users/teo/tmp/archive2.tar", append: false) else {
        fatalError("Error: failed to make output stream")
    }
    print("TSE: About to pipe tarStr into writeStream.")
    tarStr.pipe(into: writeStream) { exit(EXIT_SUCCESS) }
    
    /// Check the archive.tar file with an external tar utility for confirmation.
}


func tarStreamWriter3() {

    /// Set up a read stream and feed it a string as input.
    guard let dat = "A simple stream of characters.".data(using: .ascii) else { fatalError("Error: Invalid string!") }
    let readStream = InputStream(data: dat)
    
    /// Create a tar stream instance and get a new archive from it.
    let tar = TarStream()
    let archive = tar.archive()
    
    // Add an entry to the archive and finalize it.
    archive.addEntry(header: [TarHeader.Field.fileName : "file.txt"], dataStream: readStream)
    archive.closeArchive()
    
    /// Now try to read from the archive.
    guard let tarStr = archive.tarReadStream else { fatalError("Error: cannot read archive.") }
    
    /// Create write stream to stdout and pipe the archive to it.
    guard let writeStream = OutputStream(toFileAtPath: "/dev/stdout", append: false) else {
        fatalError("Error: cannot create output file")
    }
    
    tarStr.pipe(into: writeStream) { exit(EXIT_SUCCESS) }
}


func tarStreamWriter4() {

    /// Set up a read stream and feed it a string as input.
    guard let d = "A simple stream of characters.".data(using: .utf8) else { fatalError("Invalid string!") }
    let readStream = InputStream(data: d)

    /// Create a tar stream instance and get a new archive from it.
    let tar = TarStream()
    let archive = tar.archive()

    // Add an entry to the archive and finalize it.
    archive.addEntry(header: [TarHeader.Field.fileName : "file.txt"], dataStream: readStream)

    /// File byte sizes in octal.
    var entry: TarEntry = archive.addEntry(header: [.fileName : "greeting.txt", .fileByteSize : "12"]) {
        /// This is the entry end handler. 
        archive.closeArchive()
    }
    
    entry.write(data: "Hej")
    entry.write(data: " ")
    entry.write(data: "Verden")
    entry.end()

    /// Output content of archive to stdout:

    /// Get the read stream from the archive. 
    guard let tarStr = archive.tarReadStream else { fatalError("Cannot read archive!") }

    /// Create write stream to stdout and pipe the archive to it.
    guard let writeStream = OutputStream(toFileAtPath: "/dev/stdout", append: false) else {
    fatalError("Cannot create output stream!")
}

tarStr.pipe(into: writeStream) { exit(EXIT_SUCCESS) }
}


/**
    This function demonstrates piping a string from a read stream into a write stream configured to output to a file.
**/
func simplePipe() {
    guard let dat = "This text is appended too.".data(using: .ascii) else { return }
    let readStream = InputStream(data: dat)
    
    if let writeStream = OutputStream(toFileAtPath: "/Users/teo/tmp/outstream.txt", append: true) {
        readStream.pipe(into: writeStream) { exit(EXIT_SUCCESS) }
    }
}

/**
    This function reads a tar stream from a chunked http stream (in this case a local IPFS node)
    and prints the result to stdout.
**/
func tarStreamReader(host: String, port: Int, query: String) {
    
    /// The url for a query to an IPFS server that returns the data as a tar stream.
    let source = "http://" + host + ":" + String(port) + query

    guard let url = URL(string: source) else { fatalError("Invalid URL") }
    
    /// 1) Make an httpStreamer and pass it the url from which to read from.
    let httpStreamer = HttpStream()
    
    guard let readStream = httpStreamer.getReadStream(for: url) else { fatalError("Could not get read stream.") }
    
    /// 2) Make a tar stream parser and configure its entry handler and end handler.
    let tarParser = TarStream()
    
    /// The entry handler is called with the found header and a stream containing the
    /// data the header refers to. The nextEntry callback must be called when the entry handler
    /// is done and wants to initiate the reading of any next entries.
    tarParser.setEntryHandler { (header: TarHeader, stream: InputStream, nextEntry: @escaping () -> Void) in
        
        print("The header is \(header)")
        
        /// set handler to be called on end of stream.
        stream.on(event: .endOfStream) {
            stream.close()
            stream.remove(from: .main, forMode: .defaultRunLoopMode)
            nextEntry()
        }
        
        stream.schedule(in: .main, forMode: .defaultRunLoopMode)
        stream.open()
 
        printPipe(stream: stream) {
            print("All done!")
        }
    }
    
    tarParser.endHandler = {
        
        httpStreamer.finish()
        exit(EXIT_SUCCESS)
    }
    
    /// 3) Connect the read stream with the configured tar stream parser.
    tarParser.setInputStream(tarStream: readStream)
}

// MARK: Helper functions

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx, ", $0) }.joined()
    }
}

func printPipe(stream: InputStream, completion: VoidFunc? = nil) {
    var data = [UInt8]()
    
    func append(from stream: InputStream, onto olddata: [UInt8]) -> [UInt8] {
        let streamBuf: [UInt8] = Array(repeating: 0, count: 512)
        let buf = UnsafeMutablePointer<UInt8>(mutating: streamBuf)
        
        let bytesRead = stream.read(buf, maxLength: 512)
        let data = olddata + streamBuf[0 ..< bytesRead]
        
        return data
    }
    
    stream.on(event: .openCompleted) {
        print("ppipe open")
    }
    
    stream.on(event: .endOfStream) {
        
        print("End of stream.")
        let datacount = data.count
        if let stringdat = String(bytes: data, encoding: String.Encoding.utf8) {
            
            print("The data (\(datacount) bytes) is:")
            print(stringdat)
        } else {
            
            let hexdat = Data(data)
            print("The data (\(datacount)) is:")
            print(hexdat.hexEncodedString())
        }
        
        completion?()
    }
    
    stream.on(event: .hasBytesAvailable) {
        data = append(from: stream, onto: data)
    }
    
    if stream.hasBytesAvailable {
        data = append(from: stream, onto: data)
    }
}

main()

