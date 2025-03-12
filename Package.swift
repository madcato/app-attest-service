// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "app-attest-service",
    platforms: [
       .macOS(.v10_15)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.110.1"),
        // 📝 OpenAPI support for Vapor.
        .package(url: "https://github.com/swift-server/swift-openapi-vapor.git", from: "1.0.1"),
        // 📝 OpenAPI support for Swift.
        .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.7.0"),
        // 📝 OpenAPI runtime for Swift.
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.7.0"),
        // AppAttest support for Swift.
        .package(url: "https://github.com/iansampson/AppAttest.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "OpenAPIVapor", package: "swift-openapi-vapor"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "AppAttest", package: "AppAttest"),
            ],
            plugins: [
               .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator"),
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "VaporTesting", package: "vapor"),
            ]
        )
    ]
)
