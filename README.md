# app-attest-service

HTTPS service to provide ios apps with security data like api tokens through a verified connection using App Attest from Apple.

## Development

To develop this project, first install the dependencies:
1. Xcode
2. Vapor with command: `brew install vapor` on Mac. Follow [this](https://docs.vapor.codes/install/linux/) guide for Linux.
3. Run the project: `vapor run`
4. Open Safari with this URL: `http://127.0.0.1:44947/secret`

## Documentation

- [Mitigate fraud with App Attest and DeviceCheck](https://developer.apple.com/videos/play/wwdc2021/10244/)
- [Vapor website](https://vapor.codes)
- [Swift OpenAPI Vapor](https://github.com/swift-server/swift-openapi-vapor)
