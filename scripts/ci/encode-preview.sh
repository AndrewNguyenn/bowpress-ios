#!/bin/bash
# Encode .build/preview/raw.mov into an Apple-spec App Preview at
# .build/preview/preview.mp4.
#
# Apple spec for the APP_IPHONE_67 preview slot (portrait):
#   - 886x1920 or 1080x1920, H.264, 30fps, ≤30s, must include audio track
# Simulator capture is 1320x2868 (~0.4602 aspect). 886x1920 has aspect 0.4615,
# so a center-crop after height-scale is the smallest distortion path.
# Audio: simulator capture has no audio, so we mux in a silent AAC stereo
# track (Apple rejects videos with no audio stream).
#
#   scripts/ci/encode-preview.sh                          # default in/out
#   scripts/ci/encode-preview.sh in.mov out.mp4
#   scripts/ci/encode-preview.sh in.mov out.mp4 25        # trim to 25s
set -e

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="$REPO/.build/preview"

INPUT="${1:-$OUT_DIR/raw.mov}"
OUT="${2:-$OUT_DIR/preview.mp4}"
DURATION="${3:-30}"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "[encode-preview] ffmpeg not found — install with: brew install ffmpeg"
  exit 1
fi
if [ ! -f "$INPUT" ]; then
  echo "[encode-preview] input not found: $INPUT"
  exit 1
fi

mkdir -p "$(dirname "$OUT")"

echo "[encode-preview] $INPUT -> $OUT (max ${DURATION}s)"

# scale=886:-2 forces width 886, computes height keeping aspect (rounded to
# even). For a 1320x2868 source that yields 886x1924; crop=886:1920 trims
# 2px off top and bottom for a clean 886x1920.
ffmpeg -y \
  -i "$INPUT" \
  -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=44100" \
  -t "$DURATION" \
  -vf "scale=886:-2,crop=886:1920,fps=30" \
  -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -movflags +faststart \
  -c:a aac -b:a 128k -shortest \
  "$OUT"

echo "[encode-preview] wrote $OUT"
ffprobe -v error -show_entries stream=index,codec_type,codec_name,width,height,r_frame_rate -show_entries format=duration,size -of default=nw=1 "$OUT"
