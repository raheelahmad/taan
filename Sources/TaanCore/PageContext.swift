//
//  PageContext.swift
//  Async
//
//  Created by Raheel Ahmad on 12/11/18.
//

import Foundation
import Down

struct PageContext: Codable {
    let body: String
    let pageNames: [String]

    init(pageFileContent: String, pageNames: [String]) throws {
        let markdownHTML = try pageFileContent.toHTML()
        self.body = markdownHTML
        self.pageNames = pageNames
    }
}
