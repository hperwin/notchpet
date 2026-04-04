// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotchPet",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NotchPet",
            resources: [
                .copy("Resources/blob.png"),
                .copy("Resources/frames"),
                .copy("Resources/pokemon"),
                .copy("Resources/berries")
            ]
        ),
        // .testTarget(
        //     name: "NotchPetTests",
        //     dependencies: ["NotchPet"]
        // ),
    ]
)
