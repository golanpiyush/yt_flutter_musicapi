import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'yt_flutter_musicapi_platform_interface.dart';

/// An implementation of [YtFlutterMusicapiPlatform] that uses method channels.
class MethodChannelYtFlutterMusicapi extends YtFlutterMusicapiPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('yt_flutter_musicapi');

  @override
  Future<Map<String, dynamic>> initialize({
    String? proxy,
    String country = 'US',
  }) async {
    final result = await methodChannel.invokeMethod<Map<String, dynamic>>(
      'initialize',
      {'proxy': proxy, 'country': country},
    );
    return result ?? {};
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
    final result = await methodChannel
        .invokeMethod<Map<String, dynamic>>('searchMusic', {
          'query': query,
          'limit': limit,
          'thumbQuality': thumbQuality,
          'audioQuality': audioQuality,
          'includeAudioUrl': includeAudioUrl,
          'includeAlbumArt': includeAlbumArt,
        });
    return result ?? {};
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
    final result = await methodChannel
        .invokeMethod<Map<String, dynamic>>('getRelatedSongs', {
          'songName': songName,
          'artistName': artistName,
          'limit': limit,
          'thumbQuality': thumbQuality,
          'audioQuality': audioQuality,
          'includeAudioUrl': includeAudioUrl,
          'includeAlbumArt': includeAlbumArt,
        });
    return result ?? {};
  }

  @override
  Future<Map<String, dynamic>> dispose() async {
    final result = await methodChannel.invokeMethod<Map<String, dynamic>>(
      'dispose',
    );
    return result ?? {};
  }
}
