import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yt_flutter_musicapi/yt_flutter_musicapi.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YouTube Music API Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      home: MusicApiTestPage(),
    );
  }
}

class AppSettings {
  static int limit = 5;
  static AudioQuality audioQuality = AudioQuality.veryHigh;
  static ThumbnailQuality thumbnailQuality = ThumbnailQuality.veryHigh;
  static bool isDarkMode = false;
  static String mode = 'auto'; // 'auto', 'batch', or 'stream'
  static String artistName = 'Ed Sheeran';
  static List<Map<String, String>> testSongs = [
    {'title': 'Perfect', 'artist': 'Ed Sheeran'},
    {'title': 'Bad Guy', 'artist': 'Billie Eilish'},
    {'title': 'Blinding Lights', 'artist': 'The Weeknd'},
  ];
  static String relatedSongTitle = 'Perfect';
  static String relatedSongArtist = 'Ed Sheeran';
}

class Inspector {
  static void checkRules(List<dynamic> results, String operation) {
    print('🔍 INSPECTOR: Checking rules for $operation');

    if (results.isEmpty) {
      print('❌ INSPECTOR: No results returned');
      return;
    }

    if (results.length > AppSettings.limit) {
      print(
        '❌ INSPECTOR: Limit exceeded! Expected: ${AppSettings.limit}, Got: ${results.length}',
      );
    } else {
      print(
        '✅ INSPECTOR: Limit respected: ${results.length}/${AppSettings.limit}',
      );
    }

    for (int i = 0; i < results.length; i++) {
      var item = results[i];
      print('📋 INSPECTOR: Item ${i + 1}:');

      if (item is SearchResult) {
        _checkSearchResult(item);
      } else if (item is RelatedSong) {
        _checkRelatedSong(item);
      } else if (item is ArtistSong) {
        _checkArtistSong(item);
      } else if (item is SongDetail) {
        _checkSongDetail(item);
      }
    }
  }

  static void _checkArtistSong(ArtistSong song) {
    print('  Title: ${song.title}');
    print('  Artists: ${song.artists}');
    print('  Video ID: ${song.videoId}');
    print('  Duration: ${song.duration ?? 'N/A'}');
    print('  Artist Name: ${song.artistName}');

    if (song.albumArt != null) {
      print(
        '  ✅ Album Art: Available (${AppSettings.thumbnailQuality.value} quality)',
      );
    } else {
      print('  ❌ Album Art: Missing');
    }

    if (song.audioUrl != null) {
      print(
        '  ✅ Audio URL: Available (${AppSettings.audioQuality.value} quality)',
      );
    } else {
      print('  ❌ Audio URL: Missing');
    }
    print('  ---');
  }

  static void _checkSongDetail(SongDetail song) {
    print('  Title: ${song.title}');
    print('  Artists: ${song.artists}');
    print('  Video ID: ${song.videoId}');
    print('  Duration: ${song.duration ?? 'N/A'}');
    print('  Year: ${song.year ?? 'N/A'}');
    print('  Album: ${song.album ?? 'N/A'}');

    if (song.albumArt != null) {
      print(
        '  ✅ Album Art: Available (${AppSettings.thumbnailQuality.value} quality)',
      );
    } else {
      print('  ❌ Album Art: Missing');
    }

    if (song.audioUrl != null) {
      print(
        '  ✅ Audio URL: Available (${AppSettings.audioQuality.value} quality)',
      );
    } else {
      print('  ❌ Audio URL: Missing');
    }
    print('  ---');
  }

  static void _checkSearchResult(SearchResult result) {
    print('  Title: ${result.title}');
    print('  Artists: ${result.artists}');
    print('  Video ID: ${result.videoId}');
    print('  Duration: ${result.duration ?? 'N/A'}');
    print('  Year: ${result.year ?? 'N/A'}');

    if (result.albumArt != null) {
      print(
        '  ✅ Album Art: Available (${AppSettings.thumbnailQuality.value} quality)',
      );
    } else {
      print('  ❌ Album Art: Missing');
    }

    if (result.audioUrl != null) {
      print(
        '  ✅ Audio URL: Available (${AppSettings.audioQuality.value} quality)',
      );
    } else {
      print('  ❌ Audio URL: Missing');
    }
    print('  ---');
  }

