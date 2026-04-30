# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build all crates (debug)
cargo build

# Build release
cargo build --release

# Run the GUI app
cargo run -p qtspot-gui --bin qtspot
cargo run -p qtspot-gui --bin qtspot --release

# Check code style (matches CI)
cargo clippy -- -D warnings

# Format code
cargo fmt

# Build macOS app bundle
cargo install cargo-bundle
cargo bundle --release
```

### Platform Dependencies

**Linux (Debian/Ubuntu):**
```bash
sudo apt-get install libssl-dev libasound2-dev
```

**Linux (RHEL/Fedora):**
```bash
sudo dnf install openssl-devel alsa-lib-devel
```

**Qt 6 scaffold:**
Install Qt 6 development tools (`qmake6`, Qt Quick, Qt Quick Controls 2, Qt Network), CMake, a C++ compiler, and `clang-format`. If Qt 5 is also installed, build with `QMAKE=/path/to/qmake6` or `QT_VERSION_MAJOR=6`.

## Architecture

qtspot is a native Spotify client organized as a Rust workspace. It is maintained by Cian Estella / YummierGravy.

The core crate still uses `spotix-core`; GUI branding and packaging use `qtspot`.

### spotix-core
Core library handling Spotify connectivity and audio:
- `session/` - Spotify authentication (OAuth, login5, tokens) and Mercury protocol messaging
- `player/` - Playback control, queue management, audio file loading, and worker threads
- `audio/` - Audio pipeline: decryption, decoding (symphonia), resampling, normalization, and 10-band equalizer
- `connection/` - Low-level Spotify protocol connection (Shannon encryption)
- `cache.rs`, `cdn.rs` - Track caching and CDN file fetching

### qtspot-gui
Qt 6/QML GUI application:
- `data/` - Application state models and configuration (`config.rs` for user preferences)
- `webapi/` - Spotify Web API client
- `src/bin/spotix.rs`, `src/bin/spotix-qt.rs`, `src/qt/`, `qml/` - Qt 6/QML primary UI using CXX-Qt; Cargo exposes the main binary as `qtspot`.

## Audio Backend Features

- Default audio backend: cpal (cross-platform)
- Alternative: cubeb (Mozilla's audio library) - enable with `--features cubeb`
- Audio processing: decryption -> Vorbis/MP3 decode -> resample -> normalize -> EQ -> output

## Theming

Custom themes are TOML files in `~/.config/qtspot/themes/`. Each theme defines color keys and a `name` field. Theme selection is in Settings -> General.
