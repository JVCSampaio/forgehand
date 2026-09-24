-- Travel between unlocked worlds. Players arrive on a random spawn pad of the
-- target world; respawns and rejoins put them back in the last world visited.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local GameConfig = require(Shared.Config.GameConfig)
local WorldIndex = require(Shared.WorldIndex)
local Remotes = require(Shared.Remotes)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local DataService = require(script.Parent.DataService)
local StackService = require(script.Parent.StackService)
local Analytics = require(script.Parent.Analytics)

local TravelService = {}

local limiter = RateLimiter.new(3, 0.5)
local lastTravel: { [Player]: number } = {}

local function padsFor(worldId: string): { BasePart }
	local pads = {}
	for _, pad in CollectionService:GetTagged("SpawnPad") do
		if pad:GetAttribute("World") == worldId then
			table.insert(pads, pad :: BasePart)
		end
	end
	return pads
end

local function currentWorldId(profile): string
	local world = WorldIndex:get(profile.LastWorld)
	if world and WorldIndex:isUnlocked(world, profile.Upgrades.Strength) then
		return world.Id
	end
	return WorldIndex.list[1].Id
end

-- Moves the character onto a pad of `worldId`. Yields while streaming in.
local function place(player: Player, worldId: string): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local pads = padsFor(worldId)
	if not character or not root or #pads == 0 then
		return false
	end
	local pad = pads[math.random(1, #pads)]
	local target = pad.CFrame + Vector3.new(0, 3.5, 0)
	pcall(player.RequestStreamAroundAsync, player, target.Position, 5)
	if player.Character ~= character then
		return false
	end
	character:PivotTo(target)
	StackService.allowTeleport(player, target.Position)
	return true
end

function TravelService.travel(player: Player, worldId: unknown): (boolean, string?)
	if typeof(worldId) ~= "string" then
		return false, "invalid"
	end
	local world = WorldIndex:get(worldId :: string)
	local profile = DataService.getProfile(player)
	if not world or not profile then
		return false, "invalid"
	end
	-- Locked worlds can be visited to look around: nothing there can be
	-- lifted until Strength reaches the world's first tier (canPickUp), so
	-- visiting shows the variety early without skipping any progression.
	local visiting = not WorldIndex:isUnlocked(world, profile.Upgrades.Strength)
	local now = os.clock()
	if now - (lastTravel[player] or -math.huge) < GameConfig.Travel.Cooldown then
		return false, "cooldown"
	end
	local state = StackService.getState(player)
	if state and #state.Codes > 0 then
		return false, "stack"
	end
	lastTravel[player] = now
	if not place(player, world.Id) then
		return false, "failed"
	end
	profile.LastWorld = world.Id
	if visiting then
		Remotes.Notify:FireClient(player, {
			Kind = "Event",
			Text = string.format("👀 Visiting %s! Items here need 💪 Strength %d.", world.DisplayName, world.FirstTier),
		})
		Analytics.custom(player, "Visit_" .. world.Id)
	else
		Analytics.custom(player, "Travel_" .. world.Id)
	end
	DataService.changed(player)
	return true
end

function TravelService.init()
	Remotes.Travel.OnServerEvent:Connect(function(player, worldId)
		if not limiter:allow(player) then
			return
		end
		local ok, reason = TravelService.travel(player, worldId)
		if not ok then
			local text = if reason == "stack"
				then "Bank your stack before travelling!"
				elseif reason == "cooldown" then "Hold on, still travelling…"
				else nil
			if text then
				Remotes.Notify:FireClient(player, { Kind = "Error", Text = text })
			end
		end
	end)

	-- Respawns and rejoins return players to the world they were last in.
	local function returnToWorld(player: Player)
		local profile = DataService.getProfile(player)
		if not profile then
			return
		end
		local worldId = currentWorldId(profile)
		if worldId ~= WorldIndex.list[1].Id then
			local character = player.Character
			if character then
				character:WaitForChild("HumanoidRootPart", 10)
				place(player, worldId)
			end
		end
	end

	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(returnToWorld, player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	DataService.onLoaded(function(player)
		returnToWorld(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
	end)

	DataService.addSyncBuilder(function(_player, profile, snapshot)
		snapshot.World = currentWorldId(profile)
	end)
end

return TravelService
