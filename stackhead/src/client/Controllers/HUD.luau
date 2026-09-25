-- Always-on interface: coins, stack value, wobble meter, action buttons,
-- toasts and the bank payout popup. Built in code so it can be versioned and
-- rebalanced with the rest of the game.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage").Shared
local GameConfig = require(Shared.Config.GameConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local ItemConfig = require(Shared.Config.ItemConfig)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local Economy = require(Shared.Economy)
local Wobble = require(Shared.Wobble)
local StackCodec = require(Shared.StackCodec)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local WorldIndex = require(Shared.WorldIndex)
local UIKit = require(script.Parent.UIKit)
local ClientState = require(script.Parent.ClientState)
local Audio = require(script.Parent.Audio)

local HUD = {}

local C = UIKit.Colors
local player = Players.LocalPlayer
local create = UIKit.create

local gui: ScreenGui
local coinsLabel: TextLabel
local coinsFrame: Frame
local boostLabel: TextLabel
local wobbleFrame: Frame
local wobbleFill: Frame
local wobbleText: TextLabel
local stackFrame: Frame
local stackCount: TextLabel
local stackDetail: TextLabel
local toastList: Frame
local popup: Frame
local rainLabel: TextLabel
local collectionLabel: TextLabel
local windLoop: Sound?
local glueButton: TextButton
local steadyButton: TextButton
local dashButton: TextButton
local toastQuietUntil = 0
local lastMemeToast = 0
local menuButtons: { [string]: TextButton } = {}
local badges: { [string]: TextLabel } = {}

local rarityMult = {}
for _, rarity in GameConfig.Spawning.Rarities do
	rarityMult[rarity.Suffix] = rarity.ValueMult
end

HUD.isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function stackPreview()
	local codes = ClientState.stackCodes()
	local entries = {}
	for _, code in codes do
		local id, suffix = StackCodec.parse(code)
		local def = ItemConfig.ById[id]
		if def then
			table.insert(entries, { Value = def.Value, RarityMult = rarityMult[suffix] or 1 })
		end
	end
	local data = ClientState.Data
	local coinMult = if data and data.CoinMult then data.CoinMult else 1
	local total, base, heightMult = Economy.bankPayout(entries, coinMult, EconomyConfig.HeightBonus)
	return #codes, total, base, heightMult
end

local function buildTop()
	coinsFrame = create("Frame", {
		Name = "Coins",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(230, 52),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.1,
		Parent = gui,
	}, { UIKit.corner(26), UIKit.stroke(3) })
	create("TextLabel", {
		Text = "🪙",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 44, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		TextScaled = true,
		Font = UIKit.Fonts.Display,
		Parent = coinsFrame,
	})
	coinsLabel = UIKit.label({
		Text = "0",
		Size = UDim2.new(1, -64, 0.8, 0),
		Position = UDim2.new(0, 54, 0.1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Gold,
		Parent = coinsFrame,
	})
	boostLabel = UIKit.label({
		Text = "",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 8, 0.5, 0),
		Size = UDim2.fromOffset(130, 30),
		TextColor3 = C.Green,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		Parent = coinsFrame,
	})

	collectionLabel = UIKit.label({
		Text = "",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(110, 26),
		Font = UIKit.Fonts.Body,
		TextColor3 = C.SubText,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = gui,
	})

	wobbleFrame = create("Frame", {
		Name = "Wobble",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.new(0.5, 0, 0, 22),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = gui,
	}, {
		UIKit.corner(11),
		UIKit.stroke(3),
		create("UISizeConstraint", { MaxSize = Vector2.new(340, 22) }),
	})
	wobbleFill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.Green,
		Parent = wobbleFrame,
	}, { UIKit.corner(11) })
	wobbleText = UIKit.label({
		Text = "STEADY",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = wobbleFrame,
	})

	rainLabel = UIKit.label({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 92),
		Size = UDim2.fromOffset(320, 30),
		TextColor3 = Color3.fromRGB(140, 210, 255),
		Visible = false,
		Parent = gui,
	})
