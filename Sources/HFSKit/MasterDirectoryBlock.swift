//
//  MasterDirectoryBlock.swift
//  HFSKit
//
//  Created by Kevin Brewster on 4/13/21.
//

import Foundation


typealias ExtentDataRecord = [(startBlock: AllocationBlock16, size: UInt16)]


public struct MasterDirectoryBlock {
    let signature: UInt16 // drSigWord
    let creationTimestamp: UInt32  // drCrDate
    let modificationTimestamp: UInt32  // drLsMod
    let attributes: UInt16 // drAtrb
    let totalFilesInRoot: UInt16 // drNmFls
    let bitmapFirstBlockIndex: UInt16 // drVBMSt (Typically 3 in the current implementation)
    let allocationSearchStart: AllocationBlock16 // drAllocPtr - The (allocation or volume block) index of the allocation block at which the next allocation search will begin.
    let totalAllocationBlocks: UInt16 // drNmAlBlks - number of allocation blocks in volume
    let allocationBlockSize: UInt32 // drAlBlkSiz - size (in bytes) of allocation blocks (This value must always be a multitude of 512 bytes)
    let defaultClumpSize: UInt32 // drClpSiz    
    let allocationBlockStart: LogicalBlock16 // drAlBlSt - first allocation block in volume (In allocation blocks)
    let nextUnusedCatalogNodeId: UInt32 // drNxtCNID - Can be a directory or file identifier.
    let totalUnusedAllocationBlocks: UInt16 // drFreeBks
    let name: String // drVN
    let lastBackupTimestamp: UInt32 // drVolBkUp
    let backupSequenceNumber: UInt16 // drVSeqNum
    let writeCount: UInt32 // drWrCnt - Contains the number of times the volume has been written to.
    let clumpSizeForExtentsFile: UInt32 // drXTClpSiz
    let clumpSizeForCatalogFile: UInt32 // drCTClpSiz
    let totalSubdirectoriesInRoot: UInt16 // drNmRtDirs
    let totalFiles: UInt32 // drFilCnt
    let totalDirectories: UInt32 // drDirCnt
    let finderInfo: MDBFinderInfo // drFndrInfo
    let cacheSize: UInt16 // drVCSize
    let bitmapCacheSize: UInt16 // drVBMCSize
    let commonCacheSize: UInt16 // drCtlCSize
    let overflowFileSize: UInt32 // drXTFlSize
    let overflowFileExtents: ExtentDataRecord
    let catalogFileSize: UInt32 // drCTFlSize
    let catalogFileExtents: ExtentDataRecord // drCTExtRec
}


extension MasterDirectoryBlock {
    init?(_ data: Data) {
        signature = data.load(from: 0)
        guard signature == 0x4244 else {
            NSLog("Invalid signature \(String(signature, radix: 16))")
            return nil
        }
        creationTimestamp = data.load(from: 2)
        modificationTimestamp = data.load(from: 6)
        attributes = data.load(from: 10)
        totalFilesInRoot = data.load(from: 12)
        bitmapFirstBlockIndex = data.load(from: 14)
        allocationSearchStart = data.load(from: 16)
        totalAllocationBlocks = data.load(from: 18)
        allocationBlockSize = data.load(from: 20)
        defaultClumpSize = data.load(from: 24)
        allocationBlockStart = data.load(from: 28)
        nextUnusedCatalogNodeId = data.load(from: 30)
        totalUnusedAllocationBlocks = data.load(from: 34)        
        let nameLength: UInt8 = data.load(from: 36)
        name = String(data: data[37..<37+Int(nameLength)-1], encoding: .macOSRoman) ?? ""
        lastBackupTimestamp = data.load(from: 64)
        backupSequenceNumber = data.load(from: 68)
        writeCount = data.load(from: 70)
        clumpSizeForExtentsFile = data.load(from: 74)
        clumpSizeForCatalogFile = data.load(from: 78)
        totalSubdirectoriesInRoot = data.load(from: 82)
        totalFiles = data.load(from: 84)
        totalDirectories = data.load(from: 88)
        finderInfo = MDBFinderInfo(data[92..<124])!
        cacheSize = data.load(from: 124)
        bitmapCacheSize = data.load(from: 126)
        commonCacheSize = data.load(from: 128)
        overflowFileSize = data.load(from: 130)
        overflowFileExtents = stride(from: 134, to: 146, by: 4).map { (data.load(from: $0), data.load(from: $0 + 2)) }
        catalogFileSize = data.load(from: 146)
        catalogFileExtents = stride(from: 150, to: 162, by: 4).map { (data.load(from: $0), data.load(from: $0 + 2)) }
    }
}

struct VolumeBitmap {
    let data: Data
    init(_ data: Data) {
        self.data = data
    }
}

struct MDBFinderInfo {
    let directoryId: UInt32 // Contains the directory identifier of the directory containing the bootable system. I.e. "System Folder" in Mac OS 8 or 9. Typically this value equals the value in entry 3 or 5.
    let parentId: UInt32 // Contains the parent identifier of the startup application, i.e. "Finder". The value is zero if the volume is not bootable
    let directoryIdForFinderWindow: UInt32
    let directoryIdForBootableSystemFolder: UInt32
    let directoryIdForBootableSystemFolderOSX: UInt32
    let uniqueVolumeId: UInt64
    
    init?(_ data: Data) {
        directoryId = data.load(from: 0)
        parentId = data.load(from: 4)
        directoryIdForFinderWindow = data.load(from: 8)
        directoryIdForBootableSystemFolder = data.load(from: 12)
        directoryIdForBootableSystemFolderOSX = data.load(from: 20)
        uniqueVolumeId = data.load(from: 24)
    }
}
