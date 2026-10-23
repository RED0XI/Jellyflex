#!/bin/bash
# Erzeugt das Testvideo für App-Tests und Demo-Server (siehe lib/dev/player_harness.dart):
# 90 s buntes Testbild, zwei Tonspuren (de, en) und zwei Untertitel (de, en).
# Start:  tool/make_test_video.sh [Zieldatei]   (Standard: $TMPDIR/jellyflex_test.mkv; braucht ffmpeg)
set -euo pipefail
out="${1:-${TMPDIR:-/tmp}/jellyflex_test.mkv}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for lang in de en; do
  : > "$tmp/$lang.srt"
  for i in $(seq 0 17); do
    printf '%d\n00:00:%02d,000 --> 00:00:%02d,500\n%s %d\n\n' $((i + 1)) $((i * 5)) $((i * 5 + 3)) \
      "$([ $lang = de ] && echo Untertitel || echo Subtitle)" $((i + 1)) >> "$tmp/$lang.srt"
  done
done
ffmpeg -loglevel error -y \
  -f lavfi -i testsrc2=size=1280x720:rate=25:duration=90 \
  -f lavfi -i sine=frequency=440:duration=90 \
  -f lavfi -i sine=frequency=660:duration=90 \
  -i "$tmp/de.srt" -i "$tmp/en.srt" \
  -map 0 -map 1 -map 2 -map 3 -map 4 \
  -c:v libx264 -preset veryfast -pix_fmt yuv420p -c:a aac -c:s srt \
  -metadata:s:a:0 language=ger -metadata:s:a:1 language=eng \
  -metadata:s:s:0 language=ger -metadata:s:s:1 language=eng \
  "$out"
echo "Testvideo: $out"
