import base64
from enum import Enum
import re
from typing import Any, Dict, Generator, List, Optional
import warnings
import random
import time
import socket
from urllib.error import URLError

import requests

# Suppress warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)

ytmv = "1.10.3"
ytdlpv = "2025.06.30"

# For Debugging
try:
    from ytmusicapi import YTMusic
    import yt_dlp
    print("✅ Imported ytmusicapi and yt-dlp successfully")
except Exception as e:
    print("❌ Failed to import:", e)

def check_ytmusic_and_ytdlp_ready():
    try:
        # Import and get version info
        import ytmusicapi
        import yt_dlp
        
        # Initialize YTMusic
        ytmusic = ytmusicapi.YTMusic()
        
        # Initialize yt-dlp
        ydl = yt_dlp.YoutubeDL()
        
        # Get version information
        ytmusic_version = ytmusicapi.__version__ if hasattr(ytmusicapi, '__version__') else 'Unknown'
        ytdlp_version = yt_dlp.version.__version__ if hasattr(yt_dlp, 'version') else 'Unknown'
        
        print("✅ YTMusic and yt-dlp initialized successfully")
        
        return {
            "success": True,
            "ytmusic_ready": True,
            "ytmusic_version": ytmusic_version,
            "ytdlp_ready": True,
            "ytdlp_version": ytdlp_version,
            "message": "✅ All systems ready and working.."
        }
    except Exception as e:
        print(f"❌ Initialization failed: {e}")
        return {
            "success": False,
            "message": f"Initialization failed: {str(e)}",
            "ytmusic_ready": False,
            "ytdlp_ready": False
        }

