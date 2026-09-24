-- Client-only juice: items flying onto the stack, loose items falling from
-- collapsed stacks and item rain, stacks pouring into the bank, camera shake.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage").Shared
local GameConfig = require(Shared.Config.GameConfig)
local ItemConfig = require(Shared.Config.ItemConfig)
local ItemBuilder = require(Shared.ItemBuilder)
local StackCodec = require(Shared.StackCodec)
local Remotes = require(Shared.Remotes)
local WorldIndex = require(Shared.WorldIndex)
local Audio = require(script.Parent.Audio)
local StackRenderer = require(script.Parent.StackRenderer)
local ClientState = require(script.Parent.ClientState)

local ItemFx = {}

local localPlayer = Players.LocalPlayer

type Flight = {
	Parts: { BasePart },
	Offsets: { CFrame },
	From: Vector3,
	To: () -> Vector3,
	Start: number,
	Duration: number,
	Arc: number,
	Spin: number,
	DestroyAtEnd: boolean,
	Model: Model,
	Final: { CFrame }?,
	FallIn: boolean?,
	Linger: number?,
}

local flights: { Flight } = {}
local fxFolder: Folder
local shakeUntil = 0
local shakeStrength = 0
local MAX_FLIGHTS = 150
local MAX_DEBRIS = 70

local function partsOf(model: Model): ({ BasePart }, { CFrame })
	local parts, offsets = {}, {}
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			child.CanQuery = false
			table.insert(parts, child)
			table.insert(offsets, child:GetAttribute("Offset") or CFrame.identity)
		end
	end
	return parts, offsets
end

-- fallIn: accelerate like gravity instead of easing out; linger: seconds to
-- rest where it landed before disappearing (collapse debris).
local function launch(code: string, from: Vector3, to: () -> Vector3, duration: number, arc: number, fallIn: boolean?, linger: number?)
	if #flights >= MAX_FLIGHTS then
		return
	end
	local model = ItemBuilder.build(code)
	if not model then
		return
	end
	local parts, offsets = partsOf(model)
	model.Parent = fxFolder
	table.insert(flights, {
		Parts = parts,
		Offsets = offsets,
		From = from,
		To = to,
		Start = os.clock(),
		Duration = duration,
		Arc = arc,
		Spin = math.random() * 8 - 4,
		DestroyAtEnd = true,
		Model = model,
		FallIn = fallIn,
		Linger = linger,
	})
end

function ItemFx.shake(strength: number, duration: number)
	shakeStrength = math.max(shakeStrength, strength)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
end

-- Items dropped by the server with DropFrom/DropAt fall locally before landing.
local function animateDrop(model: Model)
	local dropAt = model:GetAttribute("DropAt")
	local from = model:GetAttribute("DropFrom")
	if typeof(dropAt) ~= "number" or typeof(from) ~= "Vector3" then
		return
	end
	local remaining = dropAt - Workspace:GetServerTimeNow()
	if remaining <= 0.05 or #flights >= MAX_FLIGHTS then
		return
	end
	local parts, offsets = partsOf(model)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local finalCenter = root.CFrame * (root:GetAttribute("Offset") or CFrame.identity):Inverse()
	local finals = {}
	for i, part in parts do
		finals[i] = part.CFrame
	end
	local target = finalCenter.Position
	table.insert(flights, {
		Parts = parts,
		Offsets = offsets,
		From = from,
		To = function()
			return target
		end,
		Start = os.clock(),
		Duration = remaining,
		Arc = if (from - target).Magnitude > 60 then 0 else 6,
		Spin = math.random() * 10 - 5,
		DestroyAtEnd = false,
		Model = model,
		Final = finals,
	})
end

local function updateFlights()
	if #flights == 0 then
		return
	end
	local now = os.clock()
	local parts, cframes = {}, {}
	for index = #flights, 1, -1 do
		local flight = flights[index]
		local t = math.clamp((now - flight.Start) / flight.Duration, 0, 1)
		if t >= 1 or not flight.Model.Parent then
			table.remove(flights, index)
			if flight.DestroyAtEnd and flight.Linger and flight.Model.Parent then
				local landed = CFrame.new(flight.To()) * CFrame.Angles(flight.Spin, flight.Spin * 0.7, 0)
				for i, part in flight.Parts do
					table.insert(parts, part)
					table.insert(cframes, landed * flight.Offsets[i])
				end
				local model = flight.Model
				task.delay(flight.Linger, function()
					model:Destroy()
				end)
			elseif flight.DestroyAtEnd then
				flight.Model:Destroy()
			elseif flight.Final and flight.Model.Parent then
				for i, part in flight.Parts do
					table.insert(parts, part)
					table.insert(cframes, flight.Final[i])
				end
			end
		else
			local target = flight.To()
			local eased = if flight.DestroyAtEnd and not flight.FallIn then 1 - (1 - t) ^ 2 else t * t
			local position = flight.From:Lerp(target, eased) + Vector3.new(0, math.sin(t * math.pi) * flight.Arc, 0)
			local center = CFrame.new(position) * CFrame.Angles(t * flight.Spin, t * flight.Spin * 0.7, 0)
			for i, part in flight.Parts do
				table.insert(parts, part)
				table.insert(cframes, center * flight.Offsets[i])
			end
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function updateShake()
	local camera = Workspace.CurrentCamera
	local now = os.clock()
	if not camera or now > shakeUntil then
		shakeStrength = 0
		return
	end
	local fade = (shakeUntil - now)
	local s = shakeStrength * math.min(fade * 3, 1)
	camera.CFrame *= CFrame.Angles(math.rad(math.sin(now * 55) * s), math.rad(math.cos(now * 47) * s), 0)
