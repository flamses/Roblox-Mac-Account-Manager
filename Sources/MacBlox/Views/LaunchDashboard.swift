import SwiftUI
struct LaunchDashboard: View {
    @ObservedObject var center: ControlCenter
    @ObservedObject var accounts: Accounts
    var selected: [Account]
    @ViewState<String> private var presetName = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Destination") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Launch mode", selection: $center.mode) { ForEach(LaunchMode.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                        if center.mode == .individual {
                            Text("Each selected account uses its saved game or private invite and optional public Job ID from Account setup. Assign the same Job ID to a few alts to form a server group.").foregroundStyle(.secondary)
                        } else {
                            TextField(center.mode == .privateServer ? "Paste Roblox private-server invite link" : "Game link or place ID", text: $center.game).textFieldStyle(.roundedBorder)
                            if center.mode == .sameServer {
                                TextField("Public server Job ID (UUID)", text: $center.server).textFieldStyle(.roundedBorder)
                                HStack {
                                    Button(center.loadingServers ? "Loading…" : "Find public servers") { center.fetchServers() }.disabled(center.loadingServers)
                                    if !center.servers.isEmpty {
                                        Menu("Choose server") {
                                            ForEach(center.servers) { server in
                                                Button("\(server.playing)/\(server.maxPlayers) players · \(server.ping.map { "\($0) ms" } ?? "ping unknown") · \(server.id.prefix(8))") { center.server = server.id }
                                            }
                                        }
                                        Button("Pick room for selection") {
                                            if let server = center.servers.first(where: { $0.free >= selected.filter { !$0.isDemo }.count }) { center.server = server.id }
                                            else { center.log("No listed server has enough free slots. Refresh or try another game.") }
                                        }.disabled(selected.isEmpty)
                                    }
                                }
                                Text("Server availability can change. Full servers or access restrictions can prevent joining. For private invites, choose Private server mode.").font(.caption).foregroundStyle(.secondary)
                            } else if center.mode == .privateServer {
                                Text("Accepts /games/…?privateServerLinkCode=… and /share?code=…&type=Server. Each selected account must be allowed to join. Invites are saved with destination presets; keep them private.").font(.caption).foregroundStyle(.secondary)
                            } else { Text("Roblox chooses a server for each account; use Same public server to target one exact server.").font(.caption).foregroundStyle(.secondary) }
                        }
                    }.padding(8)
                }
                GroupBox("Launch controls") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Button { center.start(selected) } label: { Label("Launch selected (\(selected.filter { !$0.isDemo }.count))", systemImage: "play.fill") }.buttonStyle(.borderedProminent).disabled(center.working || selected.allSatisfy(\.isDemo))
                            Button("Launch all accounts") { center.start(accounts.items) }.disabled(center.working || accounts.items.allSatisfy(\.isDemo))
                            Spacer()
                            if center.working {
                                Button(center.paused ? "Resume" : "Pause queue") { center.paused.toggle() }
                                Button("Stop queue", role: .destructive) { center.stopRequested = true; center.paused = false }
                            }
                        }
                        Toggle("Skip accounts already running", isOn: $center.skipRunning)
                        Toggle("Continue after an account fails", isOn: $center.continueOnError)
                        Toggle("Bring each client to front", isOn: $center.bringToFront)
                        HStack { Text("Extra launch delay"); Slider(value: $center.delay, in: 0...30, step: 1); Text("\(Int(center.delay)) sec").monospacedDigit().frame(width: 55) }
                        Text("Pause and stop take effect after the current launch finishes. Launch options are captured when the queue starts.").font(.caption).foregroundStyle(.secondary)
                    }.padding(8)
                }
                GroupBox("Destination presets") {
                    VStack(alignment: .leading) {
                        HStack { TextField("Preset name", text: $presetName); Button("Save current") { center.savePreset(presetName); presetName = "" }.disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty) }
                        ForEach(center.savedPlans) { preset in
                            HStack { Text(preset.name); Spacer(); Text(preset.mode.rawValue).foregroundStyle(.secondary); Button("Load") { center.load(preset) }; Button("Delete", role: .destructive) { center.savedPlans.removeAll { $0.id == preset.id }; center.savePresets() } }
                        }
                    }.padding(8)
                }
            }.padding(16)
        }
    }
}
