-- Builds item models from ItemConfig primitives. Used by the server for
-- world pickups and by clients for stack visuals, so items look identical.

local ItemConfig = require(script.Parent.Config.ItemConfig)
local StackCodec = require(script.Parent.StackCodec)

local ItemBuilder = {}

local GOLD = Color3.fromRGB(255, 196, 40)

local function toVector(t, default: Vector3): Vector3
	if not t then
		return default
	end
	return Vector3.new(t[1], t[2], t[3])
end

-- Big outlined label on both faces of a flat Block (meme signs).
local function addText(part: BasePart, spec)
	local color = spec.TextColor or { 255, 255, 255 }
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Label" .. face.Name
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = spec.Text
		label.TextColor3 = Color3.fromRGB(color[1], color[2], color[3])
		label.TextStrokeColor3 = Color3.fromRGB(30, 30, 40)
		label.TextStrokeTransparency = 0
		label.Parent = gui
		gui.Parent = part
	end
end

local function makePart(spec, rarity: string): BasePart
	local part: BasePart
	local size = toVector(spec.Size, Vector3.one)
	local rotation = CFrame.identity
	if spec.Shape == "Wedge" then
		part = Instance.new("WedgePart")
	else
		local basic = Instance.new("Part")
		if spec.Shape == "Ball" then
			basic.Shape = Enum.PartType.Ball
		elseif spec.Shape == "VCylinder" then
			basic.Shape = Enum.PartType.Cylinder
			-- Cylinders run along X; stand it up.
			size = Vector3.new(size.Y, size.X, size.Z)
			rotation = CFrame.Angles(0, 0, math.rad(90))
		elseif spec.Shape == "HCylinder" then
			basic.Shape = Enum.PartType.Cylinder
		end
		part = basic
	end
	part.Size = size
	part.Color = Color3.fromRGB(spec.Color[1], spec.Color[2], spec.Color[3])
	part.Material = (Enum.Material :: any)[spec.Material or "SmoothPlastic"]
	part.Transparency = spec.Transparency or 0

	if rarity == "g" then
		part.Color = GOLD:Lerp(part.Color, 0.15)
		part.Material = Enum.Material.Foil
		part.Reflectance = 0.25
	elseif rarity == "s" then
		part.Color = part.Color:Lerp(Color3.new(1, 1, 1), 0.35)
		part.Material = Enum.Material.Glass
		part.Reflectance = 0.15
	end

	local rot = spec.Rot or { 0, 0, 0 }
	local extra = CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
	part:SetAttribute("Offset", CFrame.new(toVector(spec.Offset, Vector3.zero)) * extra * rotation)

	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if spec.Text then
		addText(part, spec)
	end
	return part
end

local function addRarityFx(root: BasePart, rarity: string)
	if rarity == "" then
		return
	end
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "Sparkle"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = if rarity == "g" then 6 else 3
	sparkle.Lifetime = NumberRange.new(0.6, 1.1)
	sparkle.Speed = NumberRange.new(0.5, 1.5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new(0.35, 0)
	sparkle.LightEmission = 0.8
	sparkle.Color = ColorSequence.new(if rarity == "g" then GOLD else Color3.fromRGB(170, 230, 255))
	sparkle.Parent = root
end

-- Builds a Model from primitive part specs (see ItemConfig). Parts carry an
-- "Offset" attribute relative to the model centre; PrimaryPart = first part.
function ItemBuilder.buildParts(specs, name: string, rarity: string?): Model
	local model = Instance.new("Model")
	model.Name = name
	for index, spec in specs do
		local part = makePart(spec, rarity or "")
		part.Name = if index == 1 then "Root" else "Part" .. index
		part.Parent = model
		if index == 1 then
			model.PrimaryPart = part
		end
	end
	return model
end

function ItemBuilder.build(code: string): Model?
	local itemId, rarity = StackCodec.parse(code)
	local def = ItemConfig.ById[itemId]
	if not def then
		return nil
	end
	local model = ItemBuilder.buildParts(def.Parts, def.Name, rarity)
	addRarityFx(model.PrimaryPart :: BasePart, rarity)
	model:SetAttribute("Code", code)
	return model
end

-- Places every part of a built model around `center`.
function ItemBuilder.pivot(model: Model, center: CFrame)
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			local offset = child:GetAttribute("Offset")
			child.CFrame = center * (offset or CFrame.identity)
		end
	end
end

function ItemBuilder.definition(code: string)
	local itemId = StackCodec.parse(code)
	return ItemConfig.ById[itemId]
end

return ItemBuilder