  static void _checkRelatedSong(RelatedSong song) {
    print('  Title: ${song.title}');
    print('  Artists: ${song.artists}');
    print('  Video ID: ${song.videoId}');
    print('  Duration: ${song.duration ?? 'N/A'}');
    print('  Is Original: ${song.isOriginal}');

    if (song.albumArt != null) {
      print(
        '  ✅ Album Art: Available (${AppSettings.thumbnailQuality.value} quality)',
      );
    } else {
      print('  ❌ Album Art: Missing');
    }

    if (song.audioUrl != null) {
      print(
        '  ✅ Audio URL: Available (${AppSettings.audioQuality.value} quality)',
      );
    } else {
      print('  ❌ Audio URL: Missing');
    }
    print('  ---');
  }

  static void checkSingleSongDetail(SongDetail? songDetail, String operation) {
    print('🔍 INSPECTOR: Checking single song detail for $operation');

    if (songDetail == null) {
      print('❌ INSPECTOR: No song detail returned');
      return;
    }

    print('📋 INSPECTOR: Song Detail:');
    _checkSongDetail(songDetail);
  }
}

class MusicApiTestPage extends StatefulWidget {
  @override
  _MusicApiTestPageState createState() => _MusicApiTestPageState();
}

class _MusicApiTestPageState extends State<MusicApiTestPage> {
  final YtFlutterMusicapi _api = YtFlutterMusicapi();
  final List<String> _cliOutput = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _isInitialized = false;
  bool _isLoading = false;
  final List<ArtistSong> _songs = [];

  @override
  void initState() {
    super.initState();
    _addToCliOutput('🚀 YouTube Music API Test App Started');
    _addToCliOutput('ℹ️  Use the buttons below to test API methods');
    _addToCliOutput('⚙️  Configure settings using the gear icon');
  }

