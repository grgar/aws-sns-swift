// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "AWSSNS",
    products: [.library(name: "AWSSNS", targets: ["AWSSNS"])],
    dependencies: [.package(url: "https://github.com/nikola-mladenovic/AwsSwiftSign.git", from: "0.3.0"),
                   .package(url: "https://github.com/drmohundro/SWXMLHash.git", from: "5.0.1")],
    targets: [.target(name: "AWSSNS", dependencies: ["AwsSign", "SWXMLHash"]),
              .testTarget(name: "AWSSNSTests", dependencies: ["AWSSNS"])],
    swiftLanguageVersions: [.v5]
)