end

-- Bank coins spin locally. Tagged parts stream in and out with the world.
local spinners: { [BasePart]: Vector3 } = {}
local function trackSpinner(instance: Instance)
	if instance:IsA("BasePart") then
		spinners[instance] = instance.Position
	end
end
local function spinCoins()
	local t = os.clock()
	for coin, base in spinners do
		if coin.Parent then
			coin.CFrame = CFrame.new(base + Vector3.new(0, math.sin(t * 1.5) * 0.8, 0)) * CFrame.Angles(0, t * 1.2, 0) * CFrame.Angles(0, 0, math.rad(90))
		else
			spinners[coin] = nil
		end
	end
end

local function stackTop(): Vector3
	local top = StackRenderer.topOf(localPlayer)
	if top then
		return top.Position
	end
	local character = localPlayer.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	return if head then head.Position + Vector3.new(0, 1, 0) else Vector3.zero
end

local function nearBank(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local offset = root.Position - WorldIndex:at(root.Position).Origin
	return Vector2.new(offset.X, offset.Z).Magnitude < GameConfig.Bank.Radius + 6
end

-- The server turns the lowest Loose.MaxPerCollapse fallen items into loot
-- (those animate via animateDrop). Everything above them would just vanish,
-- so draw it tumbling off the tower here: a 300 stack should look like 300.
local function tumble(removed: { { Code: string, CFrame: CFrame, Count: number } })
	local covered = 0
	local lootFrom = #removed + 1
	while lootFrom > 1 and covered < GameConfig.Loose.MaxPerCollapse do
		lootFrom -= 1
		covered += removed[lootFrom].Count
	end
	local debris = math.min(lootFrom - 1, MAX_DEBRIS)
	for i = 1, debris do
		local entry = removed[i]
		local from = entry.CFrame.Position
		local angle = math.random() * math.pi * 2
		local distance = 8 + math.random() * 22
		local ground = Vector3.new(
			from.X + math.cos(angle) * distance,
			GameConfig.Layout.GroundY + 0.8,
			from.Z + math.sin(angle) * distance
		)
		local fall = math.clamp(math.sqrt(2 * math.max(from.Y - ground.Y, 1) / 70), 0.45, 2.4)
		task.delay(i * 0.012, function()
			launch(entry.Code, from, function()
				return ground
			end, fall, 3, true, 1.4 + math.random())
		end)
	end
end

function ItemFx.init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "ClientFx"
	fxFolder.Parent = Workspace

	RunService:BindToRenderStep("ItemFlights", Enum.RenderPriority.Character.Value + 2, updateFlights)
	RunService:BindToRenderStep("CameraShake", Enum.RenderPriority.Camera.Value + 1, updateShake)
	CollectionService:GetInstanceAddedSignal("Spin"):Connect(trackSpinner)
	for _, coin in CollectionService:GetTagged("Spin") do
		trackSpinner(coin)
	end
	RunService.RenderStepped:Connect(spinCoins)

	local itemsFolder = Workspace:WaitForChild("Items")
	itemsFolder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			animateDrop(child)
		end
	end)

	Remotes.PickedUp.OnClientEvent:Connect(function(list)
		if typeof(list) ~= "table" then
			return
		end
		local count = #ClientState.stackCodes()
		for i, entry in list do
			local code, from = entry[1], entry[2]
			if typeof(code) == "string" and typeof(from) == "Vector3" then
				launch(code, from, stackTop, 0.28, 2)
				local id, rarity = StackCodec.parse(code)
				if rarity ~= "" then
					Audio.play("Rare")
				end
				local def = ItemConfig.ById[id]
				if def and def.Meme then
					Audio.play("Meme")
				end
				-- Rising pitch as the stack grows: the core "one more" sound.
				local pitch = 0.8 + math.min(count - #list + i, 60) * 0.015
				Audio.play("Pickup", pitch)
			end
		end
	end)

	StackRenderer.onItemsRemoved(function(player, removed)
		if not nearBank(player) then
			tumble(removed)
			return
		end
		if player ~= localPlayer then
			return
		end
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local centre = if root then WorldIndex:at(root.Position).Origin else Vector3.zero
		local bankTarget = centre + Vector3.new(0, 16, 0)
		for i, entry in removed do
			if i > 40 then
				break
			end
			task.delay(i * 0.02, function()
				launch(entry.Code, entry.CFrame.Position, function()
					return bankTarget
				end, 0.45, 4)
			end)
		end
	end)

	Remotes.Collapsed.OnClientEvent:Connect(function(userId, lost, origin)
		if typeof(origin) ~= "Vector3" then
			return
		end
		Audio.play("Collapse", 1, origin)
		if userId == localPlayer.UserId then
			ItemFx.shake(math.clamp((lost or 1) * 0.06, 0.6, 2.5), 0.6)
		end
	end)

	Remotes.Bumped.OnClientEvent:Connect(function(_otherUserId, isVictim)
		Audio.play("Bump")
		ItemFx.shake(if isVictim then 1.4 else 0.6, 0.3)
	end)
end

return ItemFx
