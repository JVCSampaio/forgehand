# Stackhead campaign v2

Roblox/Luau game; existing Three.js 0.180.0 art renderer retained. Export icon at
512x512, thumbnails at 1920x1080, sRGB opaque PNG. Review at 128px and 320px widths.

Art direction: toy-like primitives, yellow faces, blue/red outfits, legible
red car + pink pig + yellow duck silhouettes. One action and at most one short
headline per image. Reduced exposure and bloom preserve object detail. Enlarge
characters and their expressions; let the pile and collision tell the story.

The chosen visual target is the close-up icon; extend its palette and character
treatment to the tower and crash scenes. Worlds is secondary content discovery.
All models are rendered from repository geometry; characters are staged. These
are promotional compositions, not Roblox engine screenshots. Typography remains
editable in the renderer. Source: tools/art, item/world configuration in src.

No external character or stock art was used. Fredoka One is loaded through the Google Fonts stylesheet. Export scripts and source scenes are retained for reproducibility.

Windows: tools/art/run.ps1 accepts -Rojo, -Lune, -Python and -Node executable
paths. Requires Node Playwright with Chromium; the stylesheet fetches Fredoka
One from Google Fonts on first render. Three.js stays pinned to 0.180.0.
