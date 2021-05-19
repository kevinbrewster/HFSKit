//
//  DriverDescriptorRecord.swift
//  HFSKit
//
//  Created by Kevin Brewster on 4/13/21.
//

import Foundation

/*
 [From: Inside Macintosh SCSI]
 The Driver Descriptor Record

 The driver descriptor record is a data structure that identifies the device drivers installed on a disk. To support multiple operating systems or other features, a disk can have more than one device driver installed, each in its own partition. The Start Manager reads the driver descriptor record during system startup and uses the information to locate and load the appropriate device driver.
 The driver descriptor record is always located at physical block 0, the first block on the disk. The driver descriptor record is defined by the Block0 data type.
 */

struct DriverDescriptorRecord {
    let signature: UInt16 // 0x4552
    let blockSize: UInt16 // The size of the blocks on the device, in bytes
    let blockCount: UInt32 // The number of blocks on the device.
    //let deviceType: UInt16
    //let deviceId: UInt16
    //let data: UInt32
    let driverCount: UInt16 // The number of drivers installed on the disk.
    let ddBlock: UInt32 // The physical block number of the first block of the first device driver on the disk.
    let ddSize: UInt16 // The size of the device driver, in 512-byte blocks.
    let ddType: UInt16 // The operating system or processor supported by the driver. A value of 1 specifies the Macintosh Operating System.
    
    init?(_ data: Data) {
       
        signature = data.load(from: 0)
        guard signature == 0x4552 else {
            return nil
        }
        blockSize = data.load(from: 2)
        blockCount = data.load(from: 4)
        driverCount = data.load(from: 16)
        ddBlock = data.load(from: 18)
        ddSize = data.load(from: 22)
        ddType = data.load(from: 24)
    }
}