end

local function buildStackPanel()
	stackFrame = create("Frame", {
		Name = "Stack",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 40),
		Size = UDim2.fromOffset(170, 108),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = gui,
	}, { UIKit.corner(16), UIKit.stroke(3), UIKit.padding(8) })
	stackCount = UIKit.label({
		Text = "📦 0",
		Size = UDim2.new(1, 0, 0, 44),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = stackFrame,
	})
	stackDetail = UIKit.label({
		Text = "",
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 0, 46),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Gold,
		Font = UIKit.Fonts.Body,
		Parent = stackFrame,
	})
end

local function badge(parent: GuiObject): TextLabel
	local label = UIKit.label({
		Text = "!",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 0,
		BackgroundColor3 = C.Red,
		Visible = false,
		ZIndex = 5,
		Parent = parent,
	})
	UIKit.corner(12).Parent = label
	return label
end

local function buildMenuButtons()
	local size = if HUD.isTouch then 70 else 66
	-- Left edge, vertically centred: clear of the chat window (top-left)
	-- and the thumbstick (bottom-left).
	local column = create("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(size, 5 * size + 32),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local specs = {
		{ Id = "Upgrades", Text = "⬆️\nUPGRADE", Color = C.Green },
		{ Id = "Worlds", Text = "🌍\nWORLDS", Color = C.Blue },
		{ Id = "Shop", Text = "🛒\nSHOP", Color = C.Purple },
		{ Id = "Tasks", Text = "📋\nTASKS", Color = C.Gold },
		{ Id = "Settings", Text = "⚙\nSETTINGS", Color = C.PanelLight },
	}
	for order, spec in specs do
		local button = UIKit.button({
			Name = spec.Id,
			Text = spec.Text,
			LayoutOrder = order,
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = spec.Color,
			Parent = column,
		})
		UIKit.textLimit(button, 18)
		menuButtons[spec.Id] = button
		badges[spec.Id] = badge(button)
	end
end

local function buildActions()
	local size = if HUD.isTouch then 92 else 80
	dashButton = UIKit.button({
		Name = "Dash",
		Text = if HUD.isTouch then "💨\nDASH" else "💨 DASH\n[Q]",
		AnchorPoint = Vector2.new(1, 1),
		Position = if HUD.isTouch then UDim2.new(1, -18, 1, -170) else UDim2.new(1, -18, 1, -18),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = C.Blue,
		Parent = gui,
	})
	UIKit.textLimit(dashButton, 22)
	glueButton = UIKit.button({
		Name = "Glue",
		Text = "🧴 0",
		AnchorPoint = Vector2.new(1, 1),
		Position = if HUD.isTouch then UDim2.new(1, -120, 1, -170) else UDim2.new(1, -108, 1, -18),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = C.Disabled,
		Parent = gui,
	})
	UIKit.textLimit(glueButton, 22)
	steadyButton = UIKit.button({
		Name = "Steady",
		Text = "STABILIZE: OFF [E]",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -112),
		Size = UDim2.fromOffset(170, 48),
		BackgroundColor3 = C.Green,
		Parent = gui,
	})
	UIKit.textLimit(steadyButton, 20)
	player:GetAttributeChangedSignal("Steady"):Connect(function()
		local enabled = player:GetAttribute("Steady") == true
		steadyButton.Text = if enabled
			then "STABILIZE: ON"
			else (if HUD.isTouch then "STABILIZE: OFF" else "STABILIZE: OFF [E]")
		steadyButton.BackgroundColor3 = if enabled then C.Gold else C.Green
	end)
end

