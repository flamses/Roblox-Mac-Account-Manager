import SwiftUI
struct ClientsView: View {
    @ObservedObject var center: ControlCenter
    @ObservedObject var accounts: Accounts
    @ViewState<Bool> private var confirm = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("\(center.running.count) managed clients").font(.title2.bold()); Spacer(); Button("Refresh") { center.refresh() }; Button("Close all managed", role: .destructive) { confirm = true }.disabled(center.running.isEmpty || center.working) }
            Text("Only clients launched by MacBlox are listed. Status refreshes every two seconds; an open client does not confirm an in-game connection.").font(.caption).foregroundStyle(.secondary)
            List(Array(center.running.keys).sorted(), id: \.self) { id in
                HStack {
                    Image(systemName: "circle.fill").foregroundStyle(.green).font(.caption)
                    Text(accounts.items.first(where: { $0.id == id }).map { center.name($0) } ?? (id == 0 ? "Unassigned client — relaunch to identify" : "Managed account"))
                    Spacer()
                    Text("PID \(center.running[id]?.processIdentifier ?? 0)").monospacedDigit().foregroundStyle(.secondary)
                    Button("Focus") { center.focus(id) }.disabled(center.running[id]?.canFocus != true)
                    Button("Close", role: .destructive) { center.close([id]) }.disabled(center.working)
                }
            }.overlay { if center.running.isEmpty { ContentUnavailableView("No managed clients running", systemImage: "desktopcomputer") } }
        }.padding(20)
        .confirmationDialog("Close every MacBlox-managed Roblox client?", isPresented: $confirm) { Button("Close all managed clients", role: .destructive) { center.close(Set(center.running.keys)) } }
    }
}
struct QueueView: View {
    @ObservedObject var center: ControlCenter
    var body: some View {
        VSplitView {
            VStack(alignment: .leading) {
                Text("Launch queue").font(.headline)
                List(center.queue) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack { Text(center.hideNames ? "Account" : row.name); Spacer(); Text(row.destination.invite != nil ? "Private server" : "Place \(row.destination.place)").foregroundStyle(.secondary); Text(row.status).font(.caption.bold()) }
                        if let failure = row.failure, !center.hideNames { Text(failure).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
                    }
                }.overlay { if center.queue.isEmpty { Text("Your next launch plan appears here.").foregroundStyle(.secondary) } }
            }.frame(minHeight: 150)
            VStack(alignment: .leading) {
                HStack { Text("Activity").font(.headline); Spacer(); Button("Clear") { center.activity.removeAll() } }
                List(center.activity) { entry in HStack(alignment: .top) { Text(entry.date, style: .time).monospacedDigit().foregroundStyle(.secondary); Text(center.hideNames ? "Activity hidden while Hide names is enabled." : entry.text).textSelection(.enabled) } }
            }.frame(minHeight: 160)
        }.padding(20)
    }
}
