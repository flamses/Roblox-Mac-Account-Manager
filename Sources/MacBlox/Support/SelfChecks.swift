import Foundation
enum SelfChecks {
    @MainActor static func run() throws {
        let job = "12345678-1234-1234-1234-123456789abc"
        let same = try Destination(game: "https://www.roblox.com/games/142823291/Murder-Mystery-2", server: job)
        let params = URLComponents(url: same.launcherURL, resolvingAgainstBaseURL: false)!.queryItems!
        precondition(params.contains(URLQueryItem(name: "request", value: "RequestGameJob")))
        precondition(params.contains(URLQueryItem(name: "gameId", value: job)))
        precondition(params.contains(URLQueryItem(name: "placeId", value: "142823291")))
        let random = try Destination(game: "123")
        precondition(!random.launcherURL.absoluteString.contains("gameId="))
        for bad in ["https://roblox.com.evil.test/games/123", "0", "000", "12+gameinfo:bad"] {
            do { _ = try Destination(game: bad); preconditionFailure("Invalid destination accepted") } catch {}
        }
        do { _ = try Destination(game: "123", server: "private-link"); preconditionFailure("Invalid Job ID accepted") } catch {}
        let xml = "<settings><int name=\"FramerateCap\">-1</int><int name=\"Other\">99</int></settings>"
        let updated = try PerformanceSettings.replacingCap(in: xml, cap: 144)
        precondition(updated == "<settings><int name=\"FramerateCap\">144</int><int name=\"Other\">99</int></settings>")
        do { _ = try PerformanceSettings.replacingCap(in: "<settings/>", cap: 60); preconditionFailure("Unknown format accepted") } catch {}
        do { _ = try PerformanceSettings.replacingCap(in: xml, cap: 999); preconditionFailure("Invalid FPS accepted") } catch {}
        let profile = AltProfile(alias: "Test", group: "Squad", favorite: true, game: "123", server: job, notes: "Testing")
        let restored = try JSONDecoder().decode(AltProfile.self, from: JSONEncoder().encode(profile))
        precondition(restored.group == "Squad" && restored.server == job && restored.favorite)
        let clientRoot = URL(fileURLWithPath: "/tmp/test-clients")
        precondition(ManagedClients.accountID(executable: "/tmp/test-clients/111.app/Contents/MacOS/RobloxPlayer", root: clientRoot) == 111)
        precondition(ManagedClients.accountID(executable: "/tmp/test-clients/222.app/Contents/MacOS/RobloxPlayer", root: clientRoot) == 222)
        for path in ["/Applications/Roblox.app/Contents/MacOS/RobloxPlayer", "/tmp/test-clients-other/111.app/Contents/MacOS/RobloxPlayer", "/tmp/test-clients/111.app/Contents/MacOS/Helper", "/tmp/test-clients/111.app/../222.app/Contents/MacOS/Helper"] {
            precondition(ManagedClients.accountID(executable: path, root: clientRoot) == nil)
        }
        precondition(ManagedClients.accountID(executable: "/tmp/test-clients/222/Roblox.app/Contents/MacOS/RobloxPlayer", root: clientRoot) == 222)
        precondition(ManagedClients.accountID(executable: "/tmp/test-clients/Roblox.app/Contents/MacOS/RobloxPlayer", root: clientRoot) == 0)
        precondition(ManagedClients.executablePath(getpid()) != nil)
        print("PASS: process identity/path isolation and kernel PID lookup; destination routing, Job ID validation, FPS edit preservation, profile round-trip. No accounts or Roblox settings accessed.")
    }
}
