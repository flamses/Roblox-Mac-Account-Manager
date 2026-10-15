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
        let privateLink = "https://www.roblox.com/games/123/Test?privateServerLinkCode=123456789012345678901234567890"
        var privateTarget = try Destination(game: privateLink)
        precondition(privateTarget.invite?.kind == .long && privateTarget.place == "123")
        privateTarget.accessCode = job
        let privateParams = URLComponents(url: privateTarget.launcherURL, resolvingAgainstBaseURL: false)!.queryItems!
        precondition(privateParams.contains(URLQueryItem(name: "request", value: "RequestPrivateGame")))
        precondition(privateParams.contains(URLQueryItem(name: "accessCode", value: job)))
        precondition(privateParams.contains(URLQueryItem(name: "linkCode", value: "123456789012345678901234567890")))
        let share = try Destination(game: "https://www.roblox.com/share?code=abcdef1234567890&type=Server")
        precondition(share.invite?.kind == .share)
        for bad in ["https://www.roblox.com/games/123?privateServerLinkCode", "https://www.roblox.com/games/123?privateServerLinkCode=", "https://roblox.com.evil.test/share?code=abc&type=Server", "https://www.roblox.com/share?code=abc&type=Experience", "https://www.roblox.com/share?code=abc&code=def&type=Server", "https://www.roblox.com/games/123?privateServerLinkCode=bad%2Bcode"] {
            do { _ = try Destination(game: bad); preconditionFailure("Invalid invite accepted") } catch {}
        }
        do { _ = try Destination(game: privateLink, server: job); preconditionFailure("Mixed public/private target accepted") } catch {}
        let inviteJSON = try JSONSerialization.data(withJSONObject: ["privateServerInviteData": ["placeId": 123, "linkCode": "123456789012345678901234567890"]])
        let details = try PrivateServers.shareDetails(inviteJSON)
        precondition(details.place == "123" && details.link == "123456789012345678901234567890")
        let code = try PrivateServers.accessCode(html: "Roblox.GameLauncher.joinPrivateGame(123, '\(job)')", place: "123")
        precondition(code == job)
        let legacyCode = try PrivateServers.accessCode(html: "RobloxLaunch.RequestPrivateGame('PlaceLauncherStatusPanel', 123, '\(job)', null, '1234')", place: "123")
        precondition(legacyCode == job)
        do { _ = try PrivateServers.accessCode(html: "<p>Access denied</p>", place: "123"); preconditionFailure("Denied invite accepted") } catch {}
        do { _ = try PrivateServers.accessCode(html: "\"accessCode\":\"\(job)\",\"accessCode\":\"87654321-4321-4321-4321-cba987654321\"", place: "123"); preconditionFailure("Ambiguous private server accepted") } catch {}
        let legacyDestination = try JSONDecoder().decode(Destination.self, from: Data(#"{"place":"123","server":""}"#.utf8))
        precondition(legacyDestination.invite == nil)
        let redirectStart = URL(string: "https://www.roblox.com/games/123?privateServerLinkCode=12345678")!
        let canonical = try PrivateServers.redirectURL("/games/123/Test?privateServerLinkCode=12345678", from: redirectStart, place: "123", code: "12345678")
        precondition(canonical.path == "/games/123/Test")
        let restoredInvite = try PrivateServers.redirectURL("https://web.roblox.com/games/123/Test", from: redirectStart, place: "123", code: "12345678")
        precondition(restoredInvite.query?.contains("privateServerLinkCode=12345678") == true)
        for target in ["https://evil.test/games/123", "https://www.roblox.com.evil.test/games/123", "http://www.roblox.com/games/123", "https://www.roblox.com/login", "/games/999/Test", "/games/123/Test?privateServerLinkCode=different", "https://name:pass@www.roblox.com/games/123"] {
            do { _ = try PrivateServers.redirectURL(target, from: redirectStart, place: "123", code: "12345678"); preconditionFailure("Unsafe or mismatched redirect accepted") } catch {}
        }
        print("PASS: canonical invite redirects, invite preservation, redirect credential isolation; private invite parsing, private launch routing, share response parsing, denied access handling, saved-data compatibility; process identity/path isolation and kernel PID lookup; destination routing, Job ID validation, FPS edit preservation, profile round-trip. No accounts or Roblox settings accessed.")
    }
}
