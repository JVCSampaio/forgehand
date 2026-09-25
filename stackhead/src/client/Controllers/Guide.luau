-- "What do I do now?" — one objective line, a beam to the bank when it
-- matters, a highlight on the nearest grabbable item for brand-new players,
-- and a lock tag on items that need more Strength. No tutorial walls.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage").Shared
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local Economy = require(Shared.Economy)
local WorldIndex = require(Shared.WorldIndex)
local Format = require(Shared.Format)
local UIKit = require(script.Parent.UIKit)
local ClientState = require(script.Parent.ClientState)
local HUD = require(script.Parent.HUD)

local Guide = {}

local player = Players.LocalPlayer
local objective: TextButton
local beam: Beam
local beamStart: Attachment?
local highlight: Highlight
local lockTag: BillboardGui
local lockText: TextLabel
local itemsFolder: Folder
local bankAttachment: Attachment
local lastText = ""
local nearbyHighlights = {}
local candidateItems = {}

local function setObjective(text: string, color: Color3?)
	if text ~= lastText then
		lastText = text
		objective.Text = text
		UIKit.pop(objective, 0.1)
	end
	objective.TextColor3 = color or UIKit.Colors.Text
end

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function ensureBeam(root: BasePart)
	if beamStart and beamStart.Parent == root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "GuideBeam"
	attachment.Parent = root
	beamStart = attachment
	beam.Attachment0 = attachment
end

-- Nearest item within `radius`, split by whether the player can lift it.
local function nearestItems(position: Vector3, radius: number, strength: number): (Model?, Model?)
	table.clear(candidateItems)
	local bestFree, bestFreeDist = nil, radius
	local bestLocked, bestLockedDist = nil, radius
	for _, model in itemsFolder:GetChildren() do
		local root = (model :: Model).PrimaryPart
		if root then
			local distance = (root.Position - position).Magnitude
			local tier = model:GetAttribute("Tier") or 1
			if distance < 24 and tier <= strength then
				table.insert(candidateItems, { Model = model, Distance = distance })
			end
			if tier > strength then
				if distance < bestLockedDist then
					bestLocked, bestLockedDist = model :: Model, distance
				end
			elseif distance < bestFreeDist then
				bestFree, bestFreeDist = model :: Model, distance
			end
		end
	end
	table.sort(candidateItems, function(a, b)
		return a.Distance < b.Distance
	end)
	for i, marker in nearbyHighlights do
		local entry = candidateItems[i]
		marker.Adornee = entry and entry.Model
		marker.Enabled = entry ~= nil
		if entry then
			local model = entry.Model
			local recovered = (model:GetAttribute("RecoverableUntil") or 0) > Workspace:GetServerTimeNow()
			marker.OutlineColor = if recovered
				then UIKit.Colors.Green
				elseif model:GetAttribute("BonusFind") then UIKit.Colors.Gold
				else Color3.fromRGB(235, 245, 255)
		end
	end
	return bestFree, bestLocked
end

local function cheapestUpgrade(data): number?
	local cheapest = nil
	for _, id in UpgradeConfig.Order do
		local cost = Economy.upgradeCost(UpgradeConfig.Upgrades[id], data.Upgrades[id])
		if cost and (not cheapest or cost < cheapest) then
			cheapest = cost
		end
	end
	return cheapest
end

