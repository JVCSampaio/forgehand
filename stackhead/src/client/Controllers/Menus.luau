-- Upgrade and Shop panels. One modal at a time, never opened automatically:
-- the shop only appears when the player taps it.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Economy = require(Shared.Economy)
local WorldIndex = require(Shared.WorldIndex)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local ClientState = require(script.Parent.ClientState)
local Audio = require(script.Parent.Audio)
local HUD = require(script.Parent.HUD)

local Menus = {}

local C = UIKit.Colors
local create = UIKit.create
local player = Players.LocalPlayer

local openPanel: Frame? = nil
local upgradeRows: { [string]: any } = {}
local priceCache: { [string]: number } = {}

local function closePanel()
	if openPanel then
		openPanel:Destroy()
		openPanel = nil
	end
end

local function makePanel(title: string): (Frame, ScrollingFrame)
	closePanel()
	local panel = create("Frame", {
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.92, 0.78),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.04,
		ZIndex = 10,
		Parent = HUD.gui(),
	}, {
		UIKit.corner(20),
		UIKit.stroke(4),
		create("UISizeConstraint", { MaxSize = Vector2.new(560, 520) }),
	})
	UIKit.label({
		Text = title,
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -90, 0, 42),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
		Parent = panel,
	})
	local close = UIKit.button({
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = C.Red,
		ZIndex = 11,
		Parent = panel,
	})
	close.Activated:Connect(function()
		Audio.play("Click")
		closePanel()
	end)
	local list = create("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 66),
		Size = UDim2.new(1, -24, 1, -78),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 11,
		Parent = panel,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	openPanel = panel
	UIKit.pop(panel, 0.08)
	return panel, list
end

local function row(parent: Instance, order: number, height: number): Frame
	return create("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -10, 0, height),
		BackgroundColor3 = C.PanelLight,
		ZIndex = 11,
		Parent = parent,
	}, { UIKit.corner(14), UIKit.padding(8) })
end

local function formatValue(def, level: number): string
	local value = Economy.upgradeValue(def, level)
	if def.Unit == "x" then
		return Format.multiplier(value)
	elseif def.Unit == "tier" then
		local zone = WorldIndex:zoneForTier(level)
		return if zone then zone.DisplayName else tostring(level)
	end
	return string.format("%g", math.floor(value * 10 + 0.5) / 10)
end

local function refreshUpgrades()
	local data = ClientState.Data
	if not data then
		return
	end
	for id, widgets in upgradeRows do
		if not widgets.Button.Parent then
			continue
		end
		local def = UpgradeConfig.Upgrades[id]
		local level = data.Upgrades[id]
		local cost = Economy.upgradeCost(def, level)
		local levelText = if def.Unit == "tier" then "" else string.format("  Lv %d/%d", level, def.MaxLevel)
		widgets.Title.Text = string.format("%s %s%s", def.Icon, def.DisplayName, levelText)
		if cost then
			widgets.Effect.Text = string.format("%s  →  %s", formatValue(def, level), formatValue(def, level + 1))
			widgets.Button.Text = "🪙 " .. Format.short(cost)
			widgets.Button.BackgroundColor3 = if data.Coins >= cost then C.Green else C.Disabled
		else
			widgets.Effect.Text = formatValue(def, level)
			widgets.Button.Text = "MAX"
			widgets.Button.BackgroundColor3 = C.Disabled
		end
	end
end

function Menus.openUpgrades()
	local _, list = makePanel("⬆️ UPGRADES")
	table.clear(upgradeRows)
	for order, id in UpgradeConfig.Order do
		local def = UpgradeConfig.Upgrades[id]
		local frame = row(list, order, 86)
		local title = UIKit.label({
			Size = UDim2.new(0.62, 0, 0, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,
			Parent = frame,
		})
		UIKit.label({
			Text = def.Description,
			Position = UDim2.fromOffset(0, 32),
			Size = UDim2.new(0.62, 0, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = UIKit.Fonts.Body,
			TextColor3 = C.SubText,
			ZIndex = 12,
			Parent = frame,
		})
		local effect = UIKit.label({
			Position = UDim2.fromOffset(0, 52),
			Size = UDim2.new(0.62, 0, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = UIKit.Fonts.Body,
			TextColor3 = C.Gold,
			ZIndex = 12,
			Parent = frame,
		})
		local button = UIKit.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0.34, 0, 0, 58),
			ZIndex = 12,
			Parent = frame,
		})
		button.Activated:Connect(function()
			local ok, result = Remotes.BuyUpgrade:InvokeServer(id)
			if ok then
				Audio.play("Upgrade", 1 + (result :: number) * 0.03)
				UIKit.pop(frame, 0.06)
			else
				Audio.play("Error")
				if result == "coins" then
					HUD.toast("Not enough coins yet — bank a taller stack!", "Error")
				end
			end
		end)
		upgradeRows[id] = { Title = title, Effect = effect, Button = button }
	end
	refreshUpgrades()
end

local function livePrice(key: string, id: number, infoType: Enum.InfoType, hint: number): number
	if priceCache[key] then
		return priceCache[key]
	end
	local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
	local price = if ok and info and info.PriceInRobux then info.PriceInRobux else hint
	priceCache[key] = price
	return price
