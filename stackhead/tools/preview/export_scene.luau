-- Runs the game's real world-generation code (WorldService, ItemSpawnService,
-- ItemBuilder) from the built place inside Lune's Roblox DOM, then exports
-- every part as JSON for the WebGL preview. Engine-only APIs the generators
-- touch (Random, task, spatial queries) are shimmed; nothing in src/ changes.
--   lune run tools/preview/export_scene.luau build/Stackhead.rbxl build/preview/scene.json

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local placePath = process.args[1] or "build/Stackhead.rbxl"
local outPath = process.args[2] or "build/preview/scene.json"
local game = roblox.deserializePlace(fs.readFile(placePath))
local Workspace = game:GetService("Workspace")

-- Random: xorshift-based stand-in with the same API surface used by the game.
local Random = {}
Random.__index = Random
function Random.new(seed)
	local state = math.floor(seed or os.time()) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return setmetatable({ state = state }, Random)
end
function Random:NextNumber(min, max)
	self.state = (self.state * 48271) % 2147483647
	local u = self.state / 2147483647
	min = min or 0
	max = max or 1
	return min + (max - min) * u
end
function Random:NextInteger(min, max)
	return math.floor(self:NextNumber(min, max + 1))
end

local OverlapParams = {
	new = function()
		return { FilterDescendantsInstances = {}, FilterType = nil }
	end,
}

-- Derived properties the engine computes but Lune's DOM does not.
for _, className in { "Part", "WedgePart", "SpawnLocation" } do
	roblox.implementProperty(className, "Position", function(self)
		return self.CFrame.Position
	end, function(self, value)
		self.CFrame = self.CFrame - self.CFrame.Position + value
	end)
end

local serverTime = 1000
roblox.implementMethod("Workspace", "GetServerTimeNow", function()
	return serverTime
end)
roblox.implementMethod("Instance", "WaitForChild", function(self, name)
	local child = self:FindFirstChild(name)
	assert(child, "WaitForChild would hang: " .. name)
	return child
end)
-- Naive sphere-vs-root-part query over the filter folders (items only).
roblox.implementMethod("Workspace", "GetPartBoundsInRadius", function(_, position, radius, params)
	local hits = {}
	for _, root in (params and params.FilterDescendantsInstances) or {} do
		for _, part in root:GetDescendants() do
			if part:IsA("BasePart") and part.CanQuery then
				local half = part.Size.Magnitude / 2
				if (part.CFrame.Position - position).Magnitude <= radius + half then
					table.insert(hits, part)
				end
			end
		end
	end
	return hits
end)

-- CollectionService: Lune's DOM routes AddTag to Instance.AddTag, so scripts
-- get a stand-in service through a proxied `game`.
local tagged: { [string]: { any } } = {}
local collectionService = {
	AddTag = function(_, instance, tag)
		tagged[tag] = tagged[tag] or {}
		table.insert(tagged[tag], instance)
	end,
	GetTagged = function(_, tag)
		return tagged[tag] or {}
	end,
}
local gameProxy = setmetatable({
	GetService = function(_, name)
		if name == "CollectionService" then
			return collectionService
		end
		return game:GetService(name)
	end,
}, {
	__index = function(_, key)
		return game[key]
	end,
})
if not Workspace:FindFirstChild("Terrain") then
	local terrain = roblox.Instance.new("Terrain")
	terrain.Parent = Workspace
end
roblox.implementProperty("Workspace", "Terrain", function(self)
	return self:FindFirstChild("Terrain")
end)

local taskShim = {
	spawn = function() end, -- background loops are not needed for a still frame
	delay = function() end,
	wait = function()
		return 0
	end,
}

local cache = {}
local function makeEnv(scriptInstance)
	local env = {
		game = gameProxy,
		workspace = Workspace,
		script = scriptInstance,
		Instance = roblox.Instance,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
		NumberRange = roblox.NumberRange,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		Random = Random,
		OverlapParams = OverlapParams,
		task = taskShim,
		typeof = typeof,
		math = math,
		string = string,
		table = table,
		print = print,
		warn = print,
		error = error,
		assert = assert,
		pairs = pairs,
		ipairs = ipairs,
		next = next,
		select = select,
		type = type,
		tostring = tostring,
		tonumber = tonumber,
		setmetatable = setmetatable,
		getmetatable = getmetatable,
		pcall = pcall,
		os = os,
	}
	env.require = function(module)
		if cache[module] == nil then
			local chunk = luau.load(module.Source, { debugName = module:GetFullName(), environment = makeEnv(module) })
			cache[module] = chunk()
		end
		return cache[module]
	end
	return env
