// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Checkpoint",
	platforms: [
		.macOS(.v14)
	],
	products: [
		// Products define the executables and libraries a package produces, making them visible to other packages.
		.library(
			name: "Checkpoint",
			targets: ["Checkpoint"]),
	],
	dependencies: [
		.package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
		.package(url: "https://github.com/hummingbird-project/hummingbird-redis.git", from: "2.0.0-beta.8")
	],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Checkpoint",
			dependencies: [
				.product(name: "Hummingbird", package: "hummingbird"),
				.product(name: "HummingbirdRedis", package: "hummingbird-redis")
			]
		),
        .testTarget(
            name: "CheckpointTests",
            dependencies: [
				"Checkpoint",
				.product(name: "Hummingbird", package: "hummingbird"),
				.product(name: "HummingbirdTesting", package: "hummingbird")
			]
        ),
    ]
)
