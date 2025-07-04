import 'package:flutter/material.dart';
import 'package:yt_flutter_musicapi/yt_flutter_musicapi.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final YtFlutterMusicapi _ytMusicApi = YtFlutterMusicapi();
  List<SearchResult> _searchResults = [];
  List<RelatedSong> _relatedSongs = [];
  bool _isLoading = false;
  String _status = 'Not initialized';

  @override
  void initState() {
    super.initState();
    _initializeAPI();
  }

  Future<void> _initializeAPI() async {
    setState(() {
      _isLoading = true;
      _status = 'Initializing...';
    });

    try {
      final response = await _ytMusicApi.initialize(
        proxy: null, // Add proxy if needed
        country: 'US',
      );

      setState(() {
        _isLoading = false;
        _status = response.success
            ? 'Initialized successfully'
            : 'Failed to initialize: ${response.error}';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _searchMusic() async {
    if (!_ytMusicApi.isInitialized) {
      _showSnackBar('API not initialized');
      return;
    }

    setState(() {
      _isLoading = true;
      _searchResults.clear();
    });

    try {
      final response = await _ytMusicApi.searchMusic(
        query: 'Gale Lag Ja',
        limit: 10,
        thumbQuality: ThumbnailQuality.veryHigh,
        audioQuality: AudioQuality.veryHigh,
        includeAudioUrl: true,
        includeAlbumArt: true,
      );

      setState(() {
        _isLoading = false;
        if (response.success && response.data != null) {
          _searchResults = response.data!;
        } else {
          _showSnackBar('Search failed: ${response.error}');
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error: $e');
    }
  }

  Future<void> _getRelatedSongs() async {
    if (!_ytMusicApi.isInitialized) {
      _showSnackBar('API not initialized');
      return;
    }

    setState(() {
      _isLoading = true;
      _relatedSongs.clear();
    });

    try {
      final response = await _ytMusicApi.getRelatedSongs(
        songName: 'Viva La Vida',
        artistName: 'Coldplay',
        limit: 10,
        thumbQuality: ThumbnailQuality.veryHigh,
        audioQuality: AudioQuality.veryHigh,
        includeAudioUrl: true,
        includeAlbumArt: true,
      );

      setState(() {
        _isLoading = false;
        if (response.success && response.data != null) {
          _relatedSongs = response.data!;
        } else {
          _showSnackBar('Failed to get related songs: ${response.error}');
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('YT Music API Demo')),
        body: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status: $_status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text('Initialized: ${_ytMusicApi.isInitialized}'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _isLoading ? null : _searchMusic,
                    child: Text('Search Music'),
                  ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _getRelatedSongs,
                    child: Text('Get Related'),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Loading indicator
              if (_isLoading) Center(child: CircularProgressIndicator()),

              // Results
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        tabs: [
                          Tab(
                            text: 'Search Results (${_searchResults.length})',
                          ),
                          Tab(text: 'Related Songs (${_relatedSongs.length})'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Search Results Tab
                            _searchResults.isEmpty
                                ? Center(child: Text('No search results'))
                                : ListView.builder(
                                    itemCount: _searchResults.length,
                                    itemBuilder: (context, index) {
                                      final result = _searchResults[index];
                                      return Card(
                                        child: ListTile(
                                          leading: result.albumArt != null
                                              ? Image.network(
                                                  result.albumArt!,
                                                  width: 50,
                                                  height: 50,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => Icon(
                                                        Icons.music_note,
                                                      ),
                                                )
                                              : Icon(Icons.music_note),
                                          title: Text(result.title),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('Artist: ${result.artists}'),
                                              if (result.duration != null)
                                                Text(
                                                  'Duration: ${result.duration}',
                                                ),
                                              if (result.year != null)
                                                Text('Year: ${result.year}'),
                                            ],
                                          ),
                                          trailing: result.audioUrl != null
                                              ? Icon(
                                                  Icons.play_circle_fill,
                                                  color: Colors.green,
                                                )
                                              : null,
                                        ),
                                      );
                                    },
                                  ),
                            // Related Songs Tab
                            _relatedSongs.isEmpty
                                ? Center(child: Text('No related songs'))
                                : ListView.builder(
                                    itemCount: _relatedSongs.length,
                                    itemBuilder: (context, index) {
                                      final song = _relatedSongs[index];
                                      return Card(
                                        child: ListTile(
                                          leading: song.albumArt != null
                                              ? Image.network(
                                                  song.albumArt!,
                                                  width: 50,
                                                  height: 50,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => Icon(
                                                        Icons.music_note,
                                                      ),
                                                )
                                              : Icon(Icons.music_note),
                                          title: Text(song.title),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('Artist: ${song.artists}'),
                                              if (song.duration != null)
                                                Text(
                                                  'Duration: ${song.duration}',
                                                ),
                                              if (song.isOriginal)
                                                Text(
                                                  'Original Song',
                                                  style: TextStyle(
                                                    color: Colors.blue,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          trailing: song.audioUrl != null
                                              ? Icon(
                                                  Icons.play_circle_fill,
                                                  color: Colors.green,
                                                )
                                              : null,
                                        ),
                                      );
                                    },
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
      ),
    );
  }

  @override
  void dispose() {
    _ytMusicApi.dispose();
    super.dispose();
  }
}
