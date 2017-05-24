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
		.Package(url: "https://github.com/IBM-Swift/BlueSocket", majorVersion: 0, minor: 12)
	],
	swiftLanguageVersions: [3]
)
