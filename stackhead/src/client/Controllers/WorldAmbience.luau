-- Retints the (replicated) Lighting locally when the player moves between
-- worlds: sunny Stackville, crisp Frostpeak, pastel Candy Coast, dusky Neon
-- City. Also adds light weather (snow in Frostpeak).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage").Shared
local WorldIndex = require(Shared.WorldIndex)

local WorldAmbience = {}

local player = Players.LocalPlayer
local current = nil
local snow: ParticleEmitter
local snowAnchor: Part

local function apply(world)
	local look = world.Lighting
	local info = TweenInfo.new(1.5, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, {
		ClockTime = look.ClockTime,
		Brightness = look.Brightness,
		Ambient = look.Ambient,
		OutdoorAmbient = look.OutdoorAmbient,
	}):Play()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		TweenService:Create(atmosphere, info, {
			Color = look.AtmosphereColor,
			Decay = look.AtmosphereDecay,
			Density = look.AtmosphereDensity,
		}):Play()
	end
	local correction = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if correction then
		TweenService:Create(correction, info, { TintColor = look.Tint, Saturation = look.Saturation }):Play()
	end
	snow.Enabled = world.Theme == "Frostpeak"
end

function WorldAmbience.init()
	snowAnchor = Instance.new("Part")
	snowAnchor.Name = "WeatherAnchor"
	snowAnchor.Anchored = true
	snowAnchor.CanCollide = false
	snowAnchor.CanQuery = false
	snowAnchor.CanTouch = false
	snowAnchor.Transparency = 1
	snowAnchor.Size = Vector3.new(160, 1, 160)
	snowAnchor.Parent = Workspace
	snow = Instance.new("ParticleEmitter")
	snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	snow.Rate = 120
	snow.Lifetime = NumberRange.new(6, 9)
	snow.Speed = NumberRange.new(5, 9)
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.SpreadAngle = Vector2.new(20, 20)
	snow.Size = NumberSequence.new(0.35)
	snow.Color = ColorSequence.new(Color3.new(1, 1, 1))
	snow.LightEmission = 0.4
	snow.Enabled = false
	snow.Parent = snowAnchor

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		if camera then
			snowAnchor.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 45, 0))
		end
		elapsed += dt
		if elapsed < 0.5 then
			return
		end
		elapsed = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local world = WorldIndex:at(root.Position)
		if world ~= current then
			current = world
			apply(world)
		end
	end)
end

return WorldAmbience
