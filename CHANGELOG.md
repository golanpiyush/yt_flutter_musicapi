# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),  
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.1.5]

### Added
- Support of fetching Artist Songs `requires artistName="Obviously"`

- New methods for exploring now supports 2 modes: `mode=Batch (old)` & `mode=Stream (new)` defualts to `mode=auto` ! `required to explore the package`

- Enhanced error recovery for interrupted streams

- Stream cancellation support with proper resource cleanup

### Updated
- Python-Kotlin bridge for efficient generator-based streaming

- Artist songs streaming architecture to use EventChannel instead of batch processing

- Example app with streaming visualization

### Fixed
- Memory management during long streaming sessions

- Thumbnail quality consistency across screens

- Race conditions in concurrent stream operations

- Resource leaks in generator-based implementations

### Performance

- Reduced initial latency from 1200ms to 300ms

- Consistent 50ms intervals between streamed items

- Lower memory footprint during streaming (45% reduction)

- Improved backpressure handling for slow clients

### Breaking Changes
streamArtistSongs now requires explicit cancellation handling

Generator-based APIs may throw StopIteration exceptions

Stream order is no longer guaranteed to match original API
### Migration Notes
Clients should implement proper stream cancellation

Batch processing now requires explicit collection of stream items

Error handling should account for mid-stream failures

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
