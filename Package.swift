// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "azookey-service",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .executable(
            name: "azookey-service",
            targets: ["azookey-service"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/ensan-hcl/AzooKeyKanaKanjiConverter", branch: "31ce991")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "azookey-service",
            dependencies: [
                .product(name: "KanaKanjiConverterModuleWithDefaultDictionary", package: "azookeykanakanjiconverter")
            ]
        ),
    ]
)