  void _addToCliOutput(String message) {
    setState(() {
      _cliOutput.add(
        '${DateTime.now().toString().substring(11, 19)} | $message',
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearCliOutput() {
    setState(() {
      _cliOutput.clear();
    });
    _addToCliOutput('🧹 CLI Output Cleared');
  }

  Future<void> _initializeApi() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    _addToCliOutput('🔄 Initializing YouTube Music API...');

    try {
      final response = await _api.initialize(country: 'US');

      if (response.success) {
        setState(() {
          _isInitialized = true;
        });
        _addToCliOutput('✅ API Initialized Successfully');
        _addToCliOutput('📋 Message: ${response.message ?? 'Ready to use'}');
      } else {
        _addToCliOutput('❌ API Initialization Failed');
        _addToCliOutput('📋 Error: ${response.error ?? 'Unknown error'}');
      }
    } catch (e) {
      _addToCliOutput('❌ Exception during initialization: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkStatus() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    _addToCliOutput('🔍 Checking API Status...');

    try {
      final response = await _api.checkStatus();

      if (response.success && response.data != null) {
        final status = response.data!;

        _addToCliOutput('✅ API Status: OK');
        _addToCliOutput('📋 Message: ${status.message}');

        _addToCliOutput(
          '🎵 YTMusic: ${status.ytmusicReady ? '✅ Ready' : '❌ Not Ready'} (v${status.ytmusicVersion})',
        );

        _addToCliOutput(
          '⬇️ yt-dlp: ${status.ytdlpReady ? '✅ Ready' : '❌ Not Ready'} (v${status.ytdlpVersion})',
        );

        if (status.isFullyOperational) {
          _addToCliOutput('🚀 All systems operational and ready!');
          _addToCliOutput('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          _addToCliOutput('📊 System Summary:');
          _addToCliOutput('   • YTMusic API: ✅ Operational');
          _addToCliOutput('   • yt-dlp Engine: ✅ Operational');
          _addToCliOutput('   • Ready for music operations');
        } else {
          _addToCliOutput('⚠️  Some components are not ready');
          _addToCliOutput('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          _addToCliOutput('📊 System Summary:');
          _addToCliOutput(
            '   • YTMusic API: ${status.ytmusicReady ? '✅' : '❌'} ${status.ytmusicReady ? 'Operational' : 'Failed'}',
          );
          _addToCliOutput(
            '   • yt-dlp Engine: ${status.ytdlpReady ? '✅' : '❌'} ${status.ytdlpReady ? 'Operational' : 'Failed'}',
          );
          _addToCliOutput('   • ${status.statusSummary}');
        }
      } else {
        _addToCliOutput('❌ API Status: Error');
        _addToCliOutput('📋 Message: ${response.message ?? 'Unknown status'}');

        if (response.data != null) {
          final status = response.data!;

          _addToCliOutput('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          _addToCliOutput('📊 Component Status:');

          _addToCliOutput(
            '🎵 YTMusic: ${status.ytmusicReady ? '✅' : '❌'} ${status.ytmusicReady ? 'Ready' : 'Failed'} (v${status.ytmusicVersion})',
          );

          _addToCliOutput(
            '⬇️ yt-dlp: ${status.ytdlpReady ? '✅' : '❌'} ${status.ytdlpReady ? 'Ready' : 'Failed'} (v${status.ytdlpVersion})',
          );

          _addToCliOutput('📋 Status: ${status.statusSummary}');
        }
      }
    } catch (e) {
      _addToCliOutput('❌ Exception during status check: $e');

      _addToCliOutput('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _addToCliOutput('💡 Troubleshooting Guide:');
      _addToCliOutput('   1. Check Python environment setup');
      _addToCliOutput(
        '   2. Verify ytmusicapi installation: pip install ytmusicapi',
      );
      _addToCliOutput('   3. Verify yt-dlp installation: pip install yt-dlp');
      _addToCliOutput('   4. Test network connectivity');
      _addToCliOutput('   5. Check system logs for detailed errors');

      print('Status check error details: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchMusic() async {
    if (_isLoading || !_isInitialized) {
      _addToCliOutput('❌ API not initialized or busy');
      return;
    }

    String query = _searchController.text.trim();
    if (query.isEmpty) {
      query = 'Billie Eilish bad guy';
      _searchController.text = query;
    }

    setState(() {
      _isLoading = true;
    });

    _addToCliOutput('🔍 Searching for: "$query"');
    _addToCliOutput(
      '📊 Settings: Limit=${AppSettings.limit}, Audio=${AppSettings.audioQuality.value}, Thumb=${AppSettings.thumbnailQuality.value}, Mode=${AppSettings.mode}',
    );

    try {
      if (AppSettings.mode == 'stream') {
        await _streamSearchResults(query: query);
      } else {
        final response = await _api.searchMusic(
          query: query,
          limit: AppSettings.limit,
          audioQuality: AppSettings.audioQuality,
          thumbQuality: AppSettings.thumbnailQuality,
          includeAudioUrl: true,
          includeAlbumArt: true,
        );

        if (response.success && response.data != null) {
          _addToCliOutput('✅ Search completed successfully');
          _addToCliOutput('📋 Found ${response.data!.length} results');

          for (int i = 0; i < response.data!.length; i++) {
            final result = response.data![i];
            _addToCliOutput('🎵 Result ${i + 1}:');
            _addToCliOutput('   Title: ${result.title}');
            _addToCliOutput('   Artists: ${result.artists}');
            _addToCliOutput('   Duration: ${result.duration ?? 'N/A'}');
            _addToCliOutput('   Year: ${result.year ?? 'N/A'}');
            _addToCliOutput('   Video ID: ${result.videoId}');
            _addToCliOutput(
              '   Album Art: ${result.albumArt != null ? 'Available and respected!' : 'N/A'}',
            );
            _addToCliOutput(
              '   Audio URL: ${result.audioUrl != null ? 'Available and respected!' : 'N/A'}',
            );
            _addToCliOutput('   ---');
          }

          Inspector.checkRules(response.data!, 'Search Music');
          _addToCliOutput('🎉 SUCCESS: Search operation completed');
        } else {
          _addToCliOutput('❌ Search failed');
          _addToCliOutput('📋 Error: ${response.error ?? 'Unknown error'}');
        }
      }
    } catch (e) {
      _addToCliOutput('❌ Exception during search: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _streamSearchResults({required String query}) async {
    int received = 0;
    final stopwatch = Stopwatch()..start();

    _addToCliOutput('📡 Streaming search results for: "$query"');

    try {
      await for (final result in _api.streamSearchResults(
        query: query,
        limit: AppSettings.limit,
        audioQuality: AppSettings.audioQuality,
        thumbQuality: AppSettings.thumbnailQuality,
        includeAudioUrl: true,
        includeAlbumArt: true,
      )) {
        received++;
        _addToCliOutput('🎧 Streamed Result $received:');
        _addToCliOutput('   Title: ${result.title}');
        _addToCliOutput('   Artists: ${result.artists}');
        _addToCliOutput('   Duration: ${result.duration ?? 'N/A'}');
        _addToCliOutput('   Video ID: ${result.videoId}');
        _addToCliOutput(
          '   Album Art: ${result.albumArt != null ? 'Available' : 'N/A'}',
        );
        _addToCliOutput(
          '   Audio URL: ${result.audioUrl != null ? 'Available' : 'N/A'}',
        );
        _addToCliOutput('   ---');

        if (received >= AppSettings.limit) {
          _addToCliOutput('⏹️ Streaming limit reached (${AppSettings.limit})');
          break;
        }
      }

      _addToCliOutput(
        '✅ Stream finished: $received result(s) in ${stopwatch.elapsedMilliseconds}ms',
      );
    } catch (e) {
      _addToCliOutput('❌ Streaming error: $e');
    }
  }

  // Add this method to your _MusicApiTestPageState class
  Future<void> _getRelatedSongs() async {
    if (_isLoading || !_isInitialized) {
      _addToCliOutput('❌ API not initialized or busy');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _addToCliOutput(
      '🔍 Getting related songs for: "${AppSettings.relatedSongTitle}" by ${AppSettings.relatedSongArtist}',
    );
    _addToCliOutput(
      '📊 Settings: Limit=${AppSettings.limit}, Audio=${AppSettings.audioQuality.value}, '
      'Thumb=${AppSettings.thumbnailQuality.value}, Mode=${AppSettings.mode}',
    );

    try {
      if (AppSettings.mode == 'stream') {
        await _streamRelatedSongs();
      } else {
        final response = await _api.getRelatedSongs(
          songName: AppSettings.relatedSongTitle,
          artistName: AppSettings.relatedSongArtist,
          limit: AppSettings.limit,
          audioQuality: AppSettings.audioQuality,
          thumbQuality: AppSettings.thumbnailQuality,
          includeAudioUrl: true,
          includeAlbumArt: true,
        );

        if (response.success && response.data != null) {
          _addToCliOutput('✅ Related songs retrieved successfully');
          _addToCliOutput('📋 Found ${response.data!.length} related songs');

          for (int i = 0; i < response.data!.length; i++) {
            final song = response.data![i];
            _addToCliOutput('🎵 Related Song ${i + 1}:');
            _addToCliOutput('   Title: ${song.title}');
            _addToCliOutput('   Artists: ${song.artists}');
            _addToCliOutput('   Duration: ${song.duration ?? 'N/A'}');
            _addToCliOutput('   Is Original: ${song.isOriginal}');
            _addToCliOutput('   Video ID: ${song.videoId}');
            _addToCliOutput(
              '   Album Art: ${song.albumArt != null ? 'Available' : 'N/A'}',
            );
            _addToCliOutput(
              '   Audio URL: ${song.audioUrl != null ? 'Available' : 'N/A'}',
            );
            _addToCliOutput('   ---');
          }

          Inspector.checkRules(response.data!, 'Related Songs');
          _addToCliOutput('🎉 SUCCESS: Related songs operation completed');
        } else {
          _addToCliOutput('❌ Failed to get related songs');
          _addToCliOutput('📋 Error: ${response.error ?? 'Unknown error'}');
        }
      }
    } catch (e) {
      _addToCliOutput('❌ Exception during related songs fetch: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _streamRelatedSongs() async {
    int received = 0;
    final stopwatch = Stopwatch()..start();

    try {
      await for (final song in _api.streamRelatedSongs(
        songName: AppSettings.relatedSongTitle,
        artistName: AppSettings.relatedSongArtist,
        limit: AppSettings.limit,
        audioQuality: AppSettings.audioQuality,
        thumbQuality: AppSettings.thumbnailQuality,
        includeAudioUrl: true,
        includeAlbumArt: true,
      )) {
        received++;
        _addToCliOutput(
          '🎵 Received related song $received in ${stopwatch.elapsedMilliseconds}ms:',
        );
        _addToCliOutput('   Title: ${song.title}');
        _addToCliOutput('   Artists: ${song.artists}');
        _addToCliOutput('   Duration: ${song.duration ?? 'N/A'}');
        _addToCliOutput('   Is Original: ${song.isOriginal}');
        _addToCliOutput('   Video ID: ${song.videoId}');
        _addToCliOutput(
          '   Album Art: ${song.albumArt != null ? 'Available' : 'N/A'}',
        );
        _addToCliOutput(
          '   Audio URL: ${song.audioUrl != null ? 'Available' : 'N/A'}',
        );
        _addToCliOutput('   ---');

        stopwatch.reset();
      }

      _addToCliOutput('✅ Streamed $received related songs successfully');
    } catch (e) {
      _addToCliOutput('❌ Exception during related songs stream: $e');
    }
  }

  Future<void> _getArtistSongs() async {
    if (_isLoading || !_isInitialized) {
      _addToCliOutput('❌ API not initialized or busy');
      return;
    }

    setState(() {
      _isLoading = true;
      _songs.clear();
    });

    _addToCliOutput(
      '🎤 Getting songs from artist: "${AppSettings.artistName}"',
    );
    _addToCliOutput(
      '📊 Settings: Limit=${AppSettings.limit}, '
      'Audio=${AppSettings.audioQuality.value}, '
      'Thumb=${AppSettings.thumbnailQuality.value}, '
      'Mode=${AppSettings.mode}',
    );

    try {
      if (AppSettings.mode == 'stream') {
        await _streamArtistSongs();
      } else {
        final response = await _api.getArtistSongs(
          artistName: AppSettings.artistName,
          limit: AppSettings.limit,
          audioQuality: AppSettings.audioQuality,
          thumbQuality: AppSettings.thumbnailQuality,
          includeAudioUrl: true,
          includeAlbumArt: true,
        );

        if (response.success && response.data != null) {
          _addToCliOutput('✅ Artist songs retrieved successfully');
          _addToCliOutput('📋 Found ${response.data!.length} songs');

          for (int i = 0; i < response.data!.length; i++) {
            final song = response.data![i];
            _addToCliOutput('🎵 Song ${i + 1}:');
            _addToCliOutput('   Title: ${song.title}');
            _addToCliOutput('   Artists: ${song.artists}');
            _addToCliOutput('   Duration: ${song.duration ?? 'N/A'}');
            _addToCliOutput('   Video ID: ${song.videoId}');
            _addToCliOutput('   Artist Name: ${song.artistName}');
            _addToCliOutput(
              '   Album Art: ${song.albumArt != null ? 'Available' : 'N/A'}',
            );
            _addToCliOutput(
              '   Audio URL: ${song.audioUrl != null ? 'Available' : 'N/A'}',
            );
            _addToCliOutput('   ---');

            setState(() {
              _songs.add(song);
            });
          }

          Inspector.checkRules(response.data!, 'Artist Songs');
          _addToCliOutput('🎉 SUCCESS: Artist songs operation completed');
        } else {
          _addToCliOutput('❌ Failed to get artist songs');
          _addToCliOutput('📋 Error: ${response.error ?? 'Unknown error'}');
        }
      }
    } catch (e) {
      _addToCliOutput('❌ Exception during artist songs fetch: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _streamArtistSongs() async {
    int received = 0;
    final stopwatch = Stopwatch()..start();

    try {
      await for (final song in _api.streamArtistSongs(
        artistName: AppSettings.artistName,
        limit: AppSettings.limit,
        audioQuality: AppSettings.audioQuality,
        thumbQuality: AppSettings.thumbnailQuality,
        includeAudioUrl: true,
        includeAlbumArt: true,
      )) {
        received++;
        _addToCliOutput(
          '🎵 Received song $received in ${stopwatch.elapsedMilliseconds}ms:',
        );
        _addToCliOutput('   Title: ${song.title}');
        _addToCliOutput('   Artists: ${song.artists}');
        _addToCliOutput('   Duration: ${song.duration ?? 'N/A'}');
        _addToCliOutput('   Video ID: ${song.videoId}');
        _addToCliOutput('   Artist Name: ${song.artistName}');
        _addToCliOutput(
          '   Album Art: ${song.albumArt != null ? 'Available' : 'N/A'}',
        );
        _addToCliOutput(
          '   Audio URL: ${song.audioUrl != null ? 'Available' : 'N/A'}',
        );
        _addToCliOutput('   ---');

        setState(() {
          _songs.add(song);
        });

        stopwatch.reset();
      }

      if (received > 0) {
        _addToCliOutput('✅ Streamed $received songs successfully');
        Inspector.checkRules(_songs, 'Artist Songs');
      } else {
        _addToCliOutput('❌ No songs were streamed');
      }
    } catch (e) {
      _addToCliOutput('❌ Exception during artist songs stream: $e');
    }
  }

  Future<void> _getSongDetails() async {
    if (_isLoading || !_isInitialized) {
      _addToCliOutput('❌ API not initialized or busy');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _addToCliOutput('🎵 Getting song details');
    _addToCliOutput(
      '📊 Settings: Mode=${AppSettings.mode}, Audio=${AppSettings.audioQuality.value}, Thumb=${AppSettings.thumbnailQuality.value}',
    );
    _addToCliOutput('📋 Test songs: ${AppSettings.testSongs.length} songs');

    for (int i = 0; i < AppSettings.testSongs.length; i++) {
      final song = AppSettings.testSongs[i];
      _addToCliOutput('   ${i + 1}. "${song['title']}" by ${song['artist']}');
    }

    try {
      final response = await _api.getSongDetails(
        songs: AppSettings.testSongs,
        mode: AppSettings.mode == 'batch' ? 'batch' : 'single',
        audioQuality: AppSettings.audioQuality,
        thumbQuality: AppSettings.thumbnailQuality,
        includeAudioUrl: true,
        includeAlbumArt: true,
      );

      if (response.success && response.data != null) {
        _addToCliOutput('✅ Song details retrieved successfully');

        if (AppSettings.mode != 'batch') {
          final songDetail = response.data as SongDetail?;
          if (songDetail != null) {
            _addToCliOutput('📋 Single song detail retrieved:');
            _addToCliOutput('🎵 Song Detail:');
            _addToCliOutput('   Title: ${songDetail.title}');
            _addToCliOutput('   Artists: ${songDetail.artists}');
            _addToCliOutput('   Duration: ${songDetail.duration ?? 'N/A'}');
            _addToCliOutput('   Video ID: ${songDetail.videoId}');
            _addToCliOutput('   Year: ${songDetail.year ?? 'N/A'}');
            _addToCliOutput('   Album: ${songDetail.album ?? 'N/A'}');
            _addToCliOutput(
              '   Album Art: ${songDetail.albumArt != null ? 'Available' : 'N/A'}',
            );
            _addToCliOutput(
              '   Audio URL: ${songDetail.audioUrl != null ? 'Available' : 'N/A'}',
            );
            _addToCliOutput('   ---');

            Inspector.checkSingleSongDetail(
              songDetail,
              'Song Details (Single)',
            );
          } else {
            _addToCliOutput('❌ No song detail returned');
          }
        } else {
          final songDetails = response.data as List<SongDetail>;
          _addToCliOutput('📋 Found ${songDetails.length} detailed songs');

          for (int i = 0; i < songDetails.length; i++) {
            final song = songDetails[i];
            _addToCliOutput('🎵 Song Detail ${i + 1}:');
            _addToCliOutput('   Title: ${song.title}');
            _addToCliOutput('   Artists: ${song.artists}');
            _addToCliOutput('   Duration: ${song.duration ?? 'N/A'}');
            _addToCliOutput('   Video ID: ${song.videoId}');
            _addToCliOutput('   Year: ${song.year ?? 'N/A'}');
            _addToCliOutput('   Album: ${song.album ?? 'N/A'}');
            _addToCliOutput(
              '   Album Art: ${song.albumArt != null ? 'Available' : 'N/A'}',
            );
            _addToCliOutput(
              '   Audio URL: ${song.audioUrl != null ? 'Available' : 'N/A'}',
            );
            _addToCliOutput('   ---');
          }

          Inspector.checkRules(songDetails, 'Song Details (Batch)');
        }

        _addToCliOutput('🎉 SUCCESS: Song details operation completed');
      } else {
        _addToCliOutput('❌ Failed to get song details');
        _addToCliOutput('📋 Error: ${response.error ?? 'Unknown error'}');
      }
    } catch (e) {
      _addToCliOutput('❌ Exception during song details fetch: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _disposeApi() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    _addToCliOutput('🗑️ Disposing API...');

    try {
      final response = await _api.dispose();

      if (response.success) {
        setState(() {
          _isInitialized = false;
        });
        _addToCliOutput('✅ API Disposed Successfully');
        _addToCliOutput(
          '📋 Message: ${response.message ?? 'Resources cleaned up'}',
        );
      } else {
        _addToCliOutput('❌ API Disposal Failed');
        _addToCliOutput('📋 Error: ${response.error ?? 'Unknown error'}');
      }
    } catch (e) {
      _addToCliOutput('❌ Exception during disposal: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        onSettingsChanged: () {
          setState(() {});
          _addToCliOutput('⚙️ Settings updated');
        },
        onClearCli: _clearCliOutput, // Add this line
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppSettings.isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(
        appBar: AppBar(
          title: Text('YouTube Music API Test'),
          actions: [
            IconButton(icon: Icon(Icons.settings), onPressed: _showSettings),
          ],
        ),
        body: Column(
          children: [
            // CLI Output Area
            Expanded(
              flex: 3,
              child: Container(
                margin: EdgeInsets.all(8),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppSettings.isDarkMode
                      ? Colors.grey[900]
                      : Colors.black,
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'CLI Output',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.clear, color: Colors.green),
                          onPressed: _clearCliOutput,
                          tooltip: 'Clear Output',
                        ),
                      ],
                    ),
                    Divider(color: Colors.green),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: _cliOutput.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 1),
                            child: Text(
                              _cliOutput[index],
                              style: TextStyle(
                                color: Colors.green,
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Search Input
            Padding(
              padding: EdgeInsets.all(8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText:
                      'Enter search query (default: Billie Eilish bad guy)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),

            // Test Buttons
            Expanded(
              flex: 2,
              child: Container(
                padding: EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text(
                      'Test Controls',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),

                    // Status Row
                    Row(
                      children: [
                        Icon(
                          _isInitialized ? Icons.check_circle : Icons.error,
                          color: _isInitialized ? Colors.green : Colors.red,
                        ),
                        SizedBox(width: 8),
                        Text(
                          _isInitialized
                              ? 'API Initialized'
                              : 'API Not Initialized',
                          style: TextStyle(
                            color: _isInitialized ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        if (_isLoading)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Button Grid
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        childAspectRatio: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            icon: Icon(Icons.play_arrow),
                            label: Text('Initialize'),
                            onPressed: _isLoading ? null : _initializeApi,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: Icon(Icons.info),
                            label: Text('Check Status'),
                            onPressed: _isLoading ? null : _checkStatus,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: Icon(Icons.search),
                            label: Text('Search Music'),
                            onPressed: (_isLoading || !_isInitialized)
                                ? null
                                : _searchMusic,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          // Add this button to your button grid (where you have other test buttons)
                          ElevatedButton.icon(
                            icon: Icon(Icons.queue_music),
                            label: Text('Related Songs'),
                            onPressed: (_isLoading || !_isInitialized)
                                ? null
                                : _getRelatedSongs,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: Icon(Icons.person),
                            label: Text('Artist Songs'),
                            onPressed: (_isLoading || !_isInitialized)
                                ? null
                                : _getArtistSongs,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: Icon(Icons.info_outline),
                            label: Text('Song Details'),
                            onPressed: (_isLoading || !_isInitialized)
                                ? null
                                : _getSongDetails,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: Icon(Icons.stop),
                            label: Text('Dispose'),
                            onPressed: _isLoading ? null : _disposeApi,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: Icon(Icons.settings),
                            label: Text('Settings'),
                            onPressed: _showSettings,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsDialog extends StatefulWidget {
  final VoidCallback onSettingsChanged;
  final VoidCallback onClearCli; // Add this line

  const SettingsDialog({
    required this.onSettingsChanged,
    required this.onClearCli, // Add this line
    Key? key,
  }) : super(key: key);

  @override
  _SettingsDialogState createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late int _limit;
  late AudioQuality _audioQuality;
  late ThumbnailQuality _thumbnailQuality;
  late bool _isDarkMode;
  late String _mode;
  late TextEditingController _artistController;

  @override
  void initState() {
    super.initState();
    _limit = AppSettings.limit;
    _audioQuality = AppSettings.audioQuality;
    _thumbnailQuality = AppSettings.thumbnailQuality;
    _isDarkMode = AppSettings.isDarkMode;
    _mode = AppSettings.mode;
    _artistController = TextEditingController(text: AppSettings.artistName);
  }

  @override
  void dispose() {
    _artistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Limit Setting
            ListTile(
              title: Text('Limit: $_limit'),
              subtitle: Slider(
                value: _limit.toDouble(),
                min: 1,
                max: 15,
                divisions: 14,
                onChanged: (value) {
                  setState(() {
                    _limit = value.toInt();
                  });
                },
              ),
            ),

            // Add this to your SettingsDialog build method (inside the Column)
            TextField(
              controller: TextEditingController(
                text: AppSettings.relatedSongTitle,
              ),
              decoration: InputDecoration(
                labelText: 'Related Song Title',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => AppSettings.relatedSongTitle = value,
            ),
            SizedBox(height: 8),
            TextField(
              controller: TextEditingController(
                text: AppSettings.relatedSongArtist,
              ),
              decoration: InputDecoration(
                labelText: 'Related Song Artist',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => AppSettings.relatedSongArtist = value,
            ),

            // Mode Selection
            ListTile(
              title: Text('Operation Mode'),
              subtitle: DropdownButton<String>(
                value: _mode,
                isExpanded: true,
                items: ['auto', 'batch', 'stream'].map((mode) {
                  return DropdownMenuItem(
                    value: mode,
                    child: Text(mode.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _mode = value;
                    });
                  }
                },
              ),
            ),

            // Artist Name Input
            TextField(
              controller: _artistController,
              decoration: InputDecoration(
                labelText: 'Artist Name for Testing',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 8),

            // Audio Quality Setting
            ListTile(
              title: Text('Audio Quality'),
              subtitle: DropdownButton<AudioQuality>(
                value: _audioQuality,
                isExpanded: true,
                items: AudioQuality.values.map((quality) {
                  return DropdownMenuItem(
                    value: quality,
                    child: Text(quality.value),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _audioQuality = value;
                    });
                  }
                },
              ),
            ),

            // Thumbnail Quality Setting
            ListTile(
              title: Text('Thumbnail Quality'),
              subtitle: DropdownButton<ThumbnailQuality>(
                value: _thumbnailQuality,
                isExpanded: true,
                items: ThumbnailQuality.values.map((quality) {
                  return DropdownMenuItem(
                    value: quality,
                    child: Text(quality.value),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _thumbnailQuality = value;
                    });
                  }
                },
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(Icons.clear),
              label: Text('Clear CLI Output'),
              onPressed: () {
                widget.onClearCli();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.blueGrey,
              ),
            ),

            // Dark Mode Toggle
            SwitchListTile(
              title: Text('Dark Mode'),
              value: _isDarkMode,
              onChanged: (value) {
                setState(() {
                  _isDarkMode = value;
                });
              },
            ),
          ],
        ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // Save settings
            AppSettings.limit = _limit;
            AppSettings.audioQuality = _audioQuality;
            AppSettings.thumbnailQuality = _thumbnailQuality;
            AppSettings.isDarkMode = _isDarkMode;
            AppSettings.mode = _mode;
            AppSettings.artistName = _artistController.text.trim();

            widget.onSettingsChanged();
            Navigator.of(context).pop();
          },
          child: Text('Save'),
        ),
      ],
    );
  }
}
