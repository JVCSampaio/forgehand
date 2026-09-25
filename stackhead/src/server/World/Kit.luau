-- World-building kit shared by every theme. Themes describe *what* to place in
-- local coordinates (relative to the world centre, Y = absolute height); the
-- kit handles origin offsets, the item-free obstacle map, ring floors, radial
-- streets, the bank, signs and water.

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage").Shared
local GameConfig = require(Shared.Config.GameConfig)

local Kit = {}
Kit.__index = Kit

local LAYOUT = GameConfig.Layout
local ROAD_ANGLES = { 0, 90, 180, 270 }

export type Obstacle = { Position: Vector3, Radius: number }

function Kit.new(world, parent: Instance, rng: Random)
	local folder = Instance.new("Folder")
	folder.Name = world.Id
	folder.Parent = parent
	return setmetatable({
		world = world,
		zones = world.Zones,
		origin = world.Origin,
		originCF = CFrame.new(world.Origin),
		folder = folder,
		rng = rng,
		obstacles = {} :: { Obstacle },
		roadAngles = ROAD_ANGLES,
		roadHalfWidth = LAYOUT.RoadWidth / 2,
	}, Kit)
end

-- Ring floors are stacked discs, outer ones lowest, 0.1 studs apart.
function Kit.ringTop(index: number, zoneCount: number): number
	return LAYOUT.GroundY + 0.1 * (zoneCount - index + 1)
end

