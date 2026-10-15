import Foundation
struct AltProfile: Codable {
    var alias = ""
    var group = ""
    var favorite = false
    var game = ""
    var server = ""
    var notes = ""
}
enum LaunchMode: String, CaseIterable, Codable {
    case sameGame = "Same game", sameServer = "Same public server", privateServer = "Private server", individual = "Per-account destinations"
}
struct Destination: Codable, Equatable {
    var place: String
    var server: String = ""
    var invite: PrivateInvite?
    var accessCode: String?
    init(game: String, server: String = "") throws {
        if let parsed = try PrivateInvite.parse(game) {
            guard server.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Failure("Private links cannot be combined with a public server Job ID.") }
            place = parsed.place ?? "0"
            invite = parsed
            return
        }
        place = try Roblox.placeID(game)
        self.server = server.trimmingCharacters(in: .whitespacesAndNewlines)
        if !self.server.isEmpty && UUID(uuidString: self.server) == nil { throw Failure("Server ID must be a full Job ID (UUID), not a private-server link.") }
    }
    var launcherURL: URL {
        var url = URLComponents(string: "https://assetgame.roblox.com/game/PlaceLauncher.ashx")!
        url.queryItems = [URLQueryItem(name: "request", value: invite != nil ? "RequestPrivateGame" : (server.isEmpty ? "RequestGame" : "RequestGameJob")), URLQueryItem(name: "placeId", value: place), URLQueryItem(name: "isPlayTogetherGame", value: "false")]
        if !server.isEmpty { url.queryItems!.append(URLQueryItem(name: "gameId", value: server)) }
        if let accessCode { url.queryItems!.append(URLQueryItem(name: "accessCode", value: accessCode)) }
        if let invite, invite.kind == .long { url.queryItems!.append(URLQueryItem(name: "linkCode", value: invite.code)) }
        return url.url!
    }
}
struct PublicServer: Decodable, Identifiable {
    var id: String
    var maxPlayers: Int
    var playing: Int
    var ping: Int?
    var free: Int { maxPlayers - playing }
}
struct QueueRow: Identifiable {
    var id = UUID()
    var accountID: Int64
    var name: String
    var destination: Destination
    var status = "Waiting"
}
struct ActivityEntry: Identifiable {
    var id = UUID()
    var date = Date()
    var text: String
}
