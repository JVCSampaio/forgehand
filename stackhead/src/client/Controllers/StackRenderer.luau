-- Renders every player's stack locally from the replicated "Stack" attribute.
-- Nothing here is physical or replicated: items are anchored, non-colliding
-- and moved in one BulkMoveTo per frame. The lean is a cosmetic spring driven
-- by the character's acceleration plus the server's wobble value, so what the
-- player sees matches the danger the server is simulating.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage").Shared
local GameConfig = require(Shared.Config.GameConfig)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)
local ItemBuilder = require(Shared.ItemBuilder)
local StackCodec = require(Shared.StackCodec)

local StackRenderer = {}

type RenderItem = { Code: string, Model: Model, Parts: { BasePart }, Offsets: { CFrame }, Height: number, Yaw: CFrame }
type Render = {
	Player: Player,
	Folder: Folder,
	Items: { RenderItem },
	Count: number,
	Lean: Vector2,
	LeanVel: Vector2,
	LastVel: Vector3,
	Label: BillboardGui,
	LabelText: TextLabel,
	Anchor: Part,
	Visible: boolean,
	LastTop: CFrame?,
	Base: RenderItem?,
	Proxies: { RenderItem },
}

local localPlayer = Players.LocalPlayer
local renders: { [Player]: Render } = {}
local rootFolder: Folder
local removedCallbacks = {}

local SPRING = 38
local DAMPING = 7
local ACCEL_GAIN = 0.0016
local MAX_LEAN = 0.9

-- Removed entries are top first; a proxy entry stands for Count items.
function StackRenderer.onItemsRemoved(callback: (Player, { { Code: string, CFrame: CFrame, Count: number } }) -> ())
	table.insert(removedCallbacks, callback)
end

-- Top of the rendered stack (world CFrame), for effects.
function StackRenderer.topOf(player: Player): CFrame?
	local render = renders[player]
	return render and render.LastTop
end

local function destroyItem(item: RenderItem)
	item.Model:Destroy()
end

local function buildItem(code: string, index: number, isLocal: boolean): RenderItem?
	local model = ItemBuilder.build(code)
	local def = ItemBuilder.definition(code)
	if not model or not def then
		return nil
	end
	local parts, offsets = {}, {}
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			child.CanQuery = false
			child.CastShadow = isLocal
			table.insert(parts, child)
			table.insert(offsets, child:GetAttribute("Offset") or CFrame.identity)
		end
	end
	-- Deterministic per-slot yaw so stacks look hand-piled, not machine-made.
	-- Fronts face backwards: the owner's camera sits behind them, and that is
	-- the view players see and screenshot (duck faces, meme signs).
	local yaw = CFrame.Angles(0, math.pi + math.rad(((index * 137) % 60) - 30), 0)
	return { Code = code, Model = model, Parts = parts, Offsets = offsets, Height = def.Height, Yaw = yaw }
end

local GOLD = Color3.fromRGB(255, 196, 40)

-- One plain part standing in for several items above the detail cap. Width
-- and colour come from the first item so the tower keeps its stripes.
local function buildProxy(codes: { string }, first: number, last: number, isLocal: boolean): RenderItem
	local height = 0
	for i = first, last do
		local def = ItemBuilder.definition(codes[i])
		height += if def then def.Height else 1
	end
	local def = ItemBuilder.definition(codes[first])
	local spec = def and def.Parts[1]
	local _, rarity = StackCodec.parse(codes[first])
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = isLocal
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = if rarity == "g"
		then GOLD
		elseif spec then Color3.fromRGB(spec.Color[1], spec.Color[2], spec.Color[3])
		else Color3.new(1, 1, 1)
	local width = if spec then math.clamp(math.max(spec.Size[1], spec.Size[3]), 1, 1.8) else 1.4
	part.Size = Vector3.new(width, height, width)
	local model = Instance.new("Model")
	model.Name = "Proxy"
	part.Parent = model
	return {
		Code = table.concat(codes, ",", first, last),
		Model = model,
		Parts = { part },
		Offsets = { CFrame.identity },
		Height = height,
		Yaw = CFrame.Angles(0, math.rad(((first * 137) % 60) - 30), 0),
	}
end

type Removed = { Code: string, CFrame: CFrame, Count: number }

