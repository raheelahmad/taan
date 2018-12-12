import Foundation

import Down
import Leaf

typealias Path = String

public class Renderer {
    private let templateRenderer: LeafRenderer
    private let config: BuildConfig

    init(config: BuildConfig) throws {

        let container = BasicContainer(config: .init(), environment: .production, services: .init(), on: EmbeddedEventLoop())
        var tagsConfig = LeafTagConfig.default()
        tagsConfig.use(Raw(), as: "raw")
        let viewsDir = Renderer.topLevelDir(named: "Views", config: config)
        let leafConfig = LeafConfig(tags: tagsConfig, viewsDir: viewsDir, shouldCache: false)
        self.templateRenderer = LeafRenderer(config: leafConfig, using: container)
        self.config = config

        try setup()
    }

    private func setup() throws {
        let doesNotExist = !FileManager.default.fileExists(atPath: outputDir)
        guard doesNotExist else { return }
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: outputDir, isDirectory: true),
            withIntermediateDirectories: false, attributes: nil
        )
    }

    private var outputDir: String {
        return config.output
    }

    private var contentDir: String {
        return topLevelDir(named: "Content")
    }

    private var viewsDir: String {
        return topLevelDir(named: "Views")
    }

    private func templatePath(named name: String) -> String {
        return viewsDir.appending("/\(name).leaf")
    }

    private func topLevelDir(named dirName: String) -> String {
        return Renderer.topLevelDir(named: dirName, config: config)
    }

    private static func topLevelDir(named dirName: String, config: BuildConfig) -> String {
        return config.source.appending("/\(dirName)")
    }

    public func postPaths() throws -> [URL] {
        let blogURL = URL(fileURLWithPath: contentDir).appendingPathComponent("blog", isDirectory: true)
        return try FileManager.default
            .contentsOfDirectory(at: blogURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            .filter { $0.pathExtension == "md" }
    }

    public func pagePaths() throws -> [URL] {
        return try FileManager.default
            .contentsOfDirectory(atPath: contentDir)
            .map { URL(fileURLWithPath: contentDir).appendingPathComponent($0) }
            .filter { $0.pathExtension == "md" }
    }

    public func pageNames() throws -> [String] {
        return try pagePaths()
            .map { $0.deletingPathExtension().lastPathComponent }
            .filter { $0 != "index" }
    }


    public func render() throws {
        try copyStatic()
        try renderPages()
        try renderPosts()
    }

    private func copyStatic() throws {
        let staticDir = topLevelDir(named: "Static")
        for item in try FileManager.default.contentsOfDirectory(atPath: staticDir) {
            let itemURL = URL(fileURLWithPath: staticDir).appendingPathComponent(item)
            let outURL = URL(fileURLWithPath: outputDir).appendingPathComponent(item)
            if FileManager.default.fileExists(atPath: outURL.path, isDirectory: nil) {
                try FileManager.default.removeItem(at: outURL)
            }
            try FileManager.default.copyItem(at: itemURL, to: outURL)
        }
    }

    private func renderPosts() throws {
        let pageTemplate = templatePath(named: "post")
        let pageNames = try self.pageNames()
        for pageURL in try postPaths() {
            let pageFileContent = try String(contentsOf: pageURL)
            let (frontMatter, body) = try PostFrontMatter.readFrontMatter(fileContent: pageFileContent)
            let context = PostContext(
                title: frontMatter.title,
                date: frontMatter.dateString,
                body: body,
                pageNames: pageNames
            )
            let renderResult = try templateRenderer
                .render(pageTemplate, context)
                .wait()
            let pageFileName = pageURL.htmlFileName
            let htmlPath = outputDir.appending("/\(pageFileName)")
            let outputFile = URL(fileURLWithPath: htmlPath, isDirectory: false)
            try renderResult.data.write(to: outputFile)
        }
    }

    /// Render each Page (top-level files in Content) using the "page.leaf" template
    private func renderPages() throws {
        let pageTemplate = templatePath(named: "page")
        let pageNames = try self.pageNames()
        for pageURL in try pagePaths() {
            let pageFileContent = try String(contentsOf: pageURL)
            let renderResult = try templateRenderer
                .render(pageTemplate, PageContext(pageFileContent: pageFileContent, pageNames: pageNames))
                .wait()
            let pageFileName = pageURL.htmlFileName
            let htmlPath = outputDir.appending("/\(pageFileName)")
            let outputFile = URL(fileURLWithPath: htmlPath, isDirectory: false)
            try renderResult.data.write(to: outputFile)
        }
    }
}

extension URL {
    var htmlFileName: String {
        return deletingPathExtension()
            .appendingPathExtension("html").lastPathComponent
            .split(separator: " ")
            .joined(separator: "-")
    }
}
