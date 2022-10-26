// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Socket",
    products: [
        .library(name: "Socket", targets: ["Socket"])
    ],
    targets: [
        .target(name: "Socket", dependencies: [])
    ]
)
