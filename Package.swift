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
                .copy("Resources/berries"),
                .copy("Resources/party_strip.png"),
                .copy("Resources/party_strip_blue.png"),
                .copy("Resources/party_strip_red.png"),
                .copy("Resources/grass_strip.png"),
                .copy("Resources/bg_party.png"),
                .copy("Resources/bg_collection.png"),
                .copy("Resources/bg_stats.png"),
                .copy("Resources/bg_achievements.png")
            ]
        ),
        // .testTarget(
        //     name: "NotchPetTests",
        //     dependencies: ["NotchPet"]
        // ),
    ]
)
