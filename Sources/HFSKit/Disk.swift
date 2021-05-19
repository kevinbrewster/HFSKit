//
//  Disk.swift
//  HFSKitTests
//
//  Created by Kevin Brewster on 4/22/21.
//

import Foundation


public class Disk {
    public let url: URL
    public let volumes: [Volume]
    private let fileHandle: FileHandle
    
    public init?(_ url: URL) {
        // The ISO 9660 primary volume descriptor begins 32,768 bytes (32 KB) into the disc.
        // If present, an Apple partition map begins 512 bytes into the disc;
        // if there is no partition map, the header for an Apple HFS partition (known as a Master Directory Block, or MDB) begins 1,024 bytes into the disc
            
        do {
            self.url = url
            fileHandle = try FileHandle(forReadingFrom: url)
            guard let systemData = try fileHandle.read(upToCount: 32768) else {
                return nil
            }
            //let driverDescriptorRecord  = DriverDescriptorRecord(Data(data[0..<512]))
            
            var volumes = [Volume]()
            for i in stride(from: 512, to: systemData.count, by: 512) {
                guard let partitionEntry = PartitionMapEntryRecord(Data(systemData[i..<i+512])) else {
                    break
                }
                
                if partitionEntry.type == "Apple_HFS" {
                    let partitionOffset = Int(partitionEntry.startBlock) * 512
                    //let partitionSize = Int(partitionEntry.totalBlocks) * 512
                    let volumeFileHandle = VolumeFileHandle(fileHandle, Int(partitionOffset))
                    if let volume = Volume(volumeFileHandle) {
                        volumes.append(volume)
                    }
                }
            }
            if volumes.count == 0 {
                // If no partitions, try using the whole disk as a volume
                let volumeFileHandle = VolumeFileHandle(fileHandle, 0)
                if let volume = Volume(volumeFileHandle) {
                    volumes = [volume]
                }
            }
            guard volumes.count > 0 else {
                return nil
            }
            self.volumes = volumes
            
        } catch let error {
            print("error: \(error)")
            return nil
        }
    }
}
