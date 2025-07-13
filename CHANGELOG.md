# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),  
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.5]

### Updated
- Updated `README.md` for the package.

## [2.1.4]

### Added
-Introduced `streamSearchResults` functionality for real-time streaming of search results.
This allows incremental delivery of song metadata instead of waiting for the entire batch, significantly improving responsiveness.

## [1.1.4]

### Fixed
- Resolved issues in the Python mock/testing environment used during development.

## [1.1.3]

### Fixed
- Corrected thumbnail quality mappings in the Python layer.
- `LOW`: w60-h60 (60x60 pixels) 
- `MED`: w120-h120 (120x120 pixels)
- `HIGH`: w320-h320 (320x320 pixels)
- `VERY_HIGH`: w544-h544 (544x544 pixels)

## [1.1.2]

### Fixed
- Addressed a memory overflow issue triggered by `searchMusic` and `getRelatedSongs`.

### Added
- Basic support for retrieving additional songs by an artist and discovering related artists. (Feature is still under development.)


## [1.0.2]

### Fixed
- Corrected a Kotlin syntax error near `line 441` that was preventing builds.

## [1.0.1]

### Added
- Updated outdated documentation link in `pubspec.yaml`.

### Updated
- Updated `yt-dlp` to version `2024.06.30`.
- Updated `ytmusicapi` Python backend to version `1.10.3`.

---

## [1.0.0]

### Added
- Initial stable release.
- YouTube Music search functionality using python's `ytmusicapi` and audio using `yt-dlp`.
- Related songs feature based on current track.
- Support for configurable audio and thumbnail quality.
- Cross-platform structure with Android support.
- Integrated Kotlin-Python bridge using Chaquopy for backend communication.
