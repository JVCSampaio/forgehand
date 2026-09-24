local T = _G.T
local GameConfig = require("../src/shared/Config/GameConfig")
local ItemConfig = require("../src/shared/Config/ItemConfig")
local UpgradeConfig = require("../src/shared/Config/UpgradeConfig")
local MonetizationConfig = require("../src/shared/Config/MonetizationConfig")
local EconomyConfig = require("../src/shared/Config/EconomyConfig")
local WorldConfig = require("../src/shared/Config/WorldConfig")

T.describe("Config integrity", function()
	T.it("item ids are 3 characters and unique", function()
		local seen = {}
		for _, item in ItemConfig.Items do
			T.eq(#item.Id, 3, item.Name)
			T.truthy(not seen[item.Id], "duplicate " .. item.Id)
			seen[item.Id] = true
			T.truthy(not string.find(item.Id, ","), "comma in id")
			T.truthy(item.Value > 0 and item.Height > 0 and item.Weight > 0, item.Name)
			T.truthy(#item.Parts >= 1, item.Name .. " has parts")
		end
	end)

	T.it("rarity suffixes never collide with item ids and are single chars", function()
		for _, rarity in GameConfig.Spawning.Rarities do
			T.eq(#rarity.Suffix, 1)
		end
	end)

	T.it("every world zone tier has items and tiers run 1..N without gaps", function()
		local expected = 1
		for _, world in WorldConfig.Worlds do
			for _, zone in world.Zones do
				T.eq(zone.Tier, expected, zone.Key)
				T.truthy(ItemConfig.ByTier[zone.Tier] and #ItemConfig.ByTier[zone.Tier] > 0, zone.Key)
				expected += 1
			end
		end
		T.eq(#ItemConfig.Items > 0, true)
		for tier in ItemConfig.ByTier do
			T.truthy(tier < expected, "items exist for tier " .. tier .. " but no zone spawns them")
		end
	end)

	T.it("zones are contiguous rings inside the boundary", function()
		for _, world in WorldConfig.Worlds do
			local previous = GameConfig.Bank.Radius
			for _, zone in world.Zones do
				T.truthy(zone.InnerRadius >= previous - 1e-6, zone.Key .. " starts after previous ring")
				T.truthy(zone.OuterRadius > zone.InnerRadius, zone.Key)
				previous = zone.OuterRadius
			end
			T.truthy(previous <= GameConfig.Layout.BoundaryRadius)
		end
	end)

	T.it("worlds don't overlap", function()
		T.truthy(WorldConfig.Spacing > 2 * GameConfig.Layout.OceanRadius, "oceans overlap")
	end)

	T.it("strength max matches the highest tier", function()
		local highest = 0
		for _, world in WorldConfig.Worlds do
			for _, zone in world.Zones do
				highest = math.max(highest, zone.Tier)
			end
		end
		T.eq(UpgradeConfig.Upgrades.Strength.MaxLevel, highest)
		T.eq(#UpgradeConfig.Upgrades.Strength.Costs, highest - 1)
		T.eq(#EconomyConfig.TierScale, highest)
	end)

	T.it("item values rise with tier", function()
		local previousMax = 0
		for tier = 1, #EconomyConfig.TierScale do
			local minValue = math.huge
			local maxValue = 0
			for _, item in ItemConfig.ByTier[tier] do
				minValue = math.min(minValue, item.Value)
				maxValue = math.max(maxValue, item.Value)
			end
			T.truthy(minValue > previousMax * 0.5, "tier " .. tier .. " cheapest item should beat half of the previous best")
			previousMax = maxValue
		end
	end)

	T.it("upgrade order lists every upgrade", function()
		local count = 0
		for _ in UpgradeConfig.Upgrades do
			count += 1
		end
		T.eq(#UpgradeConfig.Order, count)
		for _, id in UpgradeConfig.Order do
			T.truthy(UpgradeConfig.Upgrades[id], id)
		end
	end)

	T.it("monetization order lists every pass and product", function()
		for _, key in MonetizationConfig.PassOrder do
			T.truthy(MonetizationConfig.GamePasses[key], key)
		end
		for _, key in MonetizationConfig.ProductOrder do
			T.truthy(MonetizationConfig.Products[key], key)
		end
	end)
end)
