import XCTest
@testable import SquirrelTests
@testable import JSONCodingTests
@testable import NutViewTests
@testable import NutViewIntegrationTests

XCTMain([
    testCase(RouteThreeTests.allTests),
    testCase(TokenTests.allTests),
    testCase(NutParserTests.allTests),
    testCase(NutParserErrors.allTests),
    testCase(FruitParserTests.allTests),
    testCase(NutResolverTests.allTests),
    testCase(JSONCodingTests.allTests),
    testCase(JSONTests.allTests)
])
