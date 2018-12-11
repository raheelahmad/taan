//
//  Taan.swift
//  App
//
//  Created by Raheel Ahmad on 12/8/18.
//

import Foundation

public final class App {
    init() { }
    
    public static func go() throws {
        let config = try Config()
        switch config.action {
        case .build(let config):
            let renderer = try Renderer(config: config)
            try renderer.render()
        case .post(let config):
            try GeneratePostPage.generate(config: config)
        }
    }
}
