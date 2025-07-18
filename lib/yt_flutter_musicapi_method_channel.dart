import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'yt_flutter_musicapi_platform_interface.dart';

class MethodChannelYtFlutterMusicapi extends YtFlutterMusicapiPlatform {
  static const MethodChannel _methodChannel =
      MethodChannel('yt_flutter_musicapi');
  static const EventChannel _searchEventChannel =
      EventChannel('yt_flutter_musicapi/searchStream');
  static const EventChannel _relatedSongsEventChannel =
      EventChannel('yt_flutter_musicapi/relatedSongsStream');
  static const EventChannel _artistSongsEventChannel =
      EventChannel('yt_flutter_musicapi/artistSongsStream');

  @override
  Future<Map<String, dynamic>> initialize({
    String? proxy,
    String country = 'US',
  }) async {
    final result = await _methodChannel.invokeMethod('initialize', {
      'proxy': proxy,
      'country': country,
    });
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
    final result = await _methodChannel.invokeMethod('searchMusic', {
      'query': query,
      'limit': limit,
      'thumbQuality': thumbQuality,
      'audioQuality': audioQuality,
      'includeAudioUrl': includeAudioUrl,
      'includeAlbumArt': includeAlbumArt,
    });
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
    _methodChannel.invokeMethod('startStreamingSearch', {
      'query': query,
      'limit': limit,
      'thumbQuality': thumbQuality,
      'audioQuality': audioQuality,
      'includeAudioUrl': includeAudioUrl,
      'includeAlbumArt': includeAlbumArt,
    });

    return _searchEventChannel
        .receiveBroadcastStream({
          'query': query,
          'limit': limit,
          'thumbQuality': thumbQuality,
          'audioQuality': audioQuality,
          'includeAudioUrl': includeAudioUrl,
          'includeAlbumArt': includeAlbumArt,
        })
        .cast<Map<dynamic, dynamic>>()
        .map((event) => Map<String, dynamic>.from(event));
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
    final result = await _methodChannel.invokeMethod('getRelatedSongs', {
      'songName': songName,
      'artistName': artistName,
      'limit': limit,
      'thumbQuality': thumbQuality,
      'audioQuality': audioQuality,
      'includeAudioUrl': includeAudioUrl,
      'includeAlbumArt': includeAlbumArt,
    });
    return (result as Map).cast<String, dynamic>();
  }

  @override
  Stream<Map<String, dynamic>> streamRelatedSongs({
    required String songName,
    required String artistName,
    int limit = 10,
    String thumbQuality = 'VERY_HIGH',
    String audioQuality = 'VERY_HIGH',
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) {
    return _relatedSongsEventChannel.receiveBroadcastStream({
      'songName': songName,
      'artistName': artistName,
      'limit': limit,
      'thumbQuality': thumbQuality,
      'audioQuality': audioQuality,
      'includeAudioUrl': includeAudioUrl,
      'includeAlbumArt': includeAlbumArt,
    }).map((event) => Map<String, dynamic>.from(event));
  }

  @override
  Future<dynamic> getArtistSongs({
    required String artistName,
    int limit = 25,
    String thumbQuality = 'VERY_HIGH',
    String audioQuality = 'HIGH',
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod('getArtistSongs', {
        'artistName': artistName,
        'limit': limit,
        'thumbQuality': thumbQuality,
        'audioQuality': audioQuality,
        'includeAudioUrl': includeAudioUrl,
        'includeAlbumArt': includeAlbumArt,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint('PlatformException in getArtistSongs: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error in getArtistSongs: $e');
      rethrow;
    }
  }

  @override
  Stream<Map<String, dynamic>> streamArtistSongs({
    required String artistName,
    int limit = 25,
    String thumbQuality = 'VERY_HIGH',
    String audioQuality = 'HIGH',
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) {
    return _artistSongsEventChannel.receiveBroadcastStream({
      'artistName': artistName,
      'limit': limit,
      'thumbQuality': thumbQuality,
      'audioQuality': audioQuality,
      'includeAudioUrl': includeAudioUrl,
      'includeAlbumArt': includeAlbumArt,
    }).map((event) => Map<String, dynamic>.from(event));
  }

  @override
  Future<Map<String, dynamic>> fetchLyrics({
    required String title,
    required String artist,
    int? duration,
  }) async {
    final result = await _methodChannel.invokeMethod('getLyrics', {
      'title': title.trim(),
      'artist': artist.trim(),
      'duration': duration ?? -1,
    });
    return (result as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> dispose() async {
    final result = await _methodChannel.invokeMethod('dispose');
    return (result as Map).cast<String, dynamic>();
  }
}
