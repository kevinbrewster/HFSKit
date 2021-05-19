//
//  BootBlock.swift
//  HFSKit
//
//  Created by Kevin Brewster on 4/13/21.
//

import Foundation


struct BootBlock {
    let signature: UInt16
    let bootCodeEntryPoint: UInt32 // machine code for `BRA.S *+ 0x90`
    let version: UInt16 // flag byte (high order) and a version byte (low order)
    let parseFlags: UInt16 // (used internally)
    let systemFilename: String
    let finderFilename: String // typically "Finder"
    let debugger1Filename: String // typically "Macsbug"
    let debugger2Filename: String // typically "Disassembler"
    let startupScreenName: String //  typically "StartUpScreen"
    let startupProgramName: String // typically "Finder"
    let scrapFilename: String // typically "Clipboard"
    let totalAllocatedFileControlBlocks: UInt16
    let maxEventQueueElements: UInt16 // This number determines the maximum number of events that the Event Manager can store at any one time. Usually this field contains the value 20.
    let heapSizeOn128kMac: UInt32
    let heapSizeOn256kMac: UInt32
    let heapSize: UInt32 // The size of the System heap on a Macintosh computer having 512 KiB or more of RAM.
    let additionalHeapSize: UInt32
    let fractionOfAvailableRamForHeap: UInt32
}
extension BootBlock {
    init?(_ data: Data) {
        signature = data.load(from: 0)
        guard signature == 0x4C4B else {
            return nil
        }
        bootCodeEntryPoint = data.load(from: 2)
        version = data.load(from: 6)
        parseFlags = data.load(from: 8)
        systemFilename = String(data: data[10..<25], encoding: .macOSRoman) ?? ""
        finderFilename = String(data: data[25..<40], encoding: .macOSRoman) ?? ""
        debugger1Filename = String(data: data[40..<55], encoding: .macOSRoman) ?? ""
        debugger2Filename = String(data: data[55..<70], encoding: .macOSRoman) ?? ""
        startupScreenName = String(data: data[70..<85], encoding: .macOSRoman) ?? ""
        startupProgramName = String(data: data[85..<100], encoding: .macOSRoman) ?? ""
        scrapFilename = String(data: data[100..<115], encoding: .macOSRoman) ?? ""
        totalAllocatedFileControlBlocks = data.load(from: 115)
        maxEventQueueElements = data.load(from: 117)
        heapSizeOn128kMac = data.load(from: 119)
        heapSizeOn256kMac = data.load(from: 123)
        heapSize = data.load(from: 127)
        additionalHeapSize = data.load(from: 133)
        fractionOfAvailableRamForHeap = data.load(from: 137)
    }
}
