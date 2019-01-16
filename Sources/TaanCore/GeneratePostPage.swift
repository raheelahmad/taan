//
//  GeneratePostPage.swift
//  Async
//
//  Created by Raheel Ahmad on 12/9/18.
//

import Foundation
import Down

struct PostContext: Codable {
    let title: String
    let date: String
    let body: String
    let pages: [Page]

    init(title: String, date: String, body: String, pages: [Page]) throws {
        self.title = title
        self.date = date
        let markdownHTML = try body.toHTML()
        self.body = markdownHTML
        self.pages = pages
    }
}

struct PostFrontMatter: Codable {
    struct Keys {
        static let titlePrefix = "Title: "
        static let dateSuffix = "Date: "
        static let draftSuffix = "Draft: "
    }
    let title: String
    let date: Date
    let draft: Bool

    var dateString: String {
        return PostFrontMatter.displayFormatter.string(from: date)
    }

    static var displayFormatter: DateFormatter {
        let fm = DateFormatter()
        fm.dateFormat = "MMM d, yyyy"
        return fm
    }

    static var readFormatter: DateFormatter {
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
            "\(Keys.dateSuffix)\(PostFrontMatter.readFormatter.string(from: date))",
            separator
        ].joined(separator: "\n")
    }

    static func readFrontMatter(fileContent: String) throws -> (frontMatter: PostFrontMatter, body: String) {
        let separator = "---"
        let allLines = fileContent.split(separator: "\n", omittingEmptySubsequences: false)
        var separatorsEncountered = 0
        var title: String?
        var date: Date?
        var draft: Bool?
        var lastIdx = 0
        for (idx, lineSubStr) in allLines.enumerated() {
            let line = String(lineSubStr)
            lastIdx = idx
            guard separatorsEncountered < 2 else { break }
            if line == separator {
                separatorsEncountered += 1
                continue
            }
            if line.starts(with: Keys.titlePrefix) {
                title = try line.suffix(after: Keys.titlePrefix)
            }
            if line.starts(with: Keys.dateSuffix) {
                date = try line.suffix(after: Keys.dateSuffix)
                    .flatMap { readFormatter.date(from: $0) }
            }
            if line.starts(with: Keys.draftSuffix) {
                draft = try line.suffix(after: Keys.draftSuffix)
                    .map { $0 == "true" }
            }
        }

        if let title = title, let date = date {
            let body = allLines[(lastIdx)...].joined(separator: "\n")
            return (frontMatter: PostFrontMatter(title: title, date: date, draft: draft ?? false), body: body)
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
        let data = PostFrontMatter(title: config.name ?? "Post title", date: Date(), draft: true)
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
