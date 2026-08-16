# SomaFM miniplayer

[![CI](https://github.com/ealeksandrov/SomaFM-miniplayer/actions/workflows/test.yml/badge.svg)](https://github.com/ealeksandrov/SomaFM-miniplayer/actions/workflows/test.yml)
[![Latest Release](https://img.shields.io/github/release/ealeksandrov/SomaFM-miniplayer.svg)](https://github.com/ealeksandrov/SomaFM-miniplayer/releases/latest)
[![License](https://img.shields.io/github/license/ealeksandrov/SomaFM-miniplayer.svg)](LICENSE.md)
![Platform](https://img.shields.io/badge/platform-macOS%2014+-blue.svg)

![Screenshot](01.jpg)

An unofficial, minimal menu-bar player for [SomaFM](https://somafm.com/).

## Installation

[<img src="https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-mac-app-store/black/en-us" alt="Download on the Mac App Store" height="40">](https://apps.apple.com/app/id1303140142)

Or download the latest `dmg` from [GitHub Releases](https://github.com/ealeksandrov/SomaFM-miniplayer/releases/latest).

## Usage

- Left-click the status item to open the menu, or switch it to play/pause in Settings.
- Right-click, Control-click, or Option-click always opens the menu.
- The menu header shows the station and current track, with a play/pause button beside them.
- Click the current track to copy it or search with the action selected in Settings.
- Settings covers playback (start at login, play on launch, track notifications) and behavior (left-click action, track click action, station sorting, recent stations).

## Building

Open `SomaFM.xcodeproj` in Xcode 26 or later and run the `SomaFM` scheme. The project has no third-party dependencies or bootstrap step.

## Author

Created and maintained by Evgeny Aleksandrov ([@ealeksandrov](https://twitter.com/ealeksandrov)).

## License

SomaFM miniplayer is available under the MIT license. See [LICENSE.md](LICENSE.md) and the [privacy policy](PRIVACY.md).
