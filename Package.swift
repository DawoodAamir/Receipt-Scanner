// swift-tools-version: 5.7
import PackageDescription
let package = Package(name: "ReceiptCore", products: [.library(name: "ReceiptCore", targets: ["ReceiptCore"])], targets: [.target(name: "ReceiptCore", path: "Sources/Core"), .testTarget(name: "ReceiptCoreTests", dependencies: ["ReceiptCore"], path: "Tests")])
