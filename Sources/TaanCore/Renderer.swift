import Foundation

import Down
import Leaf

typealias Path = String

struct Page: Codable {
    let name: String
}

public class Renderer {
    struct BaseContext: Codable {
        let pageNames: [String]
        let siteTitle: String
    }

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
    }

    private func baseContext() throws -> BaseContext {
        return BaseContext(
            pageNames: try pageNames(),
            siteTitle: config.siteSettings.title
        )
    }

    /// Sets up the renderer
    private func setup() throws {
        if FileManager.default.fileExists(atPath: outputDir) {
            try FileManager.default.removeItem(atPath: outputDir)
        }
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: outputDir, isDirectory: true),
            withIntermediateDirectories: false, attributes: nil
        )
        if !FileManager.default.fileExists(atPath: outputBlogDir) {
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: outputBlogDir, isDirectory: true),
                withIntermediateDirectories: false, attributes: nil
            )
        }
    }

    private var outputDir: String {
        return config.output
    }

    private var outputBlogDir: String {
        return outputDir.appending("/blog")
    }

    private var contentDir: String {
        return topLevelDir(named: "Content")
    }

    private var viewsDir: String {
        return topLevelDir(named: "Views")
    }

    private var blogURL: URL {
        return URL(fileURLWithPath: contentDir).appendingPathComponent("blog", isDirectory: true)
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
        var allNames = try pagePaths()
            .map { $0.deletingPathExtension().lastPathComponent }
            + ["blog"]
        if let indexIndex = allNames.firstIndex(of: "index") {
            allNames.remove(at: indexIndex)
            allNames.insert("index", at: 0)
        }
        return allNames
    }


    public func render() throws {
        let start = Date()
        try setup()
        try copyStatic()
        try renderPages()
        try renderPosts()
        try renderBlogIndex()
        let end = Date()
        let interval = end.timeIntervalSince(start) * 1000
        print("rendered in \(Int(interval)) ms.")
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
        let pages = try self.pageNames()
            .map { Page(name: $0) }
        for pageURL in try postPaths() {
            let pageFileContent = try String(contentsOf: pageURL)
            let (frontMatter, body) = try PostFrontMatter.readFrontMatter(fileContent: pageFileContent)
            guard !frontMatter.draft else {
                continue
            }
            let context = try PostContext(
                title: frontMatter.title,
                date: frontMatter.dateString,
                body: body,
                pages: pages
            )
            let renderResult = try templateRenderer
                .render(pageTemplate, context)
                .wait()
            let pageFileName = pageURL.htmlFileName
            let htmlPath = outputBlogDir.appending("/\(pageFileName)")
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
            let pages = pageNames.map { Page(name: $0) }
            let renderResult = try templateRenderer
                .render(pageTemplate, PageContext(pageFileContent: pageFileContent, pages: pages))
                .wait()
            let pageFileName = pageURL.htmlFileName
            let htmlPath = outputDir.appending("/\(pageFileName)")
            let outputFile = URL(fileURLWithPath: htmlPath, isDirectory: false)
            try renderResult.data.write(to: outputFile)
        }
    }

    private func renderBlogIndex() throws {
        struct BlogPageContext: Codable {
            let title: String
            let path: String
            let date: String
        }
        struct BlogContext: Codable {
            let title: String
            let posts: [BlogPageContext]
            let pages: [Page]
        }

        let indexTemplate = templatePath(named: "blog")
        let posts = try postPaths()
            .compactMap { pageURL -> BlogPageContext? in
                let pageFileContent = try String(contentsOf: pageURL)
                let (frontMatter, _) = try PostFrontMatter.readFrontMatter(fileContent: pageFileContent)
                guard !frontMatter.draft else {
                    return nil
                }
                let pageFileName = pageURL.htmlFileName
                return BlogPageContext(title: frontMatter.title, path: "/blog/\(pageFileName)", date: frontMatter.dateString)
            }

        let blogTitle = config.siteSettings.blogTitle
        let pages = try pageNames().map { Page(name: $0)}
        let context = BlogContext(title: blogTitle, posts: posts, pages: pages)
        let renderResult = try templateRenderer
            .render(indexTemplate, context)
            .wait()
        let htmlPath = outputBlogDir.appending("/index.html")
        let outputFile = URL(fileURLWithPath: htmlPath, isDirectory: false)
        try renderResult.data.write(to: outputFile)
    }
}

extension URL {
    var fileName: String {
        return deletingPathExtension()
            .lastPathComponent
    }
    var htmlFileName: String {
        return deletingPathExtension()
            .appendingPathExtension("html").lastPathComponent
            .split(separator: " ")
            .joined(separator: "-")
    }
}
