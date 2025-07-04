import 'yt_flutter_musicapi_platform_interface.dart';

/// Enum for Audio Quality
enum AudioQuality {
  low('LOW'),
  med('MED'),
  high('HIGH'),
  veryHigh('VERY_HIGH');

  const AudioQuality(this.value);
  final String value;
}

/// Enum for Thumbnail Quality
enum ThumbnailQuality {
  low('LOW'),
  med('MED'),
  high('HIGH'),
  veryHigh('VERY_HIGH');

  const ThumbnailQuality(this.value);
  final String value;
}

/// Data class for Search Results
class SearchResult {
  final String title;
  final String artists;
  final String videoId;
  final String? duration;
  final String? year;
  final String? albumArt;
  final String? audioUrl;

  SearchResult({
    required this.title,
    required this.artists,
    required this.videoId,
    this.duration,
    this.year,
    this.albumArt,
    this.audioUrl,
  });

  factory SearchResult.fromMap(Map<String, dynamic> map) {
    return SearchResult(
      title: map['title'] ?? '',
      artists: map['artists'] ?? '',
      videoId: map['videoId'] ?? '',
      duration: map['duration'],
      year: map['year'],
      albumArt: map['albumArt'],
      audioUrl: map['audioUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'artists': artists,
      'videoId': videoId,
      'duration': duration,
      'year': year,
      'albumArt': albumArt,
      'audioUrl': audioUrl,
    };
  }

  @override
  String toString() {
    return 'SearchResult(title: $title, artists: $artists, videoId: $videoId, duration: $duration, year: $year, albumArt: $albumArt, audioUrl: $audioUrl)';
  }
}

/// Data class for Related Songs
class RelatedSong {
  final String title;
  final String artists;
  final String videoId;
  final String? duration;
  final String? albumArt;
  final String? audioUrl;
  final bool isOriginal;

  RelatedSong({
    required this.title,
    required this.artists,
    required this.videoId,
    this.duration,
    this.albumArt,
    this.audioUrl,
    this.isOriginal = false,
  });

  factory RelatedSong.fromMap(Map<String, dynamic> map) {
    return RelatedSong(
      title: map['title'] ?? '',
      artists: map['artists'] ?? '',
      videoId: map['videoId'] ?? '',
      duration: map['duration'],
      albumArt: map['albumArt'],
      audioUrl: map['audioUrl'],
      isOriginal: map['isOriginal'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'artists': artists,
      'videoId': videoId,
      'duration': duration,
      'albumArt': albumArt,
      'audioUrl': audioUrl,
      'isOriginal': isOriginal,
    };
  }

  @override
  String toString() {
    return 'RelatedSong(title: $title, artists: $artists, videoId: $videoId, duration: $duration, albumArt: $albumArt, audioUrl: $audioUrl, isOriginal: $isOriginal)';
  }
}

/// YouTube Music API Response wrapper
class YTMusicResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? error;
  final int? count;

  YTMusicResponse({
    required this.success,
    this.data,
    this.message,
    this.error,
    this.count,
  });

  factory YTMusicResponse.fromMap(Map<String, dynamic> map) {
    return YTMusicResponse<T>(
      success: map['success'] ?? false,
      data: map['results'] ?? map['data'],
      message: map['message'],
      error: map['error'],
      count: map['count'],
    );
  }
}

/// Main YtFlutterMusicapi class
class YtFlutterMusicapi {
  static bool _isInitialized = false;

  /// Initialize the YouTube Music API
  ///
  /// [proxy] - Optional proxy URL (e.g., "http://proxy:port")
  /// [country] - Country code for search results (default: "US")
  Future<YTMusicResponse<void>> initialize({
    String? proxy,
    String country = 'US',
  }) async {
    try {
      final result = await YtFlutterMusicapiPlatform.instance.initialize(
        proxy: proxy,
        country: country,
      );

      _isInitialized = result['success'] ?? false;

      return YTMusicResponse<void>(
        success: _isInitialized,
        message: result['message'],
        error: result['error'],
      );
    } catch (e) {
      return YTMusicResponse<void>(success: false, error: e.toString());
    }
  }

