import os
import sys
import time
import datetime
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

SCOPES = [
    'https://www.googleapis.com/auth/youtube',
    'https://www.googleapis.com/auth/youtube.force-ssl'
]

CLIENT_SECRET_FILE = 'client_secret.json'
TOKEN_FILE = 'token.json'

# User's Local Timezone Offset (+07:00 ICT)
LOCAL_UTC_OFFSET_HOURS = 7

# 3 Daily Publishing Slots in Local Time (Hour, Minute)
SLOTS = [
    (9, 0),    # 09:00 AM (Slot 1)
    (14, 0),   # 02:00 PM (Slot 2)
    (19, 30)   # 07:30 PM (Slot 3)
]

def get_authenticated_service():
    if not os.path.exists(TOKEN_FILE):
        raise FileNotFoundError(f"Missing {TOKEN_FILE}")
    creds = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)
    if creds.expired and creds.refresh_token:
        creds.refresh(Request())
        with open(TOKEN_FILE, 'w') as f:
            f.write(creds.to_json())
    return build('youtube', 'v3', credentials=creds)

def fetch_channel_videos_status(youtube):
    """
    Fetches all recent private chess videos and separates them into:
    1. already_scheduled (with their publishAt dates)
    2. unscheduled (waiting to be scheduled)
    """
    channel_resp = youtube.channels().list(mine=True, part='contentDetails,snippet').execute()
    channel_title = channel_resp['items'][0]['snippet']['title']
    uploads_id = channel_resp['items'][0]['contentDetails']['relatedPlaylists']['uploads']
    print(f"Connected to Channel: {channel_title}")
    print("Scanning YouTube Studio for videos...")

    raw_items = []
    next_page = None
    while True:
        res = youtube.playlistItems().list(
            playlistId=uploads_id,
            part='snippet,status',
            maxResults=50,
            pageToken=next_page
        ).execute()
        for item in res.get('items', []):
            if item['status']['privacyStatus'] == 'private':
                pub_at = item['snippet']['publishedAt']
                if pub_at.startswith('2026'):
                    raw_items.append({
                        'id': item['snippet']['resourceId']['videoId'],
                        'title': item['snippet']['title'],
                        'uploaded_at': pub_at
                    })
        next_page = res.get('nextPageToken')
        if not next_page:
            break

    print(f"Found {len(raw_items)} private chess videos. Checking schedule status...")

    scheduled = []
    unscheduled = []

    for i in range(0, len(raw_items), 50):
        batch = raw_items[i:i+50]
        batch_ids = [v['id'] for v in batch]
        vid_res = youtube.videos().list(id=','.join(batch_ids), part='status,snippet').execute()
        for item in vid_res.get('items', []):
            status = item.get('status', {})
            publish_at = status.get('publishAt')
            v_info = {
                'id': item['id'],
                'title': item['snippet']['title'],
                'uploaded_at': item['snippet']['publishedAt']
            }
            if publish_at:
                v_info['publishAt'] = publish_at
                scheduled.append(v_info)
            else:
                unscheduled.append(v_info)

    # Sort oldest uploaded first
    unscheduled.sort(key=lambda x: x['uploaded_at'])
    return scheduled, unscheduled

def calculate_next_start_slot(scheduled_videos):
    """
    Finds the latest scheduled publishAt date and calculates the next slot.
    If none scheduled, defaults to tomorrow at 09:00 AM.
    """
    now_local = datetime.datetime.now()
    default_start = (now_local + datetime.timedelta(days=1)).date()

    if not scheduled_videos:
        return default_start, 0

    latest_utc_str = max(v['publishAt'] for v in scheduled_videos)
    # Parse UTC string (e.g. 2026-10-24T12:30:00Z)
    clean_str = latest_utc_str.replace('Z', '+00:00')
    latest_utc_dt = datetime.datetime.fromisoformat(clean_str)
    latest_local_dt = latest_utc_dt + datetime.timedelta(hours=LOCAL_UTC_OFFSET_HOURS)

    # Determine which slot was the latest
    latest_hour = latest_local_dt.hour
    latest_date = latest_local_dt.date()

    if latest_hour < 11:
        # Next is Slot 2 (14:00) of same day
        return latest_date, 1
    elif latest_hour < 16:
        # Next is Slot 3 (19:30) of same day
        return latest_date, 2
    else:
        # Next is Slot 1 (09:00) of next day
        return latest_date + datetime.timedelta(days=1), 0

def generate_schedule_slots(start_date, start_slot_idx, total_count):
    """Generates continuous schedule slots starting from the next available slot."""
    slots = []
    current_day = start_date
    current_slot_idx = start_slot_idx
    video_idx = 0

    while video_idx < total_count:
        while current_slot_idx < len(SLOTS) and video_idx < total_count:
            hour, minute = SLOTS[current_slot_idx]
            local_dt = datetime.datetime(
                current_day.year, current_day.month, current_day.day,
                hour, minute, 0
            )
            utc_dt = local_dt - datetime.timedelta(hours=LOCAL_UTC_OFFSET_HOURS)
            slots.append((utc_dt, local_dt))
            video_idx += 1
            current_slot_idx += 1
        current_day += datetime.timedelta(days=1)
        current_slot_idx = 0

    return slots

def schedule_video(youtube, video_id, publish_at_utc):
    iso_str = publish_at_utc.strftime('%Y-%m-%dT%H:%M:%SZ')
    body = {
        'id': video_id,
        'status': {
            'privacyStatus': 'private',
            'publishAt': iso_str,
            'selfDeclaredMadeForKids': False
        }
    }
    return youtube.videos().update(part='status', body=body).execute()

def main():
    youtube = get_authenticated_service()
    
    scheduled_videos, unscheduled_videos = fetch_channel_videos_status(youtube)
    print(f"\n📊 Current Status:")
    print(f"  - Already Scheduled: {len(scheduled_videos)} videos")
    print(f"  - Remaining to Schedule: {len(unscheduled_videos)} videos")
    
    if not unscheduled_videos:
        print("🎉 All videos are already scheduled! No action needed.")
        return

    start_date, start_slot_idx = calculate_next_start_slot(scheduled_videos)
    time_slots = generate_schedule_slots(start_date, start_slot_idx, len(unscheduled_videos))

    print(f"\n=======================================================")
    print(f" 🚀 YOUTUBE 3-SLOT DAILY AUTO-SCHEDULER")
    print(f" Daily Slots (Local +07:00): 09:00 AM | 02:00 PM | 07:30 PM")
    print(f" Resuming From: {time_slots[0][1].strftime('%Y-%m-%d %H:%M')}")
    print(f" Ending At:     {time_slots[-1][1].strftime('%Y-%m-%d %H:%M')}")
    print(f"=======================================================\n")

    success_count = 0
    quota_exceeded = False

    for idx, (video, (utc_dt, local_dt)) in enumerate(zip(unscheduled_videos, time_slots), start=1):
        vid_id = video['id']
        title = video['title']
        loc_str = local_dt.strftime('%Y-%m-%d %H:%M')

        try:
            schedule_video(youtube, vid_id, utc_dt)
            print(f"[{idx:4d}/{len(unscheduled_videos)}] ✅ Scheduled: {loc_str} | {vid_id} | {title[:50]}", flush=True)
            success_count += 1
            time.sleep(0.1)
        except HttpError as e:
            err_content = str(e)
            if "quotaExceeded" in err_content or "quota" in err_content.lower():
                print(f"\n⚠️ YouTube API daily quota limit reached after {success_count} videos.", flush=True)
                print("YouTube allows ~200 video updates per 24 hours.", flush=True)
                print(f"Progress saved! Total scheduled on channel is now: {len(scheduled_videos) + success_count}", flush=True)
                print("Simply run 'python batch_scheduler.py' again tomorrow to continue the next batch.", flush=True)
                quota_exceeded = True
                break
            else:
                print(f"[{idx:4d}/{len(unscheduled_videos)}] ❌ Error for {vid_id}: {e}", flush=True)
                time.sleep(1)

    print(f"\n=======================================================")
    print(f" SUMMARY:")
    print(f" Scheduled in this run: {success_count} video(s)")
    print(f" Total Scheduled on channel: {len(scheduled_videos) + success_count} video(s)")
    print(f" Remaining Unscheduled: {len(unscheduled_videos) - success_count} video(s)")
    print(f"=======================================================\n")

if __name__ == '__main__':
    main()
