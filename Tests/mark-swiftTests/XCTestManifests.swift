import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(mark_swiftTests.allTests),
    ]
}
#endif