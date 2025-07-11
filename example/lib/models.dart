// /// Enum for Audio Quality
// enum AudioQuality {
//   low('LOW'),
//   med('MED'),
//   high('HIGH'),
//   veryHigh('VERY_HIGH');

//   const AudioQuality(this.value);
//   final String value;
// }

// /// Enum for Thumbnail Quality
// enum ThumbnailQuality {
//   low('LOW'),
//   med('MED'),
//   high('HIGH'),
//   veryHigh('VERY_HIGH');

//   const ThumbnailQuality(this.value);
//   final String value;
// }

// class SearchResult {
//   final String title;
//   final String artists;
//   final String videoId;
//   final String? duration;
//   final String? year;
//   final String? albumArt;
//   final String? audioUrl;

//   SearchResult({
//     required this.title,
//     required this.artists,
//     required this.videoId,
//     this.duration,
//     this.year,
//     this.albumArt,
//     this.audioUrl,
//   });

//   factory SearchResult.fromMap(Map<String, dynamic> map) {
//     return SearchResult(
//       title: map['title'] ?? '',
//       artists: map['artists'] ?? '',
//       videoId: map['videoId'] ?? '',
//       duration: map['duration'],
//       year: map['year'],
//       albumArt: map['albumArt'],
//       audioUrl: map['audioUrl'],
//     );
//   }

//   Map<String, dynamic> toMap() {
//     return {
//       'title': title,
//       'artists': artists,
//       'videoId': videoId,
//       'duration': duration,
//       'year': year,
//       'albumArt': albumArt,
//       'audioUrl': audioUrl,
//     };
//   }

//   @override
//   String toString() {
//     return 'SearchResult(title: $title, artists: $artists, videoId: $videoId, duration: $duration, year: $year, albumArt: $albumArt, audioUrl: $audioUrl)';
//   }
// }

// /// Data class for Related Songs
// class RelatedSong {
//   final String title;
//   final String artists;
//   final String videoId;
//   final String? duration;
//   final String? albumArt;
//   final String? audioUrl;
//   final bool isOriginal;

//   RelatedSong({
//     required this.title,
//     required this.artists,
//     required this.videoId,
//     this.duration,
//     this.albumArt,
//     this.audioUrl,
//     this.isOriginal = false,
//   });

//   factory RelatedSong.fromMap(Map<String, dynamic> map) {
//     return RelatedSong(
//       title: map['title'] ?? '',
//       artists: map['artists'] ?? '',
//       videoId: map['videoId'] ?? '',
//       duration: map['duration'],
//       albumArt: map['albumArt'],
//       audioUrl: map['audioUrl'],
//       isOriginal: map['isOriginal'] ?? false,
//     );
//   }

//   Map<String, dynamic> toMap() {
//     return {
//       'title': title,
//       'artists': artists,
//       'videoId': videoId,
//       'duration': duration,
//       'albumArt': albumArt,
//       'audioUrl': audioUrl,
//       'isOriginal': isOriginal,
//     };
//   }

//   @override
//   String toString() {
//     return 'RelatedSong(title: $title, artists: $artists, videoId: $videoId, duration: $duration, albumArt: $albumArt, audioUrl: $audioUrl, isOriginal: $isOriginal)';
//   }
// }
