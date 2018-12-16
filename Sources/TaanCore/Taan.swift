//
//  Taan.swift
//  App
//
//  Created by Raheel Ahmad on 12/8/18.
//

import Foundation

import Dispatch

public final class App {
    init() { }
    
    public static func go() throws {
        let config = try Config()
        switch config.action {
        case .build(let config):
            let renderer = try Renderer(config: config)
            try renderer.render()
            let fm = FileManager.default

            let exists = fm.fileExists(atPath: config.source)
            guard exists else { return }
            do {
                try Watcher.watch(path: config.source, isRoot: true) {
                    try renderer.render()
                }
            } catch {
                print(error)
            }
            print("Watching for changes in \(config.source)")
            RunLoop.main.run()
        case .post(let config):
            try GeneratePostPage.generate(config: config)
        }
    }
}
