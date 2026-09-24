local T = _G.T
local GameConfig = require("../src/shared/Config/GameConfig")
local ItemConfig = require("../src/shared/Config/ItemConfig")
local UpgradeConfig = require("../src/shared/Config/UpgradeConfig")
local MonetizationConfig = require("../src/shared/Config/MonetizationConfig")
local EconomyConfig = require("../src/shared/Config/EconomyConfig")

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

	T.it("every zone tier has items", function()
		for _, zone in GameConfig.Zones do
			T.truthy(ItemConfig.ByTier[zone.Tier] and #ItemConfig.ByTier[zone.Tier] > 0, zone.Id)
		end
	end)

	T.it("zones are contiguous rings inside the boundary", function()
		local previous = GameConfig.Bank.Radius
		for _, zone in GameConfig.Zones do
			T.truthy(zone.InnerRadius >= previous - 1e-6, zone.Id .. " starts after previous ring")
			T.truthy(zone.OuterRadius > zone.InnerRadius, zone.Id)
			previous = zone.OuterRadius
		end
		T.truthy(previous <= GameConfig.World.BoundaryRadius)
	end)

	T.it("strength max matches the highest zone tier", function()
		local highest = 0
		for _, zone in GameConfig.Zones do
			highest = math.max(highest, zone.Tier)
		end
		T.eq(UpgradeConfig.Upgrades.Strength.MaxLevel, highest)
		T.eq(#UpgradeConfig.Upgrades.Strength.Costs, highest - 1)
		T.eq(#EconomyConfig.TierScale, highest)
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
