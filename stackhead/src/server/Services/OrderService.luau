-- Daily orders: generated on the first visit of the day, advanced by every
-- bank, claimed through a validated remote.

local Shared = game:GetService("ReplicatedStorage").Shared
local EconomyConfig = require(Shared.Config.EconomyConfig)
local ItemConfig = require(Shared.Config.ItemConfig)
local Economy = require(Shared.Economy)
local Orders = require(Shared.Orders)
local Remotes = require(Shared.Remotes)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local DataService = require(script.Parent.DataService)
local StackService = require(script.Parent.StackService)
local Analytics = require(script.Parent.Analytics)

local OrderService = {}

local limiter = RateLimiter.new(4, 1)

function OrderService.ensureToday(profile)
	local today = Economy.dayIndex(os.time())
	local orders = profile.Orders
	if orders.Day == today and #orders.List == 3 then
		return
	end
	local strength = profile.Upgrades.Strength
	orders.Day = today
	orders.List = Orders.generate(today, strength, profile.Stats.BestStack, Economy.tierScale(strength, EconomyConfig), ItemConfig)
	orders.Progress = { 0, 0, 0 }
	orders.Claimed = { false, false, false }
end

function OrderService.claim(player: Player, index: unknown): boolean
	if typeof(index) ~= "number" or index ~= math.floor(index :: number) or (index :: number) < 1 or (index :: number) > 3 then
		return false
	end
	local profile = DataService.getProfile(player)
	if not profile then
		return false
	end
	OrderService.ensureToday(profile)
	local i = index :: number
	local order = profile.Orders.List[i]
	if not order or profile.Orders.Claimed[i] or profile.Orders.Progress[i] < order.Target then
		return false
	end
	profile.Orders.Claimed[i] = true
	profile.Coins += order.RewardCoins
	profile.Glue = math.min(EconomyConfig.MaxGlue, profile.Glue + order.RewardGlue)
	Analytics.source(player, order.RewardCoins, profile.Coins, Enum.AnalyticsEconomyTransactionType.Gameplay.Name, "Order_" .. order.Kind)
	Analytics.custom(player, "OrderClaimed", i)
	Remotes.Notify:FireClient(player, { Kind = "Daily", Text = string.format("Order complete! +%d coins", order.RewardCoins) })
	DataService.changed(player)
	return true
end

function OrderService.init()
	DataService.onLoaded(function(player, profile)
		OrderService.ensureToday(profile)
		DataService.changed(player)
	end)

	StackService.onBanked(function(player, profile, count, codes, coins)
		OrderService.ensureToday(profile)
		local bank = { Count = count, Codes = codes, Coins = coins }
		for i, order in profile.Orders.List do
			local before = profile.Orders.Progress[i]
			local after = Orders.advance(order, before, bank)
			profile.Orders.Progress[i] = after
			if before < order.Target and after >= order.Target and not profile.Orders.Claimed[i] then
				Remotes.Notify:FireClient(player, { Kind = "Unlock", Text = "✅ Order done! Claim it in TASKS." })
			end
		end
		DataService.changed(player)
	end)

	Remotes.ClaimOrder.OnServerEvent:Connect(function(player, index)
		if limiter:allow(player) then
			OrderService.claim(player, index)
		end
	end)

	DataService.addSyncBuilder(function(_player, profile, snapshot)
		OrderService.ensureToday(profile)
		snapshot.Orders = {
			List = profile.Orders.List,
			Progress = table.clone(profile.Orders.Progress),
			Claimed = table.clone(profile.Orders.Claimed),
		}
	end)
end

return OrderService
