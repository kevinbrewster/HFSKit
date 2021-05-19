//
//  BTreeNode.swift
//  HFSKit
//
//  Created by Kevin Brewster on 4/14/21.
//

import Foundation

// Reference: Inside Macintosh: Files / Chapter 2 - File Manager

class BTree {
    let data: Data
    let headerRecord: BTreeHeaderRecord
    let mapRecord: BTreeMapRecord
    let rootNode: BTreeNode
            
    init?(_ data: Data) {
        self.data = data
        let headerNode = BTreeNode(Data(data[0..<512]))
        
        guard headerNode.records.count == 3 else {
            return nil
        }
        headerRecord = BTreeHeaderRecord(headerNode.records[0])
        mapRecord = BTreeMapRecord(headerNode.records[2])
        
        let rootNodeOffset = 512 * Int(headerRecord.rootNodeBlock)
        rootNode = BTreeNode(Data(data[rootNodeOffset..<rootNodeOffset+512]))
    }
    internal func node(at logicalBlock: LogicalBlock32) -> BTreeNode {
        let offset = 512 * Int(logicalBlock)
        return BTreeNode(data[offset..<offset+512])
    }
    func leafNodeRecords<T: NodeRecord>() -> [T] {
        var leafNodeRecords = [T]()
        var leafNodeBlock = headerRecord.firstLeafNodeBlock
        while leafNodeBlock != headerRecord.lastLeafNodeBlock{
            let leafNode = node(at: leafNodeBlock)
            leafNodeRecords += leafNode.records.compactMap { T($0) }
            leafNodeBlock = leafNode.forwardLink
        }
        return leafNodeRecords
    }
}
 
struct BTreeNode {
    enum NodeType: UInt8 {
        case leaf = 0xFF
        case index = 0
        case header = 1
        case map = 2
    }
    let forwardLink: LogicalBlock32
    let backwardLink: LogicalBlock32
    let type: NodeType
    let height: UInt8
    let numberOfRecords: UInt16
    let records: [Data]
    
    init(_ data: Data) { // 512 byes total
        // Node Descriptor
        forwardLink = data.load(from: 0)
        backwardLink = data.load(from: 4)
        type = NodeType(rawValue: data.load(from: 8)) ?? .index
        height = data.load(from: 9)
        numberOfRecords = data.load(from: 10)
        guard numberOfRecords != UInt16.max else {
            records = []
            return
        }
        records = (0..<numberOfRecords).map {
            let startOffset: UInt16 = data.load(from: 510 - Int($0 * 2))
            let endOffset: UInt16 = data.load(from: 508 - Int($0 * 2))
            return data[data.startIndex+Int(startOffset)..<data.startIndex+Int(endOffset)]
        }
    }
}

struct BTreeHeaderRecord : NodeRecord { // BTHdrRec
    let depth: UInt16 // bthDepth - current depth of tree
    let rootNodeBlock: LogicalBlock32 // bthRoot - number of root node
    let totalRecords: UInt32 // bthNRecs - number of leaf records in tree
    let firstLeafNodeBlock: LogicalBlock32 // bthFNode
    let lastLeafNodeBlock: LogicalBlock32 // bthLNode
    let nodeSize: UInt16 // bthNodeSize
    let maxKeyLength: UInt16 // bthKeyLen
    let totalNodesInTree: UInt32 // bthNNodes
    let totalFreeNodes: UInt32 // bthFree
    
    init(_ data: Data) {
        depth = data.load(from: 0)
        rootNodeBlock = data.load(from: 2)
        totalRecords = data.load(from: 6)
        firstLeafNodeBlock = data.load(from: 10)
        lastLeafNodeBlock = data.load(from: 14)
        nodeSize = data.load(from: 18)
        maxKeyLength = data.load(from: 20)
        totalNodesInTree = data.load(from: 22)
        totalFreeNodes = data.load(from: 24)
    }
}

struct BTreeMapRecord : NodeRecord {
    let data: Data
    
    init(_ data: Data) {
        self.data = data
    }
}

protocol NodeRecord {
    init?(_ data: Data)
}


