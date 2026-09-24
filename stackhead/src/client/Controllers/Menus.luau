-- Upgrade and Shop panels. One modal at a time, never opened automatically:
-- the shop only appears when the player taps it.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)
local Cosmetics = require(Shared.Cosmetics)
local Economy = require(Shared.Economy)
local Orders = require(Shared.Orders)
local ItemConfig = require(Shared.Config.ItemConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
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

local function makePanel(title: string, quiet: boolean?): (Frame, ScrollingFrame)
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
	if not quiet then
		UIKit.pop(panel, 0.08)
	end
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

local function sectionHeader(list: Instance, order: number, text: string)
	local frame = create("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -10, 0, 30),
		BackgroundTransparency = 1,
		ZIndex = 11,
		Parent = list,
	})
	UIKit.label({
		Text = text,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Gold,
		ZIndex = 12,
		Parent = frame,
	})
end

local BASE_PASSES = { UfoBase = true, FlameBase = true }

function Menus.openShop(quiet: boolean?)
	local _, list = makePanel("🛒 SHOP", quiet)
	local data = ClientState.Data
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	local function buyButton(parent: Instance, key: string, spec, isPass: boolean, owned: boolean?)
		local button = UIKit.button({
			Text = if owned then "OWNED" else "…",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0.34, 0, 0, 54),
			BackgroundColor3 = if owned then C.Disabled else C.Purple,
			ZIndex = 12,
			Parent = parent,
		})
		if owned then
			return button
		end
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
		return button
	end

	local function textRow(title: string, body: string, height: number): Frame
		local frame = row(list, nextOrder(), height)
		UIKit.label({
			Text = title,
			Size = UDim2.new(0.62, 0, 0, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,
			Parent = frame,
		})
		UIKit.label({
			Text = body,
			Position = UDim2.fromOffset(0, 32),
			Size = UDim2.new(0.62, 0, 0, height - 44),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			Font = UIKit.Fonts.Body,
			TextColor3 = C.SubText,
			ZIndex = 12,
			Parent = frame,
		})
		return frame
	end

	-- One-time starter offer, only until bought.
	local starter = MonetizationConfig.Products.StarterPack
	if starter.Id ~= 0 and data and not data.StarterPackBought then
		local frame = textRow(starter.Icon .. " " .. starter.DisplayName .. " (one time)", starter.Description, 80)
		frame.BackgroundColor3 = C.Purple:Lerp(C.PanelLight, 0.5)
		buyButton(frame, "StarterPack", starter, false)
	end

	-- Stack bases: earned and premium.
	sectionHeader(list, nextOrder(), "🎩 STACK BASES — everyone sees them")
	for _, base in CosmeticConfig.Bases do
		local unlocked = data and data.Cosmetics and data.Cosmetics.Unlocked[base.Id]
		local equipped = data and data.Cosmetics and data.Cosmetics.Equipped == base.Id
		local passKey = base.Unlock.Kind == "Pass" and base.Unlock.Pass or nil
		local pass = passKey and MonetizationConfig.GamePasses[passKey]
		if unlocked or not (pass and pass.Id == 0) then
			local detail = if unlocked then "Unlocked" else "🔒 " .. Cosmetics.requirement(base)
			local frame = textRow(base.Icon .. " " .. base.Name, detail, 70)
			if unlocked then
				local button = UIKit.button({
					Text = if equipped then "EQUIPPED" else "EQUIP",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.new(0.34, 0, 0, 50),
					BackgroundColor3 = if equipped then C.Disabled else C.Green,
					ZIndex = 12,
					Parent = frame,
				})
				if not equipped then
					button.Activated:Connect(function()
						Audio.play("Upgrade", 1.4)
						Remotes.EquipCosmetic:FireServer(base.Id)
					end)
				end
			elseif pass and passKey then
				buyButton(frame, passKey, pass, true)
			end
		end
	end

	local any = false
	sectionHeader(list, nextOrder(), "⭐ PASSES")
	for _, key in MonetizationConfig.PassOrder do
		local spec = MonetizationConfig.GamePasses[key]
		if spec.Id ~= 0 and not BASE_PASSES[key] then
			any = true
			local owned = data and data.Passes and data.Passes[key]
			local frame = textRow(spec.Icon .. " " .. spec.DisplayName, spec.Description, 74)
			buyButton(frame, key, spec, true, owned)
		end
	end
	sectionHeader(list, nextOrder(), "⚡ BOOSTS & EVENTS")
	for _, key in MonetizationConfig.ProductOrder do
		local spec = MonetizationConfig.Products[key]
		if spec.Id ~= 0 and key ~= "StarterPack" then
			any = true
			local frame = textRow(spec.Icon .. " " .. spec.DisplayName, spec.Description, 74)
			buyButton(frame, key, spec, false)
		end
	end
	if not any then
		textRow("More coming soon!", "Passes and boosts appear here once they're live.", 70)
	end
	textRow(
		"🧴 About glue",
		string.format(
			"Glue saves a collapsing stack once. Arm it before a risky trip. You have %d; earn more from daily rewards, orders and stack records.",
			if data then data.Glue else 0
		),
		84
	)
end

local function progressBar(parent: Instance, fraction: number, color: Color3)
	local bar = create("Frame", {
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(0.62, 0, 0, 12),
		BackgroundColor3 = C.Panel,
		ZIndex = 12,
		Parent = parent,
	}, { UIKit.corner(6) })
	create("Frame", {
		Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1),
		BackgroundColor3 = color,
		ZIndex = 13,
		Parent = bar,
	}, { UIKit.corner(6) })
