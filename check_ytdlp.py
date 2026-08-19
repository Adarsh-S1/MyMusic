import yt_dlp
import os
import sys

def test_download(video_id):
    print(f"Testing yt-dlp download for video ID: {video_id}...\n")
    
    # We use the same options as the app's ytdlp_wrapper.py
    ydl_opts = {
        'format': 'bestaudio[ext=m4a]/bestaudio',
        'outtmpl': 'test_download_%(id)s.%(ext)s',
        'quiet': False, # We want to see logs
        'no_warnings': False,
        'extractor_args': {'youtube': ['player_client=android,web']}
    }
    
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            print("Extracting info and downloading...")
            info = ydl.extract_info(f"https://www.youtube.com/watch?v={video_id}", download=True)
            print("\n✅ SUCCESS! Download completed.")
            print(f"Title: {info.get('title')}")
            
            # Clean up test file
            filename = f"test_download_{video_id}.m4a"
            if os.path.exists(filename):
                os.remove(filename)
                print(f"Cleaned up {filename}")
                
    except Exception as e:
        print(f"\n❌ FAILED: {str(e)}")

if __name__ == "__main__":
    test_video = "dQw4w9WgXcQ" # Rick Astley - Never Gonna Give You Up
    test_download(test_video)
