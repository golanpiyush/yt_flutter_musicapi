from ytmusicapi import YTMusic
from enum import Enum
from typing import Generator, Optional
import yt_dlp
import warnings
import random
import time
import socket
from urllib.error import URLError

# Suppress warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)

# Enums for quality settings
class AudioQuality(Enum):
    LOW = 0
    MED = 1
    HIGH = 2
    VERY_HIGH = 3

class ThumbnailQuality(Enum):
    LOW = 0
    MED = 1
    HIGH = 2
    VERY_HIGH = 3

class YTMusicSearcher:
    def __init__(self, proxy: Optional[str] = None, country: str = "US"):
        self.proxy = proxy
        self.country = country.upper() if country else "US"
        self.ytmusic = None
        self._initialize_ytmusic()
        
    def _initialize_ytmusic(self):
        max_retries = 3
        for attempt in range(max_retries):
            try:
                self.ytmusic = YTMusic()
                return
            except Exception as e:
                if attempt == max_retries - 1:
                    raise ConnectionError(f"Failed to initialize YTMusic after {max_retries} attempts: {str(e)}")
                time.sleep(2 ** attempt)

    def _get_ytdlp_instance(self, format_selector: str):
        ydl_opts = {
            "quiet": True,
            "no_warnings": True,
            "skip_download": True,
            "nocheckcertificate": True,
            "format": format_selector,
            "extract_flat": False,
            "age_limit": 99,
            "socket_timeout": 30,
            "source_address": "0.0.0.0",
            "force_ipv4": True,
            "retries": 3,
            "fragment_retries": 10,
            "extractor_retries": 3,
            "buffersize": 1024 * 1024,
            "http_chunk_size": 1024 * 1024,
            "extractor_args": {
                "youtube": {
                    "player_client": ["android", "web"],
                    "player_skip": ["configs"],
                    "skip": ["translated_subs", "hls"]
                }
            },
            "compat_opts": ["no-youtube-unavailable-videos"],
            "headers": self._generate_headers()
        }

        if self.proxy:
            ydl_opts["proxy"] = self.proxy
            ydl_opts["proxy_headers"] = ydl_opts["headers"]

        return yt_dlp.YoutubeDL(ydl_opts)

    def _generate_headers(self):
        user_agents = [
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:120.0) Gecko/20100101 Firefox/120.0',
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Safari/605.1.15',
            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        ]
        
        return {
            'User-Agent': random.choice(user_agents),
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept': '*/*',
            'Accept-Encoding': 'gzip, deflate, br'
        }

    def get_audio_url(self, video_id: str, quality: AudioQuality) -> Optional[str]:
        format_strategies = [
            "bestaudio[ext=m4a]/bestaudio[ext=mp4]/best[ext=m4a]/best[ext=mp4]",
            "251/250/249/140/139/171/18/22",
            "bestaudio/best",
            "worstaudio/worst"
        ]
        
        for format_selector in format_strategies:
            try:
                ydl = self._get_ytdlp_instance(format_selector)
                time.sleep(random.uniform(0.5, 1.5))
                
                info = ydl.extract_info(
                    f"https://www.youtube.com/watch?v={video_id}",
                    download=False,
                    process=False
                )
                info = ydl.process_ie_result(info, download=False)
                
                if info.get('is_live') or info.get('availability') == 'unavailable':
                    continue
                
                if info.get('drm') or any(f.get('drm') for f in info.get('formats', [])):
                    continue
                
                requested_formats = info.get('requested_formats', [info])
                formats = info.get('formats', requested_formats)
                
                audio_formats = [
                    f for f in formats 
                    if f.get('acodec') != 'none' 
                    and f.get('url')
                    and not any(x in f['url'].lower() for x in ["manifest", ".m3u8"])
                ]
                
                if not audio_formats:
                    continue
                
                audio_formats.sort(key=lambda f: f.get('abr', 0) or f.get('tbr', 0) or 0, reverse=True)
                return audio_formats[0]['url']
                        
            except yt_dlp.utils.DownloadError as e:
                if "HTTP Error 403" in str(e):
                    time.sleep(2)
                    continue
                if "unavailable" in str(e).lower():
                    break
                continue
            except (URLError, socket.timeout, ConnectionError):
                time.sleep(2)
                continue
            except Exception:
                continue
        
        return None

    def get_music_details(
        self,
        query: str,
        limit: int = 10,
        thumb_quality: ThumbnailQuality = ThumbnailQuality.VERY_HIGH,
        audio_quality: AudioQuality = AudioQuality.VERY_HIGH,
        include_audio_url: bool = True,
        include_album_art: bool = True
    ) -> Generator[dict, None, None]:
        processed_count = 0
        skipped_count = 0
        max_attempts = limit * 3
        
        for attempt in range(3):
            try:
                results = self.ytmusic.search(query, filter="songs", limit=max_attempts)
                break
            except Exception:
                if attempt == 2:
                    return
                time.sleep(2 ** attempt)
                self._initialize_ytmusic()

        for item in results:
            if processed_count >= limit:
                break
                
            try:
                video_id = item.get("videoId")
                if not video_id:
                    skipped_count += 1
                    continue

                title = item.get("title", "Unknown Title")
                artists = ", ".join(a.get("name", "Unknown") for a in item.get("artists", [])) or "Unknown Artist"
                duration = item.get("duration")
                year = item.get("year")

                album_art = ""
                if include_album_art:
                    thumbnails = item.get("thumbnails", [])
                    if thumbnails:
                        if thumb_quality == ThumbnailQuality.VERY_HIGH:
                            thumbnails.sort(
                                key=lambda t: int(t.get("width", 0)) * int(t.get("height", 0)),
                                reverse=True
                            )
                            url = thumbnails[0].get("url", "")
                            album_art = url.split('=')[0] if '=' in url else url
                        else:
                            index = {
                                ThumbnailQuality.LOW: 0,
                                ThumbnailQuality.MED: min(1, len(thumbnails) - 1),
                                ThumbnailQuality.HIGH: min(2, len(thumbnails) - 1)
                            }.get(thumb_quality, -1)
                            album_art = thumbnails[index].get("url", "")

                audio_url = None
                if include_audio_url:
                    for _ in range(3):
                        audio_url = self.get_audio_url(video_id, audio_quality)
                        if audio_url:
                            break
                        time.sleep(1)

                if not include_audio_url or audio_url:
                    song_data = {
                        "title": title,
                        "artists": artists,
                        "videoId": video_id,
                        "duration": duration,
                        "year": year
                    }
                    if include_album_art:
                        song_data["albumArt"] = album_art
                    if include_audio_url:
                        song_data["audioUrl"] = audio_url

                    processed_count += 1
                    yield song_data
                else:
                    skipped_count += 1

            except Exception:
                skipped_count += 1
                continue

        print(f"Found {processed_count} valid results (skipped {skipped_count})")


# =================================================================================================================================
# =================================================================================================================================


class YTMusicRelatedFetcher:
    def __init__(self, proxy: Optional[str] = None, country: str = "US"):
        self.proxy = proxy
        self.country = country.upper() if country else "US"
        self.ytmusic = None
        self._initialize_ytmusic()
        
    def _initialize_ytmusic(self):
        max_retries = 3
        for attempt in range(max_retries):
            try:
                self.ytmusic = YTMusic()
                return
            except Exception as e:
                if attempt == max_retries - 1:
                    raise ConnectionError(f"Failed to initialize YTMusic after {max_retries} attempts: {str(e)}")
                time.sleep(2 ** attempt)

    def _get_ytdlp_instance(self, format_selector: str):
        ydl_opts = {
            "quiet": True,
            "no_warnings": True,
            "skip_download": True,
            "nocheckcertificate": True,
            "format": format_selector,
            "extract_flat": False,
            "age_limit": 99,
            "socket_timeout": 30,
            "source_address": "0.0.0.0",
            "force_ipv4": True,
            "retries": 3,
            "fragment_retries": 10,
            "extractor_retries": 3,
            "buffersize": 1024 * 1024,
            "http_chunk_size": 1024 * 1024,
            "extractor_args": {
                "youtube": {
                    "player_client": ["android", "web"],
                    "player_skip": ["configs"],
                    "skip": ["translated_subs", "hls"]
                }
            },
            "compat_opts": ["no-youtube-unavailable-videos"],
            "headers": self._generate_headers()
        }

        if self.proxy:
            ydl_opts["proxy"] = self.proxy
            ydl_opts["proxy_headers"] = ydl_opts["headers"]

        return yt_dlp.YoutubeDL(ydl_opts)

    def _generate_headers(self):
        user_agents = [
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:120.0) Gecko/20100101 Firefox/120.0',
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Safari/605.1.15',
            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        ]
        
        return {
            'User-Agent': random.choice(user_agents),
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept': '*/*',
            'Accept-Encoding': 'gzip, deflate, br'
        }

    def get_audio_url(self, video_id: str, quality: AudioQuality) -> Optional[str]:
        format_strategies = [
            "bestaudio[ext=m4a]/bestaudio[ext=mp4]/best[ext=m4a]/best[ext=mp4]",
            "251/250/249/140/139/171/18/22",
            "bestaudio/best",
            "worstaudio/worst"
        ]
        
        for format_selector in format_strategies:
            try:
                ydl = self._get_ytdlp_instance(format_selector)
                time.sleep(random.uniform(0.5, 1.5))
                
                info = ydl.extract_info(
                    f"https://www.youtube.com/watch?v={video_id}",
                    download=False,
                    process=False
                )
                info = ydl.process_ie_result(info, download=False)
                
                if info.get('is_live') or info.get('availability') == 'unavailable':
                    continue
                
                if info.get('drm') or any(f.get('drm') for f in info.get('formats', [])):
                    continue
                
                requested_formats = info.get('requested_formats', [info])
                formats = info.get('formats', requested_formats)
                
                audio_formats = [
                    f for f in formats 
                    if f.get('acodec') != 'none' 
                    and f.get('url')
                    and not any(x in f['url'].lower() for x in ["manifest", ".m3u8"])
                ]
                
                if not audio_formats:
                    continue
                
                audio_formats.sort(key=lambda f: f.get('abr', 0) or f.get('tbr', 0) or 0, reverse=True)
                return audio_formats[0]['url']
                        
            except yt_dlp.utils.DownloadError as e:
                if "HTTP Error 403" in str(e):
                    time.sleep(2)
                    continue
                if "unavailable" in str(e).lower():
                    break
                continue
            except (URLError, socket.timeout, ConnectionError):
                time.sleep(2)
                continue
            except Exception:
                continue
        
        return None

    def _find_song_video_id(self, song_name: str, artist_name: str) -> Optional[str]:
        query = f"{song_name} {artist_name}"
        
        for attempt in range(3):
            try:
                results = self.ytmusic.search(query, filter="songs", limit=10)
                
                for item in results:
                    title = item.get("title", "").lower()
                    artists = [a.get("name", "").lower() for a in item.get("artists", [])]
                    
                    if any(word in title for word in song_name.lower().split()):
                        if any(artist_name.lower() in artist for artist in artists):
                            return item.get("videoId")
                
                if results:
                    return results[0].get("videoId")
                    
            except Exception:
                if attempt == 2:
                    return None
                time.sleep(2 ** attempt)
                self._initialize_ytmusic()
        
        return None

    def get_video_info(self, video_id: str) -> Optional[dict]:
        try:
            song_info = self.ytmusic.get_song(video_id)
            watch_playlist = self.ytmusic.get_watch_playlist(video_id)
            
            return {
                "song_info": song_info,
                "related_tracks": watch_playlist.get("tracks", [])
            }
            
        except Exception as e:
            print(f"Error getting video info for {video_id}: {str(e)}")
            return None

    def getRelated(
        self,
        song_name: str,
        artist_name: str,
        limit: int = 10,
        thumb_quality: ThumbnailQuality = ThumbnailQuality.VERY_HIGH,
        audio_quality: AudioQuality = AudioQuality.VERY_HIGH,
        include_audio_url: bool = True,
        include_album_art: bool = True
    ) -> Generator[dict, None, None]:
        if not song_name.strip() or not artist_name.strip():
            print("YTMusic getRelated Error: Both song_name and artist_name are required.")
            return

        print(f"Searching for related songs to '{song_name}' by '{artist_name}'...")
        
        video_id = self._find_song_video_id(song_name, artist_name)
        
        if not video_id:
            print(f"Could not find '{song_name}' by '{artist_name}'")
            return
        
        print(f"Found song with video ID: {video_id}")
        
        video_info = self.get_video_info(video_id)
        
        if not video_info or not video_info.get("related_tracks"):
            print("No related tracks found")
            return
        
        related_tracks = video_info["related_tracks"]
        processed_count = 0
        skipped_count = 0
        
        print(f"Processing {len(related_tracks)} related tracks...")
        
        for item in related_tracks:
            if processed_count >= limit:
                break
                
            try:
                track_video_id = item.get("videoId")
                if not track_video_id or track_video_id == video_id:
                    skipped_count += 1
                    continue

                title = item.get("title", "Unknown Title")
                artists = ", ".join(a.get("name", "Unknown") for a in item.get("artists", [])) or "Unknown Artist"
                duration = item.get("length", "N/A")
                
                album_art = ""
                if include_album_art:
                    thumbnails = item.get("thumbnail", [])
                    if thumbnails:
                        if thumb_quality == ThumbnailQuality.VERY_HIGH:
                            thumbnails.sort(
                                key=lambda t: int(t.get("width", 0)) * int(t.get("height", 0)),
                                reverse=True
                            )
                            album_art = thumbnails[0].get("url", "")
                        else:
                            quality_index = {
                                ThumbnailQuality.LOW: 0,
                                ThumbnailQuality.MED: 1,
                                ThumbnailQuality.HIGH: 2
                            }.get(thumb_quality, 0)
                            quality_index = min(quality_index, len(thumbnails) - 1)
                            album_art = thumbnails[quality_index].get("url", "")

                audio_url = None
                if include_audio_url:
                    for _ in range(3):
                        audio_url = self.get_audio_url(track_video_id, audio_quality)
                        if audio_url:
                            break
                        time.sleep(1)

                if not include_audio_url or audio_url:
                    song_data = {
                        "title": title,
                        "artists": artists,
                        "videoId": track_video_id,
                        "duration": duration,
                        "isOriginal": track_video_id == video_id
                    }
                    if include_album_art:
                        song_data["albumArt"] = album_art
                    if include_audio_url:
                        song_data["audioUrl"] = audio_url

                    processed_count += 1
                    yield song_data
                else:
                    skipped_count += 1

            except Exception as e:
                print(f"Error processing track: {str(e)}")
                skipped_count += 1
                continue

        print(f"Found {processed_count} valid related songs (skipped {skipped_count})")

