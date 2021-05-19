//
//  Resource.swift
//  HFSKit
//
//  Created by Kevin Brewster on 4/16/21.
//

import Foundation
import CoreGraphics
import AppKit


public struct ResourceFork {
    struct Resource {
        struct Attributes: OptionSet {
            let rawValue: UInt8
            static let needsWrite           = Attributes(rawValue: 1 << 1)
            static let preload              = Attributes(rawValue: 1 << 2)
            static let isProtected          = Attributes(rawValue: 1 << 3)
            static let isLocked             = Attributes(rawValue: 1 << 4)
            static let isPurgeable          = Attributes(rawValue: 1 << 5)
            static let loadIntoSystemHeap   = Attributes(rawValue: 1 << 6)
        }
        
        let id: UInt16
        let attributes: Attributes
        let name: String
        let data: Data
    }
    
    //let resources: [UInt32: [Resource]]
    let resources: [String: [Resource]]
    
    init?(_ data: Data) {
        guard data.count > 32 else {
            print("not enough data for resource fork: \(data.count)")
            return nil
        }
        //print("ResourceFork init. data.count = \(data.count)")
        //let data = (data[data.startIndex..<data.startIndex+4] == Data([0,0,0,0])) ? data[data.startIndex+1..<data.endIndex] : data
        // Header
        let offsetToData: UInt32 = data.load(from: 0)
        let offsetToMap: UInt32 = data.load(from: 4)
        //let resourceDataSize: UInt32 = data.load(from: 8)
        //let resourceMapSize: UInt32 = data.load(from: 12)
        
        guard offsetToData < data.count, offsetToMap + 30 <= data.count else {
            return nil
        }
        
        // Map
        //let forkAttributes: UInt16 = data.load(from: Int(offsetToMap) + 22)
        let offsetFromMapToTypeList: UInt16 = data.load(from: Int(offsetToMap) + 24)
        let offsetFromMapToNameList: UInt16 = data.load(from: Int(offsetToMap) + 26)
        let totalTypesMinus1: UInt16 = data.load(from: Int(offsetToMap) + 28)
        
        var resources = [String: [Resource]]()
                
        // Type List
        var typeListOffset = Int(offsetToMap) + Int(offsetFromMapToTypeList) + 2 // the extra 2 seems undocumented..
        for _ in 0..<(totalTypesMinus1 &+ 1) {
            guard typeListOffset + 8 < data.endIndex else {
                return nil
            }
                    
            //let type: UInt32 = data.load(from: typeListOffset)
            let type = String(data: data[data.startIndex+typeListOffset..<data.startIndex+typeListOffset+4], encoding: .macOSRoman) ?? ""
            let totalResourcesOfTypeMinus1: UInt16 = data.load(from: typeListOffset + 4)
            let offsetFromTypeList: UInt16 = data.load(from: typeListOffset + 6)
            
            //print("RESOURCE TYPE: \(type) has \(totalResourcesOfTypeMinus1 + 1) resources")
            // Reference list entry
            var referenceListOffset = Int(offsetToMap) + Int(offsetFromMapToTypeList) + Int(offsetFromTypeList)
            
            //print("referenceListOffset = \(referenceListOffset)")
            
            
            for _ in 0..<(totalResourcesOfTypeMinus1 &+ 1) {
                guard data.startIndex + referenceListOffset + 12 <= data.endIndex else {
                    return nil
                }
                let resourceId: UInt16 = data.load(from: referenceListOffset)
                let offsetFromNameList: UInt16 = data.load(from: referenceListOffset + 2)
                let attributesAndOffset: UInt32 = data.load(from: referenceListOffset + 4)
                let entryAttributes = UInt8(attributesAndOffset >> 24) // 1 byte
                let offsetFromData = attributesAndOffset & 0x00FFFFFF // 3 bytes
                
                // name
                let resourceName: String
                if offsetFromNameList == UInt16.max {
                    resourceName = ""
                } else {
                    let offsetToEntryName = Int(offsetToMap) + Int(offsetFromMapToNameList) + Int(offsetFromNameList)
                    let nameLength: UInt8 = data.load(from: offsetToEntryName)
                    guard data.startIndex + offsetToEntryName + 1 + Int(nameLength) < data.endIndex else {
                        return nil
                    }
                    resourceName = String(data: data[data.startIndex+offsetToEntryName+1..<data.startIndex+offsetToEntryName+1+Int(nameLength)], encoding: .macOSRoman) ?? ""
                }
                
                // data
                let offsetToEntryData = Int(offsetToData) + Int(offsetFromData)
                let entryDataSize: UInt32 = data.load(from: offsetToEntryData)
                guard data.startIndex + offsetToEntryData + Int(entryDataSize) + 4 < data.endIndex else {
                    continue
                }
                let resourceData = data[data.startIndex+offsetToEntryData+4..<data.startIndex+offsetToEntryData+4+Int(entryDataSize)]
                let resource = Resource(
                    id: resourceId,
                    attributes: Resource.Attributes(rawValue: entryAttributes),
                    name: resourceName,
                    data: resourceData
                )
                resources[type, default: []].append(resource)
                
                referenceListOffset += 12
            }
            typeListOffset += 8
        }
        
        self.resources = resources
    }
}


