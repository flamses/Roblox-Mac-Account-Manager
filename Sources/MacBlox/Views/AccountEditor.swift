import SwiftUI
struct AccountEditor: View {
    @ObservedObject var center: ControlCenter
    var selected: [Account]
    @ViewState<String> private var bulkGroup = ""
    @ViewState<String> private var bulkGame = ""
    @ViewState<String> private var bulkServer = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if center.hideNames { ContentUnavailableView("Account details hidden", systemImage: "eye.slash", description: Text("Turn off Hide names to edit aliases, groups, notes, and destinations.")) }
                else if selected.isEmpty { ContentUnavailableView("Select accounts", systemImage: "person.2", description: Text("Use Command-click to select several alts in the sidebar.")) }
                else if selected.count == 1, let account = selected.first {
                    SingleAccountEditor(profile: center.binding(account.id), label: center.name(account))
                } else {
                    Text("Edit \(selected.count) accounts together").font(.title2.bold())
                    TextField("Group name", text: $bulkGroup)
                    Button("Assign group to selection") { for account in selected { var p = center.profile(account.id); p.group = bulkGroup; center.profiles[String(account.id)] = p } }
                    TextField("Game link, place ID, or private-server invite", text: $bulkGame)
                    TextField("Optional public server Job ID", text: $bulkServer)
                    Button("Assign destination to selection") {
                        do {
                            _ = try Destination(game: bulkGame, server: bulkServer)
                            for account in selected { var p = center.profile(account.id); p.game = bulkGame; p.server = bulkServer; center.profiles[String(account.id)] = p }
                            center.log("Assigned destination to \(selected.count) accounts.")
                        } catch { center.log(error.localizedDescription) }
                    }
                    HStack {
                        Button("Favorite selection") { favorite(true) }
                        Button("Unfavorite selection") { favorite(false) }
                    }
                    Text("Assign a game and server to this selection, then choose a different selection and assign another destination. Launch using Per-account destinations.").foregroundStyle(.secondary)
                }
            }.textFieldStyle(.roundedBorder).padding(24)
        }
    }
    func favorite(_ value: Bool) { for account in selected { var p = center.profile(account.id); p.favorite = value; center.profiles[String(account.id)] = p } }
}
private struct SingleAccountEditor: View {
    @Binding var profile: AltProfile
    var label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(label).font(.title2.bold())
            Text("Changes save automatically on this Mac.").font(.caption).foregroundStyle(.secondary)
            TextField("Display alias", text: $profile.alias)
            TextField("Group name (e.g. Trading, Farming, Testing)", text: $profile.group)
            Toggle("Favorite account", isOn: $profile.favorite)
            Divider()
            Text("Per-account destination").font(.headline)
            TextField("Game link, place ID, or private-server invite", text: $profile.game)
            TextField("Optional public server Job ID", text: $profile.server)
            Text("Leave Job ID blank for private invites or automatic public matchmaking. These fields are used in Per-account destinations mode.").font(.caption).foregroundStyle(.secondary)
            Text("Notes").font(.headline)
            TextEditor(text: $profile.notes).frame(minHeight: 100).border(.quaternary)
        }
    }
}