def debug_dependencies():
    import sys
    from importlib.util import find_spec
    
    dependencies = {
        'ytmusicapi': find_spec("ytmusicapi") is not None,
        'yt_dlp': find_spec("yt_dlp") is not None,
        'python_version': sys.version,
        'python_path': sys.path
    }
    return dependencies


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
    
    def get_hq_album_art_from_ytdlp(self, video_id: str) -> Optional[str]:
        """
        Get high quality album art using yt-dlp from video metadata
        Returns the highest quality album art URL available
        """
        try:
            ydl_opts = {
                "quiet": True,
                "no_warnings": True,
                "skip_download": True,
                "nocheckcertificate": True,
                "extract_flat": False,
                "socket_timeout": 30,
                "source_address": "0.0.0.0",
                "force_ipv4": True,
                "retries": 2,
                "headers": self._generate_headers()
            }
            
            if self.proxy:
                ydl_opts["proxy"] = self.proxy
                ydl_opts["proxy_headers"] = ydl_opts["headers"]
            
            ydl = yt_dlp.YoutubeDL(ydl_opts)
            
            info = ydl.extract_info(
                f"https://www.youtube.com/watch?v={video_id}",
                download=False
            )
            
            # First try to get album art from metadata
            album_art_url = None
            
            # Check for album art in various metadata fields
            if info.get('album_artist') and info.get('album'):
                # Try to construct album art URL from metadata
                album_art_url = self._get_album_art_from_metadata(info)
            
            # If no album art from metadata, fall back to high quality thumbnails
            if not album_art_url:
                thumbnails = info.get('thumbnails', [])
                if thumbnails:
                    # Filter for high quality thumbnails (prefer square ones for album art)
                    hq_thumbnails = [
                        t for t in thumbnails 
                        if t.get('width', 0) >= 720 and t.get('height', 0) >= 720
                    ]
                    
                    if hq_thumbnails:
                        # Sort by resolution and prefer square aspect ratios
                        hq_thumbnails.sort(
                            key=lambda t: (
                                abs(1.0 - (t.get('width', 1) / t.get('height', 1))),  # Prefer square
                                (t.get('width', 0) * t.get('height', 0))  # Then by resolution
                            ),
                            reverse=True
                        )
                        album_art_url = hq_thumbnails[0].get('url', '')
                    else:
                        # Fall back to highest resolution thumbnail
                        thumbnails.sort(
                            key=lambda t: (t.get('width', 0) * t.get('height', 0)),
                            reverse=True
                        )
                        album_art_url = thumbnails[0].get('url', '')
            
            if album_art_url:
                print(f"HQ Album Art found: {album_art_url}")
                return album_art_url
            
            return None
            
        except Exception as e:
            print(f"Error getting HQ album art for {video_id}: {e}")
            return None

    def _get_album_art_from_metadata(self, info: dict) -> Optional[str]:
        """
        Try to get album art from video metadata
        """
        try:
            # Check for album art in various metadata fields
            album_art_fields = ['album_art', 'album_artwork', 'artwork', 'cover']
            
            for field in album_art_fields:
                if info.get(field):
                    return info[field]
            
            # Try to get from uploader avatar if it's an official channel
            uploader = info.get('uploader', '').lower()
            if any(keyword in uploader for keyword in ['official', 'records', 'music', 'vevo']):
                uploader_avatar = info.get('uploader_avatar_url')
                if uploader_avatar:
                    return uploader_avatar
            
            return None
            
        except Exception:
            return None

    def get_youtube_music_album_art(self, video_id: str) -> Optional[str]:
        """
        Get album art specifically from YouTube Music metadata
        """
        try:
            # Use YTMusic to get song details which might have better album art
            song_info = self.ytmusic.get_song(video_id)
            
            # Extract album art from song info
            thumbnails = song_info.get('videoDetails', {}).get('thumbnail', {}).get('thumbnails', [])
            
            if thumbnails:
                # Sort by resolution to get highest quality
                thumbnails.sort(
                    key=lambda t: (t.get('width', 0) * t.get('height', 0)),
                    reverse=True
                )
                
                # Prefer square thumbnails for album art
                square_thumbnails = [
                    t for t in thumbnails 
                    if abs(1.0 - (t.get('width', 1) / t.get('height', 1))) < 0.1
                ]
                
                if square_thumbnails:
                    return square_thumbnails[0].get('url', '')
                else:
                    return thumbnails[0].get('url', '')
            
            return None
            
        except Exception as e:
            print(f"Error getting YouTube Music album art for {video_id}: {e}")
            return None

    def get_music_details(
        self,
        query: str,
        limit: int = 10,
        thumb_quality: ThumbnailQuality = ThumbnailQuality.VERY_HIGH,
        audio_quality: AudioQuality = AudioQuality.HIGH,
        include_audio_url: bool = True,
        include_album_art: bool = True
    ) -> Generator[dict, None, None]:
        print(f"Starting search for query: {query}, limit: {limit}")
        processed_count = 0
        skipped_count = 0
        max_attempts = limit * 3
        
        results = None
        for attempt in range(3):
            try:
                print(f"Attempt {attempt + 1} to search...")
                results = self.ytmusic.search(query, filter="songs", limit=max_attempts)
                print(f"Search returned {len(results) if results else 0} results")
                break
            except Exception as e:
                print(f"Search attempt {attempt + 1} failed: {e}")
                if attempt == 2:
                    print("All search attempts failed, returning empty")
                    return
                time.sleep(2 ** attempt)
                self._initialize_ytmusic()

        if not results:
            print("No results found")
            return

        print(f"Processing {len(results)} results...")
        for i, item in enumerate(results):
            print(f"Processing item {i + 1}: {item.get('title', 'No title')}")
            
            if processed_count >= limit:
                print(f"Reached limit of {limit} items")
                break
                
            try:
                video_id = item.get("videoId")
                if not video_id:
                    print(f"Skipping item {i + 1}: No videoId")
                    skipped_count += 1
                    continue

                title = item.get("title", "Unknown Title")
                artists = ", ".join(a.get("name", "Unknown") for a in item.get("artists", [])) or "Unknown Artist"
                duration = item.get("duration")
                year = item.get("year")

                print(f"Basic info extracted - Title: {title}, Artists: {artists}")

                album_art = ""
                if include_album_art:
                    if thumb_quality in [ThumbnailQuality.HIGH, ThumbnailQuality.VERY_HIGH]:
                        print(f"Trying to get HQ album art for video ID: {video_id}")
                        
                        # Method 1: Try YouTube Music specific album art
                        album_art = self.get_youtube_music_album_art(video_id)
                        
                        # Method 2: Try yt-dlp with album art focus
                        if not album_art:
                            album_art = self.get_hq_album_art_from_ytdlp(video_id)
                        
                        # Method 3: Fallback to YTMusic thumbnails
                        if not album_art:
                            print("Falling back to YTMusic thumbnails")
                            thumbnails = item.get("thumbnails", [])
                            if thumbnails:
                                base_url = thumbnails[-1].get("url", "")
                                if base_url:
                                    import re
                                    if thumb_quality == ThumbnailQuality.HIGH:
                                        # w320-h320-l90-rj for high quality
                                        album_art = re.sub(r'w\d+-h\d+', 'w320-h320', base_url)
                                    elif thumb_quality == ThumbnailQuality.VERY_HIGH:
                                        # w544-h544-l90-rj for very high quality
                                        album_art = re.sub(r'w\d+-h\d+', 'w544-h544', base_url)
                                    else:
                                        album_art = base_url
                        
                        # Apply quality settings to HQ URLs if they contain YouTube image patterns
                        if album_art and any(pattern in album_art for pattern in ['googleusercontent.com', 'ytimg.com', 'youtube.com']):
                            import re
                            if thumb_quality == ThumbnailQuality.HIGH:
                                # Force HIGH quality resolution even for HQ sources
                                album_art = re.sub(r'w\d+-h\d+', 'w320-h320', album_art)
                            elif thumb_quality == ThumbnailQuality.VERY_HIGH:
                                # Keep or set VERY_HIGH quality resolution
                                album_art = re.sub(r'w\d+-h\d+', 'w544-h544', album_art)
                    else:
                        # Use YTMusic thumbnails for LOW and MED quality
                        thumbnails = item.get("thumbnails", [])
                        print(f"Found {len(thumbnails)} thumbnails from YTMusic")
                        if thumbnails:
                            base_url = thumbnails[-1].get("url", "")
                            if base_url:
                                import re
                                if thumb_quality == ThumbnailQuality.LOW:
                                    # w60-h60-l90-rj for lowest quality
                                    album_art = re.sub(r'w\d+-h\d+', 'w60-h60', base_url)
                                elif thumb_quality == ThumbnailQuality.MED:
                                    # w120-h120-l90-rj for medium quality
                                    album_art = re.sub(r'w\d+-h\d+', 'w120-h120', base_url)
                                else:
                                    album_art = base_url
                            else:
                                album_art = ""
                        print(f"Album art URL: {album_art}")


                audio_url = None
                if include_audio_url:
                    print(f"Getting audio URL for video ID: {video_id}")
                    for attempt in range(3):
                        try:
                            audio_url = self.get_audio_url(video_id, audio_quality)
                            if audio_url:
                                print(f"Got audio URL on attempt {attempt + 1}")
                                break
                            else:
                                print(f"No audio URL on attempt {attempt + 1}")
                        except Exception as e:
                            print(f"Audio URL attempt {attempt + 1} failed: {e}")
                        time.sleep(1)

                # Check if we should yield this result
                should_yield = not include_audio_url or audio_url
                print(f"Should yield: {should_yield} (include_audio_url: {include_audio_url}, audio_url: {audio_url is not None})")

                if should_yield:
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
                    print(f"Yielding song data {processed_count}: {song_data}")

                    yield song_data
                else:
                    print(f"Skipping item {i + 1}: Could not get audio URL")
                    skipped_count += 1

            except Exception as e:
                print(f"Error processing item {i + 1}: {e}")
                skipped_count += 1
                continue

        print(f"Finished processing. Found {processed_count} valid results (skipped {skipped_count})")

    def get_artist_songs(
        self,
        artist_name: str,
        limit: int = 25,
        thumb_quality: ThumbnailQuality = ThumbnailQuality.VERY_HIGH,
        audio_quality: AudioQuality = AudioQuality.HIGH,
        include_audio_url: bool = True,
        include_album_art: bool = True
    ) -> Generator[dict, None, None]:
        """
        Get songs from a specific artist and stream them one by one as they become available.
        
        Args:
            artist_name: Name of the artist to search for
            limit: Maximum number of songs to return (default: 25)
            thumb_quality: Quality of album art thumbnails
            audio_quality: Quality of audio URLs
            include_audio_url: Whether to include audio URLs
            include_album_art: Whether to include album art URLs
            
        Yields:
            dict: Song data containing title, artists, videoId, duration, audioUrl, albumArt
        """
        print(f"🎵 Starting artist songs search for: {artist_name}")
        processed_count = 0
        skipped_count = 0
        
        # Step 1: Search for the artist
        artist_results = None
        for attempt in range(3):
            try:
                print(f"🔍 Attempt {attempt + 1} to search for artist: {artist_name}")
                artist_results = self.ytmusic.search(artist_name, filter="artists", limit=5)
                print(f"✅ Found {len(artist_results) if artist_results else 0} artist results")
                break
            except Exception as e:
                print(f"❌ Artist search attempt {attempt + 1} failed: {e}")
                if attempt == 2:
                    print("💀 All artist search attempts failed, returning empty")
                    return
                time.sleep(2 ** attempt)
                self._initialize_ytmusic()
        
        if not artist_results:
            print("❌ No artist results found")
            return
        
        # Step 2: Get the best matching artist
        target_artist = None
        for artist in artist_results:
            if artist.get('artist', '').lower() == artist_name.lower():
                target_artist = artist
                break
        
        if not target_artist:
            target_artist = artist_results[0]  # Use first result if no exact match
        
        browse_id = target_artist.get('browseId')
        if not browse_id:
            print("❌ No browseId found for artist")
            return
        
        print(f"🎤 Using artist: {target_artist.get('artist', 'Unknown')} (ID: {browse_id})")
        
        # Step 3: Get artist's songs
        try:
            print(f"📀 Fetching artist songs...")
            artist_info = self.ytmusic.get_artist(browse_id)
            songs_section = None
            
            # Find songs section in artist info
            for section in artist_info.get('songs', {}).get('results', []):
                if section:
                    songs_section = section
                    break
            
            # If no songs section found, try albums approach
            if not songs_section:
                print("🔄 No direct songs found, trying albums approach...")
                albums = artist_info.get('albums', {}).get('results', [])
                all_songs = []
                
                for album in albums[:5]:  # Limit to first 5 albums to avoid too many requests
                    try:
                        album_id = album.get('browseId')
                        if album_id:
                            album_info = self.ytmusic.get_album(album_id)
                            album_tracks = album_info.get('tracks', [])
                            all_songs.extend(album_tracks)
                            print(f"📀 Added {len(album_tracks)} songs from album: {album.get('title', 'Unknown')}")
                    except Exception as e:
                        print(f"⚠️ Error getting album {album.get('title', 'Unknown')}: {e}")
                        continue
                
                songs_section = all_songs
            
            if not songs_section:
                print("❌ No songs found for artist")
                return
            
            print(f"🎵 Found {len(songs_section)} songs, processing up to {limit}...")
            
        except Exception as e:
            print(f"❌ Error getting artist info: {e}")
            return
        
        # Step 4: Process each song
        for i, song in enumerate(songs_section):
            if processed_count >= limit:
                print(f"✅ Reached limit of {limit} songs")
                break
            
            try:
                video_id = song.get("videoId")
                if not video_id:
                    print(f"⚠️ Skipping song {i + 1}: No videoId")
                    skipped_count += 1
                    continue
                
                title = song.get("title", "Unknown Title")
                artists = ", ".join(a.get("name", "Unknown") for a in song.get("artists", [])) or artist_name
                duration = song.get("duration") or song.get("duration_seconds")
                
                print(f"🎧 Processing song {processed_count + 1}: {title} by {artists}")
                
                # Get album art
                album_art = ""
                if include_album_art:
                    if thumb_quality in [ThumbnailQuality.HIGH, ThumbnailQuality.VERY_HIGH]:
                        print(f"🖼️ Getting HQ album art for: {video_id}")
                        
                        # Method 1: Try YouTube Music specific album art
                        album_art = self.get_youtube_music_album_art(video_id)
                        
                        # Method 2: Try yt-dlp with album art focus
                        if not album_art:
                            album_art = self.get_hq_album_art_from_ytdlp(video_id)
                        
                        # Method 3: Fallback to song thumbnails
                        if not album_art:
                            print("🔄 Falling back to song thumbnails")
                            thumbnails = song.get("thumbnails", [])
                            if thumbnails:
                                base_url = thumbnails[-1].get("url", "")
                                if base_url:
                                    if thumb_quality == ThumbnailQuality.HIGH:
                                        album_art = re.sub(r'w\d+-h\d+', 'w320-h320', base_url)
                                    elif thumb_quality == ThumbnailQuality.VERY_HIGH:
                                        album_art = re.sub(r'w\d+-h\d+', 'w544-h544', base_url)
                                    else:
                                        album_art = base_url
                    else:
                        # Use song thumbnails for LOW and MED quality
                        thumbnails = song.get("thumbnails", [])
                        if thumbnails:
                            base_url = thumbnails[-1].get("url", "")
                            if base_url:
                                if thumb_quality == ThumbnailQuality.LOW:
                                    album_art = re.sub(r'w\d+-h\d+', 'w60-h60', base_url)
                                elif thumb_quality == ThumbnailQuality.MED:
                                    album_art = re.sub(r'w\d+-h\d+', 'w120-h120', base_url)
                                else:
                                    album_art = base_url
                    
                    print(f"🖼️ Album art URL: {album_art}")
                
                # Get audio URL
                audio_url = None
                if include_audio_url:
                    print(f"🎵 Getting audio URL for: {video_id}")
                    for attempt in range(3):
                        try:
                            audio_url = self.get_audio_url(video_id, audio_quality)
                            if audio_url:
                                print(f"✅ Got audio URL on attempt {attempt + 1}")
                                break
                            else:
                                print(f"⚠️ No audio URL on attempt {attempt + 1}")
                        except Exception as e:
                            print(f"❌ Audio URL attempt {attempt + 1} failed: {e}")
                        time.sleep(1)
                
                # Check if we should yield this result
                should_yield = not include_audio_url or audio_url
                
                if should_yield:
                    song_data = {
                        "title": title,
                        "artists": artists,
                        "videoId": video_id,
                        "duration": duration,
                        "artist_name": artist_name
                    }
                    if include_album_art:
                        song_data["albumArt"] = album_art
                    if include_audio_url:
                        song_data["audioUrl"] = audio_url
                    
                    processed_count += 1
                    print(f"✅ Yielding song {processed_count}: {title} by {artists}")
                    yield song_data
                else:
                    print(f"⚠️ Skipping song: Could not get audio URL for {title}")
                    skipped_count += 1
            
            except Exception as e:
                print(f"❌ Error processing song {i + 1}: {e}")
                skipped_count += 1
                continue
        
        print(f"🎉 Artist songs fetch completed! Found {processed_count} valid songs (skipped {skipped_count})")

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
    
    def get_hq_album_art_from_ytdlp(self, video_id: str) -> Optional[str]:
        """
        Get high quality album art using yt-dlp from video metadata
        Returns the highest quality album art URL available
        """
        try:
            ydl_opts = {
                "quiet": True,
                "no_warnings": True,
                "skip_download": True,
                "nocheckcertificate": True,
                "extract_flat": False,
                "socket_timeout": 30,
                "source_address": "0.0.0.0",
                "force_ipv4": True,
                "retries": 2,
                "headers": self._generate_headers()
            }
            
            if self.proxy:
                ydl_opts["proxy"] = self.proxy
                ydl_opts["proxy_headers"] = ydl_opts["headers"]
            
            ydl = yt_dlp.YoutubeDL(ydl_opts)
            
            info = ydl.extract_info(
                f"https://www.youtube.com/watch?v={video_id}",
                download=False
            )
            
            # First try to get album art from metadata
            album_art_url = None
            
            # Check for album art in various metadata fields
            if info.get('album_artist') and info.get('album'):
                # Try to construct album art URL from metadata
                album_art_url = self._get_album_art_from_metadata(info)
            
            # If no album art from metadata, fall back to high quality thumbnails
            if not album_art_url:
                thumbnails = info.get('thumbnails', [])
                if thumbnails:
                    # Filter for high quality thumbnails (prefer square ones for album art)
                    hq_thumbnails = [
                        t for t in thumbnails 
                        if t.get('width', 0) >= 720 and t.get('height', 0) >= 720
                    ]
                    
                    if hq_thumbnails:
                        # Sort by resolution and prefer square aspect ratios
                        hq_thumbnails.sort(
                            key=lambda t: (
                                abs(1.0 - (t.get('width', 1) / t.get('height', 1))),  # Prefer square
                                (t.get('width', 0) * t.get('height', 0))  # Then by resolution
                            ),
                            reverse=True
                        )
                        album_art_url = hq_thumbnails[0].get('url', '')
                    else:
                        # Fall back to highest resolution thumbnail
                        thumbnails.sort(
                            key=lambda t: (t.get('width', 0) * t.get('height', 0)),
                            reverse=True
                        )
                        album_art_url = thumbnails[0].get('url', '')
            
            if album_art_url:
                print(f"HQ Album Art found: {album_art_url}")
                return album_art_url
            
            return None
            
        except Exception as e:
            print(f"Error getting HQ album art for {video_id}: {e}")
            return None

    def _get_album_art_from_metadata(self, info: dict) -> Optional[str]:
        """
        Try to get album art from video metadata
        """
        try:
            # Check for album art in various metadata fields
            album_art_fields = ['album_art', 'album_artwork', 'artwork', 'cover']
            
            for field in album_art_fields:
                if info.get(field):
                    return info[field]
            
            # Try to get from uploader avatar if it's an official channel
            uploader = info.get('uploader', '').lower()
            if any(keyword in uploader for keyword in ['official', 'records', 'music', 'vevo']):
                uploader_avatar = info.get('uploader_avatar_url')
                if uploader_avatar:
                    return uploader_avatar
            
            return None
            
        except Exception:
            return None

    def get_youtube_music_album_art(self, video_id: str) -> Optional[str]:
        """
        Get album art specifically from YouTube Music metadata
        """
        try:
            # Use YTMusic to get song details which might have better album art
            song_info = self.ytmusic.get_song(video_id)
            
            # Extract album art from song info
            thumbnails = song_info.get('videoDetails', {}).get('thumbnail', {}).get('thumbnails', [])
            
            if thumbnails:
                # Sort by resolution to get highest quality
                thumbnails.sort(
                    key=lambda t: (t.get('width', 0) * t.get('height', 0)),
                    reverse=True
                )
                
                # Prefer square thumbnails for album art
                square_thumbnails = [
                    t for t in thumbnails 
                    if abs(1.0 - (t.get('width', 1) / t.get('height', 1))) < 0.1
                ]
                
                if square_thumbnails:
                    return square_thumbnails[0].get('url', '')
                else:
                    return thumbnails[0].get('url', '')
            
            return None
            
        except Exception as e:
            print(f"Error getting YouTube Music album art for {video_id}: {e}")
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
        audio_quality: AudioQuality = AudioQuality.HIGH,
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
                    if thumb_quality in [ThumbnailQuality.HIGH, ThumbnailQuality.VERY_HIGH]:
                        print(f"Trying to get HQ album art for related track: {track_video_id}")
                        
                        # Method 1: Try YouTube Music specific album art
                        album_art = self.get_youtube_music_album_art(track_video_id)
                        
                        # Method 2: Try yt-dlp with album art focus
                        if not album_art:
                            album_art = self.get_hq_album_art_from_ytdlp(track_video_id)
                        
                        # Method 3: Fallback to YTMusic thumbnails
                        if not album_art:
                            print("Falling back to YTMusic thumbnails for related track")
                            thumbnails = item.get("thumbnail", [])
                            if thumbnails:
                                base_url = thumbnails[-1].get("url", "")
                                if base_url:
                                    import re
                                    if thumb_quality == ThumbnailQuality.HIGH:
                                        # w320-h320-l90-rj for high quality
                                        album_art = re.sub(r'w\d+-h\d+', 'w320-h320', base_url)
                                    elif thumb_quality == ThumbnailQuality.VERY_HIGH:
                                        # w544-h544-l90-rj for very high quality
                                        album_art = re.sub(r'w\d+-h\d+', 'w544-h544', base_url)
                                    else:
                                        album_art = base_url
                        
                        # Apply quality settings to HQ URLs if they contain YouTube image patterns
                        if album_art and any(pattern in album_art for pattern in ['googleusercontent.com', 'ytimg.com', 'youtube.com']):
                            import re
                            if thumb_quality == ThumbnailQuality.HIGH:
                                # Force HIGH quality resolution even for HQ sources
                                album_art = re.sub(r'w\d+-h\d+', 'w320-h320', album_art)
                            elif thumb_quality == ThumbnailQuality.VERY_HIGH:
                                # Keep or set VERY_HIGH quality resolution
                                album_art = re.sub(r'w\d+-h\d+', 'w544-h544', album_art)
                    else:
                        # Use YTMusic thumbnails for all quality levels
                        thumbnails = item.get("thumbnail", [])
                        if thumbnails:
                            base_url = thumbnails[-1].get("url", "")
                            if base_url:
                                import re
                                if thumb_quality == ThumbnailQuality.LOW:
                                    # w60-h60-l90-rj for lowest quality
                                    album_art = re.sub(r'w\d+-h\d+', 'w60-h60', base_url)
                                elif thumb_quality == ThumbnailQuality.MED:
                                    # w120-h120-l90-rj for medium quality
                                    album_art = re.sub(r'w\d+-h\d+', 'w120-h120', base_url)
                                else:
                                    album_art = base_url
                            else:
                                album_art = ""
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