end

local host = makeEnv(nil)
local Services = game:GetService("ServerScriptService").Server.Services
local Shared = game:GetService("ReplicatedStorage").Shared

host.require(Services.WorldService).init()
local ItemSpawnService = host.require(Services.ItemSpawnService)
ItemSpawnService.init()
local ItemBuilder = host.require(Shared.ItemBuilder)
local ItemConfig = host.require(Shared.Config.ItemConfig)

-- Staged "players" for the screenshots: blocky avatar + a stack built with the
-- same ItemBuilder and the same bend maths as the client StackRenderer.
local actors = roblox.Instance.new("Folder")
actors.Name = "Actors"
actors.Parent = Workspace

local function avatar(name, position, yaw, colors)
	local model = roblox.Instance.new("Model")
	model.Name = name
	local base = roblox.CFrame.new(position) * roblox.CFrame.Angles(0, math.rad(yaw), 0)
	local function limb(partName, size, offset, color)
		local p = roblox.Instance.new("Part")
		p.Name = partName
		p.Size = size
		p.CFrame = base * roblox.CFrame.new(offset)
		p.Color = color
		p.Material = roblox.Enum.Material.SmoothPlastic
		p.Parent = model
		return p
	end
	limb("LeftLeg", roblox.Vector3.new(1, 2, 1), roblox.Vector3.new(-0.5, 1, 0), colors.legs)
	limb("RightLeg", roblox.Vector3.new(1, 2, 1), roblox.Vector3.new(0.5, 1, 0), colors.legs)
	limb("Torso", roblox.Vector3.new(2, 2, 1), roblox.Vector3.new(0, 3, 0), colors.torso)
	limb("LeftArm", roblox.Vector3.new(1, 2, 1), roblox.Vector3.new(-1.5, 3, 0), colors.skin)
	limb("RightArm", roblox.Vector3.new(1, 2, 1), roblox.Vector3.new(1.5, 3, 0), colors.skin)
	local head = limb("Head", roblox.Vector3.new(1.2, 1.2, 1.2), roblox.Vector3.new(0, 4.6, 0), colors.skin)
	head:SetAttribute("Head", true)
	model.Parent = actors
	return base, head
end

local function stackOn(headPart, codes, lean)
	local folder = roblox.Instance.new("Folder")
	folder.Name = "Stack"
	folder.Parent = actors
	local total = 0
	for _, code in codes do
		total += ItemBuilder.definition(code).Height
	end
	local perStud = lean / math.max(total, 12)
	local tilt = roblox.CFrame.new(headPart.CFrame.Position + roblox.Vector3.new(0, headPart.Size.Y / 2 + 0.1, 0))
	for index, code in codes do
		local model = ItemBuilder.build(code)
		local h = ItemBuilder.definition(code).Height
		tilt = tilt * roblox.CFrame.Angles(perStud.Y * h, 0, -perStud.X * h)
		local yaw = roblox.CFrame.Angles(0, math.rad(((index * 137) % 60) - 30), 0)
		ItemBuilder.pivot(model, (tilt * roblox.CFrame.new(0, h / 2, 0)) * yaw)
		tilt = tilt * roblox.CFrame.new(0, h, 0)
		model.Parent = folder
	end
	return tilt.Position, #codes
end

