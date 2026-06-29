#!/usr/bin/env bash
set -euo pipefail

# Default values
VIDEO_DIR=""
SOUND_DIR=""
OUTPUT_DIR=""
BACKGROUND_VOLUME="${BACKGROUND_VOLUME:-0.20}"
LIMIT="${LIMIT:-0}"
SLOW_FACTOR="${SLOW_FACTOR:-2.00}"
MAX_DURATION="${MAX_DURATION:-110}"
TAGS=" #chess #checkmate #winner"
POSITIONAL_ARGS=()

# Function to display help menu
show_help() {
  cat << EOF
Usage: $(basename "$0") [options] [video_dir] [sound_dir] [output_dir]

Mix random background audio into videos, with optional speed adjustment.

Arguments (Positional):
  video_dir             Input directory containing videos (default: video_1)
  sound_dir             Input directory containing music/sound files (default: background_sounds)
  output_dir            Output directory for processed videos (default: output)

Options:
  -v, --video-dir DIR   Set the video input directory
  -s, --sound-dir DIR   Set the sound input directory
  -o, --output-dir DIR  Set the output directory
  -b, --volume VOL      Set background music volume scale, e.g., 0.15 (default: 0.20)
  -l, --limit NUM       Limit the number of videos to process (default: 0, no limit)
  -f, --slow-factor X   Slow down video/audio factor, e.g., 1.0 to disable (default: 2.00)
  -d, --duration SECS   Maximum output video duration in seconds (default: 110)
  -t, --tags STR        Set the suffix string/tags for output filename (default: " #chess #checkmate #winner")
  -h, --help            Show this help message and exit

Environment Variables:
  BACKGROUND_VOLUME     Fallback background volume (default: 0.20)
  LIMIT                 Fallback limit (default: 0)
  SLOW_FACTOR           Fallback slow factor (default: 2.00)
  MAX_DURATION          Fallback max duration (default: 110)

Examples:
  # Simple run using defaults
  ./$(basename "$0")

  # Specify directories as positional arguments
  ./$(basename "$0") video_files sound_files output_files

  # Run with custom tags and custom slow factor
  ./$(basename "$0") --tags " #viral #shorts" --slow-factor 1.5 --limit 5
EOF
}

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -v|--video-dir)
      if [[ $# -lt 2 ]]; then echo "Error: $1 requires an argument." >&2; exit 1; fi
      VIDEO_DIR="$2"
      shift 2
      ;;
    -s|--sound-dir)
      if [[ $# -lt 2 ]]; then echo "Error: $1 requires an argument." >&2; exit 1; fi
      SOUND_DIR="$2"
      shift 2
      ;;
    -o|--output-dir)
      if [[ $# -lt 2 ]]; then echo "Error: $1 requires an argument." >&2; exit 1; fi
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -b|--volume)
      if [[ $# -lt 2 ]]; then echo "Error: $1 requires an argument." >&2; exit 1; fi
      BACKGROUND_VOLUME="$2"
      shift 2
      ;;
    -l|--limit)
      if [[ $# -lt 2 ]]; then echo "Error: $1 requires an argument." >&2; exit 1; fi
      LIMIT="$2"
      shift 2
      ;;
    -f|--slow-factor)
      if [[ $# -lt 2 ]]; then echo "Error: $1 requires an argument." >&2; exit 1; fi
      SLOW_FACTOR="$2"
      shift 2
      ;;
    -d|--duration|--max-duration)
      if [[ $# -lt 2 ]]; then echo "Error: $1 requires an argument." >&2; exit 1; fi
      MAX_DURATION="$2"
      shift 2
      ;;
    -t|--tags|--suffix)
      if [[ $# -lt 2 ]]; then echo "Error: $1 requires an argument." >&2; exit 1; fi
      TAGS="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: Unknown option $1" >&2
      show_help >&2
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

# Map positional arguments if they were provided and not already overridden by flags
if [[ ${#POSITIONAL_ARGS[@]} -ge 1 ]]; then
  if [[ -z "$VIDEO_DIR" ]]; then VIDEO_DIR="${POSITIONAL_ARGS[0]}"; fi
fi
if [[ ${#POSITIONAL_ARGS[@]} -ge 2 ]]; then
  if [[ -z "$SOUND_DIR" ]]; then SOUND_DIR="${POSITIONAL_ARGS[1]}"; fi
fi
if [[ ${#POSITIONAL_ARGS[@]} -ge 3 ]]; then
  if [[ -z "$OUTPUT_DIR" ]]; then OUTPUT_DIR="${POSITIONAL_ARGS[2]}"; fi
fi

# Fallback to final default values
VIDEO_DIR="${VIDEO_DIR:-video_1}"
SOUND_DIR="${SOUND_DIR:-background_sounds}"
OUTPUT_DIR="${OUTPUT_DIR:-output}"

# Environment validation
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Error: ffmpeg is not installed. Install it with: brew install ffmpeg" >&2
  exit 1
fi

if ! command -v ffprobe >/dev/null 2>&1; then
  echo "Error: ffprobe is not installed. Install it with: brew install ffmpeg" >&2
  exit 1
fi

if [ ! -d "$VIDEO_DIR" ]; then
  echo "Error: video folder not found: $VIDEO_DIR" >&2
  exit 1
fi

if [ ! -d "$SOUND_DIR" ]; then
  echo "Error: sound folder not found: $SOUND_DIR" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Collect videos
videos=()
while IFS= read -r -d '' video_file; do
  videos+=("$video_file")
done < <(
  find "$VIDEO_DIR" -maxdepth 1 -type f \
    \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.m4v' \) \
    -print0
)

# Collect sound files
sounds=()
while IFS= read -r -d '' sound_file; do
  sounds+=("$sound_file")
done < <(
  find "$SOUND_DIR" -maxdepth 1 -type f \
    \( -iname '*.mp3' -o -iname '*.wav' -o -iname '*.m4a' -o -iname '*.aac' -o -iname '*.flac' \) \
    -print0
)

if [ "${#videos[@]}" -eq 0 ]; then
  echo "Error: no videos found in $VIDEO_DIR" >&2
  exit 1
fi

if [ "${#sounds[@]}" -eq 0 ]; then
  echo "Error: no sounds found in $SOUND_DIR" >&2
  echo "Put your music files into: $SOUND_DIR" >&2
  exit 1
fi

# Log execution parameters
echo "============================================="
echo "Video folder:      $VIDEO_DIR"
echo "Sound folder:      $SOUND_DIR"
echo "Output folder:     $OUTPUT_DIR"
echo "Background volume: $BACKGROUND_VOLUME"
echo "Slow factor:       $SLOW_FACTOR"
if [ "$MAX_DURATION" -gt 0 ]; then
  echo "Max duration:      ${MAX_DURATION}s"
fi
if [ -n "$TAGS" ]; then
  echo "Filename tags:     $TAGS"
fi
echo "Videos found:      ${#videos[@]}"
echo "Sounds found:      ${#sounds[@]}"
if [ "$LIMIT" -gt 0 ]; then
  echo "Limit:             $LIMIT"
fi
echo "============================================="
echo

count=0
for video in "${videos[@]}"; do
  if [ "$LIMIT" -gt 0 ] && [ "$count" -ge "$LIMIT" ]; then
    break
  fi

  count=$((count + 1))
  sound="${sounds[$((RANDOM % ${#sounds[@]}))]}"

  filename="$(basename "$video")"
  name="${filename%.*}"
  output="$OUTPUT_DIR/${name}${TAGS}.mp4"

  if [ -f "$output" ]; then
    echo "[$count/${#videos[@]}] $filename"
    echo "  output already exists, skipping: $output"
    echo
    continue
  fi

  duration_args=()
  if [ "$MAX_DURATION" -gt 0 ]; then
    duration_args=(-t "$MAX_DURATION")
  fi

  slow_enabled=1
  if [ "$SLOW_FACTOR" = "1" ] || [ "$SLOW_FACTOR" = "1.0" ] || [ "$SLOW_FACTOR" = "1.00" ]; then
    slow_enabled=0
  fi
  audio_atempo="$(awk "BEGIN { printf \"%.6f\", 1 / $SLOW_FACTOR }")"

  echo "[$count/${#videos[@]}] Processing: $filename"
  echo "  using music: $(basename "$sound")"

  has_audio="$(
    ffprobe -v error \
      -select_streams a:0 \
      -show_entries stream=index \
      -of csv=p=0 \
      "$video" || true
  )"

  if [ -n "$has_audio" ]; then
    if [ "$slow_enabled" -eq 1 ]; then
      ffmpeg -y \
        -i "$video" \
        -stream_loop -1 -i "$sound" \
        -filter_complex "[0:v]setpts=${SLOW_FACTOR}*PTS[vout];[0:a]atempo=${audio_atempo}[orig];[1:a]volume=${BACKGROUND_VOLUME}[bg];[orig][bg]amix=inputs=2:duration=first:dropout_transition=2[aout]" \
        -map "[vout]" \
        -map "[aout]" \
        -c:v libx264 \
        -preset veryfast \
        -crf 18 \
        -pix_fmt yuv420p \
        -c:a aac \
        -b:a 192k \
        -shortest \
        "${duration_args[@]}" \
        "$output"
    else
      ffmpeg -y \
        -i "$video" \
        -stream_loop -1 -i "$sound" \
        -filter_complex "[1:a]volume=${BACKGROUND_VOLUME}[bg];[0:a][bg]amix=inputs=2:duration=first:dropout_transition=2[aout]" \
        -map 0:v:0 \
        -map "[aout]" \
        -c:v copy \
        -c:a aac \
        -b:a 192k \
        -shortest \
        "${duration_args[@]}" \
        "$output"
    fi
  else
    if [ "$slow_enabled" -eq 1 ]; then
      ffmpeg -y \
        -i "$video" \
        -stream_loop -1 -i "$sound" \
        -filter_complex "[0:v]setpts=${SLOW_FACTOR}*PTS[vout];[1:a]volume=${BACKGROUND_VOLUME}[aout]" \
        -map "[vout]" \
        -map "[aout]" \
        -c:v libx264 \
        -preset veryfast \
        -crf 18 \
        -pix_fmt yuv420p \
        -c:a aac \
        -b:a 192k \
        -shortest \
        "${duration_args[@]}" \
        "$output"
    else
      ffmpeg -y \
        -i "$video" \
        -stream_loop -1 -i "$sound" \
        -filter_complex "[1:a]volume=${BACKGROUND_VOLUME}[aout]" \
        -map 0:v:0 \
        -map "[aout]" \
        -c:v copy \
        -c:a aac \
        -b:a 192k \
        -shortest \
        "${duration_args[@]}" \
        "$output"
    fi
  fi

  echo "  saved: $output"
  echo
done

echo "Done."
