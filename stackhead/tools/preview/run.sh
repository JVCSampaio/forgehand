#!/usr/bin/env bash
# Visual inspection: build the place, run the real world generators in Lune,
# render standard camera views of every world in headless Chromium.
#   tools/preview/run.sh [views...]      (default: overview gameplay)
# Output: build/preview/shots/<world>-<view>.png
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT=build/preview
mkdir -p "$OUT/shots"
rojo build default.project.json -o build/Stackhead.rbxl >/dev/null
lune run tools/preview/export_scene.luau build/Stackhead.rbxl "$OUT/scene.json"
cp tools/preview/preview.html "$OUT/index.html"
[ -f "$OUT/three.module.min.js" ] || cp ../abyssal/vendor/three.module.min.js "$OUT/" 2>/dev/null || true
if [ ! -f "$OUT/fonts.css" ]; then
	UA="Mozilla/5.0 (X11; Linux x86_64) Chrome/120 Safari/537.36"
	curl -sS -A "$UA" "https://fonts.googleapis.com/css2?family=Fredoka+One&family=Noto+Color+Emoji&display=swap" > "$OUT/fonts.css" || true
	python3 - "$OUT" <<'PY'
import re, subprocess, sys
out = sys.argv[1]
css = open(f"{out}/fonts.css").read()
for i, u in enumerate(re.findall(r"url\((https://[^)]+)\)", css)):
    subprocess.run(["curl", "-sS", "-o", f"{out}/f{i}.woff2", u], check=False)
    css = css.replace(u, f"f{i}.woff2")
open(f"{out}/fonts.css", "w").write(css)
PY
fi
PORT=${PORT:-8123}
(cd "$OUT" && exec python3 -m http.server "$PORT" >/dev/null 2>&1) &
SERVER=$!
trap 'kill $SERVER 2>/dev/null || true' EXIT
sleep 1
VIEWS="${*:-overview gameplay}" node tools/preview/shoot.mjs "http://localhost:$PORT" "$OUT/shots"