# Test examples
# if __name__ == "__main__":
#     # Initialize both services
#     print("Initializing services...")
#     searcher = YTMusicSearcher(country="US")
#     related_fetcher = YTMusicRelatedFetcher(country="US")
    
#     # Test search functionality
#     print("\n=== Testing Search Functionality ===")
#     test_query = "Gale Lag Ja"
#     print(f"Searching for: {test_query}")
    
#     for i, song in enumerate(searcher.get_music_details(test_query, limit=3), 1):
#         print(f"\n{i}. {song['title']} by {song['artists']}")
#         print(f"Duration: {song.get('duration', 'N/A')}")
#         if 'albumArt' in song:
#             print(f"Album Art: {song['albumArt']}")
#         if 'audioUrl' in song:
#             print(f"Audio URL: {song['audioUrl'][:50]}...")  # Print first 50 chars of URL
    
#     # Test related songs functionality
#     print("\n=== Testing Related Songs Functionality ===")
#     test_song = "Viva La Vida"
#     test_artist = "Coldplay"
#     print(f"Finding related songs for: {test_song} by {test_artist}")
    
#     for i, song in enumerate(related_fetcher.getRelated(
#         song_name=test_song,
#         artist_name=test_artist,
#         limit=3,
#         include_audio_url=False  # Faster testing without audio URLs
#     ), 1):
#         print(f"\n{i}. {song['title']} by {song['artists']}")
#         print(f"Duration: {song.get('duration', 'N/A')}")
#         if 'albumArt' in song:
#             print(f"Album Art: {song['albumArt']}")
#         print(f"Is Original: {song.get('isOriginal', False)}")
    
#     print("\nTests completed successfully!")