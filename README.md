# 🎵 YT Flutter Music API

A powerful Flutter plugin that bridges **YouTube Music** functionality using a **Kotlin + Python (Chaquopy)** backend.  
Search songs, stream results in real time, and fetch related tracks—all directly from your Flutter app.

---

## ✨ Features

- 🔍 Search **YouTube Music** with real-time results  
- 📡 Stream search results live via `EventChannel`  
- 🎶 Fetch **related songs** intelligently  
- 🎚️ Adjustable audio & thumbnail quality  
- 🧠 Powered by `ytmusicapi` + `yt-dlp`  
- ⚙️ Kotlin + Python bridge using **Chaquopy**  
- 📱 Android support with Flutter frontend  

---

## 🚀 Getting Started

### 1. Initialize the plugin

```dart
await YtFlutterMusicapi().initialize(
  proxy: null,
  country: 'US',
);
```

### 2. Perform a direct search

```dart
final result = await YtFlutterMusicapi().searchMusic(
  query: 'Alan Walker Faded',
  limit: 5,
  audioQuality: 'VERY_HIGH',
  thumbQuality: 'VERY_HIGH',
);

print(result['title']); // Outputs: Faded
```

### 3. Stream results in real-time

```dart
await for (final song in YtFlutterMusicapi().streamSearchResults(
  query: 'Alan Walker Faded',
  limit: 5,
  audioQuality: 'VERY_HIGH',
  thumbQuality: 'VERY_HIGH',
)) {
  print('🎧 ${song['title']} by ${song['artists']}');
}
```

> ⚡ Fast feedback: Items arrive as they're fetched — perfect for CLI-style UIs and progressive lists.

---

## ⚙️ Configuration Options

| Parameter           | Type     | Description                              |
|---------------------|----------|------------------------------------------|
| `query`             | `String` | Search query (required)                  |
| `limit`             | `int`    | Number of results (default: 10)          |
| `audioQuality`      | `String` | LOW / MED / HIGH / VERY_HIGH             |
| `thumbQuality`      | `String` | LOW / MED / HIGH / VERY_HIGH             |
| `includeAudioUrl`   | `bool`   | If true, includes audio stream URL       |
| `includeAlbumArt`   | `bool`   | If true, includes album art URL          |

---

## 🧪 Test the Plugin

Download prebuilt APK from:

👉 [Releases](https://github.com/golanpiyush/yt_flutter_musicapi/releases)

---

## 🧠 Internals

- ✅ Native side: Kotlin plugin + Chaquopy Python bridge  
- ✅ Python packages:
  - [`ytmusicapi`](https://github.com/sigma67/ytmusicapi)
  - [`yt-dlp`](https://github.com/yt-dlp/yt-dlp)
- ✅ Uses `MethodChannel` for control and `EventChannel` for streaming  

---

## 💡 Example CLI Output

```text
📡 Streaming search results for: "Alan Walker Faded"
🎧 Streamed Result 1:
   Title: Faded
   Artists: Alan Walker
   Duration: 3:32
   Video ID: xyz123
   Album Art: Available
   Audio URL: Available
---
⏹️ Streaming limit reached (5)
✅ Stream finished: 5 result(s)
```

---

## 🧑‍💻 Contributing

I welcome contributions!

```bash
git clone https://github.com/golanpiyush/yt_flutter_musicapi.git
cd yt_flutter_musicapi
```

1. Fork & create a feature branch  
2. Make your changes  
3. Submit a pull request with description  

---

## 📄 License

This project is licensed under the MIT License.  
See [LICENSE](LICENSE) for more details.


---

## 📦 Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  yt_flutter_musicapi:
    git:
      url: https://github.com/golanpiyush/yt_flutter_musicapi.git
      ref: main
```

---

## 👤 Author

**Piyush Golan**  
💻 Developer
GitHub: [@golanpiyush](https://github.com/golanpiyush)

📬 For questions or collaboration, open an issue or drop a message!

