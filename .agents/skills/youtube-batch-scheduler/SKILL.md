---
name: youtube-batch-scheduler
description: Automatically batch schedules YouTube Shorts / videos on the channel (史力爱卫) using the YouTube Data API v3. Handles OAuth authentication, 3 daily time slots (09:00, 14:00, 19:30 Local Time), auto-resuming from previous batches, and daily quota limits.
---

# YouTube Video Batch Scheduler Skill

## Overview
This skill automates scheduling private/draft YouTube Shorts on the **史力爱卫** channel using YouTube Data API v3.

## Publishing Schedule Policy
- **Daily Frequency**: Exactly **3 videos per day**.
- **Timeslots (Local UTC+7 / ICT)**:
  - **Slot 1 (Morning)**: `09:00 AM` (02:00 UTC)
  - **Slot 2 (Afternoon)**: `14:00 PM` (07:00 UTC)
  - **Slot 3 (Evening)**: `19:30 PM` (12:30 UTC)
- **Order**: Oldest uploaded first (sequential release).

## Key Files
- `client_secret.json`: OAuth 2.0 Client credentials from Google Cloud Console.
- `token.json`: Authenticated user OAuth token (valid and persistent).
- `batch_scheduler.py`: Main executable auto-resuming batch scheduler.

## How to Run / Continue
Whenever the user asks to schedule videos, check progress, or continue the next batch:
```bash
./venv/bin/python batch_scheduler.py
```

## Behavior & Quota Limits
1. The script inspects all private videos on the channel and identifies:
   - Already scheduled videos (reads their `publishAt` dates).
   - Unscheduled draft videos.
2. It finds the latest scheduled date and automatically calculates the next slot so there are no gaps.
3. YouTube Data API allows ~180-200 updates per 24 hours (10,000 units quota). When quota is reached, it saves state and stops cleanly.
4. Running the script again on the next day picks up seamlessly from the next unscheduled video.
