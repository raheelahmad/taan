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
    let pages: [Page]

    init(pageFileContent: String, pages: [Page]) throws {
        let markdownHTML = try pageFileContent.toHTML()
        self.body = markdownHTML
        self.pages = pages
    }
}
