import Foundation
import Security
import SwiftUI
struct Account: Codable, Identifiable, Hashable {
    var id: Int64
    var name: String
    var displayName: String
    var isDemo: Bool { id < 0 }
    var cookie: String
}
@MainActor final class Accounts: ObservableObject {
    static let shared = Accounts()
    @Published var items: [Account] = []
    @Published var message = "Add an account to get started."
    @Published var busy = false
    private let service = "local.macblox.accounts"
    init() {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query.merging([kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]) { _, b in b } as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            do { items = try JSONDecoder().decode([Account].self, from: data) }
            catch { message = "Could not read saved accounts: \(error.localizedDescription)" }
        } else if status != errSecItemNotFound { message = "Keychain unavailable (\(status))." }
    }
    private var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "vault"] }
    func commit(_ updated: [Account]) throws {
        let data = try JSONEncoder().encode(updated.filter { !$0.isDemo })
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging([kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]) { _, b in b } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw Failure("Keychain could not save accounts (\(status)).") }
        items = updated
    }
    func add(cookie: String) async throws {
        let account = try await Roblox.account(cookie: cookie)
        try commit(items.filter { $0.id != account.id } + [account])
        message = "Saved @\(account.name) in Keychain."
    }
    func addDemo() -> Int64 {
        let id: Int64 = (items.filter(\.isDemo).map(\.id).min() ?? 0) - 1
        if !items.contains(where: { $0.id == id }) {
            items.append(Account(id: id, name: "DemoAlt_\(-id)", displayName: "Demo Alt \(-id)", cookie: ""))
        }
        message = "Demo alt added. This is a fictional account; no Roblox login is connected."
        return id
    }
    func remove(_ account: Account) {
        if account.isDemo { items.removeAll { $0.id == account.id }; message = "Demo alt removed."; return }
        do { try commit(items.filter { $0.id != account.id }); message = "Account removed." }
        catch { message = error.localizedDescription }
    }
}
struct Failure: LocalizedError {
    var errorDescription: String?
    init(_ text: String) { errorDescription = text }
}
