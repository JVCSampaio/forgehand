-- Stack bases: validates equips against unlock rules and publishes the
-- equipped base as a player attribute that every client renders.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local CosmeticConfig = require(Shared.Config.CosmeticConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Cosmetics = require(Shared.Cosmetics)
local WorldIndex = require(Shared.WorldIndex)
local Remotes = require(Shared.Remotes)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local Analytics = require(script.Parent.Analytics)

local CosmeticService = {}

local limiter = RateLimiter.new(4, 1)
local known: { [Player]: { [string]: boolean } } = {}

local function worldFirstTier(id: string): number?
	local world = WorldIndex:get(id)
	return world and world.FirstTier
end

function CosmeticService.view(player: Player, profile)
	local passes = {}
	for key in MonetizationConfig.GamePasses do
		passes[key] = MonetizationService.ownsPass(player, key)
	end
	return {
		BestStack = profile.Stats.BestStack,
		Strength = profile.Upgrades.Strength,
		DailyStreak = profile.Daily.Streak,
		Owned = profile.Cosmetics.Owned,
		Passes = passes,
	}
end

function CosmeticService.unlocked(player: Player, profile): { [string]: boolean }
	local view = CosmeticService.view(player, profile)
	local set = {}
	for _, base in CosmeticConfig.Bases do
		if Cosmetics.isUnlocked(base, view, worldFirstTier) then
			set[base.Id] = true
		end
	end
	return set
end

local function publish(player: Player, profile)
	local set = CosmeticService.unlocked(player, profile)
	local equipped = profile.Cosmetics.Equipped
	if equipped == "" or not set[equipped] then
		equipped = CosmeticConfig.Default
	end
	player:SetAttribute("Base", equipped)
end

function CosmeticService.equip(player: Player, id: unknown): boolean
	if typeof(id) ~= "string" or not CosmeticConfig.ById[id :: string] then
		return false
	end
	local profile = DataService.getProfile(player)
	if not profile or not CosmeticService.unlocked(player, profile)[id :: string] then
		return false
	end
	profile.Cosmetics.Equipped = id :: string
	publish(player, profile)
	Analytics.custom(player, "Equip_" .. (id :: string))
	DataService.changed(player)
	return true
end

function CosmeticService.init()
	Remotes.EquipCosmetic.OnServerEvent:Connect(function(player, id)
		if limiter:allow(player) then
			CosmeticService.equip(player, id)
		end
	end)
	DataService.onLoaded(function(player, profile)
		known[player] = CosmeticService.unlocked(player, profile)
		publish(player, profile)
	end)
	MonetizationService.onPassChanged(function(player)
		local profile = DataService.getProfile(player)
		if profile then
			publish(player, profile)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		known[player] = nil
	end)

	DataService.addSyncBuilder(function(player, profile, snapshot)
		local set = CosmeticService.unlocked(player, profile)
		-- Announce newly earned bases once per session.
		local previous = known[player]
		if previous then
			for id in set do
				local base = CosmeticConfig.ById[id]
				-- Pass bases appear when ownership loads; only announce earned ones.
				if not previous[id] and base.Unlock.Kind ~= "Pass" then
					Remotes.Notify:FireClient(player, { Kind = "Record", Text = string.format("%s New stack base: %s! Equip it in SHOP.", base.Icon, base.Name) })
				end
			end
		end
		known[player] = set
		snapshot.Cosmetics = { Equipped = player:GetAttribute("Base") or CosmeticConfig.Default, Unlocked = set }
		snapshot.StarterPackBought = profile.Flags.StarterPack
	end)
end

return CosmeticService
