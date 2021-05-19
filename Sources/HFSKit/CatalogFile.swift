//
//  CatalogFile.swift
//  HFSKit
//
//  Created by Kevin Brewster on 5/16/21.
//

import Foundation


struct CatalogIndexRecord : KeyedCatalogRecord {
    // Key
    let parentId: UInt32
    let name: String
    
    // Data
    let nodeBlock: LogicalBlock32
    
    init?(_ data: Data) {
        let keyLength: UInt8 = data.load(from: 0)
        guard keyLength > 0 else {
            return nil // indicates a deleted file
        }
        parentId = data.load(from: 2)
        let nameLength: UInt8 = data.load(from: 6)
        name = String(data: data[data.startIndex + 7..<data.startIndex+7+Int(nameLength)], encoding: .macOSRoman) ?? ""
        nodeBlock = data.load(from: Int(keyLength) + 1)
    }
}


enum CatalogLeafRecord : NodeRecord, KeyedCatalogRecord {
    case directory(DirectoryRecord)
    case file(FileRecord)
    case directoryThread(DirectoryThreadRecord)
    case fileThread(FileThreadRecord)
    
    init?(_ data: Data) {
        var keyLength: UInt8 = data.load(from: 0)
        guard keyLength > 0 else {
            print("catalog leaf node deleted")
            return nil // indicates a deleted file
        }
        let parentId: UInt32 = data.load(from: 2)
        let nameLength: UInt8 = data.load(from: 6)
        let name = String(data: data[data.startIndex+7..<data.startIndex+7+Int(nameLength)], encoding: .macOSRoman) ?? ""
        
        if keyLength.isMultiple(of: 2) {
            keyLength += 1 //  name field is padded with null characters if necessary to have the next record data or pointer begin on a word boundary.
        }
        let recordData = data[data.startIndex + Int(keyLength) + 1..<data.endIndex]
        
        //let type: UInt8 = data.load(from: Int(keyLength) + 1)
        
        switch recordData[recordData.startIndex] { // the 'type'
            case 1: self = .directory(DirectoryRecord(parentId, name, recordData))
            case 2: self = .file(FileRecord(parentId, name, recordData))
            case 3: self = .directoryThread(DirectoryThreadRecord(parentId, name, recordData))
            case 4: self = .fileThread(FileThreadRecord(parentId, name, recordData))
            default:
                print("catalog leaf node '\(name)' unknown type")
                return nil
        }
    }
    
    var parentId: UInt32 {
        switch self {
        case .directory(let d): return d.parentId
        case .file(let f): return f.parentId
        case .directoryThread(let d): return d.parentId
        case .fileThread(let f): return f.parentId
        }
    }
    var name: String {
        switch self {
        case .directory(let d): return d.name
        case .file(let f): return f.name
        case .directoryThread(let d): return d.name
        case .fileThread(let f): return f.name
        }
    }
}


protocol KeyedCatalogRecord {
    var parentId: UInt32 { get }
    var name: String { get }
}
extension KeyedCatalogRecord {
    func compare(_ parentId: UInt32, _ name: String) -> ComparisonResult {
        if self.parentId < parentId {
            return .orderedAscending
        } else if self.parentId > parentId {
            return .orderedDescending
        } else {
            return self.name.caseInsensitiveCompare(name)
        }
    }
}





struct DirectoryRecord {
    struct FinderInfo {
        let windowBoundaries: (top: UInt16, left: UInt16, bottom: UInt16, right: UInt16)
        let flags: FinderFlags
        let location: (v: UInt16, h: UInt16)
        let folder: UInt16
        
        // Extended folder information
        let scrollPosition: (v: UInt16, h: UInt16)
        let addedTimestamp: UInt32 // alternatively: openDirectoryChain if kHFSHasDateAddedMask is not set
        let scriptCodeFlags: UInt8
        let extendedFlags: UInt8
        let comment: UInt16
        let putAwayFolderId: CNID
    }
    // Key
    let parentId: UInt32
    let name: String
    
    // Data
    let flags: UInt16 // dirFlags
    let totalEntries: UInt16 // dirVal
    let id: UInt32 // dirDirID
    let creationTimestamp: UInt32 // dirCrDat
    let modificationTimestamp: UInt32 // dirMdDat
    let lastBackupTimestamp: UInt32 // dirBkDat
    let finderInfo: FinderInfo // dirUsrInfo + dirFndrInfo
    
    init(_ parentId: UInt32, _ name: String, _ data: Data) {
        self.parentId = parentId
        self.name = name
        flags = data.load(from: 2)
        totalEntries = data.load(from: 4)
        id = data.load(from: 6)
        creationTimestamp = data.load(from: 10)
        modificationTimestamp = data.load(from: 14)
        lastBackupTimestamp = data.load(from: 18)
        finderInfo = FinderInfo(
            windowBoundaries: (data.load(from: 22), data.load(from: 24), data.load(from: 26), data.load(from: 28)),
            flags: FinderFlags(rawValue: data.load(from: 30)),
            location: (data.load(from: 32), data.load(from: 34)),
            folder: data.load(from: 36),
            scrollPosition: (data.load(from: 38), data.load(from: 40)),
            addedTimestamp: data.load(from: 42),
            scriptCodeFlags: data.load(from: 46),
            extendedFlags: data.load(from: 47),
            comment: data.load(from: 48),
            putAwayFolderId: data.load(from: 50)
        )
    }
}
struct FileRecord {
    struct FinderInfo {
        let type: UInt32
        let creator: UInt32
        let flags: FinderFlags
        let location: (v: UInt16, h: UInt16)
        let folder: UInt16
    }
    struct ExtendedFinderInfo { // FXInfo
        let iconId: UInt16 // fdIconID
        let scriptCodeFlags: UInt8 // fdScript
        let extendedFlags: UInt8 // fdXFlags
        let comment: UInt16 // fdComment - comment ID number
        let putAwayFolderId: CNID // fdPutAway - home directory ID
    }
    struct Flags: OptionSet {
        let rawValue: UInt8

