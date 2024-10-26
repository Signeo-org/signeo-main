# Signeo Project Architecture

Signeo is a suite of applications dedicated to enabling live subtitling with support for both **sign language** and **text**.

## Architecture Overview

For a high-level overview of Signeo's architecture, please refer to the [Architecture Diagram in our Documentation Repository](https://github.com/signeo-org/signeo-docs/blob/main/assets/diagrams/SigneoArchitectureDiagram.png).

## Overview of Components

- **Desktop App**: The primary application interface for desktop users, consisting of a frontend (`signeo-desktop-frontend`) and backend (`signeo-desktop-backend`) packaged together for offline functionality.
- **Mobile App**: A mobile version with its own frontend (`signeo-mobile-frontend`) and backend (`signeo-mobile-backend`) to allow similar functionality on mobile devices.
- **Shared Services**: 
  - `signeo-db`: Central database service managing user data, subtitle history, and system state.
  - `signeo-libs`: Shared libraries providing utility functions and resources used across different applications.
- **Infrastructure & Support**:
  - `signeo-devops`: Manages CI/CD, infrastructure as code, and deployment workflows.
  - `signeo-docs`: Contains all documentation, guides, and API references for contributors and users.

## How to Get Involved
- **Contributing**: Check out our [Contributing Guidelines](https://github.com/signeo-org/signeo-docs/blob/main/CONTRIBUTING.md) in the documentation repository.
- **Documentation**: Visit [signeo-docs](https://github.com/signeo-org/signeo-docs) for setup instructions, guides, and the latest API references.
- **Discussions**: Join our community in the [Discussions](https://github.com/signeo-org/signeo-main/discussions) section.

Thank you for your interest in Signeo!