# =================================================================================================================================
# =================================================================================================================================


class DynamicLyricsProvider:
    """
    A dynamic lyrics provider that fetches lyrics with timestamps from KuGou.
    Designed for Flutter/Kotlin integration to provide real-time lyrics display.
    """
    
    PAGE_SIZE = 8
    HEAD_CUT_LIMIT = 30
    DURATION_TOLERANCE = 8
    ACCEPTED_REGEX = re.compile(r"\[(\d\d):(\d\d)\.(\d{2,3})\].*")
    BANNED_REGEX = re.compile(r".+].+[:：].+")
    
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        })
    
    def normalize_title(self, title: str) -> str:
        """Clean title for better search results"""
        return re.sub(r'\(.*\)|（.*）|「.*」|『.*』|<.*>|《.*》|〈.*〉|＜.*＞', '', title).strip()
    
    def normalize_artist(self, artist: str) -> str:
        """Clean artist name for better search results"""
        artist = re.sub(r', | & |\.|和', '、', artist)
        return re.sub(r'\(.*\)|（.*）', '', artist).strip()
    
    def generate_keyword(self, title: str, artist: str) -> Dict[str, str]:
        """Generate search keywords from title and artist"""
        return {
            'title': self.normalize_title(title),
            'artist': self.normalize_artist(artist)
        }
    
    def normalize_lyrics(self, lyrics: str) -> str:
        """Clean and filter lyrics to keep only timestamped lines"""
        lyrics = lyrics.replace("&apos;", "'")
        lines = [line for line in lyrics.split('\n') if self.ACCEPTED_REGEX.match(line)]
        
        # Remove useless info from beginning
        head_cut_line = 0
        for i in range(min(self.HEAD_CUT_LIMIT, len(lines)-1), -1, -1):
            if self.BANNED_REGEX.match(lines[i]):
                head_cut_line = i + 1
                break
        filtered_lines = lines[head_cut_line:]
        
        # Remove useless info from end
        tail_cut_line = 0
        for i in range(min(len(lines)-self.HEAD_CUT_LIMIT, len(lines)-1), -1, -1):
            if self.BANNED_REGEX.match(lines[len(lines)-1-i]):
                tail_cut_line = i + 1
                break
        final_lines = filtered_lines[:len(filtered_lines)-tail_cut_line] if tail_cut_line > 0 else filtered_lines
        
        return '\n'.join(final_lines)
    
    def search_songs(self, keyword: Dict[str, str]) -> Dict[str, Any]:
        """Search for songs on KuGou to get hash"""
        url = "https://mobileservice.kugou.com/api/v3/search/song"
        params = {
            'version': 9108,
            'plat': 0,
            'pagesize': self.PAGE_SIZE,
            'showtype': 0,
            'keyword': f"{keyword['title']} - {keyword['artist']}"
        }
        try:
            response = self.session.get(url, params=params, timeout=10)
            return response.json()
        except Exception as e:
            print(f"Error searching songs: {e}")
            return {}
    
    def search_lyrics_by_keyword(self, keyword: Dict[str, str], duration: int = -1) -> Dict[str, Any]:
        """Search for lyrics by keyword"""
        url = "https://lyrics.kugou.com/search"
        params = {
            'ver': 1,
            'man': 'yes',
            'client': 'pc',
            'keyword': f"{keyword['title']} - {keyword['artist']}"
        }
        if duration != -1:
            params['duration'] = duration * 1000
        
        try:
            response = self.session.get(url, params=params, timeout=10)
            return response.json()
        except Exception as e:
            print(f"Error searching lyrics by keyword: {e}")
            return {}
    
    def search_lyrics_by_hash(self, hash: str) -> Dict[str, Any]:
        """Search for lyrics by song hash"""
        url = "https://lyrics.kugou.com/search"
        params = {
            'ver': 1,
            'man': 'yes',
            'client': 'pc',
            'hash': hash
        }
        try:
            response = self.session.get(url, params=params, timeout=10)
            return response.json()
        except Exception as e:
            print(f"Error searching lyrics by hash: {e}")
            return {}
    
    def download_lyrics(self, id: str, accesskey: str) -> Dict[str, Any]:
        """Download lyrics content"""
        url = "https://lyrics.kugou.com/download"
        params = {
            'fmt': 'lrc',
            'charset': 'utf8',
            'client': 'pc',
            'ver': 1,
            'id': id,
            'accesskey': accesskey
        }
        try:
            response = self.session.get(url, params=params, timeout=10)
            return response.json()
        except Exception as e:
            print(f"Error downloading lyrics: {e}")
            return {}
    
    def parse_lrc_timestamps(self, lyrics: str) -> List[Dict[str, Any]]:
        """Parse LRC format and convert to structured format for Flutter"""
        lines = []
        for line in lyrics.split('\n'):
            match = self.ACCEPTED_REGEX.match(line)
            if match:
                minutes = int(match.group(1))
                seconds = int(match.group(2))
                milliseconds = int(match.group(3).ljust(3, '0')[:3])  # Ensure 3 digits
                
                timestamp_ms = (minutes * 60 * 1000) + (seconds * 1000) + milliseconds
                text = line.split(']', 1)[1].strip() if ']' in line else ""
                
                if text:  # Only add non-empty lines
                    lines.append({
                        'timestamp': timestamp_ms,
                        'text': text,
                        'time_formatted': f"{minutes:02d}:{seconds:02d}.{milliseconds:03d}"
                    })
        
        return sorted(lines, key=lambda x: x['timestamp'])
    
    def fetch_lyrics(self, title: str, artist: str, duration: int = -1) -> Optional[Dict[str, Any]]:
        """
        Main method to fetch lyrics with timestamps.
        Returns simplified structured data suitable for Flutter/Kotlin integration.
        """
        print(f"Starting lyrics fetch for: {title} by {artist}")
        
        keyword = self.generate_keyword(title, artist)
        print(f"Generated keyword: {keyword}")

        # First try searching by song hash
        print("Searching songs by keyword...")
        songs = self.search_songs(keyword)
        print(f"Found {len(songs.get('data', {}).get('info', []))} song matches")

        for song in songs.get('data', {}).get('info', []):
            try:
                if duration == -1 or abs(song['duration'] - duration) <= self.DURATION_TOLERANCE:
                    print(f"Trying song hash: {song['hash']}")
                    lyrics_data = self.search_lyrics_by_hash(song['hash'])
                    print(f"Lyrics search result: {lyrics_data}")

                    if lyrics_data.get('candidates'):
                        candidate = lyrics_data['candidates'][0]
                        print(f"Downloading lyrics for candidate: {candidate}")
                        lyrics = self.download_lyrics(candidate['id'], candidate['accesskey'])
                        print(f"Downloaded lyrics content: {lyrics.get('content') is not None}")

                        if lyrics.get('content'):
                            try:
                                content = base64.b64decode(lyrics['content']).decode('utf-8')
                                normalized = self.normalize_lyrics(content)
                                print(f"Normalized lyrics length: {len(normalized)} chars")

                                if "纯音乐，请欣赏" in normalized or "酷狗音乐  就是歌多" in normalized:
                                    print("Skipping instrumental track")
                                    continue
                                
                                parsed_lyrics = self.parse_lrc_timestamps(normalized)
                                print(f"Parsed {len(parsed_lyrics)} lyrics lines")

                                if parsed_lyrics:
                                    return {
                                        'success': True,
                                        'lyrics': parsed_lyrics,
                                        'source': 'KuGou',
                                        'total_lines': len(parsed_lyrics)
                                    }
                            except Exception as e:
                                print(f"Error processing lyrics: {e}")
                                continue
            except Exception as e:
                print(f"Error processing song: {e}")
                continue

        # If not found, try searching by keyword
        print("Trying lyrics search by keyword...")
        lyrics_data = self.search_lyrics_by_keyword(keyword, duration)
        print(f"Keyword search result: {lyrics_data}")

        if lyrics_data.get('candidates'):
            candidate = lyrics_data['candidates'][0]
            print(f"Downloading lyrics for keyword candidate: {candidate}")
            lyrics = self.download_lyrics(candidate['id'], candidate['accesskey'])
            print(f"Downloaded lyrics content: {lyrics.get('content') is not None}")

            if lyrics.get('content'):
                try:
                    content = base64.b64decode(lyrics['content']).decode('utf-8')
                    normalized = self.normalize_lyrics(content)
                    print(f"Normalized lyrics length: {len(normalized)} chars")

                    if "纯音乐，请欣赏" in normalized or "酷狗音乐  就是歌多" in normalized:
                        print("Returning not found for instrumental track")
                        return {
                            'success': False,
                            'error': f'No lyrics found for {title} by {artist}'
                        }
                    
                    parsed_lyrics = self.parse_lrc_timestamps(normalized)
                    print(f"Parsed {len(parsed_lyrics)} lyrics lines")

                    if parsed_lyrics:
                        return {
                            'success': True,
                            'lyrics': parsed_lyrics,
                            'source': 'KuGou',
                            'total_lines': len(parsed_lyrics)
                        }
                except Exception as e:
                    print(f"Error processing lyrics: {e}")

        print("No lyrics found after all attempts")
        return {
            'success': False,
            'error': f'No lyrics found for {title} by {artist}'
        }

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


