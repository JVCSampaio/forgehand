-- Coin sink: validated upgrade purchases.

local Shared = game:GetService("ReplicatedStorage").Shared
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local WorldIndex = require(Shared.WorldIndex)
local Economy = require(Shared.Economy)
local Remotes = require(Shared.Remotes)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local DataService = require(script.Parent.DataService)
local StatsService = require(script.Parent.StatsService)
local Analytics = require(script.Parent.Analytics)

local UpgradeService = {}

local limiter = RateLimiter.new(8, 4)

-- Returns (ok, reasonOrNewLevel)
function UpgradeService.buy(player: Player, upgradeId: unknown): (boolean, any)
	if typeof(upgradeId) ~= "string" then
		return false, "invalid"
	end
	local def = UpgradeConfig.Upgrades[upgradeId :: string]
	if not def then
		return false, "invalid"
	end
	local profile = DataService.getProfile(player)
	if not profile then
		return false, "loading"
	end
	local level = profile.Upgrades[upgradeId]
	local cost = Economy.upgradeCost(def, level)
	if not cost then
		return false, "max"
	end
	if profile.Coins < cost then
		return false, "coins"
	end

	profile.Coins -= cost
	profile.Upgrades[upgradeId] = level + 1
	StatsService.apply(player)

	Analytics.sink(player, cost, profile.Coins, Enum.AnalyticsEconomyTransactionType.Shop.Name, upgradeId .. "_" .. (level + 1))
	Analytics.funnel(player, profile, "FirstUpgrade")
	if upgradeId == "Strength" then
		local zone = WorldIndex:zoneForTier(level + 1)
		local world = WorldIndex:worldForTier(level + 1)
		Analytics.progression(player, "Strength", level + 1, zone and zone.Key or "")
		if level + 1 == 2 then
			Analytics.funnel(player, profile, "UnlockedYard")
		elseif level + 1 == 3 then
			Analytics.funnel(player, profile, "UnlockedFarm")
		end
		if world and world.FirstTier == level + 1 then
			Remotes.Notify:FireClient(player, { Kind = "Unlock", Text = world.Icon .. " " .. world.DisplayName .. " unlocked! Open WORLDS to travel." })
			Analytics.custom(player, "WorldUnlocked_" .. world.Id)
		elseif zone then
			Remotes.Notify:FireClient(player, { Kind = "Unlock", Text = zone.DisplayName .. " unlocked! Heavier items = more coins." })
		end
	end
	DataService.changed(player)
	return true, level + 1
end

function UpgradeService.init()
	Remotes.BuyUpgrade.OnServerInvoke = function(player, upgradeId)
		if not limiter:allow(player) then
			return false, "slow"
		end
		return UpgradeService.buy(player, upgradeId)
	end
end

return UpgradeService