-- On touch devices, park Dash above Roblox's jump button and Glue to its
-- left, whatever size the device gives the jump button.
local function followJumpButton()
	if not HUD.isTouch then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local touchGui = playerGui:WaitForChild("TouchGui", 15)
	local jump = touchGui and touchGui:FindFirstChild("JumpButton", true) :: GuiObject?
	if not jump then
		return
	end
	local function place()
		local inset = gui.AbsolutePosition
		local jumpPos = jump.AbsolutePosition - inset
		local jumpSize = jump.AbsoluteSize
		local size = math.clamp(jumpSize.X * 0.8, 64, 100)
		local centerX = jumpPos.X + jumpSize.X / 2
		dashButton.AnchorPoint = Vector2.new(0.5, 1)
		dashButton.Size = UDim2.fromOffset(size, size)
		dashButton.Position = UDim2.fromOffset(centerX, jumpPos.Y - 10)
		glueButton.AnchorPoint = Vector2.new(1, 1)
		glueButton.Size = UDim2.fromOffset(size, size)
		glueButton.Position = UDim2.fromOffset(jumpPos.X - 10, jumpPos.Y + jumpSize.Y)
		steadyButton.Position = UDim2.fromOffset(jumpPos.X - 10, jumpPos.Y - 10)
		steadyButton.Size = UDim2.fromOffset(size + 20, 48)
	end
	jump:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
	jump:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()
end

local function buildToasts()
	toastList = create("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 128),
		Size = UDim2.new(0.8, 0, 0, 160),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("UISizeConstraint", { MaxSize = Vector2.new(560, 160) }),
	})
end

local toastOrder = 0
local TOAST_COLORS = {
	Collapse = C.Red,
	Error = C.Red,
	Glue = C.Green,
	Unlock = C.Gold,
	Daily = C.Gold,
	Event = Color3.fromRGB(120, 200, 255),
	Broadcast = C.SubText,
	Purchase = C.Purple,
	Record = C.Gold,
	Meme = Color3.fromRGB(255, 130, 220),
	Info = C.Text,
}

