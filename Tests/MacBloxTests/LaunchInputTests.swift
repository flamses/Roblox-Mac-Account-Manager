import XCTest
@testable import MacBlox
final class LaunchInputTests: XCTestCase {
    func testValidDestinations() throws {
        XCTAssertEqual(try Roblox.placeID(" 12345 "), "12345")
        XCTAssertEqual(try Roblox.placeID("https://www.roblox.com/games/12345/Example?x=1"), "12345")
    }
    func testRejectsOtherHostsAndCommands() {
        for input in ["", "0", "https://roblox.com.evil.test/games/123", "https://evil.test/games/123", "roblox-player:launch", "123+gameinfo:bad", "https://www.roblox.com/games/abc", "-12"] {
            XCTAssertThrowsError(try Roblox.placeID(input), input)
        }
    }
}
