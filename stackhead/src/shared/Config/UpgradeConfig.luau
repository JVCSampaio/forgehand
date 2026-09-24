-- Permanent upgrades bought with coins.
-- cost(level) = round(BaseCost * Growth ^ level) for the level being bought
-- (level = current level, so the first purchase costs BaseCost).
-- Strength uses explicit costs because each level unlocks a new zone.

local UpgradeConfig = {}

UpgradeConfig.Order = { "Speed", "Reach", "Balance", "Strength" }

UpgradeConfig.Upgrades = {
	Speed = {
		DisplayName = "Speed",
		Description = "Walk faster",
		Icon = "👟",
		StartLevel = 0,
		MaxLevel = 12,
		BaseCost = 40,
		Growth = 1.75,
		-- WalkSpeed = Base + PerLevel * level
		Base = 16,
		PerLevel = 1.25,
		Unit = "speed",
	},
	Reach = {
		DisplayName = "Reach",
		Description = "Grab items from further away",
		Icon = "🧲",
		StartLevel = 0,
		MaxLevel = 12,
		BaseCost = 30,
		Growth = 1.7,
		Base = 5,
		PerLevel = 0.8,
		Unit = "studs",
	},
	Balance = {
		DisplayName = "Balance",
		Description = "Taller stacks wobble less",
		Icon = "⚖️",
		StartLevel = 0,
		MaxLevel = 20,
		BaseCost = 60,
		Growth = 1.55,
		Base = 1,
		PerLevel = 0.22,
		Unit = "x",
	},
	Strength = {
		DisplayName = "Strength",
		Description = "Carry heavier items and unlock new zones",
		Icon = "💪",
		StartLevel = 1,
		MaxLevel = 4,
		-- Cost to go from level N to N+1 is Costs[N].
		Costs = { 400, 5000, 60000 },
		Base = 0,
		PerLevel = 1,
		Unit = "tier",
	},
}

return UpgradeConfig
