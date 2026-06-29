# Video Background Mixer

This project is a command-line script to automate mixing background audio into a batch of videos.

## What it is

The Video Background Mixer is a shell script utility designed to batch process all videos in a specified directory by adding randomly selected audio tracks from a sound directory. It supports adjusting the video and audio speed (slowdown factor), controlling background music volume, cropping output to a maximum duration, limiting the number of videos processed, and appending tags to the output filenames.

## Why use it

Manual video editing for batch automation can be tedious and CPU-intensive. This script solves these issues:

1. Automation: Instead of dragging and dropping files in video editing software, you can batch-process hundreds of videos with a single command.
2. Intelligent Speed Optimization: 
   - When the slow factor is set to 1.0, the script copies the video stream directly without re-encoding (using direct video copy). This preserves the original video quality and completes processing in seconds.
   - Re-encoding (transcoding) is only done when you explicitly request a video slowdown (slow factor not equal to 1.0).
3. Randomization: It automatically selects a random audio track from your music folder for each video, ensuring variation across outputs.
4. Robustness: It handles videos both with and without pre-existing audio tracks, mixing them correctly without failing.

## Workflow

The script executes the following sequence:

1. Initialization: Configures default variables for video source, sound source, output directory, volume, slowdown factor, limits, and filename tags.
2. Argument Parsing: Parses command-line options and positional parameters.
3. System Check: Verifies that ffmpeg and ffprobe exist in the environment path and that target directories exist.
4. File Discovery: Scans the video directory for video files (mp4, mov, m4v) and the sound directory for audio files (mp3, wav, m4a, aac, flac).
5. Processing Loop: Iterates through each discovered video file (up to the defined limit):
   - Selects a random music track from the sound directory.
   - Determines the output file name by appending the configured suffix tags.
   - Checks if the output file already exists (skips if it does).
   - Probes the input video using ffprobe to detect if it has an audio track.
   - Matches the slowdown setting:
     - If slow-motion is disabled: Maps the video stream directly (fast copy) and mixes the video's original audio with the background music.
     - If slow-motion is enabled: Re-encodes the video stream to slow it down (using presentation timestamp scaling) and stretches/slows the original audio before mixing.
   - Loops the background audio stream indefinitely so that it never cuts off early, but uses the shortest flag to terminate when the video ends.
   - Saves the final processed file in the output directory.

## How to use it

### Prerequisites

Ensure you have ffmpeg and ffprobe installed on your system path.

### Execution

Make the script executable:
chmod +x add_random_background.sh

Run with default settings:
./add_random_background.sh

Run with positional arguments:
./add_random_background.sh [video_dir] [sound_dir] [output_dir]

Run with custom options:
./add_random_background.sh [options]

### Options

-v, --video-dir DIR
Set the video input directory (default: video_1)

-s, --sound-dir DIR
Set the sound input directory (default: background_sounds)

-o, --output-dir DIR
Set the output directory (default: output)

-b, --volume VOL
Set background music volume scale, e.g., 0.15 for 15% (default: 0.20)

-l, --limit NUM
Limit the number of videos to process (default: 0 for no limit)

-f, --slow-factor X
Slow down video and audio factor, set to 1.0 to disable (default: 2.00)

-d, --duration SECS
Maximum output video duration in seconds (default: 110)

-t, --tags STR
Set the suffix string or tags for the output filename (default: " #chess #checkmate #winner")

-h, --help
Show help message and exit

### Examples

Disable video slowdown and output tags to process videos at original speed:
./add_random_background.sh --slow-factor 1.0 --tags ""

Process up to 5 videos with background volume set to 10% and maximum output duration capped at 60 seconds:
./add_random_background.sh -l 5 -b 0.10 -d 60
