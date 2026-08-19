import yt_dlp
import os
import json

def fetch_video_metadata(video_id):
    ydl_opts = {
        'quiet': True,
        'no_warnings': True,
        'extract_flat': True,
        'skip_download': True,
        'extractor_args': {'youtube': ['player_client=android,web']}
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(f"https://www.youtube.com/watch?v={video_id}", download=False)
        return json.dumps({
            "title": info.get("title", ""),
            "uploader": info.get("uploader", ""),
            "channel": info.get("channel", ""),
            "duration": info.get("duration", 0),
            "thumbnail": info.get("thumbnail", "")
        })

def fetch_playlist_videos(playlist_url):
    ydl_opts = {
        'quiet': True,
        'no_warnings': True,
        'extract_flat': True,
        'skip_download': True,
        'extractor_args': {'youtube': ['player_client=android,web']}
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(playlist_url, download=False)
        return json.dumps({
            "title": info.get("title", ""),
            "entries": [
                {
                    "video_id": entry.get("id"),
                    "title": entry.get("title", ""),
                    "duration": entry.get("duration", 0)
                } for entry in info.get("entries", []) if entry.get("id")
            ]
        })

def download_audio_full(video_id, output_dir, safe_filename):
    output_path = os.path.join(output_dir, f"{video_id}_{safe_filename}.m4a")
    ydl_opts = {
        'format': 'bestaudio[ext=m4a]/bestaudio',
        'outtmpl': output_path,
        'quiet': True,
        'no_warnings': True,
        'noprogress': True,
        'extractor_args': {'youtube': ['player_client=android,web']}
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(f"https://www.youtube.com/watch?v={video_id}", download=True)
        return json.dumps({
            "path": output_path,
            "metadata": {
                "title": info.get("title", ""),
                "uploader": info.get("uploader", ""),
                "channel": info.get("channel", ""),
                "duration": info.get("duration", 0),
                "thumbnail": info.get("thumbnail", "")
            }
        })

def check_stream_url(video_id):
    ydl_opts = {
        'quiet': True,
        'no_warnings': True,
        'extract_flat': False,
        'skip_download': True,
        'extractor_args': {'youtube': ['player_client=android,web']}
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(f"https://www.youtube.com/watch?v={video_id}", download=False)
        return json.dumps({
            "url": info.get("url", "") or next((f.get("url") for f in info.get("formats", []) if f.get("url")), "")
        })
