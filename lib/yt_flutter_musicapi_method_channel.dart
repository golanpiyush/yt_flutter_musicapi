import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'yt_flutter_musicapi_platform_interface.dart';

/// An implementation of [YtFlutterMusicapiPlatform] that uses method channels.
class MethodChannelYtFlutterMusicapi extends YtFlutterMusicapiPlatform {
  /// The method channel used to interact with the native platform.
  static const MethodChannel _methodChannel =
      MethodChannel('yt_flutter_musicapi');
  static const EventChannel _eventChannel =
      EventChannel('yt_flutter_musicapi/stream');

  @override
  Future<Map<String, dynamic>> initialize({
    String? proxy,
    String country = 'US',
  }) async {
    final result = await _methodChannel.invokeMethod(
      'initialize',
      {
        'proxy': proxy,
        'country': country,
      },
    );

    return (result as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> searchMusic({
    required String query,
    int limit = 10,
    String thumbQuality = 'VERY_HIGH',
    String audioQuality = 'VERY_HIGH',
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) async {
    final result = await _methodChannel.invokeMethod(
      'searchMusic',
      {
        'query': query,
        'limit': limit,
        'thumbQuality': thumbQuality,
        'audioQuality': audioQuality,
        'includeAudioUrl': includeAudioUrl,
        'includeAlbumArt': includeAlbumArt,
      },
    );

    return (result as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> getRelatedSongs({
    required String songName,
    required String artistName,
    int limit = 10,
    String thumbQuality = 'VERY_HIGH',
    String audioQuality = 'VERY_HIGH',
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) async {
    final result = await _methodChannel.invokeMethod(
      'getRelatedSongs',
      {
        'songName': songName,
        'artistName': artistName,
        'limit': limit,
        'thumbQuality': thumbQuality,
        'audioQuality': audioQuality,
        'includeAudioUrl': includeAudioUrl,
        'includeAlbumArt': includeAlbumArt,
      },
    );

    return (result as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> fetchLyrics({
    required String title,
    required String artist,
    int? duration,
  }) async {
    final result = await _methodChannel.invokeMethod(
      'getLyrics',
      {
        'title': title.trim(),
        'artist': artist.trim(),
        'duration': duration ?? -1,
      },
    );

    return (result as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> dispose() async {
    final result = await _methodChannel.invokeMethod('dispose');
    return (result as Map).cast<String, dynamic>();
  }

  @override
  Stream<Map<String, dynamic>> streamSearchResults({
    required String query,
    int limit = 10,
    String thumbQuality = 'VERY_HIGH',
    String audioQuality = 'VERY_HIGH',
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) {
    // ✅ Step 1: Start the native streaming process first
    _methodChannel.invokeMethod('startStreamingSearch', {
      'query': query,
      'limit': limit,
      'thumbQuality': thumbQuality,
      'audioQuality': audioQuality,
      'includeAudioUrl': includeAudioUrl,
      'includeAlbumArt': includeAlbumArt,
    });

    // ✅ Step 2: Don't reuse streams. Just return a fresh one.
    return _eventChannel
        .receiveBroadcastStream({
          'query': query,
          'limit': limit,
          'thumbQuality': thumbQuality,
          'audioQuality': audioQuality,
          'includeAudioUrl': includeAudioUrl,
          'includeAlbumArt': includeAlbumArt,
        }) // ✅ arguments passed correctly
        .cast<Map<dynamic, dynamic>>()
        .map((event) {
          debugPrint('[Dart] ✅ Stream event received: $event');
          return Map<String, dynamic>.from(event);
        });
  }
}
