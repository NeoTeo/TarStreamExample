import PackageDescription

let package = Package(
    name: "TarStreamExample",
    dependencies: [
        .Package(url: "https://github.com/NeoTeo/TarStream.git", majorVersion: 0),
        .Package(url: "https://github.com/NeoTeo/HttpStream.git", majorVersion: 0),
    ]
)
