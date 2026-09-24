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

Schema.CURRENT_VERSION = 1

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
		Settings = { Music = true, Sfx = true },
	}
end

-- Each entry migrates data FROM version index-1... e.g. MIGRATIONS[2] turns v1 into v2.
local MIGRATIONS: { [number]: (any) -> any } = {}

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
