-- Robux catalogue. Ids of 0 mean "not created yet": the item is hidden and
-- the game keeps working. Create the passes/products on the Creator Dashboard
-- and paste the ids here. PriceHint is only shown until the live price loads.

local MonetizationConfig = {}

MonetizationConfig.GamePasses = {
	DoubleCoins = {
		Id = 0,
		PriceHint = 299,
		DisplayName = "2x Coins",
		Description = "Double coins from every bank. Forever.",
		Icon = "💰",
		CoinMult = 2,
	},
	VIP = {
		Id = 0,
		PriceHint = 199,
		DisplayName = "VIP",
		Description = "+20% coins, Golden Tray base, VIP tag, +1 daily glue.",
		Icon = "👑",
		CoinMult = 1.2,
		DailyGlue = 1,
	},
	MagnetHands = {
		Id = 0,
		PriceHint = 99,
		DisplayName = "Magnet Hands",
		Description = "+3 studs of reach.",
		Icon = "🧲",
		BonusReach = 3,
	},
	RainbowTrail = {
		Id = 0,
		PriceHint = 49,
		DisplayName = "Rainbow Trail",
		Description = "Leave a rainbow behind you.",
		Icon = "🌈",
	},
	UfoBase = {
		Id = 0,
		PriceHint = 99,
		DisplayName = "UFO Saucer Base",
		Description = "Your tower rides a glowing saucer.",
		Icon = "🛸",
	},
	FlameBase = {
		Id = 0,
		PriceHint = 149,
		DisplayName = "Flame Ring Base",
		Description = "Your tower stands on fire. Literally.",
		Icon = "🔥",
	},
}

MonetizationConfig.PassOrder = { "DoubleCoins", "VIP", "MagnetHands", "RainbowTrail", "UfoBase", "FlameBase" }

MonetizationConfig.Products = {
	-- Shown once; hidden after purchase. A repeat purchase still grants the glue.
	StarterPack = {
		Id = 0,
		PriceHint = 99,
		DisplayName = "Starter Pack",
		Description = "10 glue, 30 min of 2x coins and the Starter Crate base.",
		Icon = "🎁",
		OneTime = true,
		Grant = { Glue = 10, BoostSeconds = 1800, Cosmetic = "crate" },
	},
	GoldenHour = {
		Id = 0,
		PriceHint = 149,
		DisplayName = "Golden Hour",
		Description = "10 min of 5x shiny & golden chances for the WHOLE server.",
		Icon = "✨",
		Grant = { GoldenHour = 600 },
	},
	Glue3 = {
		Id = 0,
		PriceHint = 25,
		DisplayName = "3 Glue",
		Description = "Each glue saves one collapsing stack.",
		Icon = "🧴",
		Grant = { Glue = 3 },
	},
	Glue10 = {
		Id = 0,
		PriceHint = 79,
		DisplayName = "10 Glue",
		Description = "Each glue saves one collapsing stack.",
		Icon = "🧴",
		Grant = { Glue = 10 },
	},
	Boost15 = {
		Id = 0,
		PriceHint = 49,
		DisplayName = "2x Coins (15 min)",
		Description = "Stacks with the 2x Coins pass.",
		Icon = "⚡",
		Grant = { BoostSeconds = 900 },
	},
	ItemRain = {
		Id = 0,
		PriceHint = 99,
		DisplayName = "Item Rain",
		Description = "Make items rain on the WHOLE server for 30s.",
		Icon = "🌧️",
		Grant = { ItemRain = true },
	},
	CoinsSmall = {
		Id = 0,
		PriceHint = 49,
		DisplayName = "Coin Pouch",
		Description = "Coins scaled to your strength tier.",
		Icon = "🪙",
		Grant = { ScaledCoins = 400 },
	},
	CoinsLarge = {
		Id = 0,
		PriceHint = 399,
		DisplayName = "Coin Vault",
		Description = "Coins scaled to your strength tier.",
		Icon = "🏦",
		Grant = { ScaledCoins = 5000 },
	},
}

MonetizationConfig.ProductOrder = { "StarterPack", "Glue3", "Boost15", "ItemRain", "GoldenHour", "CoinsSmall", "Glue10", "CoinsLarge" }

-- Receipts remembered per player to make grants idempotent.
MonetizationConfig.ReceiptHistory = 60

return MonetizationConfig
