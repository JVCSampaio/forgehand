-- Builds every world from its theme (src/server/World/Themes) and answers
-- world-aware layout questions for the other services: floor height, item
-- obstacles, ring sampling. Deterministic per world seed, so every server
-- has identical maps.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage").Shared
local GameConfig = require(Shared.Config.GameConfig)
local WorldIndex = require(Shared.WorldIndex)
local Kit = require(script.Parent.Parent.World.Kit)
local Themes = script.Parent.Parent.World.Themes

local WorldService = {}

local kits: { [string]: any } = {}

function WorldService.kit(worldId: string)
	return kits[worldId]
end

-- Floor height at an absolute position (ring floors step up toward the bank).
function WorldService.groundTopAt(position: Vector3): number
	local world = WorldIndex:at(position)
	local r = WorldIndex:radius(world, position)
	for index, zone in world.Zones do
		if r < zone.OuterRadius then
			return Kit.ringTop(index, #world.Zones)
		end
	end
	return GameConfig.Layout.GroundY
end

-- Random absolute point in a ring of `world`, uniform by area.
function WorldService.randomPointInRing(random: Random, world, inner: number, outer: number): Vector3
	local angle = random:NextNumber(0, math.pi * 2)
	local r = math.sqrt(random:NextNumber(inner * inner, outer * outer))
	return world.Origin + Vector3.new(math.cos(angle) * r, GameConfig.Layout.GroundY, math.sin(angle) * r)
end

function WorldService.isNearObstacle(position: Vector3, padding: number): boolean
	local world = WorldIndex:at(position)
	local kit = kits[world.Id]
	if not kit then
		return false
	end
	for _, obstacle in kit.obstacles do
		local offset = position - obstacle.Position
		if offset.X * offset.X + offset.Z * offset.Z < (obstacle.Radius + padding) ^ 2 then
			return true
		end
	end
	return false
end

function WorldService.zoneAt(position: Vector3)
	return WorldIndex:zoneAt(position)
end

local function buildLighting()
	local look = WorldIndex.list[1].Lighting
	Lighting.ClockTime = look.ClockTime
	Lighting.Brightness = look.Brightness
	Lighting.Ambient = look.Ambient
	Lighting.OutdoorAmbient = look.OutdoorAmbient
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true

	-- Clients retint these per world (WorldAmbience); names are looked up there.
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = look.AtmosphereDensity
	atmosphere.Offset = 0.2
	atmosphere.Color = look.AtmosphereColor
	atmosphere.Decay = look.AtmosphereDecay
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1
	atmosphere.Parent = Lighting

	local correction = Instance.new("ColorCorrectionEffect")
	correction.Saturation = look.Saturation
	correction.TintColor = look.Tint
	correction.Contrast = 0.08
	correction.Brightness = 0.02
	correction.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 20
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.Parent = Lighting

	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.7
	clouds.Parent = Workspace.Terrain
end

function WorldService.init()
	buildLighting()
	local mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	for _, world in WorldIndex.list do
		local started = os.clock()
		local kit = Kit.new(world, mapFolder, Random.new(world.Seed))
		require(Themes[world.Theme]).build(kit)
		kits[world.Id] = kit
		local parts = 0
		for _, d in kit.folder:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
			end
		end
		print(string.format("[WorldService] %s: %d parts, %d obstacles (%.0f ms)", world.Id, parts, #kit.obstacles, (os.clock() - started) * 1000))
	end
	mapFolder.Parent = Workspace

	local items = Instance.new("Folder")
	items.Name = "Items"
	items.Parent = Workspace
end

return WorldService
