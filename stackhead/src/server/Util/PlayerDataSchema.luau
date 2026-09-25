-- Player save format, migrations and sanitisation. Pure (configs injected)
-- so it is unit tested outside Roblox.
--
-- Bump CURRENT_VERSION and add a step to MIGRATIONS whenever the shape changes.

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[deepCopy(k)] = deepCopy(v)
	end
	return copy
end

local Schema = {}

Schema.CURRENT_VERSION = 2

function Schema.defaults(economyConfig, upgradeConfig)
	local upgrades = {}
	for id, def in upgradeConfig.Upgrades do
		upgrades[id] = def.StartLevel
	end
	return {
		Version = Schema.CURRENT_VERSION,
		Coins = economyConfig.StartingCoins,
		Glue = economyConfig.StartingGlue,
		Upgrades = upgrades,
		BoostEndsAt = 0,
		Stats = {
			TotalBanked = 0,
			TotalCoins = 0,
			BestStack = 0,
			Banks = 0,
			Collapses = 0,
			ItemsPicked = 0,
			Playtime = 0,
			Sessions = 0,
			FirstJoin = 0,
			LastJoin = 0,
			RobuxSpent = 0,
		},
		Daily = { Streak = 0, LastClaimDay = 0 },
		Discovered = {},
		Milestones = {},
		Funnel = {},
		Purchases = {},
		PurchaseOrder = {},
		Settings = { Music = true, Sfx = true, Memes = true, ReducedMotion = false },
		-- v2
		LastWorld = "",
		Orders = { Day = 0, List = {}, Progress = { 0, 0, 0 }, Claimed = { false, false, false } },
		Cosmetics = { Owned = {}, Equipped = "" },
		Flags = { StarterPack = false },
	}
end

-- Each entry migrates data FROM version index-1... e.g. MIGRATIONS[2] turns v1 into v2.
local MIGRATIONS: { [number]: (any) -> any } = {
	-- v2 added worlds, daily orders and cosmetics; defaults fill them in.
	[2] = function(data)
		return data
	end,
}

function Schema.migrate(data)
	local version = tonumber(data.Version) or 0
	if version < 1 then
		-- Pre-release saves had no version; treat as v1.
		version = 1
	end
	for v = version + 1, Schema.CURRENT_VERSION do
		local step = MIGRATIONS[v]
		if step then
			data = step(data)
		end
	end
	data.Version = Schema.CURRENT_VERSION
	return data
end

local function finiteNumber(value, fallback: number, min: number, max: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	return math.clamp(value, min, max)
end

-- Fills missing fields from defaults and repairs obviously corrupt values so
-- a single bad write never bricks a save.
function Schema.sanitize(data, economyConfig, upgradeConfig)
	local defaults = Schema.defaults(economyConfig, upgradeConfig)
	if type(data) ~= "table" then
		return defaults
	end
	data = Schema.migrate(deepCopy(data))

	local out = defaults
	out.Coins = math.floor(finiteNumber(data.Coins, defaults.Coins, 0, 1e15))
	out.Glue = math.floor(finiteNumber(data.Glue, defaults.Glue, 0, economyConfig.MaxGlue))
	out.BoostEndsAt = finiteNumber(data.BoostEndsAt, 0, 0, 1e12)

	if type(data.Upgrades) == "table" then
		for id, def in upgradeConfig.Upgrades do
			out.Upgrades[id] = math.floor(finiteNumber(data.Upgrades[id], def.StartLevel, def.StartLevel, def.MaxLevel))
		end
	end

	if type(data.Stats) == "table" then
		for key, default in defaults.Stats do
			out.Stats[key] = finiteNumber(data.Stats[key], default, 0, 1e15)
		end
	end

	if type(data.Daily) == "table" then
		out.Daily.Streak = math.floor(finiteNumber(data.Daily.Streak, 0, 0, 1e6))
		out.Daily.LastClaimDay = math.floor(finiteNumber(data.Daily.LastClaimDay, 0, 0, 1e7))
	end

	for _, key in { "Discovered", "Milestones", "Funnel" } do
		if type(data[key]) == "table" then
			for k, v in data[key] do
				if type(k) == "string" and v == true then
					out[key][k] = true
				end
			end
		end
	end

	if type(data.PurchaseOrder) == "table" and type(data.Purchases) == "table" then
		for _, id in data.PurchaseOrder do
			if type(id) == "string" and data.Purchases[id] ~= nil then
				table.insert(out.PurchaseOrder, id)
				out.Purchases[id] = true
			end
		end
	end

	if type(data.LastWorld) == "string" and #data.LastWorld <= 32 then
		out.LastWorld = data.LastWorld
	end

	if type(data.Orders) == "table" then
		out.Orders.Day = math.floor(finiteNumber(data.Orders.Day, 0, 0, 1e7))
		if type(data.Orders.List) == "table" then
			for i = 1, 3 do
				local order = data.Orders.List[i]
				if type(order) == "table" and type(order.Kind) == "string" and #order.Kind <= 16 then
					out.Orders.List[i] = {
						Kind = order.Kind,
						Target = math.floor(finiteNumber(order.Target, 1, 1, 1e15)),
						ItemId = if type(order.ItemId) == "string" and #order.ItemId <= 8 then order.ItemId else nil,
						RewardCoins = math.floor(finiteNumber(order.RewardCoins, 0, 0, 1e15)),
						RewardGlue = math.floor(finiteNumber(order.RewardGlue, 0, 0, 10)),
					}
				end
			end
			-- A partial list is useless; regenerate the day.
			if #out.Orders.List ~= 3 then
				out.Orders.List = {}
				out.Orders.Day = 0
			end
		end
		for i = 1, 3 do
			if type(data.Orders.Progress) == "table" then
				out.Orders.Progress[i] = math.floor(finiteNumber(data.Orders.Progress[i], 0, 0, 1e15))
			end
			if type(data.Orders.Claimed) == "table" then
				out.Orders.Claimed[i] = data.Orders.Claimed[i] == true
			end
		end
	end

	if type(data.Cosmetics) == "table" then
		if type(data.Cosmetics.Owned) == "table" then
			for id, owned in data.Cosmetics.Owned do
				if type(id) == "string" and owned == true then
					out.Cosmetics.Owned[id] = true
				end
			end
		end
		if type(data.Cosmetics.Equipped) == "string" and #data.Cosmetics.Equipped <= 32 then
			out.Cosmetics.Equipped = data.Cosmetics.Equipped
		end
	end

	if type(data.Flags) == "table" then
		for key, default in defaults.Flags do
			if type(data.Flags[key]) == type(default) then
				out.Flags[key] = data.Flags[key]
			end
		end
	end

	if type(data.Settings) == "table" then
		for key, default in defaults.Settings do
			if type(data.Settings[key]) == type(default) then
				out.Settings[key] = data.Settings[key]
			end
		end
	end

	return out
end

-- Remembers a receipt id, forgetting the oldest beyond `limit`.
function Schema.recordPurchase(data, purchaseId: string, limit: number)
	data.Purchases[purchaseId] = true
	table.insert(data.PurchaseOrder, purchaseId)
	while #data.PurchaseOrder > limit do
		local oldest = table.remove(data.PurchaseOrder, 1)
		data.Purchases[oldest] = nil
	end
end

return Schema
