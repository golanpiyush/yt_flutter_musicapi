from ytmusicapi import YTMusic

# Initialize YTMusic without auth
ytmusic = YTMusic()

def get_artist_songs(artist_name, max_songs=20):
    # Step 1: Search the artist
    results = ytmusic.search(artist_name, filter="artists")
    if not results:
        print("Artist not found.")
        return

    artist = results[0]
    artist_id = artist["browseId"]

    # Step 2: Fetch artist's full details
    artist_data = ytmusic.get_artist(artist_id)
    songs = []

    # Step 3: Go through artist's "songs" section
    for section in artist_data["songs"]["results"][:max_songs]:
        title = section["title"]
        video_id = section["videoId"]
        artists = ', '.join([a["name"] for a in section["artists"]])
        songs.append({
            "title": title,
            "video_id": video_id,
            "artists": artists
        })

    return songs

# Example usage
songs = get_artist_songs("Enimen", max_songs=10)
for idx, song in enumerate(songs, 1):
    print(f"{idx}. {song['title']} - {song['artists']} (https://music.youtube.com/watch?v={song['video_id']})")