local function randomStack(tiers, count, seed)
	local rng = Random.new(seed)
	local codes = {}
	for i = 1, count do
		local pool = ItemConfig.ByTier[tiers[rng:NextInteger(1, #tiers)]]
		local def = pool[rng:NextInteger(1, #pool)]
		local roll = rng:NextNumber()
		local suffix = if roll < 0.03 then "g" elseif roll < 0.09 then "s" else ""
		codes[i] = def.Id .. suffix
	end
	return codes
end

local noob = { skin = roblox.Color3.fromRGB(245, 205, 48), torso = roblox.Color3.fromRGB(13, 105, 172), legs = roblox.Color3.fromRGB(40, 127, 71) }
local red = { skin = roblox.Color3.fromRGB(234, 184, 146), torso = roblox.Color3.fromRGB(196, 40, 28), legs = roblox.Color3.fromRGB(27, 42, 53) }
local purple = { skin = roblox.Color3.fromRGB(160, 95, 53), torso = roblox.Color3.fromRGB(107, 50, 124), legs = roblox.Color3.fromRGB(99, 95, 98) }
local white = { skin = roblox.Color3.fromRGB(255, 204, 153), torso = roblox.Color3.fromRGB(242, 243, 243), legs = roblox.Color3.fromRGB(52, 88, 150) }

local labels = {}
local function actor(name, position, yaw, colors, codes, lean)
	local _, head = avatar(name, position, yaw, colors)
	if codes and #codes > 0 then
		local top, count = stackOn(head, codes, lean or roblox.Vector2.zero)
		table.insert(labels, { text = tostring(count), x = top.X, y = top.Y + 2.2, z = top.Z, color = if name == "Hero" then "#ffdc50" else "#ffffff" })
	end
end

-- The same little scene in every world, using that world's item tiers:
-- a hero walking back to the bank, a leaning tower, a bumper, a banker and
-- a fresh collapse.
local WorldIndex = host.require(Shared.WorldIndex)
for _, world in WorldIndex.list do
	local o = world.Origin
	local t = world.FirstTier
	local function at(x, y, z)
		return o + roblox.Vector3.new(x, y, z)
	end
	actor("Hero", at(0, 0.4, 44), 0, noob, randomStack({ t }, 28, 7 + t), roblox.Vector2.new(0.05, 0.22))
	actor("Tower", at(-26, 0.3, 104), 150, purple, randomStack({ t, t + 1 }, 85, 11 + t), roblox.Vector2.new(-0.55, 0.35))
	actor("Bumper", at(-18, 0.3, 96), 120, red, randomStack({ t }, 4, 3 + t), roblox.Vector2.zero)
	actor("Banker", at(6, 0.61, -4), 30, white, randomStack({ t, t + 1 }, 16, 21 + t), roblox.Vector2.new(0.1, 0))
	local collapseAt = at(34, 0.4, 30)
	actor("Crashed", collapseAt, 220, red, randomStack({ t }, 9, 5 + t), roblox.Vector2.zero)
	for i, code in randomStack({ t }, 14, 9 + t) do
		local angle = i * 2.39
		local dist = 4 + (i % 5) * 2.2
		local model = ItemBuilder.build(code)
		local h = ItemBuilder.definition(code).Height
		ItemBuilder.pivot(
			model,
			roblox.CFrame.new(collapseAt + roblox.Vector3.new(math.cos(angle) * dist, h / 2 + 0.1, math.sin(angle) * dist))
				* roblox.CFrame.Angles(0.4 * (i % 3), angle, 0.3 * (i % 2))
		)
		model.Parent = actors
	end
end

-- Export.
local parts = {}
local texts = {}
local function round(n)
	return math.floor(n * 1000 + 0.5) / 1000
end
for _, inst in Workspace:GetDescendants() do
	if inst:IsA("BasePart") and inst.ClassName ~= "Terrain" and inst.Transparency < 1 then
		local cf = inst.CFrame
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
		table.insert(parts, {
			c = inst.ClassName,
			n = inst.Name,
			s = if inst:IsA("Part") then inst.Shape.Name else "Block",
			z = { round(inst.Size.X), round(inst.Size.Y), round(inst.Size.Z) },
			m = { round(x), round(y), round(z), round(r00), round(r01), round(r02), round(r10), round(r11), round(r12), round(r20), round(r21), round(r22) },
			k = { math.floor(inst.Color.R * 255 + 0.5), math.floor(inst.Color.G * 255 + 0.5), math.floor(inst.Color.B * 255 + 0.5) },
			t = round(inst.Transparency),
			r = round(inst.Reflectance),
			mat = inst.Material.Name,
			sparkle = inst:FindFirstChildOfClass("ParticleEmitter") ~= nil,
		})
		for _, gui in inst:GetChildren() do
			if gui:IsA("SurfaceGui") or gui:IsA("BillboardGui") then
				local lines = {}
				for _, label in gui:GetDescendants() do
					if label:IsA("TextLabel") then
						table.insert(lines, label.Text)
					end
				end
				table.insert(texts, {
					kind = gui.ClassName,
					face = if gui:IsA("SurfaceGui") then gui.Face.Name else nil,
					part = #parts,
					lines = lines,
				})
			end
		end
	end
end

local lighting = game:GetService("Lighting")
fs.writeDir(string.match(outPath, "^(.*)/[^/]+$") or ".")
fs.writeFile(
	outPath,
	require("@lune/serde").encode("json", {
		parts = parts,
		texts = texts,
		labels = labels,
		clockTime = lighting.ClockTime,
		ambient = { lighting.Ambient.R, lighting.Ambient.G, lighting.Ambient.B },
	})
)
print(string.format("exported %d parts, %d gui surfaces, %d stack labels -> %s", #parts, #texts, #labels, outPath))
