# HFSKit

HFSKit is a high-level framework written in pure Swift for programatically reading (and soon, writing!) [Hierarchical File System (HFS)](https://en.wikipedia.org/wiki/Hierarchical_File_System) volumes.

Generally, these volumes will be in the form of ISO files, but HFSKit should support any raw HFS volume.

HFS was the standard file system on Macs from 1985 until 1998, when HFS+ was released. "With the introduction of Mac OS X 10.6, Apple dropped support for formatting or writing HFS disks and images, which remain supported as read-only volumes. Starting with macOS 10.15, HFS disks can no longer be read."

__NOTE:__

__If you are interested in an app with a GUI to extract HFS volumes, check out [HFS.app](https://github.com/kevinbrewster/HFS)__

__If you are interested a cross platform python HFS library/CLI, check out [machfs](https://github.com/elliotnunn/machfs)__


## Installation

### Swift Package Manager

First, declare your dependency in your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/kevinbrewster/HFSKit.git", .branch("master")),
    // ...
]
```

and add "HFSKit" to your application/library target dependencies, e.g. like this:

```swift
.target(name: "ExampleApp", dependencies: [
    "HFSKit",
    // ...
])
```

## Usage

### Load a volume from an ISO

```swift
guard let isoURL = Bundle.module.url(forResource: "test", withExtension: "iso"),
    let disk = Disk(isoURL), 
    let volume = disk.volumes.first 
else {
    print("Invalid volume")
    return
}
```

### Access file/directory at path

```swift
if let entry = volume["path:to:some:file.jpg"] {
    switch entry {
    case .file(let file):
        print("found the file at path!")
    case .directory(let directory):
        print("hmm..this was supposed to be a file..")
    }
}

if let file = volume.file(at: "path:to:some:file.jpg") {
    print("Copying \(file.name) to \(destURL)..")
    file.dataFork()?.write(to: destURL)
}

if let directory = volume.directory(at: "path:to:some:directory") {
    print("directory \(directory.name) has \(directory.contents.count) entries")
}
```

### Access resource fork

```swift
if let file = volume.file(at: "path:to:some:icon"),
    let resourceForkData = file.resourceFork(),
    let resourceFork = ResourceFork(resourceForkData),
    let iconResourceData = resourceFork.resources["icl8"]?.first?.data,
    let icon = NSImage(clut8: iconResourceData, width: 32, height: 32) 
{    
    print("Recovered icon from resource data!")
}
```


### Recurively read entire contents of a volume

```swift
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

if let rootDirectory = volume.rootDirectory {
    printContents(rootDirectory)
}
```
### Write contents of volume to local directory


```swift

do {
    let destURL = URL(fileURLWithPath: "/path/to/desktop")
    try volume.write(to: destURL)
    
} catch let error {
    print("Error during volume write: \(error)")
}
    
```
