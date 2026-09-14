// swift-tools-version: 5.9
import PackageDescription

// OopsCore не зависит ни от одного системного фреймворка — только Foundation.
// Это не аккуратность ради аккуратности: ядро так собирается и проверяется
// командой `swift test` за секунды, без Xcode и без запуска приложения,
// которому нужны разрешения Accessibility.
let package = Package(
    name: "Oops",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "OopsCore", targets: ["OopsCore"])
    ],
    targets: [
        .target(name: "OopsCore"),
        .testTarget(name: "OopsCoreTests", dependencies: ["OopsCore"])
    ]
)
