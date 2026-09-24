-- Coin economy. See docs/ECONOMY.md for the model behind these numbers.

local EconomyConfig = {}

-- payout = sum(item value * rarity) * heightMultiplier(itemCount) * coinMultiplier
EconomyConfig.HeightBonus = {
	PerItem = 0.05,
	Max = 16,
}

EconomyConfig.StartingCoins = 0
EconomyConfig.StartingGlue = 2
EconomyConfig.MaxGlue = 999

-- Paid once, on the very first bank, so the first upgrade lands in ~1 minute.
EconomyConfig.FirstBankBonus = 40

-- First time an item+rarity is banked it pays this many extra times its value.
EconomyConfig.DiscoveryBonusMult = 3

-- Rewards that should stay meaningful late game are multiplied by the
-- player's strength tier scale (roughly income per minute at that tier).
EconomyConfig.TierScale = {
	1,
	6,
	40,
	250,
	700,
	2000,
	5000,
	14000,
	35000,
	90000,
	250000,
	650000,
	1800000,
	5000000,
	13000000,
	35000000,
}

-- Seven-day login streak; day 8 loops back to day 1.
EconomyConfig.DailyRewards = {
	{ Coins = 60, Glue = 1 },
	{ Coins = 100, Glue = 0 },
	{ Coins = 150, Glue = 1 },
	{ Coins = 250, Glue = 0 },
	{ Coins = 400, Glue = 1 },
	{ Coins = 600, Glue = 1 },
	{ Coins = 1000, Glue = 2 },
}

-- Best-stack records. Reaching one grants a title and glue once.
EconomyConfig.Milestones = {
	{ Stack = 10, Glue = 1, Title = "Stacker" },
	{ Stack = 25, Glue = 1, Title = "Wobbler" },
	{ Stack = 50, Glue = 2, Title = "Tower Tamer" },
	{ Stack = 100, Glue = 3, Title = "Skyscraper" },
	{ Stack = 200, Glue = 3, Title = "Cloud Toucher" },
	{ Stack = 350, Glue = 4, Title = "Sky Stacker" },
	{ Stack = 500, Glue = 5, Title = "Space Stacker" },
	{ Stack = 750, Glue = 6, Title = "Moon Mover" },
	{ Stack = 999, Glue = 10, Title = "Stack Legend" },
}

EconomyConfig.PremiumCoinMult = 1.1

return EconomyConfig