function HUD.toast(text: string, kind: string?)
	if os.clock() < toastQuietUntil and kind ~= "Collapse" and kind ~= "Error" and kind ~= "Purchase" then
		return
	end
	toastOrder += 1
	local label = UIKit.label({
		Text = text,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = toastOrder,
		TextColor3 = TOAST_COLORS[kind or "Info"] or C.Text,
		TextTransparency = 1,
		Parent = toastList,
	})
	UIKit.textLimit(label, 28)
	TweenService:Create(label, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
	local items = {}
	for _, child in toastList:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(items, child)
		end
	end
	if #items > 1 then
		table.sort(items, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		items[1]:Destroy()
	end
	task.delay(3.5, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			task.wait(0.4)
			label:Destroy()
		end
	end)
end

local function showBankPopup(info)
	if popup then
		popup:Destroy()
	end
	popup = create("Frame", {
		Name = "BankPopup",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(0.8, 0, 0, 170),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UIKit.create("UISizeConstraint", { MaxSize = Vector2.new(360, 220), Parent = popup })
	local total = UIKit.label({
		Text = "+0",
		Size = UDim2.new(1, 0, 0, 80),
		TextColor3 = C.Gold,
		Parent = popup,
	})
	local lines = {
		string.format(
			"📦 %d items  ×%s height bonus",
			info.Count,
			string.sub(Format.multiplier(info.HeightMult), 2)
		),
	}
	if info.CoinMult and info.CoinMult > 1.001 then
		table.insert(lines, string.format("%s coin boost", Format.multiplier(info.CoinMult)))
	end
	if info.DiscoveryBonus > 0 then
		table.insert(
			lines,
			string.format("✨ %d new discoveries  +%s", #info.Discoveries, Format.short(info.DiscoveryBonus))
		)
	end
	if info.FirstBonus > 0 then
		table.insert(lines, string.format("🎉 First delivery bonus  +%d", info.FirstBonus))
	end
	if info.NewRecord and info.Count > 1 then
		table.insert(lines, "🏆 NEW RECORD!")
	end
	UIKit.label({
		Text = table.concat(lines, "\n"),
		Position = UDim2.fromOffset(0, 82),
		Size = UDim2.new(1, 0, 0, 22 * #lines),
		Font = UIKit.Fonts.Body,
		Parent = popup,
	})

	-- Count up the payout: the dopamine moment of the loop.
	local target = info.Total
	local start = os.clock()
	local duration = math.clamp(0.4 + info.Count * 0.02, 0.4, 1.4)
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not total.Parent then
			connection:Disconnect()
			return
		end
		local t = math.min((os.clock() - start) / duration, 1)
		total.Text = "+" .. Format.commas(target * (1 - (1 - t) ^ 3))
		if t >= 1 then
			connection:Disconnect()
		end
	end)
	UIKit.pop(popup, 0.3)
	local thisPopup = popup
	task.delay(2.6, function()
		if thisPopup.Parent then
			for _, child in thisPopup:GetDescendants() do
				if child:IsA("TextLabel") then
					TweenService:Create(child, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
				end
			end
			task.wait(0.45)
			thisPopup:Destroy()
		end
	end)
end

local lastCoins = nil
local function refreshData()
	local data = ClientState.Data
	if not data then
		return
	end
	coinsLabel.Text = Format.commas(data.Coins)
	local found = 0
	for _ in data.Discovered do
		found += 1
	end
	collectionLabel.Text = string.format("📖 %d/%d", found, #ItemConfig.Items * (1 + #GameConfig.Spawning.Rarities))
	-- Badge on WORLDS when a better world is unlocked than the one you're in.
	local worldsBadge = false
	for _, world in WorldIndex.list do
		if
			data.Upgrades.Strength >= world.FirstTier
			and data.World
			and WorldIndex:get(data.World).Index < world.Index
		then
			worldsBadge = true
		end
	end
	badges.Worlds.Visible = worldsBadge
	if lastCoins and data.Coins > lastCoins then
		UIKit.pop(coinsFrame, 0.12)
	end
	lastCoins = data.Coins

	local armed = ClientState.glueArmed()
	glueButton.Text =
		string.format("🧴 %d\n%s", data.Glue, if armed then "ARMED" elseif HUD.isTouch then "GLUE" else "[G]")
	glueButton.BackgroundColor3 = if armed then C.Green elseif data.Glue > 0 then C.Blue else C.Disabled

	-- Badge when any upgrade is affordable.
	local affordable = false
	for _, id in UpgradeConfig.Order do
		local cost = Economy.upgradeCost(UpgradeConfig.Upgrades[id], data.Upgrades[id])
		if cost and data.Coins >= cost then
			affordable = true
		end
	end
	badges.Upgrades.Visible = affordable
	local canClaim = data.DailyLastClaimDay < data.Today
	local orderReady = false
	if data.Orders then
		for i, order in data.Orders.List do
			if not data.Orders.Claimed[i] and data.Orders.Progress[i] >= order.Target then
				orderReady = true
			end
		end
	end
	badges.Tasks.Visible = canClaim or orderReady
end

local function refreshStack()
	local count, total, _base, heightMult = stackPreview()
	stackFrame.Visible = count > 0
	stackCount.Text = string.format("%d ITEMS", count)
	stackDetail.Text = string.format("DEPOSIT %s  •  %s", Format.short(total), Format.multiplier(heightMult))
end

local function updateWobble()
	local height = ClientState.stackHeight()
	local wobble = ClientState.wobble()
	local risky = height > GameConfig.Wobble.SafeHeight and Wobble.heightFactor(height, GameConfig.Wobble) > 0.05
	wobbleFrame.Visible = risky or wobble > 0.02
	wobbleFill.Size = UDim2.fromScale(math.clamp(wobble, 0, 1), 1)
	local color
	if wobble < 0.45 then
		color = C.Green
		wobbleText.Text = "FALL RISK: LOW"
	elseif wobble < 0.75 then
		color = C.Gold
		wobbleText.Text = "FALL RISK: RISING"
	else
		color = C.Red
		wobbleText.Text = "HIGH RISK — STABILIZE!"
	end
	wobbleFill.BackgroundColor3 = color
	if windLoop then
		-- Wind rises with danger: players hear trouble before they see it.
		windLoop.Volume = math.clamp((wobble - 0.3) * 1.2, 0, 0.7)
	end

	local boost = ClientState.boostRemaining()
	boostLabel.Visible = boost > 0
	if boost > 0 then
		boostLabel.Text = "⚡2x " .. Format.duration(boost)
	end

	local now = Workspace:GetServerTimeNow()
	local rainEnds = Workspace:GetAttribute("RainEndsAt")
	local rainLeft = if typeof(rainEnds) == "number" then rainEnds - now else 0
	local goldEnds = Workspace:GetAttribute("GoldenEndsAt")
	local goldLeft = if typeof(goldEnds) == "number" then goldEnds - now else 0
	local nextRain = Workspace:GetAttribute("NextRainAt") or 0
	rainLabel.Visible = rainLeft > 0 or goldLeft > 0 or nextRain > now
	if rainLeft > 0 then
		rainLabel.Text = "🌧️ ITEM RAIN " .. Format.duration(rainLeft)
	elseif goldLeft > 0 then
		rainLabel.Text = "✨ GOLDEN HOUR " .. Format.duration(goldLeft)
	elseif nextRain > now then
		rainLabel.Text = "ITEM RAIN IN " .. Format.duration(nextRain - now)
	end
end

function HUD.menuButton(id: string): TextButton
	return menuButtons[id]
end

function HUD.steadyButton(): TextButton
	return steadyButton
end

function HUD.dashButton(): TextButton
	return dashButton
end

function HUD.glueButton(): TextButton
	return glueButton
end

function HUD.gui(): ScreenGui
	return gui
end

function HUD.init()
	gui = create("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		Parent = player:WaitForChild("PlayerGui"),
	})
	buildTop()
	buildStackPanel()
	buildMenuButtons()
	buildActions()
	buildToasts()
	local function layout()
		local width, height = gui.AbsoluteSize.X, gui.AbsoluteSize.Y
		local compact = width < 900 or height < 550
		local column = gui:FindFirstChild("Menu") :: Frame
		local old = column:FindFirstChildOfClass("UIListLayout")
		if old then
			old:Destroy()
		end
		local grid = column:FindFirstChildOfClass("UIGridLayout") or Instance.new("UIGridLayout")
		grid.CellPadding = UDim2.fromOffset(6, 6)
		grid.CellSize = UDim2.fromOffset(if compact then 48 else 66, if compact then 48 else 66)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = column
		local portrait = width < 600
		grid.FillDirectionMaxCells = if portrait then 5 elseif compact then 2 else 1
		column.AnchorPoint = if portrait then Vector2.new(0.5, 0) else Vector2.new(0, 0.5)
		column.Position = if portrait then UDim2.new(0.5, 0, 0, 60) else UDim2.new(0, 10, 0.5, 12)
		column.Size = if portrait
			then UDim2.fromOffset(264, 48)
			elseif compact then UDim2.fromOffset(102, 156)
			else UDim2.fromOffset(66, 354)
		collectionLabel.Visible = false
		coinsFrame.Size = UDim2.fromOffset(if compact then 190 else 230, 48)
		boostLabel.Position = UDim2.new(0.5, -65, 1, 0)
		-- All critical stack information stays inside the central safe column,
		-- clear of Roblox's player list and the touch movement/action corners.
		local top = if portrait then 116 else 62
		stackFrame.AnchorPoint = Vector2.new(0.5, 0)
		stackFrame.Position = UDim2.new(0.5, 0, 0, top)
		stackFrame.Size = UDim2.fromOffset(if portrait then math.min(width - 24, 300) else 300, 60)
		stackCount.Size = UDim2.new(1, 0, 0, 20)
		stackCount.TextXAlignment = Enum.TextXAlignment.Center
		stackDetail.Position = UDim2.fromOffset(0, 22)
		stackDetail.Size = UDim2.new(1, 0, 0, 20)
		stackDetail.TextXAlignment = Enum.TextXAlignment.Center
		wobbleFrame.Position = UDim2.new(0.5, 0, 0, top + 66)
		wobbleFrame.Size = UDim2.new(0, if portrait then math.min(width - 24, 300) else 300, 0, 22)
		rainLabel.AnchorPoint = Vector2.new(0.5, 1)
		rainLabel.Position = UDim2.new(0.5, 0, 1, -62)
		rainLabel.Size = UDim2.new(0.45, 0, 0, 18)
		toastList.Position = UDim2.new(0.5, 0, 0, top + 96)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	layout()
	task.spawn(followJumpButton)

	ClientState.Changed:Connect(refreshData)
	ClientState.StackChanged:Connect(function()
		refreshStack()
		refreshData()
	end)
	refreshStack()
	windLoop = Audio.loop("Wobble")
	RunService.Heartbeat:Connect(updateWobble)

	local lastWobbleWarn = 0
	player:GetAttributeChangedSignal("Wobble"):Connect(function()
		local w = ClientState.wobble()
		if w > 0.8 and os.clock() - lastWobbleWarn > 4 then
			lastWobbleWarn = os.clock()
			UIKit.pop(wobbleFrame, 0.2)
		end
	end)

	Remotes.Notify.OnClientEvent:Connect(function(message)
		if typeof(message) ~= "table" or typeof(message.Text) ~= "string" then
			return
		end
		HUD.toast(message.Text, message.Kind)
		if message.Kind == "Glue" then
			Audio.play("Glue")
		elseif message.Kind == "Unlock" or message.Kind == "Daily" then
			Audio.play("Upgrade", 1.2)
		elseif message.Kind == "Error" then
			Audio.play("Error")
		end
	end)

	Remotes.Banked.OnClientEvent:Connect(function(info)
		if typeof(info) ~= "table" then
			return
		end
		Audio.play("Bank", 1 + math.min(info.Count, 50) * 0.01)
		showBankPopup(info)
		toastQuietUntil = os.clock() + 3.3
		for _, child in toastList:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		local reward = nil
		if info.NewRecord and info.Count >= 10 and info.PreviousBest and info.PreviousBest < 10 then
			reward = "PIZZA TRAY unlocked — try it in SHOP!"
		elseif #(info.Milestones or {}) > 0 then
			local milestone = info.Milestones[#info.Milestones]
			reward = string.format("%s unlocked! +%d glue", milestone.Title, milestone.Glue)
		end
		if reward then
			task.delay(3.4, function()
				HUD.toast(reward, "Unlock")
			end)
		end
	end)

	-- Meme items get a shout-out on pickup: they are the "screenshot this" moments.
	Remotes.PickedUp.OnClientEvent:Connect(function(list)
		if typeof(list) ~= "table" then
			return
		end
		for _, entry in list do
			local code = typeof(entry) == "table" and entry[1]
			if typeof(code) == "string" then
				local def = ItemConfig.ById[StackCodec.parse(code)]
				if def and def.Meme and os.clock() - lastMemeToast > 3 then
					lastMemeToast = os.clock()
					HUD.toast("😂 MEME: " .. def.Name .. "!", "Meme")
				end
			end
		end
	end)

	Remotes.Bumped.OnClientEvent:Connect(function(otherUserId, isVictim)
		local other = Players:GetPlayerByUserId(otherUserId)
		local name = if other then other.DisplayName else "Someone"
		if isVictim then
			HUD.toast(name .. " bumped you!", "Collapse")
		else
			HUD.toast("You bumped " .. name .. "!", "Info")
		end
	end)
end

return HUD
