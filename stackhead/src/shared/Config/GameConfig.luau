-- Core tuning for Stackhead. Every gameplay number lives here or in a sibling
-- config so the game can be rebalanced without touching logic.

local GameConfig = {}

GameConfig.Version = "0.1.0"

-- Server simulation rate for pickups, wobble, banking and bumps.
GameConfig.TickRate = 10

-- Island layout shared by every world (see WorldConfig for the worlds).
GameConfig.Layout = {
	GroundY = 0,
	-- Players can't walk past this radius (invisible wall ring).
	BoundaryRadius = 300,
	BoundarySegments = 28,
	OceanRadius = 1100,
	-- Width of the four radial streets that lead out from the bank.
	RoadWidth = 12,
}

-- Every world has a bank at its centre. Standing inside it cashes in the
-- stack and protects the player from bumps.
GameConfig.Bank = {
	Radius = 20,
	SpawnRadius = 27,
	SpawnCount = 8,
	-- Height (studs) the server allows above the platform when checking entry.
	MaxHeightAbove = 14,
}

GameConfig.Travel = {
	Cooldown = 3,
}

GameConfig.Spawning = {
	-- Seconds between respawn attempts per zone.
	RespawnInterval = 1,
	-- Items spawned per attempt when a zone is below its cap.
	RespawnBatch = 4,
	-- Minimum spacing between spawned items.
	MinSpacing = 3,
	PlacementAttempts = 12,
	Rarities = {
		-- Order matters: rolled from rarest to most common.
		{ Id = "Golden", Suffix = "g", Chance = 0.006, ValueMult = 25 },
		{ Id = "Shiny", Suffix = "s", Chance = 0.035, ValueMult = 5 },
	},
}

-- Wobble is the risk system: every disturbance fills a meter scaled by the
-- stack height; standing still drains it. Reaching 1 collapses the stack.
GameConfig.Wobble = {
	-- factor = ((height - SafeHeight) / HeightScale) ^ HeightExponent
	-- ≈0.2 at 20 market items, ≈1 at 40, ≈3 at 80, ≈9 at 150 (see docs/ECONOMY.md).
	HeightScale = 29,
	HeightExponent = 1.5,
	-- Stacks shorter than this never gain wobble (new players can't fail).
	SafeHeight = 8,
	-- Wobble per stud/s of velocity change between ticks.
	AccelGain = 0.0045,
	-- Wobble per second per stud/s of walking speed.
	MoveGain = 0.002,
	JumpKick = 0.16,
	-- Velocity change that counts as a jump.
	JumpVelocity = 25,
	-- Drain per second, multiplied by the balance multiplier.
	RecoverStill = 0.34,
	RecoverMoving = 0.07,
	-- Horizontal speed below which the player counts as standing still.
	StillSpeed = 1.5,
	-- Balance multiplier per Balance upgrade level.
	BalancePerLevel = 0.15,
	-- Fraction of the stack kept on collapse (bottom part).
	CollapseKeepFraction = 0.5,
	-- Seconds of immunity after a collapse.
	CollapseGrace = 2,
	-- Wobble left after glue saves a stack.
	GlueResidual = 0.35,
}

GameConfig.Dash = {
	Cooldown = 3.5,
	-- Seconds after a dash during which contact bumps others.
	BumpWindow = 0.6,
	BumpRadius = 5,
	-- Wobble applied to the victim (before their height factor).
	BumpKick = 0.55,
	-- Wobble applied to the dasher (before their height factor).
	SelfKick = 0.12,
	-- Seconds a bumped player can't be bumped again.
	VictimImmunity = 3,
	-- Client-side dash impulse (studs/s added horizontally).
	Impulse = 70,
}

GameConfig.Loose = {
	-- Items that fall off a collapsing stack stay this long as free loot.
	Lifetime = 25,
	MaxPerCollapse = 40,
	ScatterMin = 4,
	ScatterMax = 16,
	-- Server waits this long so clients can animate the fall first.
	LandDelay = 0.7,
	-- The owner can't instantly re-grab their own fallen items.
	OwnerPickupDelay = 1.5,
}

GameConfig.Movement = {
	BaseWalkSpeed = 16,
	-- Server rejects pickups during ticks faster than this multiple of the
	-- allowed speed (teleports / speed hacks).
	SpeedTolerance = 1.8,
}

GameConfig.Camera = {
	MaxZoom = 320,
}

GameConfig.Events = {
	ItemRain = {
		-- Automatic rain every N seconds (0 disables).
		Interval = 540,
		Duration = 30,
		ItemsPerSecond = 5,
		-- Rarity chances are multiplied by this during rain.
		RarityBoost = 3,
		DropHeight = 120,
	},
	-- Broadcast banks at least this tall to the whole server.
	BroadcastStack = 40,
}

GameConfig.Leaderboard = {
	StoreName = "Stackhead_TallestStack_v1",
	RefreshInterval = 120,
	Entries = 10,
}

GameConfig.Render = {
	MaxItemsLocal = 320,
	MaxItemsOthers = 160,
	-- Other players' stacks further than this are not rendered.
	OtherRenderDistance = 450,
}

return GameConfig
