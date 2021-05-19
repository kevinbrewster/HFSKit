//
//  DirectoryEntry.swift
//  HFSKit
//
//  Created by Kevin Brewster on 4/20/21.
//

import Foundation

public struct File {
    internal weak var volume: Volume?
    internal let record: FileRecord
    
    public let id: UInt32
    public let name: String
    
    public func dataFork() -> Data? {
        volume?.fileData(record.dataForkExtents, record.dataForkLogicalLength, .data, record.id)
    }
    public func resourceFork() -> Data? {
        volume?.fileData(record.resourceForkExtents, record.resourceForkLogicalLength, .resource, record.id)
    }
}
public class Directory {
    public let id: UInt32
    public let name: String
    private(set) public lazy var contents: [DirectoryEntry] = {
        volume?.contentsOfDirectory(id).compactMap {
            volume?.content(leafRecord: $0)
        } ?? []
    }()
    internal weak var volume: Volume?
    
    internal init(id: UInt32, name: String, volume: Volume) {
        self.id = id
        self.name = name
        self.volume = volume
    }
}

public enum DirectoryEntry : CustomStringConvertible {
    case file(File)
    case directory(Directory)
    
    private var nameAndId: (String, CNID) {
        switch self {
        case .file(let file): return (file.name, file.id)
        case .directory(let directory): return (directory.name, directory.id)
        }
    }
    
    public var name: String { nameAndId.0 }
    public var id: CNID { nameAndId.1 }
        
    public var description: String {
        nameAndId.0
    }
}

extension Volume {
    
    internal func content(leafRecord: CatalogLeafRecord) -> DirectoryEntry? {
        switch leafRecord {
            case .directory(let directory):
                return .directory(Directory(id: directory.id, name: directory.name, volume: self))
            case .file(let file):
                return .file(File(volume: self, record: file, id: file.id, name: file.name))
            default:
                return nil
        }
    }
    internal func contentsOfDirectory(_ directoryId: UInt32) -> [CatalogLeafRecord] {
        var contents = [CatalogLeafRecord]()
        var leafNode = firstMatchingLeafNode(directoryId, "")
                
        while leafNode != nil {
            for recordData in leafNode!.records {
                guard let record = CatalogLeafRecord(recordData) else {
                    continue
                }
                if record.parentId > directoryId {
                    return contents
                } else if record.parentId == directoryId {
                    contents.append(record)
                }
            }
            if leafNode!.forwardLink > 0 {
                leafNode = catalogTree?.node(at: leafNode!.forwardLink)
            } else {
                leafNode = nil
            }
        }
        return contents
    }
}
