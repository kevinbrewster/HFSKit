//
//  PartitionMap.swift
//  HFSKit
//
//  Created by Kevin Brewster on 4/13/21.
//

import Foundation

struct PartitionMapEntryRecord {
    let signature: UInt16
    let mapTotalBlocks: UInt32 // pmMapBlkCnt - The size of the partition map, in blocks.
    let startBlock: UInt32 // pmPyPartStart - The physical block number of the first block of the partition.
    let totalBlocks: UInt32 // pmPartBlkCnt - The size of the partition, in blocks.
    let name: String
    let type: String
    let startLogicalBlock: LogicalBlock32 // pmLgDataStart - The logical block number of the first block containing file system data. This is for use by operating systems, such as A/UX, in which the file system does not begin at logical block 0 of the partition.
    let totalLogicalBlocks: LogicalBlock32 // pmDataCnt - The size of the file system data area, in blocks. This is used in conjunction with the pmLgDataStart field,
    let status: UInt32 // pmPartStatus
    let startingSectorOfBootCode: UInt32 // pmLgBootStart - The logical block number of the first block containing boot code.
    let bootCodeSize: UInt32 // pmBootSize
    let bootCodeAddress: UInt32 // pmBootAddr
    let bootCodeEntryPoint: UInt32 // pmBootEntry
    let bootCodeChecksum: UInt32 // pmBootCksum
    let processorType: String

    init?(_ data: Data) {
        signature = data.load(from: 0)
        guard signature == 0x504D else {
            return nil
        }
        mapTotalBlocks = data.load(from: 4)
        startBlock = data.load(from: 8)
        totalBlocks = data.load(from: 12)
        name = String(cString: data[16..<47]) ?? ""
        type = String(cString: data[48..<79]) ?? ""
        startLogicalBlock = data.load(from: 80)
        totalLogicalBlocks = data.load(from: 84)
        status = data.load(from: 88)
        startingSectorOfBootCode = data.load(from: 92)
        bootCodeSize = data.load(from: 96)
        bootCodeAddress = data.load(from: 100)
        bootCodeEntryPoint = data.load(from: 108)
        bootCodeChecksum = data.load(from: 116)
        processorType = String(data: data[120..<136], encoding: .macOSRoman) ?? ""
    }
}


extension String {
    init?(cString data: Data) {
        self.init(cString: data.withUnsafeBytes {
            $0.baseAddress!.assumingMemoryBound(to: CChar.self)
        })
    }
}
