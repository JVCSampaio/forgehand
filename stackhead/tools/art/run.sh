#!/usr/bin/env bash
# Marketing art: thumbnails (1920x1080) and icon (512x512) rendered from the
# real map and item models with post-processing. Output: marketing/*.png
#   tools/art/run.sh            (all)
#   SHOTS="tower icon" tools/art/run.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT=build/art
mkdir -p "$OUT/out" marketing
rojo build default.project.json -o build/Stackhead.rbxl >/dev/null
lune run tools/preview/export_scene.luau build/Stackhead.rbxl "$OUT/scene.json"
[ -d "$OUT/node_modules/three" ] || (cd "$OUT" && npm install --silent three@0.180.0)
cp tools/art/art.html tools/art/composite.html "$OUT/"
# Font stylesheet is tracked; initial rendering needs access to Google Fonts.
cp tools/art/fonts.css "$OUT/"
PORT=${PORT:-8124}
(cd "$OUT" && exec python3 -m http.server "$PORT" >/dev/null 2>&1) &
SERVER=$!
trap 'kill $SERVER 2>/dev/null || true' EXIT
sleep 1
SHOTS="${SHOTS:-tower crash icon panels worlds}" node tools/art/shoot.mjs "http://localhost:$PORT" "$OUT/out"
cp "$OUT"/out/thumbnail-*.png "$OUT/out/icon-512.png" marketing/ 2>/dev/null || true
ls -la marketing
