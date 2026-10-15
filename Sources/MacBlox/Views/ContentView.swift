import SwiftUI
struct ContentView: View {
    @StateObject private var accounts = Accounts.shared
    @StateObject private var center = ControlCenter.shared
    @ViewState<Set<Int64>> private var selection = []
    @ViewState<Bool> private var showLogin = false
    @ViewState<String> private var search = ""
    @ViewState<String> private var group = "All accounts"
    @ViewState<Bool> private var favoritesOnly = false
    @ViewState<Bool> private var confirmRemove = false
    @ViewState<Bool> private var confirmClose = false
    var selected: [Account] { accounts.items.filter { selection.contains($0.id) } }
    var visible: [Account] {
        accounts.items.filter { account in
            let p = center.profile(account.id)
            return (group == "All accounts" || p.group == group) && (!favoritesOnly || p.favorite) && (search.isEmpty || [account.name, account.displayName, p.alias, p.group].contains { $0.localizedCaseInsensitiveContains(search) })
        }.sorted { center.profile($0.id).favorite && !center.profile($1.id).favorite }
    }
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                Picker("Group", selection: $group) {
                    Text("All accounts").tag("All accounts")
                    ForEach(Array(Set(center.profiles.values.map(\.group).filter { !$0.isEmpty })).sorted(), id: \.self) { Text($0).tag($0) }
                }.padding([.horizontal, .top])
                Toggle("Favorites only", isOn: $favoritesOnly).toggleStyle(.checkbox).padding(.horizontal).padding(.vertical, 8)
                List(selection: $selection) {
                    ForEach(visible) { account in
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(center.name(account))
                                Text(center.hideNames ? (center.running[account.id] == nil ? "Offline" : "Client running") : "@\(account.name)\(account.isDemo ? " · Demo" : "")").font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: center.running[account.id] == nil ? "person.crop.circle" : "play.circle.fill").foregroundStyle(center.running[account.id] == nil ? Color.secondary : Color.green) }.tag(account.id)
                    }
                }
                HStack {
                    Button("Select visible") { selection = Set(visible.map(\.id)) }
                    Button("Clear") { selection.removeAll() }
                }.controlSize(.small).padding(8)
                Text("\(selection.count) selected · \(center.running.count) running").font(.caption).foregroundStyle(.secondary).padding(.bottom, 12)
            }.searchable(text: $search).navigationTitle("Accounts").navigationSplitViewColumnWidth(min: 240, ideal: 270)
        } detail: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "square.stack.3d.up.fill").font(.largeTitle).foregroundStyle(.tint)
                    VStack(alignment: .leading) { Text("MacBlox").font(.largeTitle.bold()); Text("Launch together. Organize your alts.").foregroundStyle(.secondary) }
                    Spacer()
                    if center.working { ProgressView().controlSize(.small) }
                }.padding([.horizontal, .top], 22)
                TabView {
                    LaunchDashboard(center: center, accounts: accounts, selected: selected).tabItem { Label("Launch", systemImage: "play.fill") }
                    AccountEditor(center: center, selected: selected).tabItem { Label("Account setup", systemImage: "person.crop.circle") }
                    ClientsView(center: center, accounts: accounts).tabItem { Label("Running", systemImage: "desktopcomputer") }
                    QueueView(center: center).tabItem { Label("Queue & activity", systemImage: "list.bullet.rectangle") }
                    PerformanceView(center: center).tabItem { Label("Performance", systemImage: "speedometer") }
                }.padding(.horizontal, 16)
                Label(center.hideNames ? "Names and activity hidden. \(center.running.count) managed client(s) running." : center.notice, systemImage: "info.circle").font(.callout).textSelection(.enabled).lineLimit(3).padding(.horizontal, 22).padding(.bottom, 16)
            }
        }.frame(minWidth: 1080, minHeight: 720)
        .toolbar {
            Button { showLogin = true } label: { Label("Add account", systemImage: "person.badge.plus") }.disabled(center.working).keyboardShortcut("n")
            Button("Demo alt") { selection = [accounts.addDemo()] }
            Toggle(isOn: $center.hideNames) { Label("Hide names", systemImage: "eye.slash") }
            Menu {
                Button("Launch selected") { center.start(selected) }.disabled(center.working || selected.isEmpty)
                Button("Close selected clients") { confirmClose = true }.disabled(center.working || selection.isEmpty)
                Divider()
                Button("Remove selected accounts", role: .destructive) { confirmRemove = true }.disabled(center.working || selection.isEmpty)
            } label: { Label("Actions", systemImage: "ellipsis.circle") }
        }
        .sheet(isPresented: $showLogin) { LoginView(accounts: accounts) }
        .confirmationDialog("Remove selected accounts from MacBlox?", isPresented: $confirmRemove) {
            Button("Remove accounts", role: .destructive) { for account in selected { accounts.remove(account) }; selection.removeAll() }
        }
        .confirmationDialog("Close selected Roblox clients?", isPresented: $confirmClose) {
            Button("Close clients", role: .destructive) { center.close(selection) }
        }
        .onChange(of: accounts.message) { _, text in center.log(text) }
        .task {
            if ProcessInfo.processInfo.arguments.contains("--demo") { for _ in 0..<3 { selection.insert(accounts.addDemo()) } }
            while !Task.isCancelled { center.refresh(); try? await Task.sleep(for: .seconds(2)) }
        }
    }
}
