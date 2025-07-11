import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yt_flutter_musicapi/yt_flutter_musicapi.dart';
import 'package:yt_flutter_musicapi/yt_flutter_musicapi_platform_interface.dart';

class MockYtMusicPlatform extends Mock implements YtFlutterMusicapiPlatform {}

void main() {
  final mockPlatform = MockYtMusicPlatform();
  final api = YtFlutterMusicapi();

  setUp(() {
    YtFlutterMusicapiPlatform.instance = mockPlatform;
  });

  group('YTMusic API Tests', () {
    test('Initialize API', () async {
      when(() => mockPlatform.initialize(
              proxy: any(named: 'proxy'), country: any(named: 'country')))
          .thenAnswer((_) async => {'success': true, 'message': 'Initialized'});

      final response = await api.initialize();
      expect(response.success, true);
      expect(response.message, 'Initialized');
    });

    test('Search Music returns mock result', () async {
      await api
          .initialize(); // Mark initialized manually since mock doesn't change _isInitialized
      api
          .initialize()
          .then((_) {}); // Prevent actual initialization from failing logic

      when(() => mockPlatform.searchMusic(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            thumbQuality: any(named: 'thumbQuality'),
            audioQuality: any(named: 'audioQuality'),
            includeAudioUrl: any(named: 'includeAudioUrl'),
            includeAlbumArt: any(named: 'includeAlbumArt'),
          )).thenAnswer((_) async => {
            'success': true,
            'results': [
              {
                'title': 'Test Song',
                'artists': 'Test Artist',
                'videoId': 'abc123',
                'duration': '3:45',
                'year': '2024',
                'albumArt': 'url',
                'audioUrl': 'stream_url',
              }
            ]
          });

      final result = await api.searchMusic(query: 'test');
      expect(result.success, true);
      expect(result.data, isA<List<SearchResult>>());
      expect(result.data!.first.title, 'Test Song');
    });

    test('Dispose API', () async {
      when(() => mockPlatform.dispose())
          .thenAnswer((_) async => {'success': true, 'message': 'Disposed'});

      final response = await api.dispose();
      expect(response.success, true);
      expect(response.message, 'Disposed');
    });
  });
}
