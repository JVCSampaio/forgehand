local T = _G.T
local Cosmetics = require("../src/shared/Cosmetics")
local CosmeticConfig = require("../src/shared/Config/CosmeticConfig")
local MonetizationConfig = require("../src/shared/Config/MonetizationConfig")
local WorldConfig = require("../src/shared/Config/WorldConfig")
local Worlds = require("../src/shared/Worlds")

local index = Worlds.new(WorldConfig)
local function firstTier(id)
	local world = index:get(id)
	return world and world.FirstTier
end

local function view(overrides)
	local v = { BestStack = 0, Strength = 1, DailyStreak = 0, Owned = {}, Passes = {} }
	for k, value in overrides or {} do
		v[k] = value
	end
	return v
end

T.describe("Cosmetics", function()
	T.it("default base is free", function()
		local base = CosmeticConfig.ById[CosmeticConfig.Default]
		T.truthy(base)
		T.eq(Cosmetics.isUnlocked(base, view(), firstTier), true)
	end)

	T.it("records, worlds, streaks, passes and owned grants unlock", function()
		T.eq(Cosmetics.isUnlocked(CosmeticConfig.ById.pizza, view({ BestStack = 24 }), firstTier), false)
		T.eq(Cosmetics.isUnlocked(CosmeticConfig.ById.pizza, view({ BestStack = 25 }), firstTier), true)
		T.eq(Cosmetics.isUnlocked(CosmeticConfig.ById.snow, view({ Strength = 4 }), firstTier), false)
		T.eq(Cosmetics.isUnlocked(CosmeticConfig.ById.snow, view({ Strength = 5 }), firstTier), true)
		T.eq(Cosmetics.isUnlocked(CosmeticConfig.ById.star, view({ DailyStreak = 7 }), firstTier), true)
		T.eq(Cosmetics.isUnlocked(CosmeticConfig.ById.gold, view(), firstTier), false)
		T.eq(Cosmetics.isUnlocked(CosmeticConfig.ById.gold, view({ Passes = { VIP = true } }), firstTier), true)
		T.eq(Cosmetics.isUnlocked(CosmeticConfig.ById.crate, view({ Owned = { crate = true } }), firstTier), true)
	end)

	T.it("config references exist", function()
		local seen = {}
		for _, base in CosmeticConfig.Bases do
			T.truthy(not seen[base.Id], "duplicate " .. base.Id)
			seen[base.Id] = true
			if base.Unlock.Kind == "Pass" then
				T.truthy(MonetizationConfig.GamePasses[base.Unlock.Pass], base.Id .. " pass")
			elseif base.Unlock.Kind == "World" then
				T.truthy(index:get(base.Unlock.World), base.Id .. " world")
			end
			T.truthy(Cosmetics.requirement(base) ~= nil)
		end
		for key, product in MonetizationConfig.Products do
			if product.Grant.Cosmetic then
				T.truthy(CosmeticConfig.ById[product.Grant.Cosmetic], key .. " cosmetic")
			end
		end
	end)
end)
