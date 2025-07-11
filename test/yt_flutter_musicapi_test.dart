import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import '../lib/yt_flutter_musicapi.dart';

void main() {
  group('YouTube Music API Tests', () {
    late YtFlutterMusicapi api;
    TestWidgetsFlutterBinding.ensureInitialized();

    setUp(() {
      api = YtFlutterMusicapi();
    });

    group('Initialization Tests', () {
      test('should initialize API successfully', () async {
        // Mock the platform interface
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('yt_flutter_musicapi'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'initialize':
                return {
                  'success': true,
                  'message': 'API initialized successfully',
                };
              default:
                return null;
            }
          },
        );

        final response = await api.initialize();

        expect(response.success, true);
        expect(response.message, 'API initialized successfully');
        expect(api.isInitialized, true);
      });

      test('should handle initialization failure', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('yt_flutter_musicapi'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'initialize':
                return {
                  'success': false,
                  'error': 'Network error',
                };
              default:
                return null;
            }
          },
        );

        final response = await api.initialize();

        expect(response.success, false);
        expect(response.error, contains('Network error'));
        expect(api.isInitialized, false);
      });

      test('should initialize with custom parameters', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('yt_flutter_musicapi'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'initialize':
                final args = methodCall.arguments as Map;
                expect(args['country'], 'UK');
                expect(args['proxy'], 'http://proxy.example.com');
                return {
                  'success': true,
                  'message': 'API initialized with custom settings',
                };
              default:
                return null;
            }
          },
        );

        final response = await api.initialize(
          country: 'UK',
          proxy: 'http://proxy.example.com',
        );

        expect(response.success, true);
        expect(response.message, 'API initialized with custom settings');
      });
    });

    group('Search Music Tests', () {
      setUp(() async {
        // Mock successful initialization
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('yt_flutter_musicapi'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'initialize':
                return {
                  'success': true,
                  'message': 'API initialized successfully',
                };
              default:
                return null;
            }
          },
        );

        await api.initialize();
      });

      test('should search music successfully', () async {
        final mockResults = [
          {
            'title': 'Bad Guy',
            'artists': 'Billie Eilish',
            'videoId': 'DyDfgMOUjCI',
            'duration': '3:14',
            'year': '2019',
            'albumArt': 'https://example.com/art1.jpg',
            'audioUrl': 'https://example.com/audio1.mp3',
          },
          {
            'title': 'When the Party\'s Over',
            'artists': 'Billie Eilish',
            'videoId': 'pbMwTqkKSps',
            'duration': '3:16',
            'year': '2018',
            'albumArt': 'https://example.com/art2.jpg',
            'audioUrl': 'https://example.com/audio2.mp3',
          },
        ];

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('yt_flutter_musicapi'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'initialize':
                return {
                  'success': true,
                  'message': 'API initialized successfully'
                };
              case 'searchMusic':
                final args = methodCall.arguments as Map;
                expect(args['query'], 'Billie Eilish');
                expect(args['limit'], 5);
                expect(args['audioQuality'], 'VERY_HIGH');
                expect(args['thumbQuality'], 'VERY_HIGH');
                expect(args['includeAudioUrl'], true);
                expect(args['includeAlbumArt'], true);

                return {
                  'success': true,
                  'results': mockResults,
                  'count': mockResults.length,
                };
              default:
                return null;
            }
          },
        );

        final response = await api.searchMusic(
          query: 'Billie Eilish',
          limit: 5,
          audioQuality: AudioQuality.veryHigh,
          thumbQuality: ThumbnailQuality.veryHigh,
        );

        expect(response.success, true);
        expect(response.data, isNotNull);
        expect(response.data!.length, 2);

        final firstResult = response.data![0];
        expect(firstResult.title, 'Bad Guy');
        expect(firstResult.artists, 'Billie Eilish');
        expect(firstResult.videoId, 'DyDfgMOUjCI');
        expect(firstResult.duration, '3:14');
        expect(firstResult.year, '2019');
        expect(firstResult.albumArt, isNotNull);
        expect(firstResult.audioUrl, isNotNull);
      });

      test('should handle search with different quality settings', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('yt_flutter_musicapi'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'initialize':
                return {
                  'success': true,
                  'message': 'API initialized successfully'
                };
              case 'searchMusic':
                final args = methodCall.arguments as Map;
                expect(args['audioQuality'], 'LOW');
                expect(args['thumbQuality'], 'MED');
                expect(args['limit'], 3);

                return {
                  'success': true,
                  'results': [
                    {
                      'title': 'Test Song',
                      'artists': 'Test Artist',
                      'videoId': 'test123',
                      'duration': '2:30',
                      'albumArt': 'https://example.com/test.jpg',
                      'audioUrl': 'https://example.com/test.mp3',
                    }
                  ],
                };
              default:
                return null;
            }
          },
        );

        final response = await api.searchMusic(
          query: 'test',
          limit: 3,
          audioQuality: AudioQuality.low,
          thumbQuality: ThumbnailQuality.med,
        );

        expect(response.success, true);
        expect(response.data!.length, 1);
      });

      test('should handle search failure', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('yt_flutter_musicapi'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'initialize':
                return {
                  'success': true,
                  'message': 'API initialized successfully'
                };
              case 'searchMusic':
                throw PlatformException(
                  code: 'SEARCH_ERROR',
                  message: 'Network timeout',
                );
              default:
                return null;
            }
          },
        );

        final response = await api.searchMusic(query: 'test');

        expect(response.success, false);
        expect(response.error, contains('Network timeout'));
      });

      test('should fail search when not initialized', () async {
        final newApi = YtFlutterMusicapi();

        final response = await newApi.searchMusic(query: 'test');

        expect(response.success, false);
        expect(response.error, contains('not initialized'));
      });
    });

    group('Related Songs Tests', () {
      setUp(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('yt_flutter_musicapi'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'initialize':
                return {
                  'success': true,
                  'message': 'API initialized successfully',
                };
              default:
                return null;
            }
          },
        );

        await api.initialize();
      });

      test('should get related songs successfully', () async {
        final mockRelatedSongs = [
          {
            'title': 'Thinking Out Loud',
            'artists': 'Ed Sheeran',
            'videoId': 'lp-EO5I60KA',
            'duration': '4:41',
            'albumArt': 'https://example.com/thinking.jpg',
            'audioUrl': 'https://example.com/thinking.mp3',
            'isOriginal': false,
          },
          {
            'title': 'Perfect',
            'artists': 'Ed Sheeran',
            'videoId': '2Vv-BfVoq4g',
            'duration': '4:23',
            'albumArt': 'https://example.com/perfect.jpg',
            'audioUrl': 'https://example.com/perfect.mp3',
            'isOriginal': true,
          },
        ];

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('yt_flutter_musicapi'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'initialize':
                return {
                  'success': true,
                  'message': 'API initialized successfully'
                };
              case 'getRelatedSongs':
                final args = methodCall.arguments as Map;
                expect(args['songName'], 'Perfect');
                expect(args['artistName'], 'Ed Sheeran');
                expect(args['limit'], 10);
                expect(args['audioQuality'], 'VERY_HIGH');
                expect(args['thumbQuality'], 'VERY_HIGH');

                return {
                  'success': true,
                  'results': mockRelatedSongs,
                  'count': mockRelatedSongs.length,
                };
              default:
                return null;
            }
          },
        );

        final response = await api.getRelatedSongs(
          songName: 'Perfect',
          artistName: 'Ed Sheeran',
          limit: 10,
        );

        expect(response.success, true);
        expect(response.data, isNotNull);
        expect(response.data!.length, 2);

        final firstSong = response.data![0];
        expect(firstSong.title, 'Thinking Out Loud');
        expect(firstSong.artists, 'Ed Sheeran');
        expect(firstSong.isOriginal, false);

        final secondSong = response.data![1];
        expect(secondSong.title, 'Perfect');
        expect(secondSong.isOriginal, true);
      });

      test('should handle related songs with different settings', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('yt_flutter_musicapi'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'initialize':
                return {
                  'success': true,
                  'message': 'API initialized successfully'
                };
              case 'getRelatedSongs':
                final args = methodCall.arguments as Map;
                expect(args['limit'], 5);
                expect(args['audioQuality'], 'HIGH');
                expect(args['thumbQuality'], 'LOW');
                expect(args['includeAudioUrl'], false);
                expect(args['includeAlbumArt'], false);

                return {
                  'success': true,
                  'results': [
                    {
                      'title': 'Shape of You',
                      'artists': 'Ed Sheeran',
                      'videoId': 'JGwWNGJdvx8',
                      'duration': '3:53',
                      'isOriginal': false,
                    }
                  ],
                };
              default:
                return null;
            }
          },
        );

        final response = await api.getRelatedSongs(
          songName: 'Perfect',
          artistName: 'Ed Sheeran',
          limit: 5,
          audioQuality: AudioQuality.high,
          thumbQuality: ThumbnailQuality.low,
          includeAudioUrl: false,
          includeAlbumArt: false,
        );

        expect(response.success, true);
        expect(response.data!.length, 1);
        expect(response.data![0].albumArt, isNull);
        expect(response.data![0].audioUrl, isNull);
      });

      test('should handle related songs failure', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('yt_flutter_musicapi'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'initialize':
                return {
                  'success': true,
                  'message': 'API initialized successfully'
                };
              case 'getRelatedSongs':
                throw PlatformException(
                  code: 'RELATED_ERROR',
                  message: 'Song not found',
                );
              default:
                return null;
            }
          },
        );

        final response = await api.getRelatedSongs(
          songName: 'NonExistent',
          artistName: 'Unknown Artist',
        );

        expect(response.success, false);
        expect(response.error, contains('Song not found'));
      });
    });

    group('Status Check Tests', () {
      test('should check API status successfully', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('yt_flutter_musicapi'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'checkStatus':
                return {
                  'success': true,
                  'message': 'API is running smoothly',
                };
              default:
                return null;
            }
          },
        );

        final response = await api.checkStatus();

        expect(response.success, true);
        expect(response.message, 'API is running smoothly');
      });

      test('should handle status check failure', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('yt_flutter_musicapi'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'checkStatus':
                return {
                  'success': false,
                  'message': 'Service unavailable',
                };
              default:
                return null;
            }
          },
        );

        final response = await api.checkStatus();

        expect(response.success, false);
        expect(response.message, 'Service unavailable');
      });
    });

    group('Dispose Tests', () {
      test('should dispose API successfully', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('yt_flutter_musicapi'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'initialize':
                return {
                  'success': true,
                  'message': 'API initialized successfully'
                };
              case 'dispose':
                return {
                  'success': true,
                  'message': 'API disposed successfully',
                };
              default:
                return null;
            }
          },
        );

        await api.initialize();
        expect(api.isInitialized, true);

        final response = await api.dispose();

        expect(response.success, true);
        expect(response.message, 'API disposed successfully');
        expect(api.isInitialized, false);
      });

      test('should handle dispose failure', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('yt_flutter_musicapi'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'initialize':
                return {
                  'success': true,
                  'message': 'API initialized successfully'
                };
              case 'dispose':
                return {
                  'success': false,
                  'error': 'Disposal failed',
                };
              default:
                return null;
            }
          },
        );

        await api.initialize();

        final response = await api.dispose();

        expect(response.success, false);
        expect(response.error, 'Disposal failed');
      });
    });

    group('Data Model Tests', () {
      test('SearchResult should serialize and deserialize correctly', () {
        final map = {
          'title': 'Test Song',
          'artists': 'Test Artist',
          'videoId': 'test123',
          'duration': '3:30',
          'year': '2023',
          'albumArt': 'https://example.com/art.jpg',
          'audioUrl': 'https://example.com/audio.mp3',
        };

        final result = SearchResult.fromMap(map);

        expect(result.title, 'Test Song');
        expect(result.artists, 'Test Artist');
        expect(result.videoId, 'test123');
        expect(result.duration, '3:30');
        expect(result.year, '2023');
        expect(result.albumArt, 'https://example.com/art.jpg');
        expect(result.audioUrl, 'https://example.com/audio.mp3');

        final serialized = result.toMap();
        expect(serialized['title'], 'Test Song');
        expect(serialized['artists'], 'Test Artist');
        expect(serialized['videoId'], 'test123');
      });

      test('RelatedSong should serialize and deserialize correctly', () {
        final map = {
          'title': 'Related Song',
          'artists': 'Related Artist',
          'videoId': 'related123',
          'duration': '2:45',
          'albumArt': 'https://example.com/related.jpg',
          'audioUrl': 'https://example.com/related.mp3',
          'isOriginal': true,
        };

        final song = RelatedSong.fromMap(map);

        expect(song.title, 'Related Song');
        expect(song.artists, 'Related Artist');
        expect(song.videoId, 'related123');
        expect(song.duration, '2:45');
        expect(song.albumArt, 'https://example.com/related.jpg');
        expect(song.audioUrl, 'https://example.com/related.mp3');
        expect(song.isOriginal, true);

        final serialized = song.toMap();
        expect(serialized['title'], 'Related Song');
        expect(serialized['isOriginal'], true);
      });

      test('should handle missing fields gracefully', () {
        final incompleteMap = {
          'title': 'Incomplete Song',
          'artists': 'Incomplete Artist',
          'videoId': 'incomplete123',
        };

        final result = SearchResult.fromMap(incompleteMap);

        expect(result.title, 'Incomplete Song');
        expect(result.artists, 'Incomplete Artist');
        expect(result.videoId, 'incomplete123');
        expect(result.duration, isNull);
        expect(result.year, isNull);
        expect(result.albumArt, isNull);
        expect(result.audioUrl, isNull);
      });
    });

    group('Enum Tests', () {
      test('AudioQuality enum should have correct values', () {
        expect(AudioQuality.low.value, 'LOW');
        expect(AudioQuality.med.value, 'MED');
        expect(AudioQuality.high.value, 'HIGH');
        expect(AudioQuality.veryHigh.value, 'VERY_HIGH');
      });

      test('ThumbnailQuality enum should have correct values', () {
        expect(ThumbnailQuality.low.value, 'LOW');
        expect(ThumbnailQuality.med.value, 'MED');
        expect(ThumbnailQuality.high.value, 'HIGH');
        expect(ThumbnailQuality.veryHigh.value, 'VERY_HIGH');
      });
    });

    group('Response Wrapper Tests', () {
      test('YTMusicResponse should parse correctly', () {
        final map = {
          'success': true,
          'results': ['data1', 'data2'],
          'message': 'Success message',
          'count': 2,
        };

        final response = YTMusicResponse<List<String>>.fromMap(map);

        expect(response.success, true);
        expect(response.data, ['data1', 'data2']);
        expect(response.message, 'Success message');
        expect(response.count, 2);
      });

      test('ApiResponse should parse correctly', () {
        final map = {
          'success': false,
          'message': 'Error occurred',
          'results': null,
        };

        final response = ApiResponse<String>.fromMap(map);

        expect(response.success, false);
        expect(response.message, 'Error occurred');
        expect(response.data, isNull);
      });
    });

    group('Integration Tests', () {
      test('should perform complete workflow', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('yt_flutter_musicapi'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'initialize':
                return {'success': true, 'message': 'Initialized'};
              case 'searchMusic':
                return {
                  'success': true,
                  'results': [
                    {
                      'title': 'Perfect',
                      'artists': 'Ed Sheeran',
                      'videoId': '2Vv-BfVoq4g',
                      'duration': '4:23',
                      'albumArt': 'https://example.com/perfect.jpg',
                      'audioUrl': 'https://example.com/perfect.mp3',
                    }
                  ],
                };
              case 'getRelatedSongs':
                return {
                  'success': true,
                  'results': [
                    {
                      'title': 'Thinking Out Loud',
                      'artists': 'Ed Sheeran',
                      'videoId': 'lp-EO5I60KA',
                      'duration': '4:41',
                      'isOriginal': false,
                    }
                  ],
                };
              case 'checkStatus':
                return {'success': true, 'message': 'Running'};
              case 'dispose':
                return {'success': true, 'message': 'Disposed'};
              default:
                return null;
            }
          },
        );

        // Initialize
        var response = await api.initialize();
        expect(response.success, true);
        expect(api.isInitialized, true);

        // Search
        final searchResponse =
            await api.searchMusic(query: 'Ed Sheeran Perfect');
        expect(searchResponse.success, true);
        expect(searchResponse.data!.length, 1);

        // Get related songs
        final relatedResponse = await api.getRelatedSongs(
          songName: 'Perfect',
          artistName: 'Ed Sheeran',
        );
        expect(relatedResponse.success, true);
        expect(relatedResponse.data!.length, 1);

        // Check status
        final statusResponse = await api.checkStatus();
        expect(statusResponse.success, true);

        // Dispose
        final disposeResponse = await api.dispose();
        expect(disposeResponse.success, true);
        expect(api.isInitialized, false);
      });

      test('should handle limit constraints properly', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('yt_flutter_musicapi'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'initialize':
                return {'success': true, 'message': 'Initialized'};
              case 'searchMusic':
                final args = methodCall.arguments as Map;
                final limit = args['limit'] as int;

                // Simulate returning exactly the requested limit
                final results = List.generate(
                    limit,
                    (index) => {
                          'title': 'Song $index',
                          'artists': 'Artist $index',
                          'videoId': 'video$index',
                          'duration': '3:${index.toString().padLeft(2, '0')}',
                        });

                return {
                  'success': true,
                  'results': results,
                  'count': results.length,
                };
              default:
                return null;
            }
          },
        );

        await api.initialize();

        // Test different limits
        for (int limit in [1, 5, 10, 15]) {
          final response = await api.searchMusic(
            query: 'test',
            limit: limit,
          );

          expect(response.success, true);
          expect(response.data!.length, limit);
          print('✅ Limit $limit test passed: ${response.data!.length} results');
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('yt_flutter_musicapi'),
        null,
      );
    });
  });
}
