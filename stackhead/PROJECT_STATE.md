# PROJECT_STATE

## Current game

**Stackhead**: Roblox game (Luau, Rojo). Everything the player walks into is
stacked on their head. Taller stacks pay a bigger multiplier at the central bank,
but wobble (simulated on the server from real movement) can topple the stack,
scattering the items as free loot. Design: `docs/DESIGN.md`. Economy: `docs/ECONOMY.md`.

## Implemented (vertical slice / MVP)

- World generated from config: bank + 4 ring zones, decorations, spawns, boundary, lighting, leaderboard board
- 20 items in 4 tiers + Shiny/Golden rarities; zone respawns; loose loot with expiry; item rain
- Server-authoritative core loop: proximity pickups, wobble, collapse, banking, dash bumps, glue
- Upgrades: Speed, Reach, Balance, Strength (zone gate)
- Persistence: session-locked DataStore wrapper, retries, autosave, BindToClose, schema version + sanitize, Studio in-memory fallback
- Daily streak, stack-record milestones + titles, discovery collection
- Monetization: 4 passes, 6 dev products, idempotent receipts, Premium perks (all ids = 0 until created)
- Analytics: onboarding funnel, economy, progression and custom events
- Client: stack renderer (BulkMoveTo, lean spring), pickup/fall/bank effects, HUD, upgrade/shop menus, contextual guide, dash/glue input (touch, keyboard, gamepad), audio with placeholder engine sounds
- Tooling: 45 Lune unit tests, economy pacing sim, place structure verifier, CI workflow

## Verified

Clean luau-lsp typecheck with Roblox definitions, unit tests, pacing sim, `rojo build`
and place verification. World/item generators executed in Lune's Roblox DOM and
rendered with `tools/preview` (fixed inverted wedge roofs, ring-floor z-fighting,
hidden zone borders, items sunk into raised floors). **Not yet run inside Roblox Studio.**

## Current task

First Studio playtest of the MVP (see Next tasks #1).

## Known issues

- Never executed in the engine: expect small runtime issues on first playtest.
- Sounds are engine placeholders (`rbxasset://sounds/...`); replace with licensed Creator Store audio.
- Speed hacks below 1.8× walk speed are not detected (pickups only skip clear teleports).
- Leaderboard names use `GetNameFromUserIdAsync`, uncached across servers.
- Hats/accessories can clip into the first stacked item.
- No settings menu (music/SFX toggles exist in save data but not in UI).

## Next tasks

1. Studio: `rojo build` → open `build/Stackhead.rbxl` → Play; fix console errors; test with 2–3 players (Test → Clients and Servers) for bumps, loose loot, rain.
2. Tune `GameConfig.Wobble` by feel; keep `tools/economy_sim.luau` in sync.
3. Create passes/products on the Creator Dashboard, paste ids into `MonetizationConfig`.
4. Replace placeholder sounds; make icon + 2 thumbnails (DESIGN §14).
5. Settings toggles (SFX/music), reduced-motion option for the camera shake.
6. Week 1 content: 6 new items (config only).

## Important architecture decisions

- **Rojo + code-generated world**: the whole place is source; the map is built from `GameConfig` at server start.
- **Pure modules** (`Economy`, `Wobble`, `StackCodec`, `Format`, `PlayerDataSchema`, `SessionStore`, `RateLimiter`, `MemoryStore`) have no Roblox API calls so Lune can test and simulate them. Keep it that way.
- **Server owns every reward.** Clients only send intent: `Dash`, `UseGlue(bool)`, `ClaimDaily`, `BuyUpgrade(id)`. All rate limited and validated.
- **Stacks replicate as a string attribute** (`Player.Stack`, codes like `pigg`), rendered client-side; nothing physical is welded to characters.
- **Loose/rain items** carry `DropFrom`/`DropAt` attributes; clients animate the fall, server blocks pickup until `DropAt`.
- **Session lock**: a profile can be written only by the server holding its lock; released profiles can't be re-locked by late autosaves.
- **Receipts**: grant → record PurchaseId → force save → only then `PurchaseGranted`.
