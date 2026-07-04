# Video Background Mixer 🎬🎶

A highly automated bash utility to mix background music into chess videos, apply customized text watermarks, handle dynamic speed adjustments, and auto-group outputs into parts for YouTube Shorts/Short-form uploads.

---

## ✨ Features

1. **🎨 Bold Text Watermarking:**
   * Automatically adds a semi-transparent, bold text watermark **"史力爱卫"** to the bottom-right corner of the video.
   * Utilizes macOS system font `STHeiti Medium.ttc` for high-quality bold Chinese rendering.
2. **🔊 Amplified Background Music:**
   * Mixes background music at **1.50 (150% volume)** relative to the original video audio (which remains at 100% volume).
   * No fade-in or fade-out effects are applied, ensuring the music starts loud immediately.
3. **📁 Auto-Grouping Outputs:**
   * Groups generated videos into subfolders (e.g., `part_1`, `part_2`) with a strict limit of **15 videos per folder**.
4. **⏱️ Dynamic Speed-Up & Duration Limits:**
   * Enforces a maximum duration of **3 minutes (180 seconds)** for YouTube Shorts compatibility.
   * If a video is longer than 3 minutes, it dynamically speeds up both video (`setpts`) and audio (`atempo`) to target exactly **2 minutes and 50 seconds (170 seconds)** without truncating the content.
5. **🚫 Scope Control:**
   * Excludes the `fb/` directory automatically, targeting only raw input files in the `videos/` folder.

---

## 🛠️ Prerequisites & Installation

Applying text overlays requires a version of FFmpeg built with the `libfreetype` library enabled. The standard Homebrew formula may lack this, so installing `ffmpeg-full` is recommended.

```bash
# 1. Uninstall existing standard FFmpeg (if installed)
brew uninstall ffmpeg

# 2. Install ffmpeg-full
brew install ffmpeg-full

# 3. Link ffmpeg-full as default
brew link --overwrite ffmpeg-full
```

Verify that the `drawtext` filter is active:
```bash
ffmpeg -filters | grep drawtext
# Output should show: T. drawtext V->V Draw text on top of video frames...
```

---

## 🚀 How to Use

### 1. Basic Run
Make the script executable and run with default parameters:
```bash
chmod +x add_random_background.sh
./add_random_background.sh videos background_sounds output
```
* **videos:** Directory containing raw input videos.
* **background_sounds:** Directory containing background audio/music.
* **output:** Directory where processed subfolders (`part_1/`, `part_2/`, etc.) will be created.

### 2. Script Options

You can customize the run using command-line flags:
* `-v, --video-dir DIR`: Set input video folder (default: `video_1`)
* `-s, --sound-dir DIR`: Set sound folder (default: `background_sounds`)
* `-o, --output-dir DIR`: Set output folder (default: `output`)
* `-b, --volume VOL`: Set background volume scale (default: `1.50`)
* `-l, --limit NUM`: Limit the number of videos processed (default: `0` / no limit)
* `-f, --slow-factor X`: Default video slow/speed factor (default: `1.00`)
* `--fade-duration SECS`: Fade-in duration in seconds (default: `0`)
* `-d, --duration SECS`: Max video duration cap (default: `180`)
* `-t, --tags STR`: Suffix/hashtags added to filenames (default: `" #chess #checkmate #winner"`)

---

## 📁 Directory Structure
* 📁 **`videos/`**: Source folder containing raw game recordings (e.g. `.mov` or `.mp4`).
* 📁 **`background_sounds/`**: Source folder containing background music tracks.
* 📁 **`output/`**: Destination folder where processed videos are grouped into `part_1/`, `part_2/` subdirectories.
* 📄 **`add_random_background.sh`**: The main execution shell script.
* 📄 **`.agents/AGENTS.md`**: Project-specific rules followed by AI coding assistants.
