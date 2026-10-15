import Foundation
import AppKit
enum PerformanceSettings {
    static func replacingCap(in xml: String, cap: Int) throws -> String {
        guard [-1, 60, 120, 144, 240].contains(cap) else { throw Failure("Unsupported FPS cap.") }
        let pattern = "(<int\\s+name=\"FramerateCap\"\\s*>)[^<]*(</int>)"
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(xml.startIndex..., in: xml)
        guard regex.numberOfMatches(in: xml, range: range) == 1 else { throw Failure("This Roblox settings format is not recognized. No changes made.") }
        let match = regex.firstMatch(in: xml, range: range)!
        let start = Range(match.range(at: 1), in: xml)!
        let end = Range(match.range(at: 2), in: xml)!
        let valueRange = start.upperBound..<end.lowerBound
        var result = xml
        result.replaceSubrange(valueRange, with: String(cap))
        return result
    }
    @MainActor static func file() throws -> URL {
        guard !NSWorkspace.shared.runningApplications.contains(where: { ($0.bundleIdentifier ?? "").hasPrefix("com.roblox") && !($0.bundleIdentifier ?? "").lowercased().contains("studio") }) else { throw Failure("Quit all Roblox Player windows before changing FPS settings.") }
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Roblox")
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.range(of: "^GlobalBasicSettings_[0-9]+\\.xml$", options: .regularExpression) != nil }
        guard let file = files.sorted(by: { $0.lastPathComponent.compare($1.lastPathComponent, options: .numeric) == .orderedDescending }).first else { throw Failure("Open and quit Roblox once to create its settings file.") }
        return file
    }
    @MainActor static func apply(_ cap: Int) throws {
        let file = try file()
        let xml = try String(contentsOf: file, encoding: .utf8)
        let updated = try replacingCap(in: xml, cap: cap)
        let backup = file.appendingPathExtension("macblox-backup")
        if !FileManager.default.fileExists(atPath: backup.path) { try Data(contentsOf: file).write(to: backup, options: .atomic) }
        try updated.write(to: file, atomically: true, encoding: .utf8)
    }
    @MainActor static func restore() throws {
        let file = try file(), backup = file.appendingPathExtension("macblox-backup")
        guard FileManager.default.fileExists(atPath: backup.path) else { throw Failure("There is no MacBlox settings backup to restore.") }
        try Data(contentsOf: backup).write(to: file, options: .atomic)
    }
}
