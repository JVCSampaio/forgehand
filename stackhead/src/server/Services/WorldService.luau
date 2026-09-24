-- Generates the whole map from code: ground rings, bank, spawns, boundary,
-- decorations and lighting. Deterministic from GameConfig.World.Seed so every
-- server looks the same, and new zones are a config change.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage").Shared
local GameConfig = require(Shared.Config.GameConfig)

local WorldService = {}

-- Circles items must not spawn inside: { Position: Vector3, Radius: number }
WorldService.Obstacles = {}

local mapFolder: Folder
local rng: Random

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	if not props.Parent then
		p.Parent = mapFolder
	end
	return p
end

local function wedge(props): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(w :: any)[key] = value
	end
	if not props.Parent then
		w.Parent = mapFolder
	end
	return w
end

local function disc(radius: number, topY: number, color: Color3, material: Enum.Material?, name: string?): Part
	local thickness = 1
	return part({
		Name = name or "Disc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(0, topY - thickness / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

local function addObstacle(position: Vector3, radius: number)
	table.insert(WorldService.Obstacles, { Position = position, Radius = radius })
end

-- Random point in a ring, uniform by area.
function WorldService.randomPointInRing(random: Random, inner: number, outer: number): Vector3
	local angle = random:NextNumber(0, math.pi * 2)
	local r = math.sqrt(random:NextNumber(inner * inner, outer * outer))
	return Vector3.new(math.cos(angle) * r, GameConfig.World.GroundY, math.sin(angle) * r)
end

local function pointInZone(zone, margin: number): Vector3
	return WorldService.randomPointInRing(rng, zone.InnerRadius + margin, zone.OuterRadius - margin)
end

local function facingCenter(position: Vector3): CFrame
	return CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
end

local function sign(position: Vector3, text: string, color: Color3)
	local cf = facingCenter(position)
	part({ Name = "SignPost", Size = Vector3.new(0.6, 7, 0.6), CFrame = cf * CFrame.new(0, 3.5, 0), Color = Color3.fromRGB(90, 70, 50) })
	local board = part({
		Name = "Sign",
		Size = Vector3.new(12, 3.2, 0.5),
		CFrame = cf * CFrame.new(0, 7.2, 0),
		Color = color,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = Color3.new(1, 1, 1)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(30, 30, 40)
		stroke.Parent = label
		label.Parent = gui
		gui.Parent = board
	end
	addObstacle(position, 2)
end

local function tree(position: Vector3, scale: number)
	part({
		Name = "Trunk",
		Size = Vector3.new(1.4, 6, 1.4) * scale,
		CFrame = CFrame.new(position + Vector3.new(0, 3 * scale, 0)),
		Color = Color3.fromRGB(110, 75, 45),
	})
	part({
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 7 * scale,
		CFrame = CFrame.new(position + Vector3.new(0, 7.5 * scale, 0)),
		Color = Color3.fromRGB(70, 160, 70):Lerp(Color3.fromRGB(120, 190, 60), rng:NextNumber()),
		CanCollide = false,
	})
	addObstacle(position, 2.5 * scale)
end

local function stall(position: Vector3)
	local cf = facingCenter(position)
	local awning = Color3.fromHSV(rng:NextNumber(), 0.6, 0.95)
	part({ Name = "Counter", Size = Vector3.new(8, 3, 3), CFrame = cf * CFrame.new(0, 1.5, 0), Color = Color3.fromRGB(180, 130, 80) })
	for _, x in { -3.7, 3.7 } do
		part({ Name = "Post", Size = Vector3.new(0.5, 7, 0.5), CFrame = cf * CFrame.new(x, 3.5, 1.2), Color = Color3.fromRGB(240, 240, 240) })
	end
	wedge({ Name = "Awning", Size = Vector3.new(9, 1.5, 4), CFrame = cf * CFrame.new(0, 7.5, 0.3) * CFrame.Angles(0, math.rad(180), 0), Color = awning })
	addObstacle(position, 5)
end

local function house(position: Vector3)
	local cf = facingCenter(position)
	local wall = Color3.fromHSV(rng:NextNumber(), 0.25, 0.95)
	local roof = Color3.fromHSV(rng:NextNumber(), 0.55, 0.65)
	part({ Name = "House", Size = Vector3.new(12, 9, 10), CFrame = cf * CFrame.new(0, 4.5, 0), Color = wall })
	wedge({ Name = "Roof", Size = Vector3.new(13, 4, 5.5), CFrame = cf * CFrame.new(0, 11, -2.75) * CFrame.Angles(0, math.rad(180), 0), Color = roof })
	wedge({ Name = "Roof", Size = Vector3.new(13, 4, 5.5), CFrame = cf * CFrame.new(0, 11, 2.75), Color = roof })
	part({ Name = "Door", Size = Vector3.new(2.5, 5, 0.3), CFrame = cf * CFrame.new(0, 2.5, -5.1), Color = Color3.fromRGB(120, 80, 50) })
	addObstacle(position, 8)
end

local function fence(position: Vector3)
	local cf = facingCenter(position) * CFrame.Angles(0, math.rad(90), 0)
	part({ Name = "Fence", Size = Vector3.new(10, 0.5, 0.3), CFrame = cf * CFrame.new(0, 2.2, 0), Color = Color3.fromRGB(240, 240, 235) })
	part({ Name = "Fence", Size = Vector3.new(10, 0.5, 0.3), CFrame = cf * CFrame.new(0, 1.2, 0), Color = Color3.fromRGB(240, 240, 235) })
	for _, x in { -4.8, 0, 4.8 } do
		part({ Name = "FencePost", Size = Vector3.new(0.5, 3, 0.5), CFrame = cf * CFrame.new(x, 1.5, 0), Color = Color3.fromRGB(230, 230, 225) })
	end
	addObstacle(position, 5.5)
end

local function barn(position: Vector3)
	local cf = facingCenter(position)
	local red = Color3.fromRGB(190, 45, 40)
	part({ Name = "Barn", Size = Vector3.new(22, 14, 18), CFrame = cf * CFrame.new(0, 7, 0), Color = red })
	wedge({ Name = "Roof", Size = Vector3.new(23, 7, 9.5), CFrame = cf * CFrame.new(0, 17.5, -4.75) * CFrame.Angles(0, math.rad(180), 0), Color = Color3.fromRGB(70, 60, 60) })
	wedge({ Name = "Roof", Size = Vector3.new(23, 7, 9.5), CFrame = cf * CFrame.new(0, 17.5, 4.75), Color = Color3.fromRGB(70, 60, 60) })
	part({ Name = "BarnDoor", Size = Vector3.new(8, 10, 0.4), CFrame = cf * CFrame.new(0, 5, -9.1), Color = Color3.fromRGB(245, 240, 230) })
	addObstacle(position, 15)
end

local function silo(position: Vector3)
	part({
		Name = "Silo",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(26, 9, 9),
		CFrame = CFrame.new(position + Vector3.new(0, 13, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(200, 205, 210),
		Material = Enum.Material.Metal,
	})
	part({ Name = "SiloTop", Shape = Enum.PartType.Ball, Size = Vector3.one * 9, CFrame = CFrame.new(position + Vector3.new(0, 26, 0)), Color = Color3.fromRGB(190, 60, 50) })
	addObstacle(position, 6)
end

local function cropRow(position: Vector3)
	local cf = facingCenter(position) * CFrame.Angles(0, math.rad(90), 0)
	part({ Name = "Crops", Size = Vector3.new(16, 1.2, 2), CFrame = cf * CFrame.new(0, 0.6, 0), Color = Color3.fromRGB(95, 150, 50), CanCollide = false })
	addObstacle(position, 3)
end

local function container(position: Vector3)
	local cf = facingCenter(position) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
	part({
		Name = "Container",
		Size = Vector3.new(8, 8, 18),
		CFrame = cf * CFrame.new(0, 4, 0),
		Color = Color3.fromHSV(rng:NextNumber(), 0.7, 0.8),
		Material = Enum.Material.CorrodedMetal,
	})
	addObstacle(position, 10)
end

local function crane(position: Vector3)
	local cf = facingCenter(position)
	local yellow = Color3.fromRGB(245, 190, 40)
	part({ Name = "Crane", Size = Vector3.new(3, 40, 3), CFrame = cf * CFrame.new(0, 20, 0), Color = yellow, Material = Enum.Material.Metal })
	part({ Name = "CraneArm", Size = Vector3.new(3, 3, 34), CFrame = cf * CFrame.new(0, 39, 10), Color = yellow, Material = Enum.Material.Metal })
	part({ Name = "CraneHook", Size = Vector3.new(0.4, 16, 0.4), CFrame = cf * CFrame.new(0, 30, 24), Color = Color3.fromRGB(40, 40, 40) })
	addObstacle(position, 3.5)
end

local function buildBank()
	local bank = GameConfig.Bank
	local center = bank.Position
	disc(bank.Radius, 0.6, Color3.fromRGB(255, 214, 90), Enum.Material.SmoothPlastic, "BankFloor")
	disc(bank.Radius - 1.5, 0.65, Color3.fromRGB(255, 236, 170), Enum.Material.SmoothPlastic, "BankInner")
	local ring = disc(bank.Radius + 0.6, 0.35, Color3.fromRGB(255, 170, 40), Enum.Material.Neon, "BankRing")
	ring.CanCollide = false

	part({
		Name = "BankPillar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(14, 4, 4),
		CFrame = CFrame.new(center + Vector3.new(0, 7.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(60, 60, 80),
	})
	local coin = part({
		Name = "BankCoin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 9, 9),
		CFrame = CFrame.new(center + Vector3.new(0, 20, 0)),
		Color = Color3.fromRGB(255, 200, 40),
		Material = Enum.Material.Foil,
		Reflectance = 0.2,
		CanCollide = false,
	})
	coin:SetAttribute("Spin", true)
	addObstacle(center, bank.Radius + 4)

	local gui = Instance.new("BillboardGui")
	gui.Name = "BankLabel"
	gui.Size = UDim2.fromOffset(260, 90)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 600
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "BANK"
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(255, 220, 80)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(60, 40, 10)
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = coin

	-- Spawn pads just outside the bank so new players see items immediately.
	for i = 1, bank.SpawnCount do
		local angle = (i / bank.SpawnCount) * math.pi * 2
		local position = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * bank.SpawnRadius
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Size = Vector3.new(6, 0.4, 6)
		spawn.CFrame = CFrame.lookAt(position + Vector3.new(0, 0.2, 0), position * 2 + Vector3.new(0, 0.2, 0))
		spawn.Color = Color3.fromRGB(255, 255, 255)
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.Transparency = 0.3
		spawn.TopSurface = Enum.SurfaceType.Smooth
		local decal = spawn:FindFirstChildOfClass("Decal")
		if decal then
			decal:Destroy()
		end
		spawn.Parent = mapFolder
	end
end

-- Board between two spawn pads; LeaderboardService fills in the text.
local function buildLeaderboardBoard()
	local bank = GameConfig.Bank
	local angle = math.pi * 2 * 2.5 / bank.SpawnCount
	local position = bank.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (bank.Radius + 16)
	part({
		Name = "Leaderboard",
		Size = Vector3.new(14, 16, 0.6),
		CFrame = CFrame.lookAt(position + Vector3.new(0, 9, 0), Vector3.new(bank.Position.X, 9, bank.Position.Z)),
		Color = Color3.fromRGB(40, 40, 60),
	})
	for _, x in { -6, 6 } do
		local legPosition = (CFrame.lookAt(position, bank.Position) * CFrame.new(x, 0.5, 0)).Position
		part({ Name = "LeaderboardLeg", Size = Vector3.new(0.8, 2, 0.8), CFrame = CFrame.new(legPosition), Color = Color3.fromRGB(40, 40, 60) })
	end
	addObstacle(position, 8)
end

local function buildBoundary()
	local world = GameConfig.World
	local segments = world.BoundarySegments
	local radius = world.BoundaryRadius
	local width = 2 * math.pi * radius / segments + 2
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local position = Vector3.new(math.cos(angle) * radius, 30, math.sin(angle) * radius)
		part({
			Name = "Boundary",
			Size = Vector3.new(width, 60, 2),
			CFrame = CFrame.lookAt(position, Vector3.new(0, 30, 0)),
			Transparency = 1,
			CanQuery = false,
		})
	end
	part({
		Name = "Ocean",
		Size = Vector3.new(world.OceanRadius * 2, 1, world.OceanRadius * 2),
		CFrame = CFrame.new(0, -1.2, 0),
		Color = Color3.fromRGB(60, 150, 215),
		Material = Enum.Material.Glass,
		Transparency = 0.1,
		CanCollide = false,
	})
end

local function buildZones()
	local zones = GameConfig.Zones
	-- Outer rings first; each inner disc sits slightly higher to avoid z-fighting.
	for index = #zones, 1, -1 do
		local zone = zones[index]
		local material = if zone.Id == "Docks" then Enum.Material.WoodPlanks else Enum.Material.SmoothPlastic
		disc(zone.OuterRadius, 0.05 + (#zones - index) * 0.02, zone.GroundColor, material, zone.Id .. "Ground")
	end
	-- Low kerb between rings so zone borders read clearly.
	for index = 2, #zones do
		local border = disc(zones[index].InnerRadius + 0.5, 0.02, Color3.fromRGB(245, 245, 240), Enum.Material.SmoothPlastic, "Border")
		border.CanCollide = false
	end

	for index, zone in zones do
		local label = string.upper(zone.DisplayName)
		local text = if zone.Tier > 1 then string.format("%s\n💪 Strength %d", label, zone.Tier) else label
		for _, angle in { 45, 135, 225, 315 } do
			local r = zone.InnerRadius + 3
			local rad = math.rad(angle + index * 10)
			sign(Vector3.new(math.cos(rad) * r, 0, math.sin(rad) * r), text, Color3.fromRGB(60, 60, 80):Lerp(zone.GroundColor, 0.35))
		end
	end

	local market, yard, farm, docks = zones[1], zones[2], zones[3], zones[4]
	for _ = 1, 12 do
		stall(pointInZone(market, 12))
	end
	for _ = 1, 9 do
		house(pointInZone(yard, 12))
	end
	for _ = 1, 10 do
		fence(pointInZone(yard, 8))
	end
	for _ = 1, 14 do
		tree(pointInZone(yard, 6), rng:NextNumber(0.9, 1.4))
	end
	barn(pointInZone(farm, 22))
	barn(pointInZone(farm, 22))
	silo(pointInZone(farm, 12))
	silo(pointInZone(farm, 12))
	for _ = 1, 14 do
		cropRow(pointInZone(farm, 10))
	end
	for _ = 1, 12 do
		tree(pointInZone(farm, 6), rng:NextNumber(1, 1.6))
	end
	for _ = 1, 8 do
		container(pointInZone(docks, 12))
	end
	for _ = 1, 4 do
		crane(pointInZone(docks, 8))
	end
end

local function buildLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(110, 100, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 145, 160)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(200, 220, 255)
	atmosphere.Decay = Color3.fromRGB(120, 150, 200)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1
	atmosphere.Parent = Lighting

	local correction = Instance.new("ColorCorrectionEffect")
	correction.Saturation = 0.18
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
end

function WorldService.init()
	rng = Random.new(GameConfig.World.Seed)
	mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	buildLighting()
	buildBoundary()
	buildZones()
	buildBank()
	buildLeaderboardBoard()
	mapFolder.Parent = Workspace

	local items = Instance.new("Folder")
	items.Name = "Items"
	items.Parent = Workspace
end

function WorldService.isNearObstacle(position: Vector3, padding: number): boolean
	for _, obstacle in WorldService.Obstacles do
		local offset = position - obstacle.Position
		if Vector2.new(offset.X, offset.Z).Magnitude < obstacle.Radius + padding then
			return true
		end
	end
	return false
end

function WorldService.zoneAt(position: Vector3)
	local r = Vector2.new(position.X, position.Z).Magnitude
	for _, zone in GameConfig.Zones do
		if r >= zone.InnerRadius and r < zone.OuterRadius then
			return zone
		end
	end
	return nil
end

return WorldService
