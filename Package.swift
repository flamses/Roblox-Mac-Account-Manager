// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "MacBlox", platforms: [.macOS(.v14)], products: [.executable(name: "MacBlox", targets: ["MacBlox"])], targets: [.executableTarget(name: "MacBlox"), .testTarget(name: "MacBloxTests", dependencies: ["MacBlox"])], swiftLanguageModes: [.v5])
