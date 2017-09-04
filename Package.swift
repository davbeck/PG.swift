// swift-tools-version:3.1

import PackageDescription

let package = Package(
	name: "PG",
	targets: [
		Target(
			name: "PG",
			dependencies: []
		),
	],
	dependencies: [
        .Package(url: "https://github.com/davbeck/AsyncKit.git", majorVersion: 0, minor: 0),
        .Package(url: "https://github.com/IBM-Swift/BlueCryptor.git", majorVersion: 0, minor: 8),
		.Package(url: "https://github.com/IBM-Swift/BlueSocket", majorVersion: 0, minor: 12),
	],
	swiftLanguageVersions: [3]
)