        static let isLocked      = Flags(rawValue: 1 << 0)
        static let threadExists  = Flags(rawValue: 1 << 1)
        static let isUsed        = Flags(rawValue: 1 << 7)
    }
    // Key
    let parentId: UInt32
    let name: String
    
    // Data
    let flags: Flags // filFlags
    let type: UInt8 // filTyp - The file type. This field should always contain 0
    let finderInfo: FinderInfo // filUsrWds - The file's Finder information.
    let id: UInt32 // filFlNum - The file ID
    let dataForkFirstAllocationBlock: UInt16 // filStBlk - first alloc. blk. of data fork
    let dataForkLogicalLength: UInt32    // filLgLen - logical EOF of data fork
    let dataForkPhysicalLength: UInt32    // filPyLen - physical EOF of data fork
    let resourceForkFirstAllocationBlock: UInt16    // filRStBlk - first alloc. blk. of resource fork
    let resourceForkLogicalLength: UInt32    // filRLgLen - logical EOF of resource fork
    let resourceForkPhysicalLength: UInt32    // filRPyLen - physical EOF of resource fork
    let creationTimestamp: UInt32    // filCrDat - date and time of creation
    let modificationTimestamp: UInt32    // filMdDat - date and time of last modification
    let lastBackupTimestamp: UInt32    // filBkDat - date and time of last backup
    let extendedFinderInfo: ExtendedFinderInfo     // filFndrInfo - additional Finder information -- 16 bytes
    let clumpSize: UInt16 // filClpSize - file clump size
    let dataForkExtents: ExtentDataRecord  // filExtRec - first data fork extent record
    let resourceForkExtents: ExtentDataRecord  // filRExtRec - first resource fork extent record
    
    init(_ parentId: UInt32, _ name: String, _ data: Data) {
        self.parentId = parentId
        self.name = name
        flags = Flags(rawValue: data.load(from: 2))
        type = data.load(from: 3)
        finderInfo = FinderInfo(
            type: data.load(from: 4),
            creator: data.load(from: 8),
            flags: FinderFlags(rawValue: data.load(from: 12)),
            location: (data.load(from: 14), data.load(from: 16)),
            folder: data.load(from: 18)
        )
        id = data.load(from: 20)
        dataForkFirstAllocationBlock = data.load(from: 24)
        dataForkLogicalLength = data.load(from: 26)
        dataForkPhysicalLength = data.load(from: 30)
        resourceForkFirstAllocationBlock = data.load(from: 34)
        resourceForkLogicalLength = data.load(from: 36)
        resourceForkPhysicalLength = data.load(from: 40)
        creationTimestamp = data.load(from: 44)
        modificationTimestamp = data.load(from: 48)
        lastBackupTimestamp = data.load(from: 52)
        extendedFinderInfo = ExtendedFinderInfo(
            iconId: data.load(from: 56),
            scriptCodeFlags: data.load(from: 64),
            extendedFlags: data.load(from: 65),
            comment: data.load(from: 66),
            putAwayFolderId: data.load(from: 68)
        )
        clumpSize = data.load(from: 72)
        dataForkExtents = stride(from: 74, to: 86, by: 4).map { (data.load(from: $0), data.load(from: $0 + 2)) }
        resourceForkExtents = stride(from: 86, to: 98, by: 4).map { (data.load(from: $0), data.load(from: $0 + 2)) }
    }
}

struct DirectoryThreadRecord {
    // Key
    let parentId: UInt32
    let name: String
    
    // Data
    let directoryParentId: UInt32
    let directoryName: String

    init(_ parentId: UInt32, _ name: String, _ data: Data) {
        self.parentId = parentId
        self.name = name
        directoryParentId = data.load(from: 10)
        directoryName = String(cString: data[data.startIndex + 14..<data.endIndex]) ?? ""
    }
}

struct FileThreadRecord {
    
    // Key
    let parentId: UInt32
    let name: String
    
    // Data
    let fileParentId: UInt32
    let fileName: String
    
    init(_ parentId: UInt32, _ name: String, _ data: Data) {
        self.parentId = parentId
        self.name = name
        fileParentId = data.load(from: 10)
        fileName = String(cString: data[data.startIndex + 14..<data.endIndex]) ?? ""
    }
}



struct FinderFlags: OptionSet {
    let rawValue: UInt16

    static let isOnDesk         = FinderFlags(rawValue: 0x0001)
    static let color            = FinderFlags(rawValue: 0x000E)
    static let isShared         = FinderFlags(rawValue: 0x0040)
    static let hasNoInits       = FinderFlags(rawValue: 0x0080)
    static let hasBeenInited    = FinderFlags(rawValue: 0x0100)
    static let hasCustomIcon    = FinderFlags(rawValue: 0x0400)
    static let isStationary     = FinderFlags(rawValue: 0x0800)
    static let isNameLocked     = FinderFlags(rawValue: 0x1000)
    static let hasBundle        = FinderFlags(rawValue: 0x2000)
    static let isInvisible      = FinderFlags(rawValue: 0x4000)
    static let isAlias          = FinderFlags(rawValue: 0x8000)
}
