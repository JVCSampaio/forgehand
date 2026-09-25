# PROJECT_STATE

## Current game

**Stackhead**: Roblox game (Luau, Rojo). Everything the player walks into is
stacked on their head. Taller stacks pay a bigger multiplier at the central bank,
but wobble (simulated on the server from real movement) can topple the stack,
scattering the items as free loot. Design: `docs/DESIGN.md`. Economy: `docs/ECONOMY.md`.

## Implemented

- **4 worlds** (Stackville, Frostpeak, Candy Coast, Neon City), each an island with a bank and 4 rings; global tiers 1–16; every 4th Strength level opens a world; travel via WORLDS panel (validated), return to last world on respawn/rejoin
- Code-generated maps: `src/server/World/Kit.luau` (floors, radial streets, bank, signs, water, obstacle map) + `Props.luau` + one theme per world
- 84 items (16 **meme items**, one per tier, with pickup toast + sound; text signs via SurfaceGui); Shiny/Golden rarities; zone respawns; loose loot; Item Rain; Golden Hour
- Server-authoritative core loop: pickups, wobble, collapse, banking, dash bumps, glue
- Upgrades: Speed, Reach, Balance (40 levels), Strength (16 levels, costs calibrated by the sim)
- Daily streak, **3 daily orders** (TASKS panel), stack records to 999, 252-entry collection
- **Stack bases** (12 cosmetics under the stack, earned or bought), shop with starter pack, passes, products
- Persistence: session-locked DataStore, retries, autosave, BindToClose, schema v2 + sanitize
- Analytics funnel + economy/progression/custom events
- Client: stack renderer (bases, lean), effects, HUD, menus (Upgrades, Worlds, Tasks, Shop), guide, per-world lighting + snow, input for touch/keyboard/gamepad
- StreamingEnabled with atomic item models
- Tooling: 66 Lune tests, pacing sim with cost calibration, place verifier, **visual preview** (`tools/preview/run.sh`), **marketing art** (`tools/art/run.sh` → `marketing/`), **item gallery** (`SHOTS=gallery tools/art/run.sh`)

## Verified

Clean luau-lsp typecheck (Roblox definitions), unit tests, pacing sim, `rojo build`,
place verification, and visual inspection of every world rendered from the real
generators. **Not yet run inside Roblox Studio.**

## Current task

First Studio playtest (see Next tasks #1).

## September 2026 overhaul

See `docs/REVISAO-2026-09.md` for changes, evidence and remaining release gates.
Steady mode, earlier progression, cosmetic previews, settings, full-height stack
LOD, movement rollback before rewards, lazy world construction, original audio
sources and a regenerated marketing campaign are implemented. Audio upload IDs
and paid catalog IDs are still unset; zero-ID products remain hidden.

## Remaining release work

1. Open `build/Stackhead.rbxl` in Studio; play solo, then 2–3 clients. Check lag,
   dash/bump/collapse, steady speed, banking, 999-item towers, mobile portrait and
   landscape, gamepad menus, accessories, world travel and persisted settings.
2. Upload `assets/audio/*.wav` to the experience owner; set permitted asset IDs
   in `src/shared/Config/AudioAssets.luau` and test audible playback. Until then
   runtime uses engine fallback effects; the original music requires its ID.
3. Create passes/products and set their IDs in `MonetizationConfig`; verify
   purchases and receipt retry/save failures in a published test experience.
4. Upload the new `marketing/` icon and thumbnails; playtest pacing with humans
   and profile a populated server before release. No live retention or revenue
   outcome has been measured.

## Important architecture decisions

- **Rojo + code-generated worlds**: the whole place is source; maps are built from `WorldConfig` + theme modules on first use. Worlds sit `WorldConfig.Spacing` apart in one place; `Worlds`/`WorldIndex` answer "which world/zone is this position in".
- **Global tiers**: item Tier = Strength level needed; zones map 1:1 to tiers across worlds.
- **Pure modules** (`Economy`, `Wobble`, `Orders`, `Cosmetics`, `Worlds`, `StackCodec`, `Format`, `PlayerDataSchema`, `SessionStore`, `RateLimiter`, `MemoryStore`) have no Roblox API calls so Lune can test and simulate them. Keep it that way.
- **Server owns every reward.** Clients only send intent: `Dash`, `UseGlue(bool)`, `ClaimDaily`, `BuyUpgrade(id)`, `Travel(worldId)`, `ClaimOrder(i)`, `EquipCosmetic(id)`. All rate limited and validated.
- **Stacks replicate as a string attribute** (`Player.Stack`, codes like `pigg`), rendered client-side; nothing physical is welded to characters.
- **Loose/rain items** carry `DropFrom`/`DropAt` attributes; clients animate the fall, server blocks pickup until `DropAt`.
- **Session lock**: a profile can be written only by the server holding its lock; released profiles can't be re-locked by late autosaves.
- **Receipts**: grant → record PurchaseId → force save → only then `PurchaseGranted`.
