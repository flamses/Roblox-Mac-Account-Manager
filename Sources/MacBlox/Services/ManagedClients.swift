import Foundation
import AppKit
import Darwin

enum ManagedClients {
    static var root: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MacBlox/Clients", isDirectory: true)
    }
    // Match the actual executable path, never Launch Services' cached bundle identifier.
    static func accountID(executable: String, root: URL = root) -> Int64? {
        let base = root.standardizedFileURL.path + "/"
        let path = URL(fileURLWithPath: executable).standardizedFileURL.path
        guard path.hasPrefix(base) else { return nil }
        let parts = String(path.dropFirst(base.count)).split(separator: "/").map(String.init)
        if parts == ["Roblox.app", "Contents", "MacOS", "RobloxPlayer"] { return 0 }
        if parts.count == 5, parts[1] == "Roblox.app", parts[2] == "Contents", parts[3] == "MacOS", parts[4] == "RobloxPlayer",
           let id = Int64(parts[0]), id > 0 { return id }
        if parts.count == 4, parts[0].hasSuffix(".app"), parts[1] == "Contents", parts[2] == "MacOS", parts[3] == "RobloxPlayer",
           let id = Int64(parts[0].dropLast(4)), id > 0 { return id }
        return nil
    }
    static func executablePath(_ pid: pid_t) -> String? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size,
              info.pbi_status != UInt32(SZOMB) else { return nil }
        var buffer = [CChar](repeating: 0, count: 4096)
        let count = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard count > 0 else { return nil }
        return String(cString: buffer)
    }
    @MainActor static func snapshot(root: URL = root) -> [Int64: ManagedProcess] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [:] }
        var pids = [pid_t](repeating: 0, count: Int(count) + 256)
        let capacity = Int32(pids.count * MemoryLayout<pid_t>.stride)
        let used = proc_listallpids(&pids, capacity)
        guard used > 0 else { return [:] }
        var result: [Int64: ManagedProcess] = [:]
        for pid in pids.prefix(min(Int(used), pids.count)) where pid > 0 {
            guard let path = executablePath(pid), let id = accountID(executable: path, root: root) else { continue }
            let client = ManagedProcess(accountID: id, processIdentifier: pid)
            // Prefer the window-owning process if a transient child shares the executable.
            if result[id] == nil || NSRunningApplication(processIdentifier: pid) != nil { result[id] = client }
        }
        return result
    }
}
struct ManagedProcess {
    let accountID: Int64
    let processIdentifier: pid_t
    @MainActor var canFocus: Bool { NSRunningApplication(processIdentifier: processIdentifier) != nil }
    @MainActor func focus() {
        guard isStillManaged else { return }
        NSRunningApplication(processIdentifier: processIdentifier)?.activate(options: [.activateAllWindows])
    }
    var isStillManaged: Bool {
        guard let path = ManagedClients.executablePath(processIdentifier) else { return false }
        return ManagedClients.accountID(executable: path) == accountID
    }
    @MainActor func terminate() {
        // Recheck ownership immediately before signaling, in case macOS reused a PID.
        guard isStillManaged else { return }
        if let app = NSRunningApplication(processIdentifier: processIdentifier) { _ = app.terminate() }
        else { kill(processIdentifier, SIGTERM) }
    }
}
