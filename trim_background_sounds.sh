#!/usr/bin/env bash
set -euo pipefail

SOUND_DIR="background_sounds"
BACKUP_DIR="background_sounds_original"

if [ ! -d "$SOUND_DIR" ]; then
  echo "Error: sound directory '$SOUND_DIR' not found." >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"

# Collect files to process from background_sounds
files=()
while IFS= read -r -d '' f; do
  files+=("$f")
done < <(
  find "$SOUND_DIR" -maxdepth 1 -type f \
    \( -iname '*.mp3' -o -iname '*.wav' -o -iname '*.m4a' -o -iname '*.aac' -o -iname '*.flac' \) \
    -print0
)

if [ "${#files[@]}" -eq 0 ]; then
  echo "No audio files found in '$SOUND_DIR' to trim."
  exit 0
fi

echo "Found ${#files[@]} audio files in '$SOUND_DIR'."
echo "Backing up originals to '$BACKUP_DIR' and trimming..."
echo "============================================="

for filepath in "${files[@]}"; do
  filename="$(basename "$filepath")"
  backup_path="$BACKUP_DIR/$filename"
  dest_path="$SOUND_DIR/$filename"

  # Move original file to backup dir
  mv "$filepath" "$backup_path"

  # Get duration using ffprobe
  duration="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$backup_path" || echo "0")"
  
  # Remove decimals for simple comparison
  duration_int="${duration%.*}"

  if [ -z "$duration_int" ] || [ "$duration_int" -eq 0 ]; then
    echo "Warning: Could not determine duration for '$filename'. Copying original as-is."
    cp "$backup_path" "$dest_path"
    continue
  fi

  # Determine cut duration
  # If duration < 150 seconds (2:30), cut 20 seconds.
  # Otherwise, cut 30 seconds.
  if [ "$duration_int" -lt 150 ]; then
    cut_dur=20
  else
    cut_dur=30
  fi

  # If duration is shorter than or equal to cut duration, keep it as-is
  if [ "$duration_int" -le "$cut_dur" ]; then
    echo "'$filename' (${duration_int}s) is shorter than trim duration (${cut_dur}s). Keeping as-is."
    cp "$backup_path" "$dest_path"
    continue
  fi

  echo "Trimming '$filename' (Duration: ${duration_int}s, Cut: ${cut_dur}s)"

  # Perform trimming
  # Try lossless copy first, fall back to re-encoding if that fails
  if ffmpeg -y -ss "$cut_dur" -i "$backup_path" -c copy "$dest_path" >/dev/null 2>&1; then
    echo "  -> Trimmed successfully (lossless copy)"
  else
    if ffmpeg -y -ss "$cut_dur" -i "$backup_path" "$dest_path" >/dev/null 2>&1; then
      echo "  -> Trimmed successfully (re-encoded)"
    else
      echo "  -> Warning: failed to trim '$filename'. Copying original as-is."
      cp "$backup_path" "$dest_path"
    fi
  fi
done

echo "============================================="
echo "Trimming complete."
