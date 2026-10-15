import Foundation
import Darwin
import AppKit

enum Roblox {
    static func request(_ url: String, cookie: String, method: String = "GET", csrf: String? = nil, body: Data? = nil, accept: String = "application/json") async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        request.setValue(accept, forHTTPHeaderField: "Accept")
        if method == "POST" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body ?? Data("{}".utf8)
        }
        request.setValue(".ROBLOSECURITY=\(cookie)", forHTTPHeaderField: "Cookie")
        request.setValue("https://www.roblox.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.roblox.com/", forHTTPHeaderField: "Referer")
        if let csrf { request.setValue(csrf, forHTTPHeaderField: "x-csrf-token") }
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        let session = URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw Failure("Roblox returned an invalid response.") }
        return (data, response)
    }
    static func account(cookie: String) async throws -> Account {
        let (data, response) = try await request("https://users.roblox.com/v1/users/authenticated", cookie: cookie)
        guard response.statusCode == 200 else { throw Failure("Login expired or unavailable. Sign in again (\(response.statusCode)).") }
        struct User: Decodable { let id: Int64; let name: String; let displayName: String }
        let user = try JSONDecoder().decode(User.self, from: data)
        return Account(id: user.id, name: user.name, displayName: user.displayName, cookie: cookie)
    }
    static func ticket(cookie: String) async throws -> String {
        let endpoint = "https://auth.roblox.com/v1/authentication-ticket/"
        var (_, response) = try await request(endpoint, cookie: cookie, method: "POST")
        if response.statusCode == 403, let csrf = response.value(forHTTPHeaderField: "x-csrf-token") {
            (_, response) = try await request(endpoint, cookie: cookie, method: "POST", csrf: csrf)
        }
        guard response.statusCode == 200, let ticket = response.value(forHTTPHeaderField: "rbx-authentication-ticket"), !ticket.isEmpty else {
            switch response.statusCode {
            case 401: throw Failure("Roblox login expired (401). Sign in again to refresh this account.")
            case 403: throw Failure("Roblox denied the launch request (403). Your session may need verification; try signing in again.")
            case 415: throw Failure("Roblox rejected the launch request format (415). Update MacBlox; signing in again will not fix this format error.")
            case 429: throw Failure("Roblox is rate limiting launch requests (429). Wait a minute and retry.")
            default: throw Failure("Roblox could not issue a launch ticket (\(response.statusCode)). Try again later.")
            }
        }
        return ticket
    }
    static func placeID(_ input: String) throws -> String {
        let input = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !input.isEmpty, input.allSatisfy(\.isNumber), let number = UInt64(input), number > 0 { return input }
        if let url = URL(string: input), url.scheme == "https", let host = url.host, host == "roblox.com" || host.hasSuffix(".roblox.com") {
            let parts = url.pathComponents
            if let index = parts.firstIndex(of: "games"), parts.count > index + 1 { return try placeID(parts[index + 1]) }
        }
        throw Failure("Enter a numeric place ID or a Roblox /games/ URL.")
    }
}
final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

actor Launcher {
    static let shared = Launcher()
    private var launching = false
    private var clients: [Int64: ManagedProcess] = [:]
    func launch(account: Account, destination: Destination, activate: Bool = true) async throws {
        guard !account.isDemo else { throw Failure("Demo accounts cannot connect to Roblox.") }
        guard !launching else { throw Failure("Another launch is in progress. Please wait.") }
        launching = true
        defer { launching = false }
        if clients[account.id].map({  $0.isStillManaged }) == true { throw Failure("This account already has a running client.") }
        let bundleID = "com.roblox.MacBlox.account\(account.id)"
        let alreadyRunning = await MainActor.run {
            ManagedClients.snapshot()[account.id] != nil
        }
        guard !alreadyRunning else { throw Failure("This account already has an open Roblox client.") }
        let source = URL(fileURLWithPath: "/Applications/Roblox.app")
        guard FileManager.default.fileExists(atPath: source.path) else { throw Failure("Install Roblox in /Applications first.") }
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MacBlox/Clients", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let accountFolder = root.appendingPathComponent(String(account.id), isDirectory: true)
        try FileManager.default.createDirectory(at: accountFolder, withIntermediateDirectories: true)
        let clone = accountFolder.appendingPathComponent("Roblox.app")
        // Refresh the copy for each launch so Roblox updates are picked up.
        if FileManager.default.fileExists(atPath: clone.path) { try FileManager.default.removeItem(at: clone) }
        try run("/bin/cp", ["-cR", source.path, clone.path])
        let plist = clone.appendingPathComponent("Contents/Info.plist")
        var info = try PropertyListSerialization.propertyList(from: Data(contentsOf: plist), format: nil) as! [String: Any]
        info["LSMultipleInstancesProhibited"] = false
        info["CFBundleIdentifier"] = bundleID
        info["CFBundleName"] = "Roblox · \(account.name)"
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: plist)
        try run("/usr/bin/xattr", ["-cr", clone.path])
        try run("/usr/bin/codesign", ["--force", "--sign", "-", "--preserve-metadata=entitlements", clone.path])
        clients = clients.filter { $0.value.isStillManaged }
        let resolved = try await PrivateServers.resolve(destination, cookie: account.cookie)
        let ticket = try await Roblox.ticket(cookie: account.cookie)
        let join = resolved.launcherURL
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&:#%")
        let encoded = join.absoluteString.addingPercentEncoding(withAllowedCharacters: allowed)!
        let uri = "roblox-player:1+launchmode:play+gameinfo:\(ticket)+launchtime:\(Int64(Date().timeIntervalSince1970 * 1000))+placelauncherurl:\(encoded)+browsertrackerid:\(UInt64.random(in: 100000000...999999999))+robloxLocale:en_us+gameLocale:en_us+channel:"
        // Existing clients keep their semaphore handle; each new process gets a new named semaphore.
        if sem_unlink("/RobloxPlayerUniq") != 0 && errno != ENOENT { throw Failure("Could not prepare multiple clients (\(errno)).") }
        guard let url = URL(string: uri) else { throw Failure("Could not construct Roblox launch URL.") }
        _ = try await Self.openClient(at: clone, url: url, activate: activate)
        // The updater may replace/restart the original process. Follow the account folder,
        // allowing a stable replacement process to finish before the next account starts.
        let deadline = Date().addingTimeInterval(60)
        var stablePID: pid_t?
        var stableSince = Date()
        while Date() < deadline {
            let current = await MainActor.run { ManagedClients.snapshot()[account.id] }
            if let current {
                if stablePID != current.processIdentifier { stablePID = current.processIdentifier; stableSince = Date() }
                let ready = await MainActor.run { NSRunningApplication(processIdentifier: current.processIdentifier)?.isFinishedLaunching == true }
                if ready && Date().timeIntervalSince(stableSince) >= 8 {
                    clients[account.id] = current
                    return
                }
            } else { stablePID = nil; stableSince = Date() }
            try await Task.sleep(for: .milliseconds(250))
        }
        throw Failure("Roblox did not settle within 60 seconds. It may still be updating; check Running before retrying.")
    }
    @MainActor private static func openClient(at app: URL, url: URL, activate: Bool) async throws -> NSRunningApplication {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.activates = activate
        return try await NSWorkspace.shared.open([url], withApplicationAt: app, configuration: configuration)
    }
    private func run(_ path: String, _ args: [String]) throws {
        let process = Process(); process.executableURL = URL(fileURLWithPath: path); process.arguments = args
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw Failure("\(URL(fileURLWithPath: path).lastPathComponent) failed (\(process.terminationStatus)).") }
    }
}
