-- Game passes, developer products and Premium perks.
-- Receipts are idempotent: every PurchaseId is stored in the profile and the
-- grant is only confirmed to Roblox after the profile saved successfully.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local Economy = require(Shared.Economy)
local Remotes = require(Shared.Remotes)
local Schema = require(script.Parent.Parent.Util.PlayerDataSchema)
local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.Analytics)

local MonetizationService = {}

local owned: { [Player]: { [string]: boolean } } = {}
local passKeyById: { [number]: string } = {}
local productKeyById: { [number]: string } = {}
local passChangedCallbacks = {}
local rainHandler: ((Player) -> ())? = nil
local goldenHourHandler: ((Player, number) -> ())? = nil

for key, pass in MonetizationConfig.GamePasses do
	if pass.Id ~= 0 then
		passKeyById[pass.Id] = key
	end
end
for key, product in MonetizationConfig.Products do
	if product.Id ~= 0 then
		productKeyById[product.Id] = key
	end
end

function MonetizationService.ownsPass(player: Player, key: string): boolean
	local set = owned[player]
	return set ~= nil and set[key] == true
end

function MonetizationService.isPremium(player: Player): boolean
	return player.MembershipType == Enum.MembershipType.Premium
end

function MonetizationService.boostActive(profile): boolean
	return profile.BoostEndsAt > os.time()
end

function MonetizationService.coinMultiplier(player: Player, profile): number
	local mult = 1
	for key, pass in MonetizationConfig.GamePasses do
		if pass.CoinMult and MonetizationService.ownsPass(player, key) then
			mult *= pass.CoinMult
		end
	end
	if MonetizationService.isPremium(player) then
		mult *= EconomyConfig.PremiumCoinMult
	end
	if MonetizationService.boostActive(profile) then
		mult *= 2
	end
	return mult
end

function MonetizationService.bonusReach(player: Player): number
	local bonus = 0
	for key, pass in MonetizationConfig.GamePasses do
		if pass.BonusReach and MonetizationService.ownsPass(player, key) then
			bonus += pass.BonusReach
		end
	end
	return bonus
end

function MonetizationService.dailyGlueBonus(player: Player): number
	local bonus = 0
	for key, pass in MonetizationConfig.GamePasses do
		if pass.DailyGlue and MonetizationService.ownsPass(player, key) then
			bonus += pass.DailyGlue
		end
	end
	if MonetizationService.isPremium(player) then
		bonus += 1
	end
	return bonus
end

function MonetizationService.onPassChanged(callback: (Player) -> ())
	table.insert(passChangedCallbacks, callback)
end

function MonetizationService.setRainHandler(handler: (Player) -> ())
	rainHandler = handler
end

function MonetizationService.setGoldenHourHandler(handler: (Player, number) -> ())
	goldenHourHandler = handler
end

local function firePassChanged(player: Player)
	for _, callback in passChangedCallbacks do
		task.spawn(callback, player)
	end
	DataService.changed(player)
end

local function refreshPasses(player: Player)
	local set = {}
	for key, pass in MonetizationConfig.GamePasses do
		if pass.Id ~= 0 then
			local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			set[key] = ok and result == true
		end
	end
	if player.Parent then
		owned[player] = set
		firePassChanged(player)
	end
end

local function grant(player: Player, profile, product): boolean
	local g = product.Grant
	local repeatOneTime = product.OneTime and profile.Flags.StarterPack
	if product.OneTime then
		profile.Flags.StarterPack = true
	end
	if g.Cosmetic and not repeatOneTime then
		profile.Cosmetics.Owned[g.Cosmetic] = true
	end
	if g.GoldenHour then
		if not goldenHourHandler then
			return false
		end
		goldenHourHandler(player, g.GoldenHour)
	end
	if g.Glue then
		profile.Glue = math.min(EconomyConfig.MaxGlue, profile.Glue + g.Glue)
	end
	if g.BoostSeconds and not repeatOneTime then
		profile.BoostEndsAt = math.max(os.time(), profile.BoostEndsAt) + g.BoostSeconds
	end
	if g.ScaledCoins then
		local amount = g.ScaledCoins * Economy.tierScale(profile.Upgrades.Strength, EconomyConfig)
		profile.Coins += amount
		Analytics.source(player, amount, profile.Coins, Enum.AnalyticsEconomyTransactionType.IAP.Name, product.DisplayName)
	end
	if g.ItemRain then
		if not rainHandler then
			return false
		end
		rainHandler(player)
	end
	return true
end

local function processReceipt(receipt)
	local key = productKeyById[receipt.ProductId]
	if not key then
		warn("[Monetization] unknown product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = DataService.waitForProfile(player, 15)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if profile.Purchases[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local product = MonetizationConfig.Products[key]
	if not grant(player, profile, product) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Schema.recordPurchase(profile, purchaseId, MonetizationConfig.ReceiptHistory)
	profile.Stats.RobuxSpent += receipt.CurrencySpent or 0

	-- If this save fails Roblox retries later. The purchase id stays in the
	-- in-memory profile, so a retry in this session is still idempotent, and
	-- the next autosave persists grant + id together.
	if not DataService.forceSave(player) then
		DataService.changed(player)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	Analytics.custom(player, "Purchase_" .. key, receipt.CurrencySpent)
	Remotes.Notify:FireClient(player, { Kind = "Purchase", Text = "Thanks! " .. product.DisplayName .. " received." })
	DataService.changed(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.init()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passKeyById[passId]
		if purchased and key and owned[player] then
			owned[player][key] = true
			Analytics.custom(player, "PassPurchase_" .. key)
			Remotes.Notify:FireClient(player, { Kind = "Purchase", Text = "Thanks! " .. MonetizationConfig.GamePasses[key].DisplayName .. " unlocked." })
			firePassChanged(player)
		end
	end)

	Players.PlayerMembershipChanged:Connect(function(player)
		firePassChanged(player)
	end)

	DataService.onLoaded(function(player)
		owned[player] = {}
		refreshPasses(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)

	DataService.addSyncBuilder(function(player, profile, snapshot)
		local passes = {}
		for key in MonetizationConfig.GamePasses do
			passes[key] = MonetizationService.ownsPass(player, key)
		end
		snapshot.Passes = passes
		snapshot.Premium = MonetizationService.isPremium(player)
		snapshot.CoinMult = MonetizationService.coinMultiplier(player, profile)
	end)
end

return MonetizationService
