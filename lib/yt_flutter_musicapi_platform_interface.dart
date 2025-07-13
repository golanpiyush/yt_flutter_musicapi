import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'yt_flutter_musicapi_method_channel.dart';

abstract class YtFlutterMusicapiPlatform extends PlatformInterface {
  /// Constructs a YtFlutterMusicapiPlatform.
  YtFlutterMusicapiPlatform() : super(token: _token);

  static final Object _token = Object();

  static YtFlutterMusicapiPlatform _instance = MethodChannelYtFlutterMusicapi();

  /// The default instance of [YtFlutterMusicapiPlatform] to use.
  ///
  /// Defaults to [MethodChannelYtFlutterMusicapi].
  static YtFlutterMusicapiPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [YtFlutterMusicapiPlatform] when
  /// they register themselves.
  static set instance(YtFlutterMusicapiPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<Map<String, dynamic>> initialize({
    String? proxy,
    String country = 'US',
  }) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  Future<Map<String, dynamic>> searchMusic({
    required String query,
    int limit = 10,
    String thumbQuality = 'VERY_HIGH',
    String audioQuality = 'VERY_HIGH',
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) {
    throw UnimplementedError('searchMusic() has not been implemented.');
  }

  Stream<Map<String, dynamic>> streamSearchResults({
    required String query,
    int limit = 10,
    String thumbQuality = 'VERY_HIGH',
    String audioQuality = 'VERY_HIGH',
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) {
    throw UnimplementedError('streamSearchResults() has not been implemented.');
  }

  Future<Map<String, dynamic>> getRelatedSongs({
    required String songName,
    required String artistName,
    int limit = 10,
    String thumbQuality = 'VERY_HIGH',
    String audioQuality = 'VERY_HIGH',
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) {
    throw UnimplementedError('getRelatedSongs() has not been implemented.');
  }

  /// Fetch lyrics for a song by title and artist
  Future<Map<String, dynamic>> fetchLyrics({
    required String title,
    required String artist,
    int? duration,
  }) {
    throw UnimplementedError('fetchLyrics() has not been implemented.');
  }

  Future<Map<String, dynamic>> dispose() {
    throw UnimplementedError('dispose() has not been implemented.');
  }
}
