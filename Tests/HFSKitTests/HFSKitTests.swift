import XCTest
@testable import HFSKit

final class HFSKitTests: XCTestCase {
    func printContents(_ directory: Directory, _ indent: String = "") {
        for entry in directory.contents {
            switch entry {
            case .file(let file):
                print(indent + file.name)
            case .directory(let subdirectory):
                print(indent + subdirectory.name)
                printContents(subdirectory, indent + "   ")
            }
        }
    }
    func testRead() {        
        guard let isoURL = Bundle.module.url(forResource: "test", withExtension: "iso") else {
            XCTFail("Invalid ISO url")
            return
        }
        guard let disk = Disk(isoURL), let volume = disk.volumes.first else {
            XCTFail("Invalid HFS Volume")
            return
        }
        guard let rootDirectory = volume.rootDirectory else {
            XCTFail("No root directory")
            return
        }
        
        printContents(volume.rootDirectory!)
        
        let expectedFolderContents = [
            "Compatibility",
            "d e v e l o p (B&W)",
            "d e v e l o p (color)",
            "Declaration ROM",
            "Desktop",
            "dynamo",
            "Offscreen ",
            "Perils of PostScript",
            "Realistic Color",
            "TeachText",
            "the Palette Manager"
        ]
        let actualFolderContents = rootDirectory.contents.map { $0.name }
        XCTAssertEqual(expectedFolderContents, actualFolderContents)
            
    }
}