function Kit:top(index: number): number
	return Kit.ringTop(index, #self.zones)
end

-- Floor height at a local horizontal radius.
function Kit:floorAt(r: number): number
	for index, zone in self.zones do
		if r < zone.OuterRadius then
			return self:top(index)
		end
	end
	return LAYOUT.GroundY
end

---------------------------------------------------------------------------
-- Primitive placement (local CFrames)
---------------------------------------------------------------------------

local function apply(instance: BasePart, props, originCF: CFrame)
	for key, value in props do
		if key == "CFrame" then
			instance.CFrame = originCF * value
		elseif key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
end

function Kit:part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	apply(p, props, self.originCF)
	p.Parent = props.Parent or self.folder
	return p
end

function Kit:wedge(props): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Material = Enum.Material.SmoothPlastic
	apply(w, props, self.originCF)
	w.Parent = props.Parent or self.folder
	return w
end

function Kit:block(cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?, extra: { [string]: any }?): Part
	local props = { CFrame = cf, Size = size, Color = color, Material = material or Enum.Material.SmoothPlastic }
	if extra then
		for k, v in extra do
			props[k] = v
		end
	end
	return self:part(props)
end

function Kit:ball(
	position: Vector3,
	diameter: number,
	color: Color3,
	material: Enum.Material?,
	extra: { [string]: any }?
): Part
	local props = {
		Shape = Enum.PartType.Ball,
		CFrame = CFrame.new(position),
		Size = Vector3.one * diameter,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	}
	if extra then
		for k, v in extra do
			props[k] = v
		end
	end
	return self:part(props)
end

-- Upright cylinder whose base sits at `base`.
function Kit:column(
	base: Vector3,
	height: number,
	diameter: number,
	color: Color3,
	material: Enum.Material?,
	extra: { [string]: any }?
): Part
	local props = {
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Size = Vector3.new(height, diameter, diameter),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	}
	if extra then
		for k, v in extra do
			props[k] = v
		end
	end
	return self:part(props)
end

-- Cylinder along an arbitrary CFrame's X axis.
function Kit:cylinder(cf: CFrame, length: number, diameter: number, color: Color3, material: Enum.Material?): Part
	return self:part({
		Shape = Enum.PartType.Cylinder,
		CFrame = cf,
		Size = Vector3.new(length, diameter, diameter),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

function Kit:disc(
	radius: number,
	topY: number,
	color: Color3,
	material: Enum.Material?,
	name: string?,
	thickness: number?
): Part
	local t = thickness or 1
	return self:part({
		Name = name or "Disc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(t, radius * 2, radius * 2),
		CFrame = CFrame.new(0, topY - t / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

---------------------------------------------------------------------------
-- Layout helpers
---------------------------------------------------------------------------

function Kit:obstacle(localPosition: Vector3, radius: number)
	table.insert(self.obstacles, { Position = self.origin + localPosition, Radius = radius })
end

function Kit.polar(angleDegrees: number, r: number, y: number?): Vector3
	local a = math.rad(angleDegrees)
	return Vector3.new(math.cos(a) * r, y or 0, math.sin(a) * r)
end

-- CFrame at a local position, facing the world centre.
function Kit.facingCenter(position: Vector3): CFrame
	local flat = Vector3.new(0, position.Y, 0)
	if (flat - position).Magnitude < 0.01 then
		return CFrame.new(position)
	end
	return CFrame.lookAt(position, flat)
end

-- Along a road at `angle`, `r` from the centre, `side` studs to its right.
-- The returned CFrame faces the road centreline.
function Kit:roadside(angle: number, r: number, side: number, y: number?): CFrame
	local a = math.rad(angle)
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local right = Vector3.new(-dir.Z, 0, dir.X)
	local position = dir * r + right * side + Vector3.new(0, y or 0, 0)
	local target = dir * r + Vector3.new(0, y or 0, 0)
	return CFrame.lookAt(position, target)
end

function Kit:onRoad(localPosition: Vector3, padding: number): boolean
	local r = Vector2.new(localPosition.X, localPosition.Z).Magnitude
	if r < GameConfig.Bank.Radius then
		return false
	end
	local angle = math.deg(math.atan2(localPosition.Z, localPosition.X))
	for _, roadAngle in self.roadAngles do
		local delta = math.rad(((angle - roadAngle + 180) % 360) - 180)
		local lateral = math.abs(math.sin(delta)) * r
		if math.cos(delta) > 0 and lateral < self.roadHalfWidth + padding then
			return true
		end
	end
	return false
end

function Kit:isFree(localPosition: Vector3, radius: number): boolean
	if self:onRoad(localPosition, radius) then
		return false
	end
	local absolute = self.origin + localPosition
	for _, obstacle in self.obstacles do
		local offset = absolute - obstacle.Position
		if Vector2.new(offset.X, offset.Z).Magnitude < obstacle.Radius + radius then
			return false
		end
	end
	return true
end

-- Random free spot in a ring (uniform by area), or nil after `tries`.
function Kit:spot(inner: number, outer: number, radius: number, tries: number?): Vector3?
	for _ = 1, tries or 30 do
		local angle = self.rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(self.rng:NextNumber((inner + radius) ^ 2, (outer - radius) ^ 2))
		local point = Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
		if self:isFree(point, radius) then
			return point
		end
	end
	return nil
end

-- Calls fn(spot) for up to `count` free spots in zone `index`.
function Kit:scatter(index: number, count: number, radius: number, fn: (Vector3) -> ())
	local zone = self.zones[index]
	for _ = 1, count do
		local point = self:spot(zone.InnerRadius, zone.OuterRadius, radius)
		if point then
			fn(point + Vector3.new(0, self:top(index), 0))
			self:obstacle(point, radius)
		end
	end
end

---------------------------------------------------------------------------
-- Shared world features
---------------------------------------------------------------------------

function Kit:floors()
	local zones = self.zones
	for index = #zones, 1, -1 do
		local zone = zones[index]
		self:disc(
			zone.OuterRadius,
			self:top(index),
			zone.GroundColor,
			(Enum.Material :: any)[zone.Material],
			zone.Id .. "Ground"
		)
	end
	for index = 2, #zones do
		local border = self:disc(
			zones[index].InnerRadius + 0.7,
			self:top(index) + 0.05,
			Color3.new(1, 1, 1):Lerp(zones[index - 1].GroundColor, 0.25),
			Enum.Material.SmoothPlastic,
			"Border"
		)
		border.CanCollide = false
	end
end

-- Four radial streets from the bank to the shore, one segment per ring so
-- each sits just above its own floor.
function Kit:roads(surface: Color3, line: Color3?, material: Enum.Material?, edge: Color3?)
	local width = GameConfig.Layout.RoadWidth
	for _, angle in self.roadAngles do
		local a = math.rad(angle)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local rot = CFrame.lookAt(Vector3.zero, dir)
		for index, zone in self.zones do
			local inner = if index == 1 then GameConfig.Bank.Radius + 0.5 else zone.InnerRadius
			local outer = zone.OuterRadius
			local length = outer - inner
			local mid = dir * ((inner + outer) / 2)
			local y = self:top(index) + 0.12
			self:block(
				CFrame.new(mid + Vector3.new(0, y - 0.1, 0)) * rot,
				Vector3.new(width, 0.2, length),
				surface,
				material,
				{ Name = "Road", CanQuery = false }
			)
			if edge then
				for _, side in { -1, 1 } do
					local offset = Vector3.new(-dir.Z, 0, dir.X) * side * (width / 2 + 0.3)
					self:block(
						CFrame.new(mid + offset + Vector3.new(0, y - 0.05, 0)) * rot,
						Vector3.new(0.6, 0.3, length),
						edge,
						if edge.R + edge.G + edge.B > 2.2 then Enum.Material.SmoothPlastic else Enum.Material.Neon,
						{ Name = "Kerb", CanQuery = false }
					)
				end
			end
			if line then
				local dashes = math.floor(length / 8)
				for d = 0, dashes - 1 do
					local r = inner + 4 + d * 8
					if r < outer - 2 then
						self:block(
							CFrame.new(dir * r + Vector3.new(0, y + 0.02, 0)) * rot,
							Vector3.new(0.5, 0.06, 3.5),
							line,
							Enum.Material.SmoothPlastic,
							{ Name = "RoadLine", CanQuery = false, CanCollide = false }
						)
					end
				end
			end
		end
	end
end

function Kit:sign(localCF: CFrame, text: string, color: Color3, postColor: Color3?)
	self:block(localCF * CFrame.new(0, 3.5, 0), Vector3.new(0.5, 7, 0.5), postColor or Color3.fromRGB(80, 64, 50))
	local board = self:block(localCF * CFrame.new(0, 7.4, 0), Vector3.new(8, 2.6, 0.5), color, nil, { Name = "Sign" })
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
end

-- A sign at every road's entrance to every zone, on the walker's right.
function Kit:zoneSigns(color: (any) -> Color3, postColor: Color3?)
	for index, zone in self.zones do
		local text = string.upper(zone.DisplayName)
		if index > 1 or self.world.Index > 1 then
			text ..= string.format("\n💪 Strength %d", zone.Tier)
		end
		for _, angle in self.roadAngles do
			local r = zone.InnerRadius + 5
			local cf = self:roadside(angle, r, self.roadHalfWidth + 3.5, self:top(index))
			-- Face walkers coming out from the bank.
			local a = math.rad(angle)
			local position = cf.Position
			local signCF = CFrame.lookAt(position, position - Vector3.new(math.cos(a), 0, math.sin(a)))
			self:sign(signCF, text, color(zone), postColor)
			self:obstacle(position, 2)
		end
	end
end

function Kit:bank(options)
	local bank = GameConfig.Bank
	local colors = self.world.Bank
	local floor = self:disc(bank.Radius, 0.6, colors.Floor, Enum.Material.SmoothPlastic, "BankFloor")
	floor:SetAttribute("Bank", self.world.Id)
	self:disc(bank.Radius - 1.5, 0.65, colors.Inner, Enum.Material.SmoothPlastic, "BankInner")
	local ring = self:disc(bank.Radius + 0.6, 0.5, colors.Glow, Enum.Material.Neon, "BankRing")
	ring.CanCollide = false

	-- Pillar with a glowing band, plus the spinning coin on top.
	self:column(Vector3.new(0, 0.6, 0), 1.2, 7, colors.Floor)
	self:column(Vector3.new(0, 1.8, 0), 11.5, 4, colors.Inner)
	self:column(Vector3.new(0, 9, 0), 0.8, 4.4, colors.Glow, Enum.Material.Neon)
	self:column(Vector3.new(0, 13.3, 0), 0.8, 5.5, colors.Floor)
	local coin = self:part({
		Name = "BankCoin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 9, 9),
		CFrame = CFrame.new(0, 20, 0),
		Color = Color3.fromRGB(255, 200, 40),
		Material = Enum.Material.Foil,
		Reflectance = 0.2,
		CanCollide = false,
	})
	CollectionService:AddTag(coin, "Spin")
	self:obstacle(Vector3.zero, bank.Radius + 4)

	local gui = Instance.new("BillboardGui")
	gui.Name = "BankLabel"
	gui.Size = UDim2.fromOffset(140, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
	gui.MaxDistance = 260
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

	-- Spawn pads just outside the bank so players see items immediately.
	-- Only the first world uses real SpawnLocations; travel and respawns in
	-- other worlds are placed by the server on these pads.
	for i = 1, bank.SpawnCount do
		local angle = (i - 0.5) / bank.SpawnCount * 360
		local position = Kit.polar(angle, bank.SpawnRadius, self:top(1) + 0.2)
		local cf = CFrame.lookAt(position, position * Vector3.new(2, 1, 2))
		local pad: BasePart
		if options and options.SpawnLocations then
			local spawn = Instance.new("SpawnLocation")
			spawn.Neutral = true
			spawn.Duration = 0
			pad = spawn
		else
			pad = Instance.new("Part")
		end
		pad.Name = "SpawnPad"
		pad.Anchored = true
		pad.Size = Vector3.new(6, 0.4, 6)
		pad.CFrame = self.originCF * cf
		pad.Color = colors.Inner
		pad.Material = Enum.Material.SmoothPlastic
		pad.Transparency = 0.2
		pad.TopSurface = Enum.SurfaceType.Smooth
		local decal = pad:FindFirstChildOfClass("Decal")
		if decal then
			decal:Destroy()
		end
		CollectionService:AddTag(pad, "SpawnPad")
		pad:SetAttribute("World", self.world.Id)
		pad.Parent = self.folder
	end
end

function Kit:boundary(waterMaterial: Enum.Material?, waterTransparency: number?)
	local segments = LAYOUT.BoundarySegments
	local radius = LAYOUT.BoundaryRadius
	local width = 2 * math.pi * radius / segments + 2
	for i = 1, segments do
		local angle = (i / segments) * 360
		local position = Kit.polar(angle, radius, 30)
		self:part({
			Name = "Boundary",
			Size = Vector3.new(width, 60, 2),
			CFrame = CFrame.lookAt(position, Vector3.new(0, 30, 0)),
			Transparency = 1,
			CanQuery = false,
		})
	end
	self:part({
		Name = "Water",
		Size = Vector3.new(LAYOUT.OceanRadius * 2, 1, LAYOUT.OceanRadius * 2),
		CFrame = CFrame.new(0, -1.2, 0),
		Color = self.world.Water,
		Material = waterMaterial or Enum.Material.Glass,
		Transparency = waterTransparency or 0.1,
		CanCollide = false,
		CanQuery = false,
	})
end

-- Wooden (or themed) posts standing in the water around the island edge.
function Kit:pilings(spacing: number, color: Color3, material: Enum.Material?)
	local r = self.zones[#self.zones].OuterRadius - 0.6
	local count = math.floor(2 * math.pi * r / spacing)
	for i = 1, count do
		local angle = i / count * 360
		self:column(Kit.polar(angle, r, -3), 3.6, 1.1, color, material or Enum.Material.Wood)
	end
end

return Kit
