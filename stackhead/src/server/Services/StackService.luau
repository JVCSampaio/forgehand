-- The core loop, fully server-authoritative:
--   walk near items -> server picks them up -> stack grows -> wobble builds
--   -> reach the bank to cash in, or wobble past 1 and the top half falls off.
-- Clients never tell the server what they picked up or banked; they only
-- send intent (dash, arm glue) which is validated here.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage").Shared
local GameConfig = require(Shared.Config.GameConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local Economy = require(Shared.Economy)
local Wobble = require(Shared.Wobble)
local StackCodec = require(Shared.StackCodec)
local MovementGuard = require(Shared.MovementGuard)
local Remotes = require(Shared.Remotes)
local WorldIndex = require(Shared.WorldIndex)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local DataService = require(script.Parent.DataService)
local ItemSpawnService = require(script.Parent.ItemSpawnService)
local MonetizationService = require(script.Parent.MonetizationService)
local StatsService = require(script.Parent.StatsService)
local Analytics = require(script.Parent.Analytics)

local StackService = {}

local MAX_STACK = 999
local WOBBLE_CFG = GameConfig.Wobble
local DASH_CFG = GameConfig.Dash

type Entry = { Value: number, RarityMult: number, Height: number }
type PlayerState = {
	Codes: { string },
	Entries: { Entry },
	Height: number,
	Wobble: Wobble.State,
	GraceUntil: number,
	LastDash: number,
	DashUntil: number,
	ImmuneUntil: number,
	GlueArmed: boolean,
	InBank: boolean,
	LastPos: Vector3?,
	LastImplausible: number,
	MoveCredit: number,
	Steady: boolean,
	LastSafeCFrame: CFrame?,
	Dirty: boolean,
	LastWobbleSent: number,
	Picked: { any },
}

local states: { [Player]: PlayerState } = {}
local bankedCallbacks = {}
local dashLimiter = RateLimiter.new(3, 1)
local glueLimiter = RateLimiter.new(4, 2)
local steadyLimiter = RateLimiter.new(6, 3)

local function newState(): PlayerState
	return {
		Codes = {},
		Entries = {},
		Height = 0,
		Wobble = Wobble.newState(),
		GraceUntil = 0,
		LastDash = -math.huge,
		DashUntil = 0,
		ImmuneUntil = 0,
		GlueArmed = false,
		InBank = false,
		LastPos = nil,
		LastImplausible = -math.huge,
		MoveCredit = 8,
		Steady = false,
		LastSafeCFrame = nil,
		Dirty = true,
		LastWobbleSent = -1,
		Picked = {},
	}
end

-- callback(player, profile, count, codes, coinsEarned)
function StackService.onBanked(callback: (Player, any, number, { string }, number) -> ())
	table.insert(bankedCallbacks, callback)
end

function StackService.getState(player: Player): PlayerState?
	return states[player]
end

-- Only trusted server travel can reset the movement baseline.
function StackService.authorizePosition(player: Player, cf: CFrame)
	local state = states[player]
	if state then
		state.LastPos = cf.Position
		state.LastSafeCFrame = cf
		state.MoveCredit = 8
		state.ImmuneUntil = os.clock() + 3
		state.Wobble = Wobble.newState()
	end
end

-- Every world has a bank at its centre.
local function isInBank(position: Vector3): boolean
	local world = WorldIndex:at(position)
	local offset = position - world.Origin
	return Vector2.new(offset.X, offset.Z).Magnitude <= GameConfig.Bank.Radius
		and offset.Y >= -2
		and offset.Y <= GameConfig.Bank.MaxHeightAbove
end

function StackService.isInBank(position: Vector3): boolean
	return isInBank(position)
end

local function recomputeHeight(state: PlayerState)
	local height = 0
	for _, entry in state.Entries do
		height += entry.Height
	end
	state.Height = height
end

local function notify(player: Player, kind: string, text: string)
	Remotes.Notify:FireClient(player, { Kind = kind, Text = text })
end

local function headTop(player: Player): Vector3?
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	return head.Position + Vector3.new(0, head.Size.Y / 2, 0)
end

local function bank(player: Player, state: PlayerState, profile)
	local count = #state.Codes
	local coinMult = MonetizationService.coinMultiplier(player, profile)
	local total, base, heightMult = Economy.bankPayout(state.Entries, coinMult, EconomyConfig.HeightBonus)

	local discoveries = {}
	local discoveryValue = 0
	for index, code in state.Codes do
		if not profile.Discovered[code] then
			profile.Discovered[code] = true
			table.insert(discoveries, code)
			local entry = state.Entries[index]
			discoveryValue += entry.Value * entry.RarityMult * EconomyConfig.DiscoveryBonusMult
		end
	end
	local discoveryBonus = math.floor(discoveryValue * coinMult + 0.5)
	local firstBonus = if profile.Stats.Banks == 0 then EconomyConfig.FirstBankBonus else 0
	local grand = total + discoveryBonus + firstBonus

	profile.Coins += grand
	profile.Stats.TotalCoins += grand
	profile.Stats.TotalBanked += count
	profile.Stats.Banks += 1

	local oldBest = profile.Stats.BestStack
	local milestones = {}
	if count > oldBest then
		profile.Stats.BestStack = count
		for _, milestone in Economy.newMilestones(oldBest, count, EconomyConfig) do
			if not profile.Milestones[tostring(milestone.Stack)] then
				profile.Milestones[tostring(milestone.Stack)] = true
				profile.Glue = math.min(EconomyConfig.MaxGlue, profile.Glue + milestone.Glue)
				table.insert(milestones, milestone)
			end
		end
		player:SetAttribute("Title", Economy.titleFor(count, EconomyConfig))
	end

	local bankedCodes = table.clone(state.Codes)
	table.clear(state.Codes)
	table.clear(state.Entries)
	state.Height = 0
	state.Wobble.Value = 0
	state.Dirty = true

	Remotes.Banked:FireClient(player, {
		Count = count,
		Total = grand,
		Base = base,
		HeightMult = heightMult,
		CoinMult = coinMult,
		DiscoveryBonus = discoveryBonus,
		FirstBonus = firstBonus,
		Discoveries = discoveries,
		Milestones = milestones,
		NewRecord = count > oldBest,
		PreviousBest = oldBest,
	})
	if count >= GameConfig.Events.BroadcastStack then
		for _, other in Players:GetPlayers() do
			if other ~= player then
				notify(other, "Broadcast", string.format("%s banked a %d stack!", player.DisplayName, count))
			end
		end
	end

	Analytics.funnel(player, profile, "FirstBank")
	Analytics.source(player, grand, profile.Coins, Enum.AnalyticsEconomyTransactionType.Gameplay.Name, "Bank")
	Analytics.custom(player, "BankStack", count)
	for _, callback in bankedCallbacks do
		task.spawn(callback, player, profile, count, bankedCodes, grand)
	end
	DataService.changed(player)
end

-- Landing spot for a fallen item: near the player, outside the bank, inside the island.
local function scatterPoint(origin: Vector3): Vector3
	local loose = GameConfig.Loose
	local centre = WorldIndex:at(origin).Origin
	local angle = math.random() * math.pi * 2
	local distance = loose.ScatterMin + math.random() * (loose.ScatterMax - loose.ScatterMin)
	local flat =
		Vector2.new(origin.X - centre.X + math.cos(angle) * distance, origin.Z - centre.Z + math.sin(angle) * distance)
	local r = flat.Magnitude
	local minR = GameConfig.Bank.Radius + 3
	local maxR = GameConfig.Layout.BoundaryRadius - 6
	if r < minR or r > maxR then
		local unit = if r > 0.01 then flat.Unit else Vector2.new(1, 0)
		flat = unit * math.clamp(r, minR, maxR)
	end
	return Vector3.new(centre.X + flat.X, GameConfig.Layout.GroundY, centre.Z + flat.Y)
end

-- keepOverride = 0 drops everything (death). Glue only protects wobble collapses.
local function collapse(player: Player, state: PlayerState, profile, keepOverride: number?)
	local count = #state.Codes
	if count == 0 then
		return
	end
	if keepOverride == nil and state.GlueArmed and profile.Glue > 0 then
		profile.Glue -= 1
		state.GlueArmed = false
		player:SetAttribute("GlueArmed", false)
		state.Wobble.Value = WOBBLE_CFG.GlueResidual
		state.GraceUntil = os.clock() + 1
		notify(player, "Glue", "Glue saved your stack!")
		Analytics.custom(player, "GlueSave", count)
		DataService.changed(player)
		return
	end

	local keep = keepOverride or Wobble.keepCount(count, WOBBLE_CFG)
	local top = headTop(player) or (state.LastPos or Vector3.zero)
	local origin = state.LastPos or top
	local heightAt = 0
	for index = 1, keep do
		heightAt += state.Entries[index].Height
	end

	local spawned = 0
	for index = keep + 1, count do
		local entry = state.Entries[index]
		heightAt += entry.Height
		if spawned < GameConfig.Loose.MaxPerCollapse then
			spawned += 1
			local from = top + Vector3.new(0, heightAt - entry.Height / 2, 0)
			ItemSpawnService.spawnLoose(state.Codes[index], from, scatterPoint(origin), player.UserId, nil)
		end
	end
	for index = count, keep + 1, -1 do
		state.Codes[index] = nil
		state.Entries[index] = nil
	end
	recomputeHeight(state)
	state.Wobble.Value = 0
	state.GraceUntil = os.clock() + WOBBLE_CFG.CollapseGrace
	state.Dirty = true

	profile.Stats.Collapses += 1
	local lost = count - keep
	Remotes.Collapsed:FireAllClients(player.UserId, lost, origin)
	if keepOverride == nil then
		notify(
			player,
			"Collapse",
			string.format("CRASH! %d items fell. Use STABILIZE to recover. Pick up the fallen items!", lost)
		)
	end
	Analytics.custom(player, "Collapse", count)
	DataService.changed(player)
end

local function pickups(player: Player, state: PlayerState, profile, position: Vector3)
	if #state.Codes >= MAX_STACK then
		return
	end
	local reach = StatsService.reach(player, profile)
	local strength = StatsService.strength(profile)
	local now = Workspace:GetServerTimeNow()
	local feet = position - Vector3.new(0, 2.5, 0)
	for _, model in ItemSpawnService.query(feet, reach) do
		local info = ItemSpawnService.info(model)
		if info and ItemSpawnService.canPickUp(info, player, strength, now) then
			local root = model.PrimaryPart
			local from = if root then root.Position else feet
			local taken = ItemSpawnService.take(model)
			if taken then
				table.insert(state.Codes, taken.Code)
				table.insert(
					state.Entries,
					{ Value = taken.Def.Value, RarityMult = taken.RarityMult, Height = taken.Def.Height }
				)
				state.Height += taken.Def.Height
				state.Dirty = true
				table.insert(state.Picked, { taken.Code, from })
				if profile.Stats.ItemsPicked == 0 then
					Analytics.funnel(player, profile, "FirstPickup")
				end
				profile.Stats.ItemsPicked += 1
				if #state.Codes >= MAX_STACK then
					break
				end
			end
		end
	end
	local count = #state.Codes
	if count >= 5 then
		Analytics.funnel(player, profile, "Stack5")
	end
	if count >= 25 then
		Analytics.funnel(player, profile, "Stack25")
	end
end

local function checkBumps(player: Player, state: PlayerState, position: Vector3, now: number)
	for other, otherState in states do
		if other ~= player and not otherState.InBank and otherState.LastPos and now >= otherState.ImmuneUntil then
			if (otherState.LastPos - position).Magnitude <= DASH_CFG.BumpRadius then
				local otherProfile = DataService.getProfile(other)
				if otherProfile then
					otherState.ImmuneUntil = now + DASH_CFG.VictimImmunity
					state.DashUntil = 0
					Wobble.kick(
						otherState.Wobble,
						DASH_CFG.BumpKick,
						otherState.Height,
						StatsService.balanceMult(otherProfile),
						WOBBLE_CFG
					)
					Remotes.Bumped:FireClient(other, player.UserId, true)
					Remotes.Bumped:FireClient(player, other.UserId, false)
					Analytics.custom(player, "Bump", #otherState.Codes)
					return
				end
			end
		end
	end
end

local function tickPlayer(player: Player, state: PlayerState, dt: number, now: number)
	local profile = DataService.getProfile(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not profile or not root or not humanoid or humanoid.Health <= 0 then
		state.LastPos = nil
		return
	end

	local position = root.Position
	local velocity = root.AssemblyLinearVelocity
	local plausible = true
	if state.LastPos then
		-- The client owns its character physics, so a spoofed "zero velocity"
		-- could dodge wobble. Fall back to measured movement when they disagree.
		local measured = (position - state.LastPos) / dt
		if (measured - velocity).Magnitude > 12 then
			velocity = measured
		end
		local moved = Vector2.new(position.X - state.LastPos.X, position.Z - state.LastPos.Z).Magnitude
		local dashing = now - state.LastDash < 1
		local speed = StatsService.walkSpeed(profile)
			* (if state.Steady then GameConfig.Movement.SteadySpeedMult else 1)
		local allowedSpeed = speed + (if dashing and now - state.LastDash < 0.4 then DASH_CFG.Impulse else 0)
		plausible, state.MoveCredit = MovementGuard.step(state.MoveCredit, moved, allowedSpeed, dt)
		if position.Y ~= position.Y or math.abs(position.Y) == math.huge then
			plausible = false
		end
		if not plausible then
			state.LastImplausible = now
			-- Roll back BEFORE banking, pickups, or bumps. Waiting at the illicit
			-- destination cannot make an invalid teleport eligible next tick.
			if state.LastSafeCFrame then
				root.CFrame = state.LastSafeCFrame
			end
			root.AssemblyLinearVelocity = Vector3.zero
			return
		end
	else
		-- First tick after spawning: don't count spawn velocity as a disturbance.
		state.Wobble.VelX, state.Wobble.VelY, state.Wobble.VelZ = velocity.X, velocity.Y, velocity.Z
	end
	state.LastPos = position
	state.LastSafeCFrame = root.CFrame

	state.InBank = isInBank(position)
	if state.InBank then
		state.Wobble.Value = 0
		state.Wobble.VelX, state.Wobble.VelY, state.Wobble.VelZ = velocity.X, velocity.Y, velocity.Z
		if #state.Codes > 0 then
			bank(player, state, profile)
		end
	else
		pickups(player, state, profile, position)
		local balance = StatsService.balanceMult(profile)
		if now >= state.GraceUntil then
			Wobble.step(state.Wobble, {
				Dt = dt,
				VelX = velocity.X,
				VelY = velocity.Y,
				VelZ = velocity.Z,
				Height = state.Height,
				BalanceMult = balance,
				Steady = state.Steady,
			}, WOBBLE_CFG)
		else
			state.Wobble.VelX, state.Wobble.VelY, state.Wobble.VelZ = velocity.X, velocity.Y, velocity.Z
		end
		if state.Wobble.Value >= 1 then
			collapse(player, state, profile, nil)
		end
		-- No bumps right after a teleport: prevents warp-and-shove griefing.
		if now < state.DashUntil and now - state.LastImplausible > 1 then
			checkBumps(player, state, position, now)
		end
	end

	if state.Dirty then
		state.Dirty = false
		player:SetAttribute("Stack", StackCodec.encode(state.Codes))
		player:SetAttribute("StackHeight", state.Height)
	end
	local wobble = math.floor(math.min(state.Wobble.Value, 1) * 50 + 0.5) / 50
	if wobble ~= state.LastWobbleSent then
		state.LastWobbleSent = wobble
		player:SetAttribute("Wobble", wobble)
	end
	if #state.Picked > 0 then
		Remotes.PickedUp:FireClient(player, state.Picked)
		state.Picked = {}
	end
end

local function onPlayerAdded(player: Player)
	states[player] = newState()
	player:SetAttribute("Stack", "")
	player:SetAttribute("StackHeight", 0)
	player:SetAttribute("Wobble", 0)
	player:SetAttribute("GlueArmed", false)

	local function onCharacter(character: Model)
		local state = states[player]
		if state then
			table.clear(state.Codes)
			table.clear(state.Entries)
			state.Height = 0
			state.Wobble = Wobble.newState()
			state.LastPos = nil
			state.LastSafeCFrame = nil
			state.Steady = false
			state.MoveCredit = 8
			player:SetAttribute("Steady", false)
			state.Dirty = true
		end
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			humanoid.Died:Connect(function()
				local current = states[player]
				local profile = DataService.getProfile(player)
				if current and profile then
					collapse(player, current, profile, 0)
				end
			end)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

function StackService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		dashLimiter:forget(player)
		glueLimiter:forget(player)
		steadyLimiter:forget(player)
	end)

	DataService.onLoaded(function(player, profile)
		player:SetAttribute("Title", Economy.titleFor(profile.Stats.BestStack, EconomyConfig))
	end)

	DataService.addSyncBuilder(function(player, _profile, snapshot)
		local state = states[player]
		snapshot.GlueArmed = state ~= nil and state.GlueArmed
	end)

	Remotes.SetSteady.OnServerEvent:Connect(function(player, enabled)
		if typeof(enabled) ~= "boolean" or not steadyLimiter:allow(player) then
			return
		end
		local state = states[player]
		local profile = DataService.getProfile(player)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not state or not profile or not humanoid or humanoid.Health <= 0 then
			return
		end
		state.Steady = enabled
		player:SetAttribute("Steady", enabled)
		StatsService.apply(player)
	end)

	Remotes.Dash.OnServerEvent:Connect(function(player)
		if not dashLimiter:allow(player) then
			return
		end
		local state = states[player]
		local profile = DataService.getProfile(player)
		if not state or not profile then
			return
		end
		local now = os.clock()
		-- Small tolerance for latency jitter; the client enforces the full cooldown.
		if now - state.LastDash < DASH_CFG.Cooldown * 0.85 then
			return
		end
		if state.Steady then
			return
		end
		state.LastDash = now
		state.DashUntil = now + DASH_CFG.BumpWindow
		if not state.InBank then
			Wobble.kick(state.Wobble, DASH_CFG.SelfKick, state.Height, StatsService.balanceMult(profile), WOBBLE_CFG)
		end
	end)

	Remotes.UseGlue.OnServerEvent:Connect(function(player, arm)
		if typeof(arm) ~= "boolean" or not glueLimiter:allow(player) then
			return
		end
		local state = states[player]
		local profile = DataService.getProfile(player)
		if not state or not profile then
			return
		end
		if arm and profile.Glue <= 0 then
			notify(player, "Error", "No glue left! Earn more from records and daily rewards.")
			return
		end
		state.GlueArmed = arm
		player:SetAttribute("GlueArmed", arm)
		DataService.changed(player)
	end)

	local interval = 1 / GameConfig.TickRate
	local accumulator = 0
	local last = os.clock()
	RunService.Heartbeat:Connect(function(frameDt)
		accumulator += frameDt
		if accumulator < interval then
			return
		end
		accumulator = 0
		local now = os.clock()
		local dt = math.min(now - last, 0.5)
		last = now
		for player, state in states do
			local ok, err = pcall(tickPlayer, player, state, dt, now)
			if not ok then
				warn("[StackService] tick failed for", player.Name, err)
			end
		end
	end)
end

return StackService
