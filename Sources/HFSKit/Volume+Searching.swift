//
//  Volume+Searching.swift
//  HFSKit
//
//  Created by Kevin Brewster on 4/20/21.
//

import Foundation

extension Volume {
    
    internal func overflowLeafRecord(_ forkType: ForkType, _ id: CNID, _ startBlock: AllocationBlock16) -> OverflowLeafRecord? {
        /*
         Inside Macintosh: "When the File Manager needs to find a data record, it begins searching at the root node (which is an index node, unless the tree has only one level), moving from one record to the next until it finds the record with the highest key that is less than or equal to the search key. The pointer of that record leads to another node, one level down in the tree. This process continues until the File Manager reaches a leaf node; then the records of that leaf node are examined until the desired key is found. At that point, the desired data has also been found."
         */
        var node: BTreeNode? = overflowTree?.rootNode
        
        while node != nil {
            
            switch node!.type {
            case .index:
               // print(" -- Index(\(node!.records.count) records) --")
                var nextNodeBlock: LogicalBlock32?
                
                // Find the maximum record whose key is <= searchKey
                recordLoop: for recordData in node!.records {
                    guard let record = OverflowIndexRecord(recordData) else {
                        continue
                    }
                    switch record.compare(forkType, id, startBlock) {
                    case .orderedDescending: // record key is higher so quit now
                        break recordLoop
                    default:
                        nextNodeBlock = record.nodeBlock
                    }
                }
                if let nextNodeBlock = nextNodeBlock {
                    node = overflowTree?.node(at: nextNodeBlock)
                } else {
                    node = nil
                }
            case .leaf:
                for recordData in node!.records {
                    guard let record = OverflowLeafRecord(recordData) else {
                        continue
                    }
                    switch record.compare(forkType, id, startBlock) {
                    case .orderedSame:
                        return record
                    case .orderedDescending: // record key is higher so quit now
                        return nil
                    default:
                        ()
                    }
                }                
            default: ()
            }
        }
        return nil
    }
    
    
    internal func firstMatchingLeafNode(_ parentId: CNID, _ name: String) -> BTreeNode? {
        var node: BTreeNode? = catalogTree?.rootNode
        
        while node != nil {
            switch node!.type {
            case .index:
               // print(" -- Index(\(node!.records.count) records) --")
                var nextNodeBlock: UInt32?
                
                // Find the maximum record whose key is <= searchKey
                recordLoop: for recordData in node!.records {
                    guard let record = CatalogIndexRecord(recordData) else {
                        continue
                    }
                    switch record.compare(parentId, name) {
                    case .orderedDescending:
                        if nextNodeBlock == nil, name == "", record.parentId == parentId {
                            // if searching for contents of directory based on parentId, the first record of node might be the first entry for directory and the name will be greater than search name of ""
                            
                            //print("Record(\(record.parentId), \(record.name)): too high but parentId matches and name == '' so using")
                            nextNodeBlock = record.nodeBlock
                        }
                        //print("Record(\(record.parentId), \(record.name)): too high, stopping")
                        break recordLoop
                    default:
                        //print("Record(\(record.parentId), \(record.name)): matches")
                        nextNodeBlock = record.nodeBlock
                    }
                }
                if let nextNodeBlock = nextNodeBlock {
                    node = catalogTree?.node(at: nextNodeBlock)
                } else {
                    node = nil
                }                
            case .leaf:
                //print(" -- Leaf(\(node!.records.count) records) --")
                return node
                
            default: ()
            }
        }
        return nil
    }
    private func firstMatchingLeafRecord(_ parentId: UInt32, _ name: String) -> CatalogLeafRecord? {
        guard let leafNode = firstMatchingLeafNode(parentId, name) else {
            return nil
        }
        for recordData in leafNode.records {
            guard let record = CatalogLeafRecord(recordData) else {
                continue
            }
            switch record.compare(parentId, name) {
            case .orderedSame:          return record
            case .orderedDescending:    return nil
            case .orderedAscending:     continue
            }
        }
        return nil
    }
    internal func firstMatchingLeafRecord(path: String) -> CatalogLeafRecord? {
        var parts = path.split(separator: ":")
        var parentDirectoryId = CNID.rootFolderID
        
        while !parts.isEmpty {
            let name = String(parts.removeFirst())
            guard let record = firstMatchingLeafRecord(parentDirectoryId, name) else {
                return nil
            }
            switch record {
            case .directory(let directory):
                if parts.isEmpty {
                    return record
                } else {
                    parentDirectoryId = directory.id
                }
            case .file(_):
                if parts.isEmpty {
                    return record
                } else {
                    return nil
                }
            default:
                ()
            }
        }
        return nil
    }
}
