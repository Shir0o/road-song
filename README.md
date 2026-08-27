# Road Song

[![Flutter CI](https://github.com/Shir0o/road-song/workflows/Flutter%20CI/badge.svg)](https://github.com/Shir0o/road-song/actions/workflows/flutter_ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

A chaotic, high-contrast **Neo-Brutalist** Flutter application built to log messy trips, capture typewriter logs, gather evidence (receipts, notes, photos), and synthesize audio tracks from trip vibes.

---

## 🎨 The Neo-Brutalist Aesthetic

Road Song rejects boring, flat, modern UI designs in favor of **Neo-Brutalism**:
- **High Contrast**: Flat, vibrant colors accented by thick `#111111` borders (`BrutalTheme.inkBlack`).
- **Heavy Shadows**: Hard offset shadows (`Offset(4, 4)`) with no blur.
- **Physical Details**: Polaroid-style photo layouts, mock Dymo tape labels, and physical tape overlays.
- **Staggered Layouts**: Asymmetrical grid systems and textured background grains (`GrainOverlay`).

---

## 🚀 Key Features

*   **📂 Messy Scrapbook**: A staggered cards list containing trip collections (e.g., Cabo, Vegas, Mudfest) with customizable tilting, tape aesthetics, and instant chaos triggers.
*   **⌨️ Typewriter Log**: A classic analog typewriter emulator to write trip journal entries.
*   **📸 Evidence Vault**: A gallery of Polaroid logs, receipt captures, and evidence folders.
*   **🎵 Vibe Studio**: An interactive audio visualizer and banger editor to synthesize sound tracks matching your trip's energy.
*   **👤 Chaotic Profile**: Manage traveler information (like Seagull fighting credits) under custom Brutalist cards.

---

## 📦 Getting Started

### Installation & Run

1. Clone the repository:
   ```bash
   git clone git@github.com:Shir0o/road-song.git
   cd road-song
   ```
2. Install package dependencies:
   ```bash
   flutter pub get
   ```
3. Launch the app on your preferred emulator or device:
   ```bash
   flutter run
   ```

---

## 🏷️ Releases

Get the latest build to install directly on your device:
- **Download APK**: Visit the [Releases](https://github.com/Shir0o/road-song/releases) page on GitHub to download the compiled `app-release.apk` for the latest version (e.g., [v1.0.0](https://github.com/Shir0o/road-song/releases/tag/v1.0.0)).
- **Build Locally**: To build a release APK on your local machine, run:
  ```bash
  flutter build apk --release
  ```
  The compiled APK will be located at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 🧪 Testing & Validation

Road Song maintains a strict **>= 90% test coverage** requirement on all pull requests, validated on every push via GitHub Actions.

- Run the full test suite (Widget & Unit tests):
  ```bash
  flutter test
  ```
- Run tests and calculate code coverage:
  ```bash
  flutter test --coverage
  ```
- View test coverage details:
  ```bash
  # Check coverage report (requires lcov installed)
  genhtml coverage/lcov.info -o coverage/html
  open coverage/html/index.html
  ```

---

## 🤝 Community & Contributing

We welcome contributions of all forms! Please refer to these guidelines to get started:

-   **Guidelines**: Check out [CONTRIBUTING.md](CONTRIBUTING.md) to learn about our branching model, coding conventions, and coverage policies.
-   **Code of Conduct**: We expect all contributors to adhere to the [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
-   **Security**: Please report security vulnerabilities privately according to [SECURITY.md](SECURITY.md).

---

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
