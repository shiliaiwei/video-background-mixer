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