  /// Search for music
  ///
  /// [query] - Search query string
  /// [limit] - Maximum number of results (default: 10)
  /// [thumbQuality] - Thumbnail quality (default: VERY_HIGH)
  /// [audioQuality] - Audio quality (default: VERY_HIGH)
  /// [includeAudioUrl] - Whether to include audio URLs (default: true)
  /// [includeAlbumArt] - Whether to include album art (default: true)
  Future<YTMusicResponse<List<SearchResult>>> searchMusic({
    required String query,
    int limit = 10,
    ThumbnailQuality thumbQuality = ThumbnailQuality.veryHigh,
    AudioQuality audioQuality = AudioQuality.veryHigh,
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) async {
    if (!_isInitialized) {
      return YTMusicResponse<List<SearchResult>>(
        success: false,
        error: 'YTMusic API not initialized. Call initialize() first.',
      );
    }

    try {
      final result = await YtFlutterMusicapiPlatform.instance.searchMusic(
        query: query,
        limit: limit,
        thumbQuality: thumbQuality.value,
        audioQuality: audioQuality.value,
        includeAudioUrl: includeAudioUrl,
        includeAlbumArt: includeAlbumArt,
      );

      if (result['success'] == true) {
        final List<dynamic> resultsData = result['results'] ?? [];
        final List<SearchResult> searchResults = resultsData
            .map((item) => SearchResult.fromMap(item as Map<String, dynamic>))
            .toList();

        return YTMusicResponse<List<SearchResult>>(
          success: true,
          data: searchResults,
          count: result['count'],
        );
      } else {
        return YTMusicResponse<List<SearchResult>>(
          success: false,
          error: result['error'] ?? 'Unknown error occurred',
        );
      }
    } catch (e) {
      return YTMusicResponse<List<SearchResult>>(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Get related songs for a given song and artist
  ///
  /// [songName] - Name of the song
  /// [artistName] - Name of the artist
  /// [limit] - Maximum number of results (default: 10)
  /// [thumbQuality] - Thumbnail quality (default: VERY_HIGH)
  /// [audioQuality] - Audio quality (default: VERY_HIGH)
  /// [includeAudioUrl] - Whether to include audio URLs (default: true)
  /// [includeAlbumArt] - Whether to include album art (default: true)
  Future<YTMusicResponse<List<RelatedSong>>> getRelatedSongs({
    required String songName,
    required String artistName,
    int limit = 10,
    ThumbnailQuality thumbQuality = ThumbnailQuality.veryHigh,
    AudioQuality audioQuality = AudioQuality.veryHigh,
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) async {
    if (!_isInitialized) {
      return YTMusicResponse<List<RelatedSong>>(
        success: false,
        error: 'YTMusic API not initialized. Call initialize() first.',
      );
    }

    try {
      final result = await YtFlutterMusicapiPlatform.instance.getRelatedSongs(
        songName: songName,
        artistName: artistName,
        limit: limit,
        thumbQuality: thumbQuality.value,
        audioQuality: audioQuality.value,
        includeAudioUrl: includeAudioUrl,
        includeAlbumArt: includeAlbumArt,
      );

      if (result['success'] == true) {
        final List<dynamic> resultsData = result['results'] ?? [];
        final List<RelatedSong> relatedSongs = resultsData
            .map((item) => RelatedSong.fromMap(item as Map<String, dynamic>))
            .toList();

        return YTMusicResponse<List<RelatedSong>>(
          success: true,
          data: relatedSongs,
          count: result['count'],
        );
      } else {
        return YTMusicResponse<List<RelatedSong>>(
          success: false,
          error: result['error'] ?? 'Unknown error occurred',
        );
      }
    } catch (e) {
      return YTMusicResponse<List<RelatedSong>>(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Dispose and clean up resources
  Future<YTMusicResponse<void>> dispose() async {
    try {
      final result = await YtFlutterMusicapiPlatform.instance.dispose();
      _isInitialized = false;

      return YTMusicResponse<void>(
        success: result['success'] ?? false,
        message: result['message'],
        error: result['error'],
      );
    } catch (e) {
      return YTMusicResponse<void>(success: false, error: e.toString());
    }
  }

  /// Check if the API is initialized
  bool get isInitialized => _isInitialized;
}