end

function Menus.openTasks(quiet: boolean?)
	local _, list = makePanel("📋 TASKS", quiet)
	local data = ClientState.Data
	if not data then
		return
	end
	-- Daily login reward.
	local canClaim = data.DailyLastClaimDay < data.Today
	local nextStreak = if data.DailyLastClaimDay == data.Today - 1 then data.DailyStreak + 1 else 1
	local streakDay = if canClaim then nextStreak else data.DailyStreak
	local reward = Economy.dailyReward(math.max(streakDay, 1), EconomyConfig)
	local scale = Economy.tierScale(data.Upgrades.Strength, EconomyConfig)
	local daily = row(list, 1, 80)
	UIKit.label({
		Text = string.format("🎁 Daily reward — day %d", math.max(streakDay, 1)),
		Size = UDim2.new(0.62, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
		Parent = daily,
	})
	UIKit.label({
		Text = string.format("🪙 %s%s · come back tomorrow for a bigger one", Format.short(reward.Coins * scale), if reward.Glue > 0 then string.format(" + 🧴%d", reward.Glue) else ""),
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(0.62, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Font = UIKit.Fonts.Body,
		TextColor3 = C.SubText,
		ZIndex = 12,
		Parent = daily,
	})
	local claimDaily = UIKit.button({
		Text = if canClaim then "CLAIM" else "CLAIMED",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0.34, 0, 0, 54),
		BackgroundColor3 = if canClaim then C.Green else C.Disabled,
		ZIndex = 12,
		Parent = daily,
	})
	if canClaim then
		claimDaily.Activated:Connect(function()
			Audio.play("Upgrade", 1.2)
			Remotes.ClaimDaily:FireServer()
			claimDaily.Text = "CLAIMED"
			claimDaily.BackgroundColor3 = C.Disabled
		end)
	end

	-- Today's orders.
	if not data.Orders then
		return
	end
	for i, order in data.Orders.List do
		local progress = data.Orders.Progress[i]
		local claimed = data.Orders.Claimed[i]
		local ready = not claimed and progress >= order.Target
		local frame = row(list, 1 + i, 80)
		local item = order.ItemId and ItemConfig.ById[order.ItemId]
		UIKit.label({
			Text = Orders.describe(order, item and item.Name or nil),
			Size = UDim2.new(0.62, 0, 0, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,
			Parent = frame,
		})
		UIKit.label({
			Text = string.format("%s / %s · reward 🪙%s%s", Format.short(math.min(progress, order.Target)), Format.short(order.Target), Format.short(order.RewardCoins), if order.RewardGlue > 0 then " + 🧴" .. order.RewardGlue else ""),
			Position = UDim2.fromOffset(0, 32),
			Size = UDim2.new(0.62, 0, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = UIKit.Fonts.Body,
			TextColor3 = C.SubText,
			ZIndex = 12,
			Parent = frame,
		})
		progressBar(frame, progress / order.Target, if ready or claimed then C.Green else C.Gold)
		local button = UIKit.button({
			Text = if claimed then "DONE" elseif ready then "CLAIM" else "…",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0.34, 0, 0, 54),
			BackgroundColor3 = if ready then C.Green else C.Disabled,
			ZIndex = 12,
			Parent = frame,
		})
		if ready then
			button.Activated:Connect(function()
				Audio.play("Upgrade", 1.3)
				Remotes.ClaimOrder:FireServer(i)
				button.Text = "DONE"
				button.BackgroundColor3 = C.Disabled
			end)
		end
	end
	local footer = row(list, 10, 40)
	footer.BackgroundTransparency = 1
	UIKit.label({
		Text = "New orders every day at 00:00 UTC.",
		Size = UDim2.fromScale(1, 1),
		Font = UIKit.Fonts.Body,
		TextColor3 = C.SubText,
		ZIndex = 12,
		Parent = footer,
	})
end

function Menus.openWorlds(quiet: boolean?)
	local _, list = makePanel("🌍 WORLDS", quiet)
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
	HUD.menuButton("Tasks").Activated:Connect(function()
		Audio.play("Click")
		if openPanel and openPanel.Name == "📋 TASKS" then
			closePanel()
		else
			Menus.openTasks()
		end
	end)
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
	ClientState.Changed:Connect(function()
		refreshUpgrades()
		-- Live panels redraw with the new snapshot.
		if openPanel and openPanel.Name == "📋 TASKS" then
			Menus.openTasks(true)
		elseif openPanel and openPanel.Name == "🌍 WORLDS" then
			Menus.openWorlds(true)
		elseif openPanel and openPanel.Name == "🛒 SHOP" then
			Menus.openShop(true)
		end
	end)
end

return Menus
