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
                .copy("Resources/frames")
            ]
        ),
        // .testTarget(
        //     name: "NotchPetTests",
        //     dependencies: ["NotchPet"]
        // ),
    ]
)
