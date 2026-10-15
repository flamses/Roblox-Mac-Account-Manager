import SwiftUI
import AppKit
@MainActor final class ControlCenter: ObservableObject {
    static let shared = ControlCenter()
    @Published var profiles: [String: AltProfile] = [:] { didSet { persist() } }
    @Published var mode: LaunchMode = .sameGame
    @Published var game = ""
    @Published var server = ""
    @Published var delay = 3.0 { didSet { UserDefaults.standard.set(delay, forKey: "delay") } }
    @Published var skipRunning = true { didSet { UserDefaults.standard.set(skipRunning, forKey: "skipRunning") } }
    @Published var continueOnError = false { didSet { UserDefaults.standard.set(continueOnError, forKey: "continueOnError") } }
    @Published var bringToFront = true { didSet { UserDefaults.standard.set(bringToFront, forKey: "bringToFront") } }
    @Published var hideNames = false
    @Published var paused = false
    @Published var stopRequested = false
    @Published var working = false
    @Published var queue: [QueueRow] = []
    @Published var activity: [ActivityEntry] = []
    @Published var running: [Int64: ManagedProcess] = [:]
    @Published var servers: [PublicServer] = []
    @Published var loadingServers = false
    @Published var notice = "Ready. Select accounts in the sidebar using Command-click or Shift-click."
    @Published var savedPlans: [SavedPlan] = []
    private let defaults = UserDefaults.standard
    struct SavedPlan: Codable, Identifiable {
        var id = UUID()
        var name: String
        var mode: LaunchMode
        var game: String
        var server: String
    }
    init() {
        if let data = defaults.data(forKey: "altProfiles"), let value = try? JSONDecoder().decode([String: AltProfile].self, from: data) { profiles = value }
        if let data = defaults.data(forKey: "launchPresets"), let value = try? JSONDecoder().decode([SavedPlan].self, from: data) { savedPlans = value }
        game = defaults.string(forKey: "place") ?? ""
        if defaults.object(forKey: "delay") != nil { delay = min(30, max(0, defaults.double(forKey: "delay"))) }
        if defaults.object(forKey: "skipRunning") != nil { skipRunning = defaults.bool(forKey: "skipRunning") }
        if defaults.object(forKey: "continueOnError") != nil { continueOnError = defaults.bool(forKey: "continueOnError") }
        if defaults.object(forKey: "bringToFront") != nil { bringToFront = defaults.bool(forKey: "bringToFront") }
    }
    func profile(_ id: Int64) -> AltProfile { profiles[String(id)] ?? AltProfile() }
    func binding(_ id: Int64) -> Binding<AltProfile> {
        Binding(get: { self.profile(id) }, set: { self.profiles[String(id)] = $0 })
    }
    func persist() { if let data = try? JSONEncoder().encode(profiles) { defaults.set(data, forKey: "altProfiles") } }
    func log(_ text: String) {
        notice = text
        activity.insert(ActivityEntry(text: text), at: 0)
        activity = Array(activity.prefix(200))
    }
    func name(_ account: Account) -> String {
        if hideNames { return "Account \(Accounts.shared.items.firstIndex(where: { $0.id == account.id }).map { $0 + 1 } ?? 0)" }
        let alias = profile(account.id).alias
        return alias.isEmpty ? account.displayName : alias
    }
    func refresh() { running = ManagedClients.snapshot() }
    func focus(_ id: Int64) { running[id]?.focus() }
    func close(_ ids: Set<Int64>) {
        for id in ids { running[id]?.terminate() }
        log("Requested close for \(ids.count) managed client(s).")
    }
    func savePreset(_ name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        savedPlans.append(SavedPlan(name: name, mode: mode, game: game, server: server))
        savePresets()
    }
    func savePresets() { if let data = try? JSONEncoder().encode(savedPlans) { defaults.set(data, forKey: "launchPresets") } }
    func load(_ preset: SavedPlan) { mode = preset.mode; game = preset.game; server = preset.server }
    func fetchServers() {
        guard !loadingServers else { return }
        loadingServers = true
        Task {
            defer { loadingServers = false }
            do {
                let place = try Roblox.placeID(game)
                let url = URL(string: "https://games.roblox.com/v1/games/\(place)/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100")!
                let (data, response) = try await URLSession.shared.data(from: url)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw Failure("Could not load public servers. Roblox may be rate limiting requests.") }
                struct Page: Decodable { var data: [PublicServer] }
                servers = try JSONDecoder().decode(Page.self, from: data).data.filter { $0.free > 0 }
                log("Loaded \(servers.count) available public servers (first page).")
            } catch { log(error.localizedDescription) }
        }
    }
    func start(_ accounts: [Account]) {
        guard !working else { return }
        refresh()
        do {
            let eligible = accounts.filter { !$0.isDemo && (!skipRunning || running[$0.id] == nil) }
            guard !eligible.isEmpty else { throw Failure("No launchable accounts. Demo accounts and already-running accounts are skipped.") }
            var rows: [QueueRow] = []
            for account in eligible {
                let p = profile(account.id)
                let destination: Destination
                if mode == .individual { destination = try Destination(game: p.game, server: p.server) }
                else {
                    if mode == .sameServer && server.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw Failure("Choose a public server or paste its Job ID to keep the selection together.") }
                    destination = try Destination(game: game, server: mode == .sameServer ? server : "")
                }
                rows.append(QueueRow(accountID: account.id, name: name(account), destination: destination))
            }
            queue = rows
            defaults.set(game, forKey: "place")
            working = true; paused = false; stopRequested = false
            Accounts.shared.busy = true
            let snapshot = Dictionary(uniqueKeysWithValues: eligible.map { ($0.id, $0) })
            let launchDelay = delay, allowErrors = continueOnError, activate = bringToFront
            Task {
                defer { working = false; Accounts.shared.busy = false; paused = false; refresh() }
                for index in queue.indices {
                    while paused && !stopRequested { try? await Task.sleep(for: .milliseconds(200)) }
                    if stopRequested { break }
                    guard let account = snapshot[queue[index].accountID] else { continue }
                    queue[index].status = "Starting"
                    log("Starting \(queue[index].name)…")
                    do {
                        try await Launcher.shared.launch(account: account, destination: queue[index].destination, activate: activate)
                        queue[index].status = "Client open"
                        log("Opened \(queue[index].name).")
                    } catch {
                        queue[index].status = "Failed"
                        log("\(queue[index].name): \(error.localizedDescription)")
                        if !allowErrors { stopRequested = true }
                    }
                    refresh()
                    if index < queue.count - 1 && !stopRequested { try? await Task.sleep(for: .seconds(launchDelay)) }
                }
                for index in queue.indices where queue[index].status == "Waiting" { queue[index].status = "Cancelled" }
                if stopRequested { log("Queue stopped. Existing clients were left open.") }
                else { log("Queue finished. \(queue.filter { $0.status == "Client open" }.count) client(s) opened.") }
            }
        } catch { log(error.localizedDescription) }
    }
}