struct AliasResource {
    enum VolumeType : UInt16 {
        case fixedHardDrive = 0
        case networkDisk = 1
        case floppyDisk400kb = 2
        case floppyDisk800kb = 3
        case floppyDisk1_4mb = 4
        case otherEjectableMedia = 5
        case unknown = 99
    }
        
    let userType: UInt32
    let size: UInt16
    let version: UInt16 // (current version = 2)
    let kind: UInt16 // (file = 0; directory = 1)
    let volumeName: String
    let volumeCreationTimestamp: UInt32 // long unsigned value in seconds since beginning 1904 to 2040
    let volumeSignature: UInt16 // short unsigned HFS value
    let volumeType: VolumeType    
    let directoryId: UInt32 // is this UInt16 or UInt32??
    let fileName: String
    let fileId: UInt32
    let fileCreatedTimestamp: UInt32 // value in seconds since beginning 1904 to 2040
    let fileType: UInt32
    let fileCreatorName: UInt32
    let nlvlFrom: UInt16
    let nlvlTo: UInt16
    let volumeAttributes: UInt32
    let volumeFileSystemId: UInt16
    
    init?(_ data: Data) {
        guard data.count >= 150 else {
            return nil
        }
        userType = data.load(from: 0)
        size = data.load(from: 4)
        version = data.load(from: 6)
        kind = data.load(from: 8)
        let volumeNameLength: UInt8 = data.load(from: 10)
        volumeName = String(cString: data[data.startIndex+11..<data.startIndex+11+Int(volumeNameLength)]) ?? ""
        volumeCreationTimestamp = data.load(from: 38) // long unsigned value in seconds since beginning 1904 to 2040
        volumeSignature = data.load(from: 42) // short unsigned HFS value
        volumeType = VolumeType(rawValue: data.load(from: 44)) ?? .unknown
        directoryId = data.load(from: 46)
        let fileNameLength: UInt8 = data.load(from: 50)
        fileName = String(cString: data[data.startIndex+51..<data.startIndex+51+Int(fileNameLength)]) ?? ""
        fileId = data.load(from: 114)
        fileCreatedTimestamp = data.load(from: 118) // value in seconds since beginning 1904 to 2040
        fileType = data.load(from: 122)
        fileCreatorName = data.load(from: 126)
        nlvlFrom = data.load(from: 130)
        nlvlTo = data.load(from: 132)
        volumeAttributes = data.load(from: 134)
        volumeFileSystemId = data.load(from: 138)
    }
}


extension ResourceFork {
    
