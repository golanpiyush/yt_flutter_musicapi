# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),  
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [1.1.4]

### Fixed
- Fixed the mock/testing code in python.

## [1.1.3]

### Fixed
- Fixed the ThumbnailQuality in python file.

- LOW: w60-h60 (60x60 pixels) 
- MED: w120-h120 (120x120 pixels)
- HIGH: w320-h320 (320x320 pixels)
- VERY_HIGH: w544-h544 (544x544 pixels)

## [1.1.2]

### Fixed
- Fixed an issue related to `searchMusic & getRelatedSongs` that would cause memory overflows.

### Added
- More songs by a particular `artist` and getting related `artists`. (Not fully implemented!)


## [1.0.2]

### Fixed
- Fixed an issue of `Syntax error around line 441 in the kotlin file`

## [1.0.1]

### Added
- Fixed outdated `documentation` link in `pubspec.yaml`.

### Updated
- Updated `yt-dlp` to version `2024.06.30`.
- Updated `ytmusicapi` Python backend to version `1.10.3`.

---

## [1.0.0]

### Added
- Initial stable release.
- YouTube Music search functionality using python's `ytmusicapi` and audios using `yt-dlp`.
- Related songs feature based on current track.
- Support for configurable audio and thumbnail quality.
- Cross-platform structure with Android support.
- Integrated Kotlin-Python bridge using Chaquopy for backend communication.
