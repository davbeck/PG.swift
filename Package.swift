// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "PG",
	products: [
		// Products define the executables and libraries produced by a package, and make them visible to other packages.
		.library(
			name: "PG",
			targets: ["PG"]),
		],
	dependencies: [
		.package(url: "https://github.com/IBM-Swift/BlueCryptor.git", from: "1.0.5"),
		.package(url: "https://github.com/apple/swift-nio.git", from: "1.7.3"),
	],
	targets: [
		// Targets are the basic building blocks of a package. A target can define a module or a test suite.
		// Targets can depend on other targets in this package, and on products in packages which this package depends on.
		.target(
			name: "PG",
			dependencies: ["Cryptor", "NIO"]),
		.testTarget(
			name: "pgTests",
			dependencies: ["PG"]),
		]
)
