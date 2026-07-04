#!/usr/bin/env bash
set -euo pipefail

# Default values
VIDEO_DIR=""
SOUND_DIR=""
OUTPUT_DIR=""
BACKGROUND_VOLUME="${BACKGROUND_VOLUME:-1.50}"
LIMIT="${LIMIT:-0}"
SLOW_FACTOR="${SLOW_FACTOR:-1.00}"
SEEK_SOUND="${SEEK_SOUND:-0}"
FADE_DURATION="${FADE_DURATION:-3}"
MAX_DURATION="${MAX_DURATION:-180}"
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
  -f, --slow-factor X   Slow down video/audio factor, e.g., 1.0 to disable (default: 1.00)
  -c, --seek-sound SECS Seconds of background music to skip at start (default: 0)
  --fade-duration SECS  Duration of fade-in for background music (default: 3)
  -d, --duration SECS   Maximum output video duration in seconds (default: 180)
  -t, --tags STR        Set the suffix string/tags for output filename (default: " #chess #checkmate #winner")
  -h, --help            Show this help message and exit

Environment Variables:
  BACKGROUND_VOLUME     Fallback background volume (default: 1.50)
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
    -c|--seek-sound|--skip-sound)
      if [[ $# -lt 2 ]]; then echo "Error: $1 requires an argument." >&2; exit 1; fi
      SEEK_SOUND="$2"
      shift 2
      ;;
    --fade-duration)
      if [[ $# -lt 2 ]]; then echo "Error: $1 requires an argument." >&2; exit 1; fi
      FADE_DURATION="$2"
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

cleanup() {
  rm -f "$OUTPUT_DIR"/temp_trimmed_*_"$$"* 2>/dev/null || true
}
trap cleanup EXIT

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
if [ "$SEEK_SOUND" -gt 0 ]; then
  echo "Seek sound:        ${SEEK_SOUND}s"
fi
if [ "$FADE_DURATION" -gt 0 ]; then
  echo "Fade duration:     ${FADE_DURATION}s"
fi
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

  # Calculate subfolder grouping (limit 15 videos per folder)
  folder_num=$(((count - 1) / 15 + 1))
  target_dir="$OUTPUT_DIR/part_$folder_num"
  mkdir -p "$target_dir"
  output="$target_dir/${name}${TAGS}.mp4"

  if [ -f "$output" ]; then
    echo "[$count/${#videos[@]}] $filename"
    echo "  output already exists, skipping: $output"
    echo
    continue
  fi

  # Check original video duration using ffprobe
  orig_duration="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video")"
  
  # Check if video duration is longer than 180 seconds (3 minutes)
  is_longer_than_3m="$(awk "BEGIN { print ($orig_duration > 180) ? 1 : 0 }")"

  # Initialize iteration-local variables
  current_slow_factor="$SLOW_FACTOR"
  current_slow_enabled=1
  if [ "$current_slow_factor" = "1" ] || [ "$current_slow_factor" = "1.0" ] || [ "$current_slow_factor" = "1.00" ]; then
    current_slow_enabled=0
  fi

  duration_args=()
  if [ "$MAX_DURATION" -gt 0 ]; then
    duration_args=(-t "$MAX_DURATION")
  fi

  if [ "$is_longer_than_3m" -eq 1 ]; then
    # Speed it up to exactly 170 seconds (2:50)
    current_slow_factor="$(awk "BEGIN { printf \"%.6f\", 170 / $orig_duration }")"
    current_slow_enabled=1
    duration_args=() # Disable duration cap since speed-up targets 170s
    echo "  video is longer than 3 minutes (${orig_duration}s). Speeding up to 2:50s (slow factor: ${current_slow_factor})."
  else
    echo "  video duration: ${orig_duration}s"
  fi

  audio_atempo="$(awk "BEGIN { printf \"%.6f\", 1 / $current_slow_factor }")"

  echo "[$count/${#videos[@]}] Processing: $filename"
  echo "  using music: $(basename "$sound")"

  # Trim the sound starting at SEEK_SOUND if requested
  actual_sound="$sound"
  if [ -n "${SEEK_SOUND:-}" ] && [ "$SEEK_SOUND" -gt 0 ]; then
    sound_duration="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$sound")"
    sound_duration_int="${sound_duration%.*}"
    if [ -n "$sound_duration_int" ] && [ "$sound_duration_int" -gt "$SEEK_SOUND" ]; then
      sound_ext="${sound##*.}"
      temp_sound="$OUTPUT_DIR/temp_trimmed_${count}_$$.${sound_ext}"
      if ffmpeg -y -ss "$SEEK_SOUND" -i "$sound" -c copy "$temp_sound" >/dev/null 2>&1; then
        actual_sound="$temp_sound"
        echo "  trimmed music first ${SEEK_SOUND}s off"
      else
        if ffmpeg -y -ss "$SEEK_SOUND" -i "$sound" "$temp_sound" >/dev/null 2>&1; then
          actual_sound="$temp_sound"
          echo "  trimmed music first ${SEEK_SOUND}s off"
        else
          echo "  Warning: failed to trim background sound. Using original."
        fi
      fi
    else
      echo "  Warning: background sound is shorter than seek time. Using original."
    fi
  fi

  has_audio="$(
    ffprobe -v error \
      -select_streams a:0 \
      -show_entries stream=index \
      -of csv=p=0 \
      "$video" || true
  )"

  bg_audio_filter="volume=${BACKGROUND_VOLUME}"
  if [ -n "${FADE_DURATION:-}" ] && [ "$FADE_DURATION" -gt 0 ]; then
    bg_audio_filter="${bg_audio_filter},afade=t=in:ss=0:d=${FADE_DURATION}"
  fi

  if [ -n "$has_audio" ]; then
    if [ "$current_slow_enabled" -eq 1 ]; then
      ffmpeg -y \
        -i "$video" \
        -stream_loop -1 -i "$actual_sound" \
        -filter_complex "[0:v]setpts=${current_slow_factor}*PTS[v_slow];[v_slow]drawtext=fontfile='/System/Library/Fonts/STHeiti Medium.ttc':text='史力爱卫':x=w-tw-20:y=h-th-20:fontsize=36:fontcolor=gray@0.3[vout];[0:a]atempo=${audio_atempo}[orig];[1:a]${bg_audio_filter}[bg];[orig][bg]amix=inputs=2:duration=first:dropout_transition=2[aout]" \
        -map "[vout]" \
        -map "[aout]" \
        -c:v libx264 \
        -preset veryfast \
        -crf 18 \
        -pix_fmt yuv420p \
        -c:a aac \
        -b:a 192k \
        -shortest \
        ${duration_args[@]+"${duration_args[@]}"} \
        "$output"
    else
      ffmpeg -y \
        -i "$video" \
        -stream_loop -1 -i "$actual_sound" \
        -filter_complex "[0:v]drawtext=fontfile='/System/Library/Fonts/STHeiti Medium.ttc':text='史力爱卫':x=w-tw-20:y=h-th-20:fontsize=36:fontcolor=gray@0.3[vout];[1:a]${bg_audio_filter}[bg];[0:a][bg]amix=inputs=2:duration=first:dropout_transition=2[aout]" \
        -map "[vout]" \
        -map "[aout]" \
        -c:v libx264 \
        -preset veryfast \
        -crf 18 \
        -pix_fmt yuv420p \
        -c:a aac \
        -b:a 192k \
        -shortest \
        ${duration_args[@]+"${duration_args[@]}"} \
        "$output"
    fi
  else
    if [ "$current_slow_enabled" -eq 1 ]; then
      ffmpeg -y \
        -i "$video" \
        -stream_loop -1 -i "$actual_sound" \
        -filter_complex "[0:v]setpts=${current_slow_factor}*PTS[v_slow];[v_slow]drawtext=fontfile='/System/Library/Fonts/STHeiti Medium.ttc':text='史力爱卫':x=w-tw-20:y=h-th-20:fontsize=36:fontcolor=gray@0.3[vout];[1:a]${bg_audio_filter}[aout]" \
        -map "[vout]" \
        -map "[aout]" \
        -c:v libx264 \
        -preset veryfast \
        -crf 18 \
        -pix_fmt yuv420p \
        -c:a aac \
        -b:a 192k \
        -shortest \
        ${duration_args[@]+"${duration_args[@]}"} \
        "$output"
    else
      ffmpeg -y \
        -i "$video" \
        -stream_loop -1 -i "$actual_sound" \
        -filter_complex "[0:v]drawtext=fontfile='/System/Library/Fonts/STHeiti Medium.ttc':text='史力爱卫':x=w-tw-20:y=h-th-20:fontsize=36:fontcolor=gray@0.3[vout];[1:a]${bg_audio_filter}[aout]" \
        -map "[vout]" \
        -map "[aout]" \
        -c:v libx264 \
        -preset veryfast \
        -crf 18 \
        -pix_fmt yuv420p \
        -c:a aac \
        -b:a 192k \
        -shortest \
        ${duration_args[@]+"${duration_args[@]}"} \
        "$output"
    fi
  fi

  # Clean up temporary trimmed sound file
  if [ "$actual_sound" != "$sound" ] && [ -f "$actual_sound" ]; then
    rm "$actual_sound"
  fi

  echo "  saved: $output"
  echo
done

echo "Done."
