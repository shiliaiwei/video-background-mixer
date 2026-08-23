#!/usr/bin/env python3
import os
import shutil
import glob

def get_unique_path(target_dir, filename):
    name, ext = os.path.splitext(filename)
    counter = 1
    new_filename = filename
    new_path = os.path.join(target_dir, new_filename)
    while os.path.exists(new_path):
        new_filename = f"{name}_dup{counter}{ext}"
        new_path = os.path.join(target_dir, new_filename)
        counter += 1
    return new_path

def main():
    fb_dir = "fb"
    stage_dir = "fb_temp_stage"
    videos_per_folder = 12
    
    if os.path.exists(stage_dir):
        shutil.rmtree(stage_dir)
    os.makedirs(stage_dir)
    
    # 1. Collect all videos from fb/
    fb_videos = []
    for ext in ("*.mp4", "*.mov"):
        fb_videos.extend(glob.glob(os.path.join(fb_dir, "**", ext), recursive=True))
        
    print(f"Found {len(fb_videos)} videos in '{fb_dir}'.")
    
    # 2. Move all videos to staging area
    for vpath in fb_videos:
        filename = os.path.basename(vpath)
        dest_path = get_unique_path(stage_dir, filename)
        shutil.move(vpath, dest_path)
        
    # 3. Clear old part folders in fb/
    for item in os.listdir(fb_dir):
        item_path = os.path.join(fb_dir, item)
        if os.path.isdir(item_path):
            shutil.rmtree(item_path)
        elif os.path.isfile(item_path) and not item.startswith('.'):
            os.remove(item_path)
            
    # 4. Sort all staged videos
    staged_files = sorted(os.listdir(stage_dir))
    total_staged = len(staged_files)
    print(f"Organizing {total_staged} videos into folders of {videos_per_folder} videos...")
    
    # 5. Distribute into part_1, part_2, ... with 12 videos each
    for i, filename in enumerate(staged_files):
        folder_num = (i // videos_per_folder) + 1
        target_folder = os.path.join(fb_dir, f"part_{folder_num}")
        os.makedirs(target_folder, exist_ok=True)
        
        src_path = os.path.join(stage_dir, filename)
        dest_path = os.path.join(target_folder, filename)
        shutil.move(src_path, dest_path)
        
    # 6. Clean up staging
    shutil.rmtree(stage_dir)
    
    num_folders = (total_staged + videos_per_folder - 1) // videos_per_folder
    print("=============================================")
    print(" Reorganization Complete!")
    print(f" Total folders created: {num_folders}")
    print(f" Total videos organized: {total_staged}")
    print(f" Limit per folder: {videos_per_folder} videos")
    print("=============================================")
    for f in range(1, num_folders + 1):
        fpath = os.path.join(fb_dir, f"part_{f}")
        count = len([x for x in os.listdir(fpath) if not x.startswith('.')]) if os.path.exists(fpath) else 0
        print(f"  - part_{f}: {count} videos")

if __name__ == "__main__":
    main()
