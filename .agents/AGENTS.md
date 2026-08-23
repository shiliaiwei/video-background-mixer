# Workspace Rules

## Video Processing Rules

- **Output Folder Grouping**: When generating videos in the output directory, always organize them into subfolders (e.g., `part_1`, `part_2`) with a strict limit of **15 videos per folder**.
- **Duration Limits & Dynamic Speed-Up**: 
  - All output videos must be **under 3 minutes** (180 seconds) to comply with YouTube Shorts requirements.
  - If a video is longer than 3 minutes, do not truncate or cap it. Instead, **speed up** both the video (`setpts`) and audio (`atempo`) dynamically by a calculated factor to bring the final duration under 3 minutes (targeting **2 minutes and 50 seconds / 170 seconds**).
- **Folder Exclusion and Scope**: Never process, modify, or touch videos inside the `fb` folder. Only look in and process videos located in the `videos` folder.
- **Watermark Font Style**: The text watermark ("史力爱卫") must be rendered in **bold** using `STHeiti Medium.ttc` or an equivalent bold system font.
- **Audio Mixing Volumes**: The background music volume must be mixed at **1.50 (150% volume)** relative to the original video audio, which remains at **1.00 (100% volume)**.
- **Audio Fading**: No fade-in or fade-out effects must be applied to any audio track (fade duration set to 0).
- **Output Preservation**: Never delete, overwrite, or clear existing processed videos in the output directory. Always keep existing outputs and only add new videos when processing.
- **Hashtag Format**: Each processed video must have exactly three hashtags in its filename. The first hashtag must represent the chess opening name (e.g., `#CaroKann` or `#CaroKannDefense` for Caro-Kann Defense, `#DanishGambit` for Danish Gambit, etc.). The second and third hashtags must always be `#CheckMate` and `#Winner` (capitalized in CamelCase).

## YouTube Auto-Scheduling Rules & Skill

- **Schedule Cadence**: Strictly **3 videos per day** at 3 fixed daily time slots (Local Time UTC+7 / ICT):
  - **Slot 1**: `09:00 AM` (02:00 UTC)
  - **Slot 2**: `14:00 PM` (07:00 UTC)
  - **Slot 3**: `19:30 PM` (12:30 UTC)
- **Batch Script**: Always use [batch_scheduler.py](file:///Users/Apple16/Desktop/Go%20To%20YouT/batch_scheduler.py) which auto-resumes from the latest scheduled video slot and respects YouTube Data API daily quotas (~186-200 videos/day).
- **Execution Command**: `./venv/bin/python batch_scheduler.py`


