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
    
    //testUntarFile()

//	tarStreamReader(host: host, port: port, query: query)

//    addAndRemoveHandlers()
	
//    tarStreamWriter()
    tarStreamWriter2()
	
    //	simplePipe()
    
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
    ppipe(stream: teoStream)
    
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

/** Create tar entries from file stream and from direct entry.**/
func tarStreamWriter2() {
	
    let group = DispatchGroup.init()

    group.enter()

	/// Path to some local file we want to read from.
    let path = "/Users/teo/tmp/hej.txt"
	
    let url = URL(fileURLWithPath: path)
    
	/// Make a read stream from the url.
    guard let readStream = InputStream(url: url) else { fatalError("Error: Invalid url!") }
    
    let tar = TarStream()
    let archive = tar.archive()
    
    // Add an entry to the archive and stream the content of the readStream into it.
    //archive.addEntry(header: [TarHeader.Field.fileName : "ollah.txt"], dataStream: readStream)
    //archive.closeArchive()
    
    /// Add entry to archive and provide a block that is called when the entry is finalized with entry.end()
    /// Problematic that we need to provide the file size up front?
    var entry: TarEntry = archive.addEntry(header: [.fileName : "my-testes.txt", .fileByteSize : "11"]) {

        print("TSE: Closing archive.")
        archive.closeArchive()

        group.leave()
    }
    
    entry.write(data: "Hello")
    entry.write(data: " ")
    entry.write(data: "World")
    print("TSE: so far...")
    entry.end()

    group.wait()

    /// Now try to read from the archive.
    guard let tarStr = archive.tarReadStream else { 
        fatalError("Error: not able to get a tar read stream from archive.")
    }
    print("TSE: tar stream has bytes available \(tarStr.hasBytesAvailable)")
    //	ppipe(stream: tarStr)
    
    guard let writeStream = OutputStream(toFileAtPath: "/Users/teo/tmp/archive.tar", append: false) else {
        fatalError("Error: failed to make output stream")
    }
    print("TSE: About to pipe tarStr into writeStream.")
    tarStr.pipe(into: writeStream) { exit(EXIT_SUCCESS) }
    /// Check the archive.tar file with an external tar utility for confirmation.
}

/**
	This function demonstrates piping a string from a read stream into a write stream configured to output to a file.
**/
func simplePipe() {
    guard let dat = "Ooh yeah, this seems to work still!".data(using: .ascii) else { return }
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
		
        print("setEntryHandler: The header is \(header)")
        
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
    
    /// 3) Connect the read stream with the configured tar stream parser.
    tarParser.setInputStream(tarStream: readStream)
}

// MARK: Helper functions

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
	
	stream.on(event: .hasBytesAvailable) {
		
		let streamBuf: [UInt8] = Array(repeating: 0, count: 512)
		let buf = UnsafeMutablePointer<UInt8>(mutating: streamBuf)
		
		let bytesRead = stream.read(buf, maxLength: 512)
		data += streamBuf[0 ..< bytesRead]
		print("stream reader read \(bytesRead) bytes")
	}
}

main()

