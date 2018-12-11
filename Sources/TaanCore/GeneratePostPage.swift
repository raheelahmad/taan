//
//  GeneratePostPage.swift
//  Async
//
//  Created by Raheel Ahmad on 12/9/18.
//

import Foundation

struct PostFrontMatter: Codable {
    let title: String
    let date: Date

    private var formatter: DateFormatter {
        let fm = DateFormatter()
        fm.dateStyle = .short
        fm.timeStyle = .none
        return fm
    }

    private let separator = "---"
    var text: String {
        return [separator, "Title: \(title)", "Date: \(formatter.string(from: date))", separator].joined(separator: "\n")
    }
}

final class GeneratePostPage {
    static func generate(config: PostConfig) throws {
        let dateComps = Calendar.current.dateComponents([.day, .month, .year], from: Date())
        var fileNameComps = ["\(dateComps.year!)", "\(dateComps.month!)", "\(dateComps.day!)"]
        if let name = config.name {
            fileNameComps.append(name)
        }
        let fileName = fileNameComps.joined(separator: "-")
        let data = PostFrontMatter(title: config.name ?? "Post title", date: Date())
            .text
            .data(using: .utf8)
        if !FileManager.default.fileExists(atPath: config.postURL.path) {
            try FileManager.default.createDirectory(at: config.postURL, withIntermediateDirectories: true, attributes: nil)
        }
        let fileURL = config.postURL.appendingPathComponent(fileName).appendingPathExtension("md")
        try data?.write(to: fileURL)
    }
}
