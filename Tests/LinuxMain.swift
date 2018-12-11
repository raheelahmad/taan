import XCTest

import mark_swiftTests

var tests = [XCTestCaseEntry]()
tests += mark_swiftTests.allTests()
XCTMain(tests)