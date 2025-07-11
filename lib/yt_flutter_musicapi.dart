import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;

  ApiResponse({
    required this.success,
    this.message,
    this.data,
  });

  factory ApiResponse.fromMap(Map<String, dynamic> map) {
    return ApiResponse<T>(
      success: map['success'] ?? false,
      message: map['message'],
      data: map['results'] as T?,
    );
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
    // Debug print to see what we're receiving
    print('Received response map: $map');

    // Handle cases where data might be in 'data' or 'results' field
    dynamic data = map['data'] ?? map['results'];

    // Special handling for list data
    if (data is List) {
      print('Data is a list with ${data.length} items');
      if (data.isNotEmpty) {
        print('First item: ${data.first}');
      }
    }

    return YTMusicResponse<T>(
      success: map['success'] ?? false,
      data: data as T?,
      message: map['message'],
      error: map['error'],
      count: map['count'] ?? (data is List ? data.length : null),
    );
  }
}

/// Main YtFlutterMusicapi class that provides access to YouTube Music API
class YtFlutterMusicapi {
  static final YtFlutterMusicapi _instance = YtFlutterMusicapi._internal();
  MethodChannel _channel = MethodChannel('yt_flutter_musicapi');

  static bool _isInitialized = false;
  static String? _lastError;

  // Getters
  static String? get lastError => _lastError;

  factory YtFlutterMusicapi() => _instance;

  YtFlutterMusicapi._internal();

  /// Initializes the YouTube Music API
  Future<YTMusicResponse<void>> initialize({
    String? proxy,
    String country = 'US',
  }) async {
    try {
      final result = (await YtFlutterMusicapiPlatform.instance.initialize(
        proxy: proxy,
        country: country,
      ))
          .cast<String, dynamic>();
      _isInitialized = result['success'] ?? false;

      if (!_isInitialized) {
        throw Exception(result['error'] ?? 'Initialization failed');
      }

      return YTMusicResponse<void>(
        success: true,
        message: result['message'],
      );
    } catch (e) {
      return YTMusicResponse<void>(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Searches for music on YouTube Music
  Future<YTMusicResponse<List<SearchResult>>> searchMusic({
    required String query,
    int limit = 10,
    ThumbnailQuality thumbQuality = ThumbnailQuality.veryHigh,
    AudioQuality audioQuality = AudioQuality.veryHigh,
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) async {
    return _executeApiCall<List<SearchResult>>(
      () async {
        try {
          final dynamic result =
              await YtFlutterMusicapiPlatform.instance.searchMusic(
            query: query,
            limit: limit,
            thumbQuality: thumbQuality.value,
            audioQuality: audioQuality.value,
            includeAudioUrl: includeAudioUrl,
            includeAlbumArt: includeAlbumArt,
          );

          debugPrint('Raw search results: ${result.runtimeType}');

          // Handle case where result might be a Map or already a List
          dynamic resultsData;
          if (result is Map<String, dynamic>) {
            resultsData = result['data'] ?? result['results'] ?? [];
          } else if (result is List) {
            resultsData = result;
          } else {
            throw Exception('Unexpected response type: ${result.runtimeType}');
          }

          // Ensure we have a List
          final List<dynamic> resultsList =
              resultsData is List ? resultsData : [resultsData];

          final List<SearchResult> searchResults = [];
          for (final item in resultsList) {
            try {
              if (item is Map) {
                // Convert to Map<String, dynamic> and handle potential nulls
                final itemMap = Map<String, dynamic>.from(item);
                searchResults.add(SearchResult.fromMap(itemMap));
              } else {
                debugPrint('Skipping invalid item (not a Map): $item');
              }
            } catch (e, stackTrace) {
              debugPrint('Error processing item: $e\n$stackTrace\nItem: $item');
            }
          }

          debugPrint(
              'Successfully mapped ${searchResults.length} search results');
          return searchResults;
        } catch (e, stackTrace) {
          debugPrint('Error in searchMusic: $e\n$stackTrace');
          rethrow;
        }
      },
    );
  }

  /// Gets related songs for a given track
  Future<YTMusicResponse<List<RelatedSong>>> getRelatedSongs({
    required String songName,
    required String artistName,
    int limit = 10,
    ThumbnailQuality thumbQuality = ThumbnailQuality.veryHigh,
    AudioQuality audioQuality = AudioQuality.veryHigh,
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) async {
    return _executeApiCall<List<RelatedSong>>(
      () async {
        try {
          final response =
              await YtFlutterMusicapiPlatform.instance.getRelatedSongs(
            songName: songName,
            artistName: artistName,
            limit: limit,
            thumbQuality: thumbQuality.value,
            audioQuality: audioQuality.value,
            includeAudioUrl: includeAudioUrl,
            includeAlbumArt: includeAlbumArt,
          );

          // Convert to Map<String, dynamic>
          final responseMap = Map<String, dynamic>.from(response);
          final dynamic data = responseMap['data'];

          // Handle case where data might be a List<dynamic> or just a dynamic value
          final List<dynamic> resultsList = data is List ? data : [data];

          final List<RelatedSong> results = [];
          for (final item in resultsList) {
            try {
              if (item is Map) {
                // Ensure proper type conversion
                final itemMap = Map<String, dynamic>.from(item);
                results.add(RelatedSong.fromMap(itemMap));
              } else {
                debugPrint('Skipping invalid item (not a Map): $item');
              }
            } catch (e, stackTrace) {
              debugPrint(
                  'Error mapping related song: $e\n$stackTrace\nItem: $item');
            }
          }

          debugPrint('Successfully mapped ${results.length} related songs');
          return results;
        } catch (e, stackTrace) {
          debugPrint('Error in getRelatedSongs: $e\n$stackTrace');
          rethrow;
        }
      },
    );
  }

  /// Fetch lyrics for a song
  ///
  /// [title] - The song title
  /// [artist] - The artist name
  /// [duration] - Optional duration in seconds for better matching
  ///
  /// Returns [LyricsResult] containing the lyrics data or error information
  /// Fetch lyrics for a song with proper error handling and type safety
  // Future<LyricsResult> fetchLyrics({
  //   required String title,
  //   required String artist,
  //   int? duration,
  // }) async {
  //   try {
  //     // Input validation
  //     if (title.trim().isEmpty) {
  //       return LyricsResult.failure(
  //         error: 'Title cannot be empty',
  //         code: 'INVALID_TITLE',
  //       );
  //     }
  //     if (artist.trim().isEmpty) {
  //       return LyricsResult.failure(
  //         error: 'Artist cannot be empty',
  //         code: 'INVALID_ARTIST',
  //       );
  //     }

  //     // Check initialization
  //     if (!_isInitialized) {
  //       return LyricsResult.failure(
  //         error: 'API not initialized',
  //         code: 'NOT_INITIALIZED',
  //       );
  //     }

  //     if (kDebugMode) {
  //       print('Fetching lyrics for: "$title" by "$artist"');
  //     }

  //     // Call platform method
  //     final response = await YtFlutterMusicapiPlatform.instance.fetchLyrics(
  //       title: title.trim(),
  //       artist: artist.trim(),
  //       duration: duration,
  //     );

  //     // Parse response
  //     final result = LyricsResult.fromMap(response);

  //     if (kDebugMode) {
  //       print('Lyrics fetch result: ${result.success ? 'Success' : 'Failed'}');
  //       if (result.success) {
  //         print('Found ${result.lyrics?.length ?? 0} lyrics lines');
  //       } else {
  //         print('Error: ${result.error}');
  //       }
  //     }

  //     return result;
  //   } on PlatformException catch (e) {
  //     if (kDebugMode) {
  //       print('PlatformException in fetchLyrics: ${e.message}');
  //     }

  //     // Try to parse the detailed error if available
  //     try {
  //       final details = e.details != null
  //           ? Map<String, dynamic>.from(e.details as Map)
  //           : null;

  //       return LyricsResult.failure(
  //         error: details?['error']?.toString() ??
  //             e.message ??
  //             'Unknown platform error',
  //         code: details?['code']?.toString() ?? e.code,
  //       );
  //     } catch (_) {
  //       return LyricsResult.failure(
  //         error: e.message ?? 'Unknown platform error',
  //         code: e.code,
  //       );
  //     }
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print('Unexpected error in fetchLyrics: $e');
  //     }
  //     return LyricsResult.failure(
  //       error: 'Failed to fetch lyrics: ${e.toString()}',
  //       code: 'UNKNOWN_ERROR',
  //     );
  //   }
  // }

  /// Cleans up resources
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
      return YTMusicResponse<void>(
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<ApiResponse<SystemStatus>> checkStatus() async {
    try {
      final result = await _channel.invokeMethod('checkStatus');

      if (result is Map) {
        final responseMap = Map<String, dynamic>.from(result);

        // Log the response for debugging
        print('Status check response: $responseMap');

        // Create SystemStatus from the response
        final systemStatus = SystemStatus.fromMap(responseMap);

        return ApiResponse<SystemStatus>(
          success: systemStatus.success,
          message: systemStatus.message,
          data: systemStatus,
        );
      } else {
        return ApiResponse<SystemStatus>(
          success: false,
          message:
              'Invalid response type: ${result.runtimeType}. Expected Map but got ${result.toString()}',
        );
      }
    } on PlatformException catch (e) {
      return ApiResponse<SystemStatus>(
        success: false,
        message: 'Platform error: ${e.message}',
      );
    } catch (e) {
      return ApiResponse<SystemStatus>(
        success: false,
        message: 'Unexpected error: ${e.toString()}',
      );
    }
  }

  /// Helper method to execute API calls with common error handling
  Future<YTMusicResponse<T>> _executeApiCall<T>(
      Future<T> Function() call) async {
    if (!_isInitialized) {
      return YTMusicResponse<T>(
        success: false,
        error: 'YTMusic API not initialized. Call initialize() first.',
      );
    }

    try {
      final data = await call();
      return YTMusicResponse<T>(
        success: true,
        data: data,
      );
    } catch (e) {
      return YTMusicResponse<T>(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Checks if the API is initialized
  bool get isInitialized => _isInitialized;
}

// 1. SystemStatus model class
class SystemStatus {
  final bool success;
  final String message;
  final bool ytmusicReady;
  final String ytmusicVersion;
  final bool ytdlpReady;
  final String ytdlpVersion;

  SystemStatus({
    required this.success,
    required this.message,
    required this.ytmusicReady,
    required this.ytmusicVersion,
    required this.ytdlpReady,
    required this.ytdlpVersion,
  });

  factory SystemStatus.fromMap(Map<String, dynamic> map) {
    return SystemStatus(
      success: map['success'] ?? false,
      message: map['message'] ?? 'Unknown',
      ytmusicReady: map['ytmusic_ready'] ?? false,
      ytmusicVersion: map['ytmusic_version'] ?? 'Unknown',
      ytdlpReady: map['ytdlp_ready'] ?? false,
      ytdlpVersion: map['ytdlp_version'] ?? 'Unknown',
    );
  }

  bool get isFullyOperational => ytmusicReady && ytdlpReady;

  String get statusSummary {
    if (isFullyOperational) {
      return 'All systems operational';
    } else if (ytmusicReady || ytdlpReady) {
      return 'Partial functionality available';
    } else {
      return 'System offline';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'message': message,
      'ytmusic_ready': ytmusicReady,
      'ytmusic_version': ytmusicVersion,
      'ytdlp_ready': ytdlpReady,
      'ytdlp_version': ytdlpVersion,
    };
  }
}

// Data Models
class LyricLine {
  final int timestamp; // in milliseconds
  final String text;
  final String timeFormatted; // MM:SS.mmm format

  const LyricLine({
    required this.timestamp,
    required this.text,
    required this.timeFormatted,
  });

  factory LyricLine.fromMap(Map<String, dynamic> map) {
    return LyricLine(
      timestamp: _parseTimestamp(map['timestamp']),
      text: map['text']?.toString() ?? '',
      timeFormatted: map['timeFormatted']?.toString() ??
          map['time_formatted']?.toString() ??
          _formatTimestamp(_parseTimestamp(map['timestamp'])),
    );
  }

  static int _parseTimestamp(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String _formatTimestamp(int ms) {
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final milliseconds =
        (duration.inMilliseconds.remainder(1000)).toString().padLeft(3, '0');
    return '$minutes:$seconds.$milliseconds';
  }

  Map<String, dynamic> toMap() => {
        'timestamp': timestamp,
        'text': text,
        'timeFormatted': timeFormatted,
      };

  @override
  String toString() => '[${timeFormatted}] $text';
}

class LyricsResult {
  final bool success;
  final List<LyricLine>? lyrics;
  final String? source;
  final int? totalLines;
  final String? error;
  final String? code;

  const LyricsResult({
    required this.success,
    this.lyrics,
    this.source,
    this.totalLines,
    this.error,
    this.code,
  });

  factory LyricsResult.fromMap(Map<String, dynamic> map) {
    try {
      final success = map['success'] == true;

      // Handle both 'total_lines' and 'totalLines'
      final totalLines = map['total_lines'] ?? map['totalLines'];

      // Parse lyrics lines
      List<LyricLine>? lyrics;
      final dynamic lyricsData = map['lyrics'];
      if (lyricsData is List) {
        lyrics = lyricsData
            .whereType<Map<String, dynamic>>()
            .map((item) => LyricLine.fromMap(item))
            .toList();
      }

      return LyricsResult(
        success: success,
        lyrics: lyrics,
        source: map['source']?.toString(),
        totalLines: totalLines is int ? totalLines : lyrics?.length,
        error: success ? null : (map['error']?.toString() ?? 'Unknown error'),
      );
    } catch (e) {
      return LyricsResult(
        success: false,
        error: 'Failed to parse lyrics response: $e',
      );
    }
  }

  factory LyricsResult.success({
    required List<LyricLine> lyrics,
    String? source,
  }) =>
      LyricsResult(
        success: true,
        lyrics: lyrics,
        source: source ?? 'KuGou',
        totalLines: lyrics.length,
      );

  factory LyricsResult.failure({
    required String error,
    String? code,
  }) =>
      LyricsResult(
        success: false,
        error: error,
        code: code,
      );

  @override
  String toString() {
    if (success) {
      return 'LyricsResult.success($totalLines lines from $source)';
    }
    return 'LyricsResult.failure($error)';
  }
}

/// Base exception for all lyrics-related errors
class LyricsException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const LyricsException(this.message, {this.code, this.details});

  @override
  String toString() =>
      'LyricsException: $message${code != null ? ' ($code)' : ''}';
}

/// Exception thrown when lyrics service is not initialized
class LyricsNotInitializedException extends LyricsException {
  const LyricsNotInitializedException()
      : super('Lyrics service not initialized. Call initialize() first.',
            code: 'NOT_INITIALIZED');
}

/// Exception thrown when lyrics are not available for a song
class LyricsNotAvailableException extends LyricsException {
  const LyricsNotAvailableException(String title, String artist)
      : super('No lyrics found for "$title" by "$artist"',
            code: 'NOT_AVAILABLE');
}

/// Exception thrown when there's a network error
class LyricsNetworkException extends LyricsException {
  const LyricsNetworkException()
      : super('Network error occurred while fetching lyrics',
            code: 'NETWORK_ERROR');
}

/// Exception thrown when there's an API error
class LyricsApiException extends LyricsException {
  const LyricsApiException(String message) : super(message, code: 'API_ERROR');
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
      title: map['title'] as String? ?? 'Unknown',
      artists: map['artists'] as String? ?? 'Unknown',
      videoId: map['videoId'] as String? ?? '',
      duration: map['duration'] as String?,
      year: map['year'] as String?,
      albumArt: map['albumArt'] as String?,
      audioUrl: map['audioUrl'] as String?,
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
      title: map['title']?.toString() ?? 'Unknown',
      artists: map['artists']?.toString() ?? 'Unknown',
      videoId: map['videoId']?.toString() ?? '',
      duration: map['duration']?.toString(),
      albumArt: map['albumArt']?.toString(),
      audioUrl: map['audioUrl']?.toString(),
      isOriginal: map['isOriginal'] is bool
          ? map['isOriginal'] as bool
          : (map['isOriginal']?.toString().toLowerCase() == 'true'),
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