local function update()
	local data = ClientState.Data
	local root = rootPart()
	if not data or not root then
		for _, marker in nearbyHighlights do
			marker.Enabled = false
		end
		return
	end
	ensureBeam(root)
	local here = WorldIndex:at(root.Position)
	bankAttachment.WorldPosition = here.Origin + Vector3.new(0, 3, 0)
	local count = #ClientState.stackCodes()
	local wobble = ClientState.wobble()
	local strength = data.Upgrades.Strength
	local free, locked = nearestItems(root.Position, 40, strength)
	local showBeam = false

	local strengthCost = Economy.upgradeCost(UpgradeConfig.Upgrades.Strength, strength)
	local cheapest = cheapestUpgrade(data)

	if wobble > 0.65 then
		setObjective("⚠️ Too wobbly! Use STABILIZE — slow down and recover!", UIKit.Colors.Red)
		showBeam = true
	elseif data.Banks == 0 and count == 0 then
		setObjective("Walk into items to stack them on your head!")
	elseif data.Banks == 0 and count < 5 then
		setObjective(string.format("Nice! Grab %d more…", 5 - count))
	elseif data.Banks == 0 then
		setObjective("Carry your stack to the BANK in the middle!", UIKit.Colors.Gold)
		showBeam = true
	elseif count == 0 and strengthCost and data.Coins >= strengthCost then
		local zone = WorldIndex:zoneForTier(strength + 1)
		local world = WorldIndex:worldForTier(strength + 1)
		local target = if world and world.FirstTier == strength + 1
			then world.DisplayName
			else (zone and zone.DisplayName or "a new zone")
		setObjective(string.format("💪 Buy Strength to unlock %s!", target), UIKit.Colors.Gold)
		-- The affordable badge is enough; no continuous bounce.
	elseif count == 0 and WorldIndex:worldForTier(strength) ~= here and here.FirstTier < strength then
		local best = WorldIndex:worldForTier(strength)
		setObjective(
			string.format("%s %s pays way more. Open WORLDS to travel!", best.Icon, best.DisplayName),
			UIKit.Colors.Gold
		)
		-- World badge communicates this change.
	elseif
		count == 0
		and data.Upgrades.Speed + data.Upgrades.Reach + data.Upgrades.Balance == 0
		and cheapest
		and data.Coins >= cheapest
	then
		setObjective("Open UPGRADE and buy your first upgrade!", UIKit.Colors.Green)
		-- The affordable badge is enough; no continuous bounce.
	elseif count >= 10 then
		local mult = Economy.heightMultiplier(count, EconomyConfig.HeightBonus)
		setObjective(
			string.format("Bonus %s — go taller or bank it before it falls!", Format.multiplier(mult)),
			UIKit.Colors.Gold
		)
		showBeam = count >= 20
	elseif strengthCost and data.Coins < strengthCost and data.Banks > 0 then
		local zone = WorldIndex:zoneForTier(strength + 1)
		setObjective(
			string.format(
				"%s coins to %s • UPGRADES",
				Format.short(strengthCost - data.Coins),
				zone and zone.DisplayName or "next tier"
			),
			UIKit.Colors.Gold
		)
	elseif count > 0 then
		setObjective("Taller stacks pay more. Bank in the middle!")
	elseif data.BestStack < 10 then
		setObjective("Try a 10 stack for your first record!")
	else
		local nextMilestone = nil
		for _, milestone in EconomyConfig.Milestones do
			if data.BestStack < milestone.Stack then
				nextMilestone = milestone
				break
			end
		end
		if nextMilestone then
			setObjective(
				string.format('Next record: %d stack → title "%s"', nextMilestone.Stack, nextMilestone.Title)
			)
		else
			setObjective("Legend. Beat your best: " .. data.BestStack)
		end
	end

	beam.Enabled = showBeam
	highlight.Adornee = nil
	highlight.Enabled = false

	if locked and ((locked.PrimaryPart :: BasePart).Position - root.Position).Magnitude < 12 then
		lockTag.Adornee = locked.PrimaryPart
		lockTag.Enabled = true
		lockText.TextColor3 = UIKit.Colors.Red
		lockText.Text = string.format("🔒 Strength %d", locked:GetAttribute("Tier") or 0)
	elseif
		free
		and free.PrimaryPart
		and (free.PrimaryPart.Position - root.Position).Magnitude < 12
		and (
			(free:GetAttribute("RecoverableUntil") or 0) > Workspace:GetServerTimeNow() or free:GetAttribute(
				"BonusFind"
			)
		)
	then
		lockTag.Adornee = free.PrimaryPart
		lockTag.Enabled = true
		local recovered = (free:GetAttribute("RecoverableUntil") or 0) > Workspace:GetServerTimeNow()
		lockText.TextColor3 = if recovered then UIKit.Colors.Green else UIKit.Colors.Gold
		lockText.Text = if recovered then "RECOVER ITEMS" else "2x RARITY CHANCE"
	else
		lockTag.Enabled = false
	end
end

function Guide.init()
	itemsFolder = Workspace:WaitForChild("Items") :: Folder
	objective = UIKit.button({
		Name = "Objective",
		BackgroundColor3 = UIKit.Colors.Panel,
		BackgroundTransparency = 0.15,
		Text = "",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, if HUD.isTouch then -8 else -24),
		Size = UDim2.new(if HUD.isTouch then 0.5 else 0.6, 0, 0, 34),
		Parent = HUD.gui(),
	})
	UIKit.textLimit(objective, 20)
	objective.Activated:Connect(function()
		require(script.Parent.Menus).openUpgrades()
	end)
	local function layoutObjective()
		local size = HUD.gui().AbsoluteSize
		if HUD.isTouch then
			objective.AnchorPoint = Vector2.new(0.5, 0)
			objective.Position = UDim2.new(0.5, 0, 0, if size.X < 600 then 254 else 192)
			objective.Size = UDim2.new(0.65, 0, 0, 38)
		end
	end
	HUD.gui():GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutObjective)
	layoutObjective()
	UIKit.create("UIScale", { Parent = objective })

	bankAttachment = Instance.new("Attachment")
	bankAttachment.Name = "BankGuide"
	bankAttachment.WorldPosition = Vector3.new(0, 3, 0)
	bankAttachment.Parent = Workspace.Terrain
	beam = Instance.new("Beam")
	beam.Attachment1 = bankAttachment
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 210, 70))
	beam.LightEmission = 1
	beam.Width0 = 0.6
	beam.Width1 = 0.6
	beam.FaceCamera = true
	beam.Transparency = NumberSequence.new(0.15)
	beam.Enabled = false
	beam.Parent = Workspace.Terrain

	highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 230, 100)
	highlight.FillTransparency = 0.85
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.Enabled = false
	highlight.Parent = Workspace.Terrain
	for _ = 1, 6 do
		local marker = highlight:Clone()
		marker.FillTransparency = 1
		marker.Parent = Workspace.Terrain
		table.insert(nearbyHighlights, marker)
	end

	lockTag = Instance.new("BillboardGui")
	lockTag.Size = UDim2.fromOffset(150, 36)
	lockTag.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
	lockTag.AlwaysOnTop = false
	lockTag.MaxDistance = 35
	lockTag.Enabled = false
	lockText = UIKit.label({ Size = UDim2.fromScale(1, 1), TextColor3 = UIKit.Colors.Red })
	lockText.Parent = lockTag
	lockTag.Parent = player:WaitForChild("PlayerGui")

	task.spawn(function()
		while true do
			local ok, err = pcall(update)
			if not ok then
				warn("[Guide]", err)
			end
			task.wait(0.2)
		end
	end)
end

return Guide
