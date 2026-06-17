#!/usr/bin/env bash
# Resize+compress source PNGs to <cardId>.jpg using the manifest mapping.
# Output -> build/player_images/ (gitignored). Re-runnable.
# Usage: tools/process_players.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CSV="$ROOT/tools/player_manifest.csv"
OUT="$ROOT/build/player_images"
MAXH=1024            # target height in px
mkdir -p "$OUT"
tail -n +2 "$CSV" | while IFS=, read -r id src dir name epithet nation pos rarity p s pa d; do
  [ -z "${src:-}" ] && continue
  in="${dir%/}/$src"
  out="$OUT/${id}.jpg"
  if [ ! -f "$in" ]; then echo "MISSING: $in" >&2; continue; fi
  cp "$in" "$out.tmp.png"
  sips -Z "$MAXH" "$out.tmp.png" --out "$out" --setProperty format jpeg --setProperty formatOptions 80 >/dev/null
  rm -f "$out.tmp.png"
  echo "✓ $id ($src)"
done
echo "→ $(ls "$OUT" | wc -l | tr -d ' ') images in $OUT, total $(du -sh "$OUT" | cut -f1)"
