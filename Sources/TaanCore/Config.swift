//
//  Config.swift
//  Async
//
//  Created by Raheel Ahmad on 12/8/18.
//

import Foundation
import Utility

enum AppError: Error {
    case noAction
}

struct BuildConfig {
    let source: Path
    let output: Path
}

struct PostConfig {
    let name: String?
    let source: Path
    var postURL: Foundation.URL {
        let url = URL(fileURLWithPath: source)
            .appendingPathComponent("Content")
            .appendingPathComponent("blog")
        return url
    }
}

enum ReadAction: String, Codable {
    case build, post
}

enum PerformAction {
    case build(BuildConfig)
    case post(PostConfig)
}

public struct Config {
    let action: PerformAction

    init() throws {
        let parser = ArgumentParser(
            commandName: "taan",
            usage: "taan -h",
            overview: "a simple static website generator"
        )
        let source = parser.add(option: "--source", shortName: "-s", kind: String.self, usage: "provides source directory (otherwise current working directory)", completion: nil)
        let output = parser.add(option: "--output", shortName: "-o", kind: String.self, usage: "provides output directory (otherwise current working directory)", completion: nil)
        let name = parser.add(option: "--name", shortName: "-n", kind: String.self, usage: "provides name for the Post", completion: nil)
        let actionArg = parser.add(positional: "", kind: String.self, optional: true, usage: "the action to perform", completion: nil)

        let arguments = Array(CommandLine.arguments.dropFirst())
        let fm = FileManager.default
        let result = try parser.parse(arguments)
        let sourceDirPath: Path = result.get(source) ?? fm.currentDirectoryPath
        let outputDirPath: Path = result.get(output) ?? fm.currentDirectoryPath.appending("/output")
        guard let actionResult = result.get(actionArg), let action = ReadAction(rawValue: actionResult) else {
            throw AppError.noAction
        }

        switch action {
        case .build:
            let config = BuildConfig(source: sourceDirPath, output: outputDirPath)
            self.action = PerformAction.build(config)
        case .post:
            let postName = result.get(name)
            let config = PostConfig(name: postName, source: sourceDirPath)
            self.action = PerformAction.post(config)
        }
    }
}
