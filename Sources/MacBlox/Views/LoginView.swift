import SwiftUI
import WebKit

@MainActor final class LoginBrowser: NSObject, ObservableObject, WKNavigationDelegate {
    let web: WKWebView
    @Published var error: String?
    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        web = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        web.navigationDelegate = self
        web.load(URLRequest(url: URL(string: "https://www.roblox.com/login")!))
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { self.error = error.localizedDescription }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        let host = url.host ?? ""
        let domains = ["roblox.com", "arkoselabs.com", "funcaptcha.com", "hcaptcha.com", "recaptcha.net", "google.com", "gstatic.com"]
        let permitted = url.scheme == "https" && domains.contains { host == $0 || host.hasSuffix("." + $0) }
        decisionHandler(permitted || url.absoluteString == "about:blank" ? .allow : .cancel)
    }
    func cookie() async throws -> String {
        let cookies = await web.configuration.websiteDataStore.httpCookieStore.allCookies()
        guard let cookie = cookies.first(where: { $0.name == ".ROBLOSECURITY" && ($0.domain == ".roblox.com" || $0.domain == "roblox.com" || $0.domain == "www.roblox.com") }) else { throw Failure("Finish signing in to Roblox, then click Save account.") }
        return cookie.value
    }
}
struct BrowserView: NSViewRepresentable {
    let browser: LoginBrowser
    func makeNSView(context: Context) -> WKWebView { browser.web }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
struct LoginView: View {
    @ObservedObject var accounts: Accounts
    @StateObject private var browser = LoginBrowser()
    @Environment(\.dismiss) private var dismiss
    @ViewState<Bool> private var saving = false
    @ViewState<String?> private var error = nil
    var body: some View {
        VStack(spacing: 0) {
            HStack { Image(systemName: "lock.shield"); Text("Sign in at roblox.com").font(.headline); Spacer(); Button("Cancel") { dismiss() } }.padding()
            BrowserView(browser: browser)
            HStack {
                Text(error ?? browser.error ?? "Complete login and any verification, then save this account.").font(.caption).foregroundStyle(error == nil ? Color.secondary : Color.red)
                Spacer()
                Button(saving ? "Saving…" : "Save account") {
                    saving = true
                    Task {
                        defer { saving = false }
                        do { let cookie = try await browser.cookie(); try await accounts.add(cookie: cookie); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }
                }.buttonStyle(.borderedProminent).disabled(saving)
            }.padding()
        }.frame(width: 900, height: 700)
    }
}
