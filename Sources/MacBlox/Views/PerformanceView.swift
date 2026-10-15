import SwiftUI
struct PerformanceView: View {
    @ObservedObject var center: ControlCenter
    @AppStorage("preferredFPS") private var cap = 60
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Frame-rate limit").font(.title2.bold())
                Text("Global Roblox Player setting · applies on the next client start").foregroundStyle(.secondary)
                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Maximum FPS", selection: $cap) {
                            Text("Roblox default").tag(-1)
                            ForEach([60, 120, 144, 240], id: \.self) { Text("\($0) FPS").tag($0) }
                        }.frame(maxWidth: 360)
                        Text("Close all Roblox Player windows before applying. MacBlox changes only FramerateCap in the existing settings file and saves a backup first. Roblox may reset or ignore this value after an update.").font(.callout).foregroundStyle(.secondary)
                        HStack {
                            Button("Apply FPS limit") { do { try PerformanceSettings.apply(cap); center.log("FPS preference saved. It takes effect on the next Roblox launch.") } catch { center.log(error.localizedDescription) } }.buttonStyle(.borderedProminent)
                            Button("Restore original settings") { do { try PerformanceSettings.restore(); center.log("Original Roblox settings restored from backup.") } catch { center.log(error.localizedDescription) } }
                        }.disabled(center.working || !center.running.isEmpty)
                    }.padding(10)
                }
                Text("Higher limits increase CPU/GPU load and power use, especially with several clients. The selected limit is a target, not a promise that each client can achieve that frame rate.").foregroundStyle(.secondary)
                Divider()
                Text("For multiple alts").font(.headline)
                Text("Use 60 FPS to reduce load, increase the queue delay on a busy Mac, and turn off Bring each client to front if you want launches in the background. Graphics quality can be adjusted inside Roblox.")
            }.padding(24)
        }
    }
}