# if __name__ == "__main__":
# #     print("=== Testing HQ Thumbnail Functionality ===")
    
# #     # Initialize searcher
#     searcher = YTMusicSearcher(country="US")
    
# #     # Test search with HQ thumbnails
#     print("\n--- Testing Search with VERY_HIGH Quality Thumbnails ---")
#     test_query = "Blinding Lights"
    
#     for i, song in enumerate(searcher.get_music_details(
#         test_query, 
#         limit=2, 
#         thumb_quality=ThumbnailQuality.VERY_HIGH,
#         audio_quality=AudioQuality.VERY_HIGH,
#         include_audio_url=True  # Faster testing
#     ), 1):
#         print(f"\n{i}. {song['title']} by {song['artists']}")
#         print(f"Video ID: {song['videoId']}")
#         if 'albumArt' in song and song['albumArt']:
#             print(f"HQ Album Art URL: {song['albumArt']}")
#             print(f"HQ Audio URL: {song['audioUrl']}")
#         else:
            # print("No album art found")
    
    # Test related songs with HQ thumbnails
    # print("\n--- Testing Related Songs with HIGH Quality Thumbnails ---")
    # related_fetcher = YTMusicRelatedFetcher(country="US")
    
    # for i, song in enumerate(related_fetcher.getRelated(
    #     song_name="Shape of You",
    #     artist_name="Ed Sheeran",
    #     limit=2,
    #     thumb_quality=ThumbnailQuality.HIGH,
    #     include_audio_url=False
    # ), 1):
    #     print(f"\n{i}. {song['title']} by {song['artists']}")
    #     print(f"Video ID: {song['videoId']}")
    #     if 'albumArt' in song and song['albumArt']:
    #         print(f"HQ Album Art URL: {song['albumArt']}")
    #     else:
    #         print("No album art found")
    
    # print("\nHQ Thumbnail testing completed!")