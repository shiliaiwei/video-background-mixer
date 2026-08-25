---
name: fb-video-reorganizer
description: Safely reorganizes and partitions Facebook videos in the 'fb/' folder into numbered batch subfolders (part_1, part_2, ...) with a strict limit of 12 videos per folder, resolving duplicate names and preventing data loss through staging.
---

# Facebook Video Folder Reorganizer Skill

## Overview
This skill reorganizes all video assets (`.mp4`, `.mov`) stored in the `fb/` directory into cleanly partitioned subfolders (`part_1`, `part_2`, `part_3`, ...) with exactly **12 videos per folder**.

## Reorganization Rules & Safety
1. **Target Directory**: `fb/`
2. **Batch Limit**: **12 videos per subfolder** (`part_1`, `part_2`, etc.).
3. **Collision Safety**: If duplicate filenames exist across subfolders, they are automatically renamed using `_dup1`, `_dup2` suffix during staging to ensure zero data loss.
4. **Staging Mechanism**: Uses a temporary staging directory `fb_temp_stage` to safely gather, deduplicate, and redistribute all videos before clearing old empty/messy subfolders.
5. **Supported Extensions**: `.mp4`, `.mov`.

## Key Files
- [reorganize_fb.py](file:///Users/Apple16/Desktop/Go%20To%20YouT/reorganize_fb.py): The standalone reorganization script.

## Execution Command
To run or trigger the reorganization workflow:
```bash
python3 reorganize_fb.py
```
or with virtual environment:
```bash
./venv/bin/python reorganize_fb.py
```

## When to Trigger
- User asks to **"reorganize fb videos"**, **"organize fb folder"**, **"split fb videos into parts"**, or **"batch fb videos 12 per folder"**.
- New raw videos have been added to the root of `fb/` or unsorted subdirectories inside `fb/`.
