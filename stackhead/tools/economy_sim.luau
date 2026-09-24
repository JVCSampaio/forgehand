-- Pacing model: a bot plays the real Economy + Wobble code with the real
-- configs and reports when key moments happen. Run from stackhead/:
--   lune run tools/economy_sim.luau
--
-- Model assumptions (documented in docs/ECONOMY.md):
-- * zones stay near their cap (respawn >> one player's pickup rate)
-- * pickup rate = density * reach sweep width * speed, capped by walking between items
-- * the bot picks the stack size that maximises coins/second for its current stats,
--   walks with a turn every ~1.5 s, and stands still whenever wobble > 0.6
-- * the bot buys the cheapest useful upgrade, preferring Strength when affordable

local process = require("@lune/process")
local roblox = require("@lune/roblox")
Vector3 = roblox.Vector3
Color3 = roblox.Color3

local GameConfig = require("../src/shared/Config/GameConfig")
local WorldConfig = require("../src/shared/Config/WorldConfig")
local Worlds = require("../src/shared/Worlds")
local WorldIndex = Worlds.new(WorldConfig)
local EconomyConfig = require("../src/shared/Config/EconomyConfig")
local ItemConfig = require("../src/shared/Config/ItemConfig")
local UpgradeConfig = require("../src/shared/Config/UpgradeConfig")
local Economy = require("../src/shared/Economy")
local Wobble = require("../src/shared/Wobble")

local DT = 1 / GameConfig.TickRate
local rng = 12345
local function random(): number
	rng = (rng * 1103515245 + 12345) % 2147483648
	return rng / 2147483648
end

local expectedRarity = 1
do
	local remaining = 1
	local total = 0
	for _, rarity in GameConfig.Spawning.Rarities do
		total += rarity.Chance * rarity.ValueMult
		remaining -= rarity.Chance
	end
	expectedRarity = total + remaining
end

local function zoneStats(zone)
	local pool = ItemConfig.ByTier[zone.Tier]
	local weight, value, height = 0, 0, 0
	for _, def in pool do
		weight += def.Weight
		value += def.Value * def.Weight
		height += def.Height * def.Weight
	end
	local area = math.pi * (zone.OuterRadius ^ 2 - zone.InnerRadius ^ 2)
	return {
		Value = value / weight * expectedRarity,
		Height = height / weight,
		Density = zone.MaxItems / area,
		Distance = (zone.InnerRadius + zone.OuterRadius) / 2 - GameConfig.Bank.Radius,
	}
end

local function stats(upgrades)
	local defs = UpgradeConfig.Upgrades
	return {
		Speed = Economy.upgradeValue(defs.Speed, upgrades.Speed),
		Reach = Economy.upgradeValue(defs.Reach, upgrades.Reach),
		Balance = Wobble.balanceMultiplier(upgrades.Balance, GameConfig.Wobble),
		Strength = upgrades.Strength,
	}
end

-- Walk `seconds` with periodic turns; stop to steady when needed.
-- Returns (timeSpent, collapsed)
local function walk(state, seconds: number, speed: number, height: number, balance: number, turnEvery: number)
	local elapsed, moving, heading, sinceTurn = 0, 0, 0, 0
	while moving < seconds do
		local standing = state.Value > 0.6
		if standing then
			while state.Value > 0.15 do
				Wobble.step(state, { Dt = DT, VelX = 0, VelY = 0, VelZ = 0, Height = height, BalanceMult = balance }, GameConfig.Wobble)
				elapsed += DT
			end
		end
		sinceTurn += DT
		if sinceTurn >= turnEvery then
			sinceTurn = 0
			heading += (random() - 0.5) * math.pi * 0.8
		end
		Wobble.step(state, {
			Dt = DT,
			VelX = math.cos(heading) * speed,
			VelY = 0,
			VelZ = math.sin(heading) * speed,
			Height = height,
			BalanceMult = balance,
		}, GameConfig.Wobble)
		if state.Value >= 1 then
			return elapsed, true
		end
		elapsed += DT
		moving += DT
	end
	return elapsed, false
end

local function trip(s, zone, target: number)
	local z = zoneStats(zone)
	local state = Wobble.newState()
	local time = z.Distance / s.Speed -- walk out empty
	-- Sweep model, capped: items are discrete and the player detours between them.
	local rate = math.min(z.Density * 2 * s.Reach * s.Speed, 1.5)
	local count = 0
	while count < target do
		local spent, collapsed = walk(state, 1 / rate, s.Speed, count * z.Height, s.Balance, 1.5)
		time += spent
		if collapsed then
			count = Wobble.keepCount(count, GameConfig.Wobble)
			state.Value = 0
			break
		end
		count += 1
	end
	local spent, collapsed = walk(state, z.Distance / s.Speed, s.Speed, count * z.Height, s.Balance, 3)
	time += spent
	if collapsed then
		count = Wobble.keepCount(count, GameConfig.Wobble)
		time += z.Distance / s.Speed * 0.5
	end
	local entries = table.create(count, { Value = z.Value, RarityMult = 1 })
	local coins = Economy.bankPayout(entries, 1, EconomyConfig.HeightBonus)
	return coins, time, count
end

local function bestTrip(s)
	local zone = WorldIndex:zoneForTier(s.Strength)
	local best = nil
	for _, target in { 5, 8, 12, 16, 20, 25, 30, 40, 50, 65, 80, 100, 130, 160, 200 } do
		local savedRng = rng
		local coins, time, count = trip(s, zone, target)
		rng = savedRng
		if not best or coins / time > best.Rate then
			best = { Target = target, Rate = coins / time }
		end
		local _ = count
	end
	return best
end

local upgrades = { Speed = 0, Reach = 0, Balance = 0, Strength = 1 }
local coins = 0
local clock = 0
local events = {}
local firstBank, firstUpgrade = nil, nil
local banks = 0
local best = 0

local function log(text)
	table.insert(events, string.format("%6.1f min  %s", clock / 60, text))
end

local function tryBuy()
	local bought = true
	while bought do
		bought = false
		local strengthCost = Economy.upgradeCost(UpgradeConfig.Upgrades.Strength, upgrades.Strength)
		if strengthCost and coins >= strengthCost then
			coins -= strengthCost
			upgrades.Strength += 1
			local zone = WorldIndex:zoneForTier(upgrades.Strength)
			local world = WorldIndex:worldForTier(upgrades.Strength)
			if world.FirstTier == upgrades.Strength then
				log(string.format("Strength %d -> NEW WORLD %s", upgrades.Strength, world.DisplayName))
			else
				log(string.format("Strength %d -> unlocks %s", upgrades.Strength, zone.DisplayName))
			end
			bought = true
		else
			local cheapestId, cheapestCost = nil, math.huge
			for _, id in { "Balance", "Speed", "Reach" } do
				local cost = Economy.upgradeCost(UpgradeConfig.Upgrades[id], upgrades[id])
				if cost and cost < cheapestCost then
					cheapestId, cheapestCost = id, cost
				end
			end
			-- Save up for Strength once it is within reach.
			local saving = strengthCost and coins > strengthCost * 0.6
			if cheapestId and coins >= cheapestCost and not saving then
				coins -= cheapestCost
				upgrades[cheapestId] += 1
				if not firstUpgrade then
					firstUpgrade = clock
					log("First upgrade: " .. cheapestId)
				end
				bought = true
			end
		end
	end
end

local SESSION = tonumber((process.args[1])) or 8 * 60 * 60
-- Per-tier income, for calibrating Strength costs (--rates).
local tierTime, tierCoins = {}, {}
local nextReport = 5 * 60
while clock < SESSION do
	local s = stats(upgrades)
	local plan = bestTrip(s)
	-- First trips follow the on-screen guide ("grab 5 more", then bank).
	if banks < 2 then
		plan.Target = if banks == 0 then 6 else 12
	end
	local gained, time, count = trip(s, WorldIndex:zoneForTier(s.Strength), plan.Target)
	clock += time
	if banks == 0 then
		gained += EconomyConfig.FirstBankBonus
	end
	coins += gained
	banks += 1
	tierTime[s.Strength] = (tierTime[s.Strength] or 0) + time
	tierCoins[s.Strength] = (tierCoins[s.Strength] or 0) + gained
	if not firstBank then
		firstBank = clock
		log(string.format("First bank: %d items, +%d coins", count, gained))
	end
	if count > best then
		for _, milestone in EconomyConfig.Milestones do
			if best < milestone.Stack and count >= milestone.Stack then
				log(string.format("Record %d stack (%s)", milestone.Stack, milestone.Title))
			end
		end
		best = count
	end
	tryBuy()
	if clock >= nextReport then
		log(string.format(
			"status: coins/min %.0f, stack target %d, Spd %d Rch %d Bal %d Str %d",
			plan.Rate * 60,
			plan.Target,
			upgrades.Speed,
			upgrades.Reach,
			upgrades.Balance,
			upgrades.Strength
		))
		nextReport += if clock < 3600 then 5 * 60 else 30 * 60
	end
end

print(string.format("Stackhead pacing simulation (solo bot, %.0f h)", SESSION / 3600))
for _, line in events do
	print(line)
end

if process.args[2] == "--rates" then
	for tier = 1, WorldIndex:maxTier() do
		if tierTime[tier] then
			print(string.format("RATE %d %.0f %.1f", tier, tierCoins[tier] / tierTime[tier] * 60, tierTime[tier] / 60))
		end
	end
end
