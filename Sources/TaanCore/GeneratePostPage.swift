//
//  GeneratePostPage.swift
//  Async
//
//  Created by Raheel Ahmad on 12/9/18.
//

import Foundation

struct PostContext: Codable {
    let title: String
    let date: String
    let body: String
    let pageNames: [String]

    init(title: String, date: String, body: String, pageNames: [String]) {
        self.title = title
        self.date = date
        self.body = body
        self.pageNames = pageNames
    }
}

struct PostFrontMatter: Codable {
    struct Keys {
        static let titlePrefix = "Title: "
        static let dateSuffix = "Date: "
    }
    let title: String
    let date: Date

    var dateString: String {
        return PostFrontMatter.formatter.string(from: date)
    }

    static var formatter: DateFormatter {
        let fm = DateFormatter()
        fm.dateStyle = .short
        fm.timeStyle = .none
        return fm
    }

    private let separator = "---"
    var text: String {
        return [
            separator,
            "\(Keys.titlePrefix)\(title)",
            "\(Keys.dateSuffix)\(PostFrontMatter.formatter.string(from: date))",
            separator
        ].joined(separator: "\n")
    }

    static func readFrontMatter(fileContent: String) throws -> (frontMatter: PostFrontMatter, body: String) {
        let separator = "---"
        let allLines = fileContent.split(separator: "\n")
        var separatorsEncountered = 0
        var title: String?
        var date: Date?
        for (idx, lineSubStr) in allLines.enumerated() {
            let line = String(lineSubStr)
            guard separatorsEncountered < 2 else { break }
            if let title = title, let date = date {
                let body = allLines[(idx+1)...].joined(separator: "\n")
                return (frontMatter: PostFrontMatter(title: title, date: date), body: body)
            }
            if line == separator {
                separatorsEncountered += 1
                continue
            }
            if line.starts(with: Keys.titlePrefix) {
                title = try line.suffix(after: Keys.titlePrefix)
            }
            if line.starts(with: Keys.dateSuffix) {
                date = try line.suffix(after: Keys.dateSuffix)
                    .flatMap { formatter.date(from: $0) }
            }
        }
        throw AppError.incompletePostFrontMatter
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

extension String {
    func suffix(after prefix: String) throws -> String? {
        let titleExpression = try NSRegularExpression(pattern: "^\(prefix)(.*)", options: [])
        let matches = titleExpression.matches(in: String(self), options: [], range: NSRange(location: 0, length: self.count))
        guard
            let offset = matches.first?.range(at: 1),
            let range = Range<String.Index>(offset, in: self)
        else { return nil }
        let result = self[range]
        return String(result)
    }
}
