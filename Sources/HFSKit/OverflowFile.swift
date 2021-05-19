//
//  OverflowFile.swift
//  HFSKit
//
//  Created by Kevin Brewster on 5/16/21.
//

import Foundation


enum ForkType : UInt8 {
    case data = 0
    case resource = 0xFF
}

struct OverflowIndexRecord : KeyedOverflowRecord {
    // Key
    let forkType: ForkType // xkrFkType
    let fileId: CNID // xkrFNum
    let startBlock: AllocationBlock16 // xkrFABN - starting file allocation block
    
    // Data
    let nodeBlock: LogicalBlock32
    
    init?(_ data: Data) {
        guard data[data.startIndex] == 7 else {
            return nil // key length should always be 7 for overflow record
        }
        guard let forkType = ForkType(rawValue: data.load(from: 1)) else {
            return nil
        }
        self.forkType = forkType
        fileId = data.load(from: 2)
        startBlock = data.load(from: 6)
        nodeBlock = data.load(from: 8)
    }
}

struct OverflowLeafRecord : KeyedOverflowRecord {
    
    // Key
    let forkType: ForkType // xkrFkType
    let fileId: CNID // xkrFNum
    let startBlock: AllocationBlock16 // xkrFABN - starting file allocation block
    
    // Data
    let extents: ExtentDataRecord
        
    init?(_ data: Data) {
        guard data[data.startIndex] == 7 else {
            return nil // key length should always be 7 for overflow record
        }
        guard let forkType = ForkType(rawValue: data.load(from: 1)) else {
            return nil
        }
        self.forkType = forkType
        fileId = data.load(from: 2)
        startBlock = data.load(from: 6)
        extents = stride(from: 8, to: 20, by: 4).map {
            (data.load(from: $0), data.load(from: $0 + 2))
        }
    }
}


protocol KeyedOverflowRecord {
    var forkType: ForkType { get }
    var fileId: UInt32 { get }
    var startBlock: AllocationBlock16 { get }
}
extension KeyedOverflowRecord {
    func compare(_ forkType: ForkType, _ fileId: UInt32, _ startBlock: AllocationBlock16) -> ComparisonResult {
        if self.forkType.rawValue < forkType.rawValue {
            return .orderedAscending
        } else if self.forkType.rawValue > forkType.rawValue {
            return .orderedDescending
        } else {
            if self.fileId < fileId {
                return .orderedAscending
            } else if self.fileId > fileId {
                return .orderedDescending
            } else {
                if self.startBlock < startBlock {
                    return .orderedAscending
                } else if self.startBlock > startBlock {
                    return .orderedDescending
                } else {
                    return .orderedSame
                }
            }
        }
    }
}
