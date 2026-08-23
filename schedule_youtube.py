import os
import sys
import datetime
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

SCOPES = [
    'https://www.googleapis.com/auth/youtube',
    'https://www.googleapis.com/auth/youtube.force-ssl'
]

CLIENT_SECRET_FILE = 'client_secret.json'
TOKEN_FILE = 'token.json'

def get_authenticated_service():
    """Authenticates the user and returns the YouTube service client."""
    creds = None
    if os.path.exists(TOKEN_FILE):
        creds = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)
        
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not os.path.exists(CLIENT_SECRET_FILE):
                print(f"Error: '{CLIENT_SECRET_FILE}' not found in current directory.", flush=True)
                sys.exit(1)
            print("Starting authentication flow...", flush=True)
            flow = InstalledAppFlow.from_client_secrets_file(CLIENT_SECRET_FILE, SCOPES)
            creds = flow.run_local_server(port=8080, open_browser=True, prompt='consent')
            
        with open(TOKEN_FILE, 'w') as token_file:
            token_file.write(creds.to_json())

    return build('youtube', 'v3', credentials=creds)

def get_all_private_videos(youtube):
    """Fetches all private/unlisted videos on the channel."""
    channel_resp = youtube.channels().list(
        mine=True,
        part='contentDetails,snippet'
    ).execute()

    if not channel_resp.get('items'):
        print("No channel found.")
        return []

    channel_title = channel_resp['items'][0]['snippet']['title']
    uploads_id = channel_resp['items'][0]['contentDetails']['relatedPlaylists']['uploads']
    print(f"Connected to Channel: {channel_title}")

    videos = []
    next_page_token = None

    while True:
        playlist_resp = youtube.playlistItems().list(
            playlistId=uploads_id,
            part='snippet,status',
            maxResults=50,
            pageToken=next_page_token
        ).execute()

        for item in playlist_resp.get('items', []):
            vid_id = item['snippet']['resourceId']['videoId']
            title = item['snippet']['title']
            privacy = item['status']['privacyStatus']
            # Only include private videos that can be scheduled
            if privacy == 'private':
                videos.append({
                    'id': vid_id,
                    'title': title,
                    'privacy': privacy,
                    'uploaded_at': item['snippet']['publishedAt']
                })

        next_page_token = playlist_resp.get('nextPageToken')
        if not next_page_token:
            break

    return videos

def schedule_video(youtube, video_id, publish_datetime_utc):
    """Schedules a video for a specific UTC datetime."""
    publish_at_iso = publish_datetime_utc.strftime('%Y-%m-%dT%H:%M:%S.000Z')

    body = {
        'id': video_id,
        'status': {
            'privacyStatus': 'private',
            'publishAt': publish_at_iso
        }
    }

    try:
        response = youtube.videos().update(
            part='status',
            body=body
        ).execute()
        return True, publish_at_iso
    except Exception as e:
        return False, str(e)

def main():
    youtube = get_authenticated_service()
    
    print("\n🔍 Fetching private / unscheduled videos from your channel...")
    private_videos = get_all_private_videos(youtube)
    
    if not private_videos:
        print("No private videos found to schedule.")
        return

    print(f"\nFound {len(private_videos)} private video(s) ready for scheduling:")
    for idx, v in enumerate(private_videos, start=1):
        print(f"  [{idx:2d}] {v['id']} | {v['title'][:60]}")

    print("\n" + "="*50)
    print("      YOUTUBE VIDEO AUTO-SCHEDULER")
    print("="*50)
    
    # 1. Order selection
    print("\nSelect Order:")
    print("  1. Oldest uploaded first (Recommended for sequential series)")
    print("  2. Newest uploaded first")
    order_choice = input("Enter choice (1/2, default: 1): ").strip() or "1"
    
    if order_choice == "1":
        private_videos.reverse()  # Oldest first

    # 2. How many videos to schedule
    count_input = input(f"\nHow many videos to schedule? (1-{len(private_videos)}, default: {len(private_videos)}): ").strip()
    count = int(count_input) if count_input.isdigit() else len(private_videos)
    videos_to_schedule = private_videos[:count]

    # 3. Start date and time
    print("\nEnter Start Date & Time (in your local time):")
    now_local = datetime.datetime.now()
    tomorrow_default = (now_local + datetime.timedelta(days=1)).strftime("%Y-%m-%d 18:00")
    start_str = input(f"Start datetime [YYYY-MM-DD HH:MM] (default: {tomorrow_default}): ").strip() or tomorrow_default
    start_local = datetime.datetime.strptime(start_str, "%Y-%m-%d %H:%M")

    # 4. Interval
    print("\nSelect Publishing Interval:")
    print("  1. Daily (1 video per day at the same time)")
    print("  2. Every X hours")
    print("  3. Custom interval in days")
    interval_choice = input("Enter choice (1/2/3, default: 1): ").strip() or "1"

    if interval_choice == "2":
        hours = float(input("Enter hours between videos (e.g. 4, 6, 12): ").strip() or "6")
        time_delta = datetime.timedelta(hours=hours)
    elif interval_choice == "3":
        days = float(input("Enter days between videos (e.g. 2, 3): ").strip() or "1")
        time_delta = datetime.timedelta(days=days)
    else:
        time_delta = datetime.timedelta(days=1)

    # Preview Schedule
    print("\n" + "="*65)
    print("PREVIEW SCHEDULE:")
    print("="*65)
    
    schedule_plan = []
    # Local time to UTC conversion
    utc_offset = datetime.datetime.now() - datetime.datetime.utcnow()
    
    current_time_local = start_local
    for idx, v in enumerate(videos_to_schedule, start=1):
        current_time_utc = current_time_local - utc_offset
        schedule_plan.append((v, current_time_utc, current_time_local))
        print(f"[{idx:2d}] {current_time_local.strftime('%Y-%m-%d %H:%M')} (Local) | {v['id']} | {v['title'][:45]}")
        current_time_local += time_delta

    print("="*65)
    confirm = input("\nProceed with scheduling these videos on YouTube? (y/n): ").strip().lower()
    if confirm != 'y':
        print("Aborted. No videos were modified.")
        return

    print("\n🚀 Scheduling videos on YouTube...")
    success_count = 0
    for v, utc_dt, loc_dt in schedule_plan:
        ok, res = schedule_video(youtube, v['id'], utc_dt)
        if ok:
            print(f"✅ Scheduled: {v['title'][:40]} -> {loc_dt.strftime('%Y-%m-%d %H:%M')}")
            success_count += 1
        else:
            print(f"❌ Failed for {v['id']}: {res}")

    print(f"\n🎉 Done! Successfully scheduled {success_count}/{len(schedule_plan)} video(s).")

if __name__ == '__main__':
    main()
