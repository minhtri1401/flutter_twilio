// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
//  Generated file. Do not edit.
//

import PackageDescription

let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "FlutterGeneratedPluginSwiftPackage", type: .static, targets: ["FlutterGeneratedPluginSwiftPackage"])
    ],
    dependencies: [
        .package(name: "firebase_messaging", path: "../.packages/firebase_messaging"),
        .package(name: "firebase_core", path: "../.packages/firebase_core"),
        .package(name: "firebase_auth", path: "../.packages/firebase_auth"),
        .package(name: "firebase_analytics", path: "../.packages/firebase_analytics"),
        .package(name: "cloud_functions", path: "../.packages/cloud_functions")
    ],
    targets: [
        .target(
            name: "FlutterGeneratedPluginSwiftPackage",
            dependencies: [
                .product(name: "firebase-messaging", package: "firebase_messaging"),
                .product(name: "firebase-core", package: "firebase_core"),
                .product(name: "firebase-auth", package: "firebase_auth"),
                .product(name: "firebase-analytics", package: "firebase_analytics"),
                .product(name: "cloud-functions", package: "cloud_functions")
            ]
        )
    ]
)
