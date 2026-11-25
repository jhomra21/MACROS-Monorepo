// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FoodPhotoEval",
    platforms: [.macOS("27.0")],
    products: [.executable(name: "FoodPhotoEval", targets: ["FoodPhotoEval"])],
    targets: [.executableTarget(name: "FoodPhotoEval")]
)
