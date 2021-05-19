//
//  Volume2.swift
//  HFSKit
//
//  Created by Kevin Brewster on 4/13/21.
//


//  xattr -p com.apple.ResourceFork


import Foundation
import AppKit
import CoreGraphics


typealias LogicalBlock16 = UInt16 // A logical block is a unit of drive space composed of up to 512 bytes
typealias LogicalBlock32 = UInt32 // A logical block is a unit of drive space composed of up to 512 bytes
typealias AllocationBlock16 = UInt16 // An allocation block is a multiple of 512 and is the smallest block for HFS data
typealias AllocationBlock32 = UInt32 // An allocation block is a multiple of 512 and is the smallest block for HFS data


public typealias CNID = UInt32

extension CNID {
    static let rootParentID: CNID            = 1 // Parent identifier of the root directory (folder)
    static let rootFolderID: CNID            = 2 // Directory identifier of the root directory (folder)
    static let overflowFileID: CNID          = 3 // The extents (overflow) file
    static let catalogFileID: CNID           = 4 // The catalog file
    static let badBlockFileID: CNID          = 5 // The bad allocation block file
    static let allocationFileID: CNID        = 6 // The allocation file (HFS+)
    static let startupFileID: CNID           = 7 // The startup file (HFS+)
    static let attributesFileID: CNID        = 8 // The attributes file (HFS+)
    static let repairCatalogFileID: CNID     = 14 // Used temporarily by fsck_hfs when rebuilding the catalog file.
    static let bogusExtentFileID: CNID       = 15 // The bogus extent file (Used temporarily during exchange files operations)
    static let firstUserCatalogNodeID: CNID  = 16 // The first available CNID for user’s files and folders
}



public class Volume {
    
    // Public
    public let mdb: MasterDirectoryBlock
    public var name: String { return mdb.name }
    public var writeDelegate: VolumeWriteDelegate?
        
    lazy public var rootDirectory: Directory? = {
        guard let rootDirectoryRecord = contentsOfDirectory(1).first,
              case let .directory(directory) = self.content(leafRecord: rootDirectoryRecord)
        else {
            return nil
        }
        return directory
    }()
    public subscript(index: String) -> DirectoryEntry? {
        get {
            guard let leafRecord = firstMatchingLeafRecord(path: index) else {
                return nil
            }
            return content(leafRecord: leafRecord)
        }
    }
    public func file(at path: String) -> File? {
        guard case let .file(file) = self[path] else {
            return nil
        }
        return file
    }
    public func directory(at path: String) -> Directory? {
        guard case let .directory(directory) = self[path] else {
            return nil
        }
        return directory
    }
    
    
    // Private / Internal
    private let fileHandle: VolumeFileHandle
    lazy internal var overflowTree: BTree? = {
        guard let overflowData = fileData(mdb.overflowFileExtents, mdb.overflowFileSize, .data, 3) else {
            return nil
        }
        return BTree(overflowData)
    }()
    lazy internal var catalogTree: BTree? = {
        guard let catalogData = fileData(mdb.catalogFileExtents, mdb.catalogFileSize, .data, 4) else {
            return nil
        }
        return BTree(catalogData)
    }()
    internal init?(_ fileHandle: VolumeFileHandle) {
        guard let data = fileHandle.data(in: 0..<1536) else {
            return nil
        }
        guard let mdb = MasterDirectoryBlock(Data(data[1024..<1536])) else {
            return nil
        }
        self.fileHandle = fileHandle
        self.mdb = mdb
        //self.volumeBitmap = VolumeBitmap(Data(data[1526..<2048]))
    }
    internal func fileData(_ extents: ExtentDataRecord, _ totalSize: UInt32, _ forkType: ForkType, _ fileId: CNID) -> Data? {
        // Each file has (up to 3) "extents" and optionally an additional (up to 3) extents (defined in overflow file)
        // where an extent is a (startBlock, countBlock) range of allocation data
        
        var allExtents = extents
        var totalBlocks = extents.reduce(0) { $0 + $1.size }
        let totalBlocksNeeded = Int((totalSize + mdb.allocationBlockSize - 1) / mdb.allocationBlockSize)
        
        // Check if we need to use the overflow file to get additional extents (if the file itself is not the overflow file)
        if fileId != .overflowFileID {
            while totalBlocks < totalBlocksNeeded {
                if let overflowLeafRecord = overflowLeafRecord(forkType, fileId, totalBlocks) {
                    for extent in overflowLeafRecord.extents {
                        allExtents.append(extent)
                        totalBlocks += extent.size
                    }
                } else {
                    return nil
                }
            }
        }
        
        var totalRead = 0
        var data = Data()
        for (startBlock, totalBlocks) in allExtents {
            let offset = (Int(mdb.allocationBlockStart) * 512) + (Int(startBlock) * Int(mdb.allocationBlockSize))
            let size = Int(totalBlocks) * Int(mdb.allocationBlockSize)
            guard let readData = fileHandle.data(in: offset..<offset+size) else {
                return nil
            }
            data.append(readData)
            totalRead += readData.count
            if totalRead >= Int(totalSize) {
                break
            }
        }
        guard totalRead >= Int(totalSize) else {
            return nil // this should never happen..
        }
        return data[0..<totalSize]
    }
}




internal class VolumeFileHandle {
    let fileHandle: FileHandle
    let offset: Int
    
    init(_ fileHandle: FileHandle, _ offset: Int) {
        self.fileHandle = fileHandle
        self.offset = offset
    }
    func data(in range: Range<Int>) -> Data? {
        do {
            try fileHandle.seek(toOffset: UInt64(offset + range.lowerBound))
            return try fileHandle.read(upToCount: range.count)
        } catch {
            return nil
        }
    }
}



extension Data {
    func load<T: FixedWidthInteger>(from offset: Int) -> T {
        return self[startIndex+offset..<startIndex+offset+MemoryLayout<T>.size].reduce(0) { $0 << 8 | T($1) }
    }
    func load<T: FixedWidthInteger>(from offset: UInt32) -> T {
        return load(from: Int(offset))
    }
}
