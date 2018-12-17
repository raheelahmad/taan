//
//  Watcher.swift
//  Async
//
//  Created by Raheel Ahmad on 12/15/18.
//

import Foundation
import Dispatch

final class Watcher {
    private static let ignoredDirNames = ["node_modules"]

    static var sources: [Path: DispatchSourceFileSystemObject] = [:]

    private static var root: Path?

    private static var watchCount = 0

    static func watch(path: Path, isRoot: Bool = false, action: @escaping (() throws -> ())) throws {
        if isRoot {
            self.root = path
            sources.removeAll()
            watchCount += 1
            print("Watch count: \(watchCount)")
        }
        let pathURL = URL(fileURLWithPath: path)
        guard !ignoredDirNames.contains(pathURL.lastPathComponent) else {
            return
        }
        let fm = FileManager.default
        if sources[path] == nil  {
            let sourceDirDescrptr = open(path, O_EVTONLY)
            guard sourceDirDescrptr != -1 else { return }
            let eventSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: sourceDirDescrptr, eventMask: DispatchSource.FileSystemEvent.write, queue: nil)
            eventSource.setEventHandler {
                do {
                    print("Changed: \(pathURL.lastPathComponent)")
                    try action()
                    if let root = root {
                        try watch(path: root, isRoot: true, action: action)
                    }
                } catch {
                    print(error)
                }
            }
            eventSource.resume()
            sources[path] = eventSource
//            print("registered for \(path)")
        }

        let res = try pathURL.resourceValues(forKeys: [URLResourceKey.isDirectoryKey])
        guard (res.isDirectory == true) else {
            return
        }

        let contents = try fm.contentsOfDirectory(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for item in contents {
            try watch(path: item.path, action: action)
        }
    }
}
