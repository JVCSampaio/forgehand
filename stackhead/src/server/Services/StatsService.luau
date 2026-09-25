-- Derived player stats (upgrades + passes) and applying them to characters.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local GameConfig = require(Shared.Config.GameConfig)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local Economy = require(Shared.Economy)
local Wobble = require(Shared.Wobble)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)

local StatsService = {}

local defs = UpgradeConfig.Upgrades

function StatsService.walkSpeed(profile): number
	return Economy.upgradeValue(defs.Speed, profile.Upgrades.Speed)
end

function StatsService.reach(player: Player, profile): number
	return Economy.upgradeValue(defs.Reach, profile.Upgrades.Reach) + MonetizationService.bonusReach(player)
end

function StatsService.balanceMult(profile): number
	return Wobble.balanceMultiplier(profile.Upgrades.Balance, GameConfig.Wobble)
end

function StatsService.strength(profile): number
	return profile.Upgrades.Strength
end

local function rainbowTrail(character: Model, enabled: boolean)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local existing = root:FindFirstChild("RainbowTrail")
	if not enabled then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailTop"
	a0.Position = Vector3.new(0, 0.8, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailBottom"
	a1.Position = Vector3.new(0, -0.8, 0)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "RainbowTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.6
	trail.LightEmission = 0.4
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 230, 110)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(70, 160, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 90, 255)),
	})
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = root
end

function StatsService.apply(player: Player)
	local profile = DataService.getProfile(player)
	local character = player.Character
	if not profile or not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = StatsService.walkSpeed(profile)
			* (if player:GetAttribute("Steady") then GameConfig.Movement.SteadySpeedMult else 1)
	end
	rainbowTrail(character, MonetizationService.ownsPass(player, "RainbowTrail"))
	player:SetAttribute("VIP", MonetizationService.ownsPass(player, "VIP"))
end

function StatsService.init()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			character:WaitForChild("HumanoidRootPart", 10)
			StatsService.apply(player)
		end)
		player.CameraMaxZoomDistance = GameConfig.Camera.MaxZoom
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	DataService.onLoaded(function(player)
		StatsService.apply(player)
	end)
	MonetizationService.onPassChanged(StatsService.apply)
end

return StatsService