end

function Menus.openShop()
	local _, list = makePanel("🛒 SHOP")
	local data = ClientState.Data
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	local glueInfo = row(list, nextOrder(), 70)
	UIKit.label({
		Text = string.format(
			"🧴 Glue saves a collapsing stack once. Arm it before a risky trip. You have %d — earn more from daily rewards and stack records.",
			if data then data.Glue else 0
		),
		Size = UDim2.fromScale(1, 1),
		Font = UIKit.Fonts.Body,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
		Parent = glueInfo,
	})

	local any = false
	local function entry(key: string, spec, isPass: boolean)
		if spec.Id == 0 then
			return
		end
		any = true
		local owned = isPass and data and data.Passes and data.Passes[key]
		local frame = row(list, nextOrder(), 74)
		UIKit.label({
			Text = spec.Icon .. " " .. spec.DisplayName,
			Size = UDim2.new(0.62, 0, 0, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,
			Parent = frame,
		})
		UIKit.label({
			Text = spec.Description,
			Position = UDim2.fromOffset(0, 32),
			Size = UDim2.new(0.62, 0, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Font = UIKit.Fonts.Body,
			TextColor3 = C.SubText,
			ZIndex = 12,
			Parent = frame,
		})
		local button = UIKit.button({
			Text = if owned then "OWNED" else "…",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0.34, 0, 0, 54),
			BackgroundColor3 = if owned then C.Disabled else C.Purple,
			ZIndex = 12,
			Parent = frame,
		})
		if not owned then
			task.spawn(function()
				local price = livePrice(key, spec.Id, if isPass then Enum.InfoType.GamePass else Enum.InfoType.Product, spec.PriceHint)
				if button.Parent then
					button.Text = "R$ " .. price
				end
			end)
			button.Activated:Connect(function()
				Audio.play("Click")
				if isPass then
					MarketplaceService:PromptGamePassPurchase(player, spec.Id)
				else
					MarketplaceService:PromptProductPurchase(player, spec.Id)
				end
			end)
		end
	end

	for _, key in MonetizationConfig.PassOrder do
		entry(key, MonetizationConfig.GamePasses[key], true)
	end
	for _, key in MonetizationConfig.ProductOrder do
		entry(key, MonetizationConfig.Products[key], false)
	end
	if not any then
		local frame = row(list, nextOrder(), 50)
		UIKit.label({
			Text = "More coming soon!",
			Size = UDim2.fromScale(1, 1),
			Font = UIKit.Fonts.Body,
			ZIndex = 12,
			Parent = frame,
		})
	end
end

function Menus.openWorlds()
	local _, list = makePanel("🌍 WORLDS")
	local data = ClientState.Data
	if not data then
		return
	end
	for order, world in WorldIndex.list do
		local frame = row(list, order, 86)
		frame.BackgroundColor3 = world.Bank.Floor:Lerp(C.PanelLight, 0.7)
		UIKit.label({
			Text = world.Icon .. " " .. world.DisplayName,
			Size = UDim2.new(0.62, 0, 0, 34),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,
			Parent = frame,
		})
		local unlocked = data.Upgrades.Strength >= world.FirstTier
		local items = {}
		for _, zone in world.Zones do
			table.insert(items, zone.DisplayName)
		end
		UIKit.label({
			Text = world.Tagline .. " · " .. table.concat(items, ", "),
			Position = UDim2.fromOffset(0, 38),
			Size = UDim2.new(0.62, 0, 0, 32),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Font = UIKit.Fonts.Body,
			TextColor3 = C.SubText,
			ZIndex = 12,
			Parent = frame,
		})
		local here = data.World == world.Id
		local button = UIKit.button({
			Text = if here then "YOU'RE HERE" elseif unlocked then "TRAVEL" else string.format("🔒 💪%d", world.FirstTier),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0.34, 0, 0, 58),
			BackgroundColor3 = if here then C.Disabled elseif unlocked then C.Green else C.Disabled,
			ZIndex = 12,
			Parent = frame,
		})
		if unlocked and not here then
			button.Activated:Connect(function()
				Audio.play("Click")
				Remotes.Travel:FireServer(world.Id)
				closePanel()
			end)
		elseif not unlocked then
			button.Activated:Connect(function()
				Audio.play("Error")
				HUD.toast(string.format("Reach Strength %d to unlock %s!", world.FirstTier, world.DisplayName), "Error")
			end)
		end
	end
end

function Menus.init()
	HUD.menuButton("Worlds").Activated:Connect(function()
		Audio.play("Click")
		if openPanel and openPanel.Name == "🌍 WORLDS" then
			closePanel()
		else
			Menus.openWorlds()
		end
	end)
	HUD.menuButton("Upgrades").Activated:Connect(function()
		Audio.play("Click")
		if openPanel and openPanel.Name == "⬆️ UPGRADES" then
			closePanel()
		else
			Menus.openUpgrades()
		end
	end)
	HUD.menuButton("Shop").Activated:Connect(function()
		Audio.play("Click")
		if openPanel and openPanel.Name == "🛒 SHOP" then
			closePanel()
		else
			Menus.openShop()
		end
	end)
	ClientState.Changed:Connect(refreshUpgrades)
end

return Menus
