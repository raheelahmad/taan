//
//  Watcher.swift
//  Async
//
//  Created by Raheel Ahmad on 12/15/18.
//

import Foundation
import Dispatch

final class Watcher {

    static var sources: [Path: DispatchSourceFileSystemObject] = [:]

    private static var root: Path?

    static func watch(path: Path, isRoot: Bool = false, action: @escaping (() throws -> ())) throws {
        if isRoot {
            self.root = path
            sources.removeAll()
        }
        let fm = FileManager.default
        if sources[path] == nil {
            let sourceDirDescrptr = open(path, O_EVTONLY)
            guard sourceDirDescrptr != -1 else { return }
            let eventSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: sourceDirDescrptr, eventMask: DispatchSource.FileSystemEvent.write, queue: nil)
            eventSource.setEventHandler {
                do {
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
            print("registered for \(path)")
        }

        let res = try URL(fileURLWithPath: path).resourceValues(forKeys: [URLResourceKey.isDirectoryKey])
        if !(res.isDirectory == true) {
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