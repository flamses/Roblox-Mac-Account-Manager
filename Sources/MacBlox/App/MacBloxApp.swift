import SwiftUI
// Avoid the SDK 27 State macro; retain the deployment-compatible property wrapper.
typealias ViewState<Value> = SwiftUI.State<Value>
@main struct MacBloxApp: App {
    init() {
        if ProcessInfo.processInfo.arguments.contains("--tracking-report") {
            let args = ProcessInfo.processInfo.arguments
            let root = args.firstIndex(of: "--tracking-root").flatMap { $0 + 1 < args.count ? URL(fileURLWithPath: args[$0 + 1]) : nil } ?? ManagedClients.root
            for (id, client) in ManagedClients.snapshot(root: root).sorted(by: { $0.key < $1.key }) { print("Account \(id == 0 ? "unassigned" : String(id)): PID \(client.processIdentifier)") }
            exit(0)
        }
        if ProcessInfo.processInfo.arguments.contains("--self-test") {
            do { try SelfChecks.run(); exit(0) } catch { print("FAIL: \(error)"); exit(1) }
        }
    }
    var body: some Scene {
        WindowGroup { ContentView() }
        .windowStyle(.automatic)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}
