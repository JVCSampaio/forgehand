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
		MaxLevel = 40,
		BaseCost = 60,
		Growth = 1.6,
		Base = 1,
		PerLevel = 0.22,
		Unit = "x",
	},
	Strength = {
		DisplayName = "Strength",
		Description = "Lift heavier items: new zones, and a new world every 4 levels",
		Icon = "💪",
		StartLevel = 1,
		MaxLevel = 16,
		-- Cost to go from level N to N+1 is Costs[N]. Levels 5, 9 and 13 open
		-- Frostpeak, Candy Coast and Neon City.
		Costs = {
			1000,
			4600,
			20000,
			120000,
			1400000,
			5900000,
			12000000,
			18000000,
			110000000,
			300000000,
			660000000,
			1000000000,
			5100000000,
			23000000000,
			46000000000,
		},
		Base = 0,
		PerLevel = 1,
		Unit = "tier",
	},
}

return UpgradeConfig
