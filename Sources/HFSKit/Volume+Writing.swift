//
//  Volume+Writing.swift
//  HFSKit
//
//  Created by Kevin Brewster on 4/20/21.
//

import Foundation
import AppKit

public protocol VolumeWriteDelegate {
    func volume(_ volume: Volume, willWriteToURL url: URL, totalBytesExpectedToWrite: UInt64)
    func volume(_ volume: Volume, willWriteFileToURL url: URL)
    func volume(_ volume: Volume, didWriteFileToURL url: URL, bytesWritten: UInt64)
}

extension Volume {
    
    public func write(to baseURL: URL) throws {
        guard let catalogTree = catalogTree else {
            return
        }
        let leafNodeRecords: [CatalogLeafRecord] = catalogTree.leafNodeRecords()
        let catalogLeafRecords: [UInt32: [CatalogLeafRecord]] = Dictionary(grouping: leafNodeRecords, by: { $0.parentId })
        
        let totalBytesToWrite: UInt64 = leafNodeRecords.reduce(0) {
            switch $1 {
            case .file(let file): return $0 + UInt64(file.dataForkLogicalLength) + UInt64(file.resourceForkLogicalLength)
            default: return $0
            }
        }
        writeDelegate?.volume(self, willWriteToURL: baseURL, totalBytesExpectedToWrite: totalBytesToWrite)
        
        var queue: [(String, UInt32)] = [("", 1)]
        
        var aliasQueue = [(aliasURL: URL, targetId: CNID)]()
        var urlsById = [UInt32: URL]() // so we can resolve alias targets later
        
        while !queue.isEmpty {
            let (destPath, dirId) = queue.removeLast()
            guard let records = catalogLeafRecords[dirId] else {
                //print("NO RECORDS FOR PARENT ID \(dirId)")
                continue
            }            
            for record in records {
                switch record {
                case .file(let file):
                    let fileName = file.name.replacingOccurrences(of: "/", with: ":")
                    var fileURL = URL(fileURLWithPath: destPath + fileName, isDirectory: false, relativeTo: baseURL)
                    
                    if file.finderInfo.flags.contains(.isAlias) {
                        guard let resourceData = fileData(file.resourceForkExtents, file.resourceForkLogicalLength, .resource, file.id),
                              let resourceFork = ResourceFork(resourceData),
                              let aliasResourceData = resourceFork.resources["alis"]?.first?.data,
                              let aliasResource = AliasResource(aliasResourceData),
                              aliasResource.volumeCreationTimestamp == mdb.creationTimestamp
                        else {
                            continue
                        }
                        aliasQueue.append((fileURL, aliasResource.fileId))
                        
                    } else {
                        writeDelegate?.volume(self, willWriteFileToURL: fileURL)
                        
                        // Data Fork
                        let data = fileData(file.dataForkExtents, file.dataForkLogicalLength, .data, file.id) ?? Data()
                        try data.write(to: fileURL)
                        urlsById[file.id] = fileURL
                                                
                        if file.finderInfo.flags.contains(.isInvisible) {
                            var resourceValues = URLResourceValues()
                            resourceValues.isHidden = true
                            try fileURL.setResourceValues(resourceValues)
                        }
                        
                        // Resource Fork -- save as 'extended attribute'
                        guard let resourceData = fileData(file.resourceForkExtents, file.resourceForkLogicalLength, .resource, file.id) else {
                            continue
                        }
                        if resourceData.count > 0 {
                            _ = fileURL.withUnsafeFileSystemRepresentation { fileSystemPath in
                                resourceData.withUnsafeBytes {
                                    setxattr(fileSystemPath, "com.apple.ResourceFork", $0.baseAddress, $0.count, 0, 0)
                                }
                            }
                            // Set file icon
                            if let resourceFork = ResourceFork(resourceData),
                               let iconResourceData = resourceFork.resources["icl8"]?.first?.data,
                               let icon = NSImage(clut8: iconResourceData, width: 32, height: 32) {
                                
                                if fileURL.lastPathComponent == "Icon\r" {
                                    if let folderURL = urlsById[file.parentId] {
                                        NSWorkspace().setIcon(icon, forFile: folderURL.path, options: [])
                                    }
                                } else {
                                    NSWorkspace().setIcon(icon, forFile: fileURL.path, options: [])
                                }
                            }
                        }
                        writeDelegate?.volume(self, didWriteFileToURL: fileURL, bytesWritten: UInt64(file.dataForkLogicalLength) + UInt64(file.resourceForkLogicalLength))
                        
                    }
                    
                case .directory(let directory):
                    let directoryName = directory.name.replacingOccurrences(of: "/", with: ":")
                    let directoryPath = destPath + directoryName + "/"
                    let directoryURL = URL(fileURLWithPath: directoryPath, isDirectory: true, relativeTo: baseURL)
                    queue.append((directoryPath, directory.id))
                    try FileManager.default.createDirectory(atPath: directoryURL.path, withIntermediateDirectories: true, attributes: nil)
                    urlsById[directory.id] = directoryURL
                    
                default: ()
                }
            }
        }
        
        // Aliases
        for (aliasUrl, targetId) in aliasQueue {
            guard let targetUrl = urlsById[targetId] else {
                continue
            }
            let bookmarkData = try targetUrl.bookmarkData(options: .suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: nil)
            try URL.writeBookmarkData(bookmarkData, to: aliasUrl)
        }
    }
}