-- Returns proxies cut off the top (top first), for collapse/bank effects.
local function syncProxies(render: Render, codes: { string }, cap: number, isLocal: boolean): { Removed }
	local group = if isLocal then GameConfig.Render.ProxyGroupLocal else GameConfig.Render.ProxyGroupOthers
	local index = 0
	for first = cap + 1, #codes, group do
		index += 1
		local last = math.min(first + group - 1, #codes)
		local existing = render.Proxies[index]
		if not existing or existing.Code ~= table.concat(codes, ",", first, last) then
			if existing then
				destroyItem(existing)
			end
			local proxy = buildProxy(codes, first, last, isLocal)
			proxy.Model.Parent = render.Folder
			render.Proxies[index] = proxy
		end
	end
	local removed = {}
	for i = #render.Proxies, index + 1, -1 do
		local proxy = render.Proxies[i]
		local _, commas = string.gsub(proxy.Code, ",", "")
		table.insert(removed, {
			Code = string.match(proxy.Code, "^[^,]+") or proxy.Code,
			CFrame = proxy.Parts[1].CFrame,
			Count = commas + 1,
		})
		destroyItem(proxy)
		render.Proxies[i] = nil
	end
	return removed
end

local function sync(render: Render)
	local codes = StackCodec.decode(render.Player:GetAttribute("Stack") :: string?)
	local isLocal = render.Player == localPlayer
	local cap = if isLocal then GameConfig.Render.MaxItemsLocal else GameConfig.Render.MaxItemsOthers
	render.Count = #codes

	-- Keep the common prefix; rebuild only what changed.
	local keep = 0
	for i = 1, math.min(#render.Items, #codes) do
		if render.Items[i].Code ~= codes[i] then
			break
		end
		keep = i
	end

	local removed = syncProxies(render, codes, cap, isLocal)
	for i = #render.Items, keep + 1, -1 do
		local item = render.Items[i]
		if item.Parts[1] then
			table.insert(removed, { Code = item.Code, CFrame = item.Parts[1].CFrame, Count = 1 })
		end
		destroyItem(item)
		render.Items[i] = nil
	end
	if #removed > 0 then
		for _, callback in removedCallbacks do
			task.spawn(callback, render.Player, removed)
		end
	end

	for i = keep + 1, math.min(#codes, cap) do
		local item = buildItem(codes[i], i, isLocal)
		if item then
			item.Model.Parent = render.Folder
			table.insert(render.Items, item)
		end
	end

	render.LabelText.Text = if render.Count > 0 then tostring(render.Count) else ""
	render.Label.Enabled = render.Count > 0
end

-- The cosmetic platform under the stack (shown only while carrying).
local function syncBase(render: Render)
	if render.Base then
		render.Base.Model:Destroy()
		render.Base = nil
	end
	local id = render.Player:GetAttribute("Base")
	local base = CosmeticConfig.ById[if typeof(id) == "string" then id else CosmeticConfig.Default]
	if not base then
		return
	end
	local model = ItemBuilder.buildParts(base.Parts, base.Name)
	local parts, offsets = {}, {}
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			child.CanQuery = false
			table.insert(parts, child)
			table.insert(offsets, child:GetAttribute("Offset") or CFrame.identity)
		end
	end
	if base.Fire and model.PrimaryPart then
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 6
		fire.Parent = model.PrimaryPart
	end
	model.Parent = render.Folder
	render.Base = { Code = base.Id, Model = model, Parts = parts, Offsets = offsets, Height = base.Height, Yaw = CFrame.identity }
end

local function addPlayer(player: Player)
	if renders[player] then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = player.Name
	folder.Parent = rootFolder

	local anchor = Instance.new("Part")
	anchor.Name = "LabelAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Parent = folder

	local label = Instance.new("BillboardGui")
	label.Name = "Count"
	label.Size = UDim2.fromOffset(120, 44)
	label.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
	label.AlwaysOnTop = true
	label.MaxDistance = 500
	label.Adornee = anchor
	label.Enabled = false
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = if player == localPlayer then Color3.fromRGB(255, 220, 80) else Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = text
	text.Parent = label
	label.Parent = folder

	local render: Render = {
		Player = player,
		Folder = folder,
		Items = {},
		Count = 0,
		Lean = Vector2.zero,
		LeanVel = Vector2.zero,
		LastVel = Vector3.zero,
		Label = label,
		LabelText = text,
		Anchor = anchor,
		Visible = true,
		LastTop = nil,
		Proxies = {},
	}
	renders[player] = render
	player:GetAttributeChangedSignal("Stack"):Connect(function()
		sync(render)
	end)
	player:GetAttributeChangedSignal("Base"):Connect(function()
		syncBase(render)
	end)
	sync(render)
	syncBase(render)
end

local function removePlayer(player: Player)
	local render = renders[player]
	if render then
		renders[player] = nil
		render.Folder:Destroy()
	end
end

local parts: { BasePart } = {}
local cframes: { CFrame } = {}

local function step(dt: number)
	dt = math.min(dt, 1 / 20)
	local now = os.clock()
	local camera = Workspace.CurrentCamera
	local cameraPos = if camera then camera.CFrame.Position else Vector3.zero
	table.clear(parts)
	table.clear(cframes)

	for player, render in renders do
		local character = player.Character
		local head = character and character:FindFirstChild("Head") :: BasePart?
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local visible = head ~= nil and root ~= nil and #render.Items > 0
		if visible and player ~= localPlayer then
			visible = ((head :: BasePart).Position - cameraPos).Magnitude < GameConfig.Render.OtherRenderDistance
		end
		if visible ~= render.Visible then
			render.Visible = visible
			render.Folder.Parent = if visible then rootFolder else nil
		end
		if not visible then
			continue
		end
		head = head :: BasePart
		root = root :: BasePart

		-- Lean spring: accelerating forward throws the stack backwards.
		local velocity = root.AssemblyLinearVelocity
		local accel = (velocity - render.LastVel) / math.max(dt, 1e-3)
		render.LastVel = velocity
		local force = -render.Lean * SPRING - render.LeanVel * DAMPING - Vector2.new(accel.X, accel.Z) * ACCEL_GAIN * SPRING
		render.LeanVel += force * dt
		render.Lean += render.LeanVel * dt
		if render.Lean.Magnitude > MAX_LEAN then
			render.Lean = render.Lean.Unit * MAX_LEAN
		end

		local wobble = player:GetAttribute("Wobble") or 0
		local shakeSpeed = 3 + wobble * 9
		local shake = Vector2.new(math.sin(now * shakeSpeed), math.cos(now * shakeSpeed * 1.3)) * wobble * 0.35
		local lean = render.Lean + shake

		local totalHeight = 0
		for _, item in render.Items do
			totalHeight += item.Height
		end
		for _, item in render.Proxies do
			totalHeight += item.Height
		end
		-- Lean is spread along the height so the stack bends like a noodle.
		local perStud = lean / math.max(totalHeight, 12)

		local yawOnly = CFrame.fromOrientation(0, select(2, root.CFrame:ToOrientation()), 0)
		local cfWorldTilt = CFrame.new(head.Position + Vector3.new(0, head.Size.Y / 2 + 0.1, 0))
		local base = render.Base
		if base then
			local center = cfWorldTilt * CFrame.new(0, base.Height / 2, 0) * yawOnly
			for i, part in base.Parts do
				table.insert(parts, part)
				table.insert(cframes, center * base.Offsets[i])
			end
			cfWorldTilt = cfWorldTilt * CFrame.new(0, base.Height, 0)
		end
		for _, list in { render.Items, render.Proxies } do
			for _, item in list do
				local h = item.Height
				cfWorldTilt = cfWorldTilt * CFrame.Angles(perStud.Y * h, 0, -perStud.X * h)
				local center = (cfWorldTilt * CFrame.new(0, h / 2, 0)) * yawOnly * item.Yaw
				for i, part in item.Parts do
					table.insert(parts, part)
					table.insert(cframes, center * item.Offsets[i])
				end
				cfWorldTilt = cfWorldTilt * CFrame.new(0, h, 0)
			end
		end
		render.LastTop = cfWorldTilt
		table.insert(parts, render.Anchor)
		table.insert(cframes, cfWorldTilt)
	end

	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function StackRenderer.init()
	rootFolder = Instance.new("Folder")
	rootFolder.Name = "ClientStacks"
	rootFolder.Parent = Workspace

	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end
	RunService:BindToRenderStep("StackRenderer", Enum.RenderPriority.Character.Value + 1, step)
end

return StackRenderer