    // 256 "System Palette" colors    
    static let clut8: [UInt32] = [0xFFFFFF, 0xFFFFCC, 0xFFFF99, 0xFFFF66, 0xFFFF33, 0xFFFF00, 0xFFCCFF, 0xFFCCCC, 0xFFCC99, 0xFFCC66, 0xFFCC33, 0xFFCC00, 0xFF99FF, 0xFF99CC, 0xFF9999, 0xFF9966, 0xFF9933, 0xFF9900, 0xFF66FF, 0xFF66CC, 0xFF6699, 0xFF6666, 0xFF6633, 0xFF6600, 0xFF33FF, 0xFF33CC, 0xFF3399, 0xFF3366, 0xFF3333, 0xFF3300, 0xFF00FF, 0xFF00CC, 0xFF0099, 0xFF0066, 0xFF0033, 0xFF0000, 0xCCFFFF, 0xCCFFCC, 0xCCFF99, 0xCCFF66, 0xCCFF33, 0xCCFF00, 0xCCCCFF, 0xCCCCCC, 0xCCCC99, 0xCCCC66, 0xCCCC33, 0xCCCC00, 0xCC99FF, 0xCC99CC, 0xCC9999, 0xCC9966, 0xCC9933, 0xCC9900, 0xCC66FF, 0xCC66CC, 0xCC6699, 0xCC6666, 0xCC6633, 0xCC6600, 0xCC33FF, 0xCC33CC, 0xCC3399, 0xCC3366, 0xCC3333, 0xCC3300, 0xCC00FF, 0xCC00CC, 0xCC0099, 0xCC0066, 0xCC0033, 0xCC0000, 0x99FFFF, 0x99FFCC, 0x99FF99, 0x99FF66, 0x99FF33, 0x99FF00, 0x99CCFF, 0x99CCCC, 0x99CC99, 0x99CC66, 0x99CC33, 0x99CC00, 0x9999FF, 0x9999CC, 0x999999, 0x999966, 0x999933, 0x999900, 0x9966FF, 0x9966CC, 0x996699, 0x996666, 0x996633, 0x996600, 0x9933FF, 0x9933CC, 0x993399, 0x993366, 0x993333, 0x993300, 0x9900FF, 0x9900CC, 0x990099, 0x990066, 0x990033, 0x990000, 0x66FFFF, 0x66FFCC, 0x66FF99, 0x66FF66, 0x66FF33, 0x66FF00, 0x66CCFF, 0x66CCCC, 0x66CC99, 0x66CC66, 0x66CC33, 0x66CC00, 0x6699FF, 0x6699CC, 0x669999, 0x669966, 0x669933, 0x669900, 0x6666FF, 0x6666CC, 0x666699, 0x666666, 0x666633, 0x666600, 0x6633FF, 0x6633CC, 0x663399, 0x663366, 0x663333, 0x663300, 0x6600FF, 0x6600CC, 0x660099, 0x660066, 0x660033, 0x660000, 0x33FFFF, 0x33FFCC, 0x33FF99, 0x33FF66, 0x33FF33, 0x33FF00, 0x33CCFF, 0x33CCCC, 0x33CC99, 0x33CC66, 0x33CC33, 0x33CC00, 0x3399FF, 0x3399CC, 0x339999, 0x339966, 0x339933, 0x339900, 0x3366FF, 0x3366CC, 0x336699, 0x336666, 0x336633, 0x336600, 0x3333FF, 0x3333CC, 0x333399, 0x333366, 0x333333, 0x333300, 0x3300FF, 0x3300CC, 0x330099, 0x330066, 0x330033, 0x330000, 0x00FFFF, 0x00FFCC, 0x00FF99, 0x00FF66, 0x00FF33, 0x00FF00, 0x00CCFF, 0x00CCCC, 0x00CC99, 0x00CC66, 0x00CC33, 0x00CC00, 0x0099FF, 0x0099CC, 0x009999, 0x009966, 0x009933, 0x009900, 0x0066FF, 0x0066CC, 0x006699, 0x006666, 0x006633, 0x006600, 0x0033FF, 0x0033CC, 0x003399, 0x003366, 0x003333, 0x003300, 0x0000FF, 0x0000CC, 0x000099, 0x000066, 0x000033, 0xEE0000, 0xDD0000, 0xBB0000, 0xAA0000, 0x880000, 0x770000, 0x550000, 0x440000, 0x220000, 0x110000, 0x00EE00, 0x00DD00, 0x00BB00, 0x00AA00, 0x008800, 0x007700, 0x005500, 0x004400, 0x002200, 0x001100, 0x0000EE, 0x0000DD, 0x0000BB, 0x0000AA, 0x000088, 0x000077, 0x000055, 0x000044, 0x000022, 0x000011, 0xEEEEEE, 0xDDDDDD, 0xBBBBBB, 0xAAAAAA, 0x888888, 0x777777, 0x555555, 0x444444, 0x222222, 0x111111, 0x000000]
}

extension NSImage {
    convenience init?(clut8 data: Data, width: Int, height: Int) {
        guard data.count == width * height else {
            return nil
        }
        let argbValues = data.map { ResourceFork.clut8[Int($0)] }
        let bitmapData = argbValues.withUnsafeBufferPointer { Data(buffer: $0) }
        
        guard let provider = CGDataProvider(data: bitmapData as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else {
            return nil
        }
        self.init(cgImage: cgImage, size: NSSize(width: width, height: height))
    }
}
 
