# App Attest Client Demo

HTTP service to provide ios apps with security data like api tokens through a verified connection using App Attest from Apple.

This project demonstrates an application utilizing Apple's App Attest framework.  It provides a service that can be used to verify the integrity of an application on a device.

**IMPORTANT** This service does not provice SSL communication. Use a configured reverse proxy like nginx, or use Cloudflared tunnel.

## Overview

The `AppAttestClientDemo` project is am Xcode app designed to interact with the App Attest API.  It's intended for testing and demonstration purposes, and is not necessarily production-ready.

## Prerequisites

*   **Docker:** This project is designed to be run within a Docker container.  Ensure you have Docker installed and configured on your system. Also install docker-compose with: `brew install docker-compose` and configure the plugin as described in the installation output log.
    - In **macOS** you can use [Colima](https://github.com/abiosoft/colima) to run docker in a virtual machine. To install Colima, follow the instructions [here](https://github.com/abiosoft/colima#installation).
    - In **Linux** you can use [Docker Desktop](https://docs.docker.com/docker-for-linux/install/) or [Podman](https://podman.io/getting-started/installation).
    - In **Windows** you can use [Docker Desktop](https://docs.docker.com/docker-for-windows/install/).

*   **Xcode:**  To open `AppAttestClientDemo.xcodeproj` and run the demo app.
*   **Vapor:** To run the service.

## Getting Started

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/madcato/app-attest-service.git
    cd app-attest-service
    ```

2. Create the **`.ev.secret`** file as shown in the **Configuration** section below.

3.  **Build and run the application using Docker Compose:**

    ```bash
    docker compose build
    docker compose up app
    ```

    This will build the Docker image and start the application.  The service will be accessible on port `44947`.

## Configuration

The application's behavior can be configured through environment variables.

*   **`LOG_LEVEL`**:  Sets the logging level (default: `debug`).
*   **`.env.secret`**:  Contains sensitive configuration information (e.g., API keys, database credentials).  **Important:** Do not commit this file to version control.
    This file must have the following format and variables:
    ```
    APPLE_DEVELOPER_ACCOUNT_TEAM_ID=<your_apple_developer_account_team_id>'
    APPLE_APP_BUNLDE_ID=<your_app_bundle_id>
    SECRET=<the_secret_to_be_distributed>
    ```

## Project Structure

*   **`AppAttestClientDemo.xcodeproj`**: Xcode project file.
*   **`docker-compose.yml`**: Docker Compose file for running the application locally. 
*   **`docker-compose.image.yml`**: Docker Compose file using the image is already built in Docker Hub at `veladan/app-attest-service`.
*   **`openapi-generator-config.yaml`**: Configuration file for OpenAPI generator.
*   **`Sources/App`**: Contains the source code for the Vapor application.
*   **`.env.secret`**: (Not included) Contains sensitive environment variables.

## Development

To develop this project, first install the dependencies:
1. Xcode
2. Vapor with command: `brew install vapor` on Mac. Follow [this](https://docs.vapor.codes/install/linux/) guide for Linux.
3. Run the project: `vapor run`
4. Open Safari with this URL: `http://127.0.0.1:44947/secret`

## Documentation

- [DeviceCheck documentation](https://developer.apple.com/documentation/devicecheck)
- [Mitigate fraud with App Attest and DeviceCheck](https://developer.apple.com/videos/play/wwdc2021/10244/)
- [Vapor website](https://vapor.codes)
- [Swift OpenAPI Vapor](https://github.com/swift-server/swift-openapi-vapor)

## Known Limitations

*   This project is intended for testing and demonstration purposes only.
*   The provided files do not include a complete production deployment guide.

## Contributing

Feel free to contribute to this project by submitting pull requests.

## License

MIT License
