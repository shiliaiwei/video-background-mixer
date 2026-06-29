# Video Background Mixer 🎬🎶

A robust, standard shell utility designed to mix random background music into folder-based videos, apply slowdown effects, and export them. Built for efficiency, portability, and compatibility.

## Features
- 🔄 **Randomized Background Audio**: Selects a random audio track from your music folder for each video.
- ⚡ **Maximum Speed Processing**: Utilizes `-c:v copy` direct stream copy when no video speed adjustment is requested (saving massive CPU cycles and time).
- 🐢 **High-Quality Slowdown**: Custom slows down both video and audio tracks concurrently when configured.
- ⚙️ **Fully Configurable**: Set volume, output name tags, max durations, and limits via standard CLI flags, environment variables, or positional arguments.

---

## Prerequisites

Before running the script, ensure `ffmpeg` and `ffprobe` are installed on your system.

### macOS (via Homebrew)
```bash
brew install ffmpeg
```

### Linux (Debian/Ubuntu)
```bash
sudo apt-get update && sudo apt-get install ffmpeg
```

---

## Usage

You can run the script using default settings, passing arguments in sequence, or specifying details using command line flags.

### Quick Start (Defaults)
Place your videos inside a folder named `video_1`, your music inside `background_sounds`, and run:
```bash
./add_random_background.sh
```

### 1. Positional Arguments
For quick runs, you can supply directories in order:
```bash
./add_random_background.sh [video_dir] [sound_dir] [output_dir]
```
Example:
```bash
./add_random_background.sh input_videos music_library output_rendered
```

### 2. Command Line Flags (Recommended)
Customize any parameters on the fly using standard flags:
```bash
./add_random_background.sh [options]
```

| Flag | Long Option | Description | Default |
|---|---|---|---|
| `-v <dir>` | `--video-dir <dir>` | Input directory containing video files | `video_1` |
| `-s <dir>` | `--sound-dir <dir>` | Input directory containing audio files | `background_sounds` |
| `-o <dir>` | `--output-dir <dir>` | Output directory for mixed files | `output` |
| `-b <num>` | `--volume <num>` | Background music volume scale (e.g. `0.15` for 15%) | `0.20` |
| `-l <num>` | `--limit <num>` | Limit the number of videos processed (0 for no limit) | `0` |
| `-f <num>` | `--slow-factor <num>`| Slowdown factor (set to `1.0` to disable slow effect) | `2.00` |
| `-d <num>` | `--duration <num>` | Maximum output video duration in seconds (0 for no limit) | `110` |
| `-t <str>` | `--tags <str>` | Suffix tag added to output filenames | `" #chess #checkmate #winner"` |
| `-h` | `--help` | Show the help menu and usage instructions | - |

---

## Examples

### Disable Suffix Tags & Slowdown
To run without slowing down the video (keeping the original speed and performing a near-instant video copy) and without tags:
```bash
./add_random_background.sh --slow-factor 1.0 --tags ""
```

### Custom Render Settings
Process 5 videos with low music volume (10%), slow down by 1.5x, cap at 60 seconds, and append custom tags:
```bash
./add_random_background.sh \
  -v my_shorts \
  -s lo-fi_beats \
  -o processed_shorts \
  --volume 0.10 \
  --slow-factor 1.5 \
  --duration 60 \
  --limit 5 \
  --tags " #shorts #edit #chill"
```

---

## Technical Details

### Speed vs. Quality
- **Standard Mode (Slow Factor = `1.0`)**: If the slow factor is set to `1.0` (or `1`), the script bypasses video re-encoding entirely. It maps the video stream directly (`-c:v copy`), only re-encoding the audio stream to AAC. This is extremely fast and lossless for the video stream.
- **Slow Motion Mode (Slow Factor != `1.0`)**: If video slowdown is requested, FFmpeg must transcode the video stream (`libx264` codec, `-preset veryfast` preset, and a visually lossless `-crf 18` target) to insert the speed modifications.

### Splicing Audio
The background audio will automatically repeat (`-stream_loop -1`) if it is shorter than the video length, and will be cut precisely to the length of the video (`-shortest`) or the max duration limit.
