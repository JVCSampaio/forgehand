-- Owns player profiles: session-locked load, autosave, save on leave and on
-- shutdown, leaderstats and client sync. Other services mutate the profile
-- table in place and call DataService.changed(player).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local EconomyConfig = require(Shared.Config.EconomyConfig)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local Remotes = require(Shared.Remotes)
local Util = script.Parent.Parent.Util
local Schema = require(Util.PlayerDataSchema)
local SessionStore = require(Util.SessionStore)
local MemoryStore = require(Util.MemoryStore)

local DataService = {}

local STORE_NAME = "StackheadPlayers_v1"
local AUTOSAVE_INTERVAL = 90
local SYNC_THROTTLE = 0.2

local profiles: { [Player]: any } = {}
local joinedAt: { [Player]: number } = {}
local syncQueued: { [Player]: boolean } = {}
local loadedCallbacks = {}
local syncBuilders = {}
local released: { [Player]: boolean } = {}
local savesInFlight = 0
local session
local usingMemoryStore = false

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

local function pickStore()
	local jobId = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)
	local store
	local ok = pcall(function()
		store = DataStoreService:GetDataStore(STORE_NAME)
		if RunService:IsStudio() then
			-- Throws when "Enable Studio Access to API Services" is off.
			store:GetAsync("__probe")
		end
	end)
	if not ok then
		if not RunService:IsStudio() then
			error("DataStore unavailable in a live server")
		end
		warn("[DataService] DataStore unavailable in Studio, using in-memory store. Progress will not persist.")
		store = MemoryStore.new()
		usingMemoryStore = true
	end
	session = SessionStore.new({
		store = store,
		jobId = jobId,
		now = os.time,
		wait = task.wait,
		warn = function(message)
			warn("[DataService] " .. message)
		end,
	})
end

local function setupLeaderstats(player: Player, profile)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = profile.Coins
	coins.Parent = folder
	local best = Instance.new("IntValue")
	best.Name = "Best Stack"
	best.Value = profile.Stats.BestStack
	best.Parent = folder
	folder.Parent = player
end

local function updateLeaderstats(player: Player, profile)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		return
	end
	local coins = folder:FindFirstChild("Coins") :: IntValue?
	local best = folder:FindFirstChild("Best Stack") :: IntValue?
	if coins then
		coins.Value = profile.Coins
	end
	if best then
		best.Value = profile.Stats.BestStack
	end
end

local function buildSnapshot(player: Player, profile)
	local snapshot = {
		Coins = profile.Coins,
		Glue = profile.Glue,
		Upgrades = table.clone(profile.Upgrades),
		BestStack = profile.Stats.BestStack,
		Banks = profile.Stats.Banks,
		Collapses = profile.Stats.Collapses,
		ItemsPicked = profile.Stats.ItemsPicked,
		Discovered = table.clone(profile.Discovered),
		Milestones = table.clone(profile.Milestones),
		BoostRemaining = math.max(0, profile.BoostEndsAt - os.time()),
		DailyStreak = profile.Daily.Streak,
		DailyLastClaimDay = profile.Daily.LastClaimDay,
		Today = math.floor(os.time() / 86400),
	}
	-- Other services add their own fields (pass ownership, glue armed, ...).
	for _, builder in syncBuilders do
		builder(player, profile, snapshot)
	end
	return snapshot
end

local function flushSync(player: Player)
	syncQueued[player] = nil
	local profile = profiles[player]
	if profile and player.Parent then
		updateLeaderstats(player, profile)
		Remotes.DataSync:FireClient(player, buildSnapshot(player, profile))
	end
end

-- Every write goes through here. Once a profile is released (player left)
-- no further non-release write may happen, or it would re-take the lock and
-- block the player from joining another server.
local function saveProfile(player: Player, profile, release: boolean): boolean
	if released[player] then
		return false
	end
	if release then
		released[player] = true
	end
	savesInFlight += 1
	local ok = session:save(keyFor(player), profile, release)
	savesInFlight -= 1
	return ok
end

function DataService.getProfile(player: Player)
	return profiles[player]
end

-- Yields until the profile loads, the player leaves, or `timeout` passes.
function DataService.waitForProfile(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 30)
	while not profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService.onLoaded(callback: (Player, any) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile)
	end
end

function DataService.addSyncBuilder(builder: (Player, any, any) -> ())
	table.insert(syncBuilders, builder)
end

-- Schedules a (throttled) client sync + leaderstats refresh.
function DataService.changed(player: Player)
	if syncQueued[player] then
		return
	end
	syncQueued[player] = true
	task.delay(SYNC_THROTTLE, flushSync, player)
end

function DataService.sessionMinutes(player: Player): number
	local started = joinedAt[player]
	return if started then (os.clock() - started) / 60 else 0
end

-- Writes immediately. Used after Robux purchases.
function DataService.forceSave(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	return saveProfile(player, profile, false)
end

function DataService.isEphemeral(): boolean
	return usingMemoryStore
end

local function onPlayerAdded(player: Player)
	local ok, data = session:load(keyFor(player))
	if not player.Parent then
		-- Left while loading: release the lock we may have taken.
		if ok then
			session:save(keyFor(player), data or Schema.defaults(EconomyConfig, UpgradeConfig), true)
		end
		return
	end
	if not ok then
		player:Kick("Your save is still in use by another server. Please rejoin in a minute.")
		return
	end

	local profile = Schema.sanitize(data, EconomyConfig, UpgradeConfig)
	local now = os.time()
	profile.Stats.Sessions += 1
	if profile.Stats.FirstJoin == 0 then
		profile.Stats.FirstJoin = now
	end
	profile.Stats.LastJoin = now

	profiles[player] = profile
	joinedAt[player] = os.clock()
	setupLeaderstats(player, profile)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile)
	end
	DataService.changed(player)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	if joinedAt[player] then
		profile.Stats.Playtime += os.clock() - joinedAt[player]
	end
	profiles[player] = nil
	joinedAt[player] = nil
	syncQueued[player] = nil
	saveProfile(player, profile, true)
	-- Player objects are not reused, so the guard can be dropped later.
	task.delay(60, function()
		released[player] = nil
	end)
end

function DataService.init()
	pickStore()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, profile in profiles do
				task.spawn(function()
					if profiles[player] == profile then
						saveProfile(player, profile, false)
					end
				end)
				task.wait(0.5)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				onPlayerRemoving(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while (pending > 0 or savesInFlight > 0) and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
