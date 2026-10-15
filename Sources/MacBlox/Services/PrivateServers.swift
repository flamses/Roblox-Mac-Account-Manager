import Foundation
struct PrivateInvite: Codable, Equatable {
    enum Kind: String, Codable { case long, share }
    var kind: Kind
    var code: String
    var place: String?
    static func validCode(_ code: String) -> Bool {
        !code.isEmpty && code.count <= 256 && code.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_").contains($0) }
    }
    static func parse(_ input: String) throws -> PrivateInvite? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URLComponents(string: value), let host = url.host else { return nil }
        guard url.scheme == "https", ["www.roblox.com", "roblox.com", "web.roblox.com"].contains(host.lowercased()), url.user == nil, url.password == nil, url.port == nil else { throw Failure("Use an HTTPS private-server link from roblox.com.") }
        let query = url.queryItems ?? []
        func item(_ key: String) throws -> String? {
            let matches = query.filter { $0.name == key }
            guard matches.count <= 1 else { throw Failure("The private invite has duplicate parameters. Copy a fresh link from Roblox.") }
            return matches.first?.value
        }
        if query.contains(where: { $0.name == "privateServerLinkCode" }) {
            guard let code = try item("privateServerLinkCode"), validCode(code) else { throw Failure("The private-server link code is invalid.") }
            return PrivateInvite(kind: .long, code: code, place: try Roblox.placeID(value))
        }
        if ["/share", "/share-links"].contains(url.path) {
            guard try item("type")?.lowercased() == "server", let code = try item("code"), validCode(code) else { throw Failure("Use a Roblox share link with type=Server and a valid code.") }
            return PrivateInvite(kind: .share, code: code)
        }
        return nil
    }
}
enum PrivateServers {
    static func resolve(_ destination: Destination, cookie: String) async throws -> Destination {
        guard let invite = destination.invite else { return destination }
        do {
            var resolved = destination
            if invite.kind == .share {
                let body = try JSONSerialization.data(withJSONObject: ["linkId": invite.code, "linkType": "Server"])
                let endpoint = "https://apis.roblox.com/sharelinks/v1/resolve-link"
                var (data, response) = try await Roblox.request(endpoint, cookie: cookie, method: "POST", body: body)
                if response.statusCode == 403, let csrf = response.value(forHTTPHeaderField: "x-csrf-token") {
                    (data, response) = try await Roblox.request(endpoint, cookie: cookie, method: "POST", csrf: csrf, body: body)
                }
                guard response.statusCode == 200 else { throw Failure("Roblox could not resolve this invite (\(response.statusCode)). It may be expired or unavailable to this account.") }
                let details = try shareDetails(data)
                resolved.place = details.place
                if let access = details.access { resolved.accessCode = access; return resolved }
                guard let link = details.link else { throw Failure("Roblox did not return usable private-server details. Copy a fresh invite.") }
                resolved.invite = PrivateInvite(kind: .long, code: link, place: details.place)
            }
            var page = URLComponents(string: "https://www.roblox.com/games/\(resolved.place)")!
            page.queryItems = [URLQueryItem(name: "privateServerLinkCode", value: resolved.invite!.code)]
            let data = try await loadInvitePage(page.url!, place: resolved.place, code: resolved.invite!.code, cookie: cookie)
            resolved.accessCode = try accessCode(html: String(decoding: data, as: UTF8.self), place: resolved.place)
            return resolved
        } catch let error as Failure { throw error }
        catch { throw Failure("Could not resolve the private invite. Check your connection and try again.") }
    }
    static func loadInvitePage(_ start: URL, place: String, code: String, cookie: String) async throws -> Data {
        var url = start
        var visited = Set<String>()
        for _ in 0..<6 {
            guard visited.insert(url.absoluteString).inserted else { throw Failure("Roblox's invite page entered a redirect loop. Try a fresh invite.") }
            let (data, response) = try await Roblox.request(url.absoluteString, cookie: cookie, accept: "text/html")
            if response.statusCode == 200 { return data }
            if [301, 302, 303, 307, 308].contains(response.statusCode) {
                guard let location = response.value(forHTTPHeaderField: "Location") else { throw Failure("Roblox returned a redirect without a destination.") }
                url = try redirectURL(location, from: url, place: place, code: code)
                continue
            }
            throw Failure("Roblox could not open the private invite (\(response.statusCode)). Check this account's login and server permissions.")
        }
        throw Failure("Roblox redirected the invite too many times. Try again later.")
    }
    static func redirectURL(_ location: String, from current: URL, place: String, code: String) throws -> URL {
        guard let target = URL(string: location, relativeTo: current)?.absoluteURL,
              var parts = URLComponents(url: target, resolvingAgainstBaseURL: true),
              parts.scheme == "https", let host = parts.host,
              ["roblox.com", "www.roblox.com", "web.roblox.com"].contains(host.lowercased()),
              parts.user == nil, parts.password == nil, parts.port == nil || parts.port == 443 else {
            throw Failure("Roblox's invite redirect was blocked because it left trusted Roblox HTTPS pages.")
        }
        let path = target.pathComponents
        if path.contains("login") || path.contains("newLogin") { throw Failure("Roblox redirected this account to login. Sign in again before joining the private server.") }
        guard path.count >= 3, path[1] == "games", path[2] == place else {
            throw Failure("Roblox redirected away from the requested game. The invite may need account verification or renewed access.")
        }
        var query = parts.queryItems ?? []
        let codes = query.filter { $0.name == "privateServerLinkCode" }
        guard codes.isEmpty || (codes.count == 1 && codes[0].value == code) else { throw Failure("Roblox redirected to a different private invite. No game was launched.") }
        if codes.isEmpty { query.append(URLQueryItem(name: "privateServerLinkCode", value: code)) }
        parts.queryItems = query
        guard let result = parts.url else { throw Failure("Roblox returned an invalid invite redirect.") }
        return result
    }
    static func shareDetails(_ data: Data) throws -> (place: String, access: String?, link: String?) {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Failure("Roblox returned an unreadable invite response.") }
        let info = (root["privateServerInviteData"] ?? root["linkData"] ?? root["data"]) as? [String: Any] ?? root
        func text(_ key: String) -> String? { (info[key] as? String) ?? (info[key] as? NSNumber)?.stringValue }
        guard let raw = text("placeId"), let number = UInt64(raw), number > 0 else { throw Failure("Roblox did not return a place ID for this invite.") }
        let access = text("accessCode").flatMap { UUID(uuidString: $0) != nil ? $0 : nil }
        let link = text("linkCode").flatMap { PrivateInvite.validCode($0) ? $0 : nil }
        return (raw, access ?? link.flatMap { UUID(uuidString: $0) != nil ? $0 : nil }, link)
    }
    static func accessCode(html: String, place: String) throws -> String {
        let uuid = "([0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12})"
        let patterns = ["joinPrivateGame\\(\\s*" + NSRegularExpression.escapedPattern(for: place) + "\\s*,\\s*['\"]" + uuid, "[\"']accessCode[\"']\\s*:\\s*[\"']" + uuid, "data-access-code=[\"']" + uuid]
        let legacy = #"(?:RobloxABLaunch|RobloxLaunch)\.RequestPrivateGame\(\s*['"][^'"]*['"]\s*,\s*"# + NSRegularExpression.escapedPattern(for: place) + #"\s*,\s*['"]"# + uuid
        let attribute = #"data-private-server-access-code=['"]"# + uuid
        for pattern in [legacy] + patterns + [attribute] {
            let regex = try NSRegularExpression(pattern: pattern)
            let values = Set(regex.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { match -> String? in
                guard let range = Range(match.range(at: 1), in: html) else { return nil }
                return String(html[range])
            })
            if values.count == 1 { return values.first! }
            if values.count > 1 { throw Failure("Roblox returned ambiguous private-server details. No game was launched; copy a fresh invite.") }
        }
        throw Failure("Roblox did not provide access to this private server for this account. Check invite permissions or copy a fresh link.")
    }
}
