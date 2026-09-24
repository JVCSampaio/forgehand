-- Thin, failure-proof wrapper over AnalyticsService. Analytics must never
-- break gameplay, so every call is pcall'd. Only gameplay events are
-- recorded; no chat, no free text, no personal data.

local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Analytics = {}

local DEBUG = RunService:IsStudio()

-- Onboarding funnel. Steps are logged at most once per player (persisted in
-- profile.Funnel) and only for players who joined for the first time.
Analytics.Funnel = {
	{ Step = 1, Name = "Joined" },
	{ Step = 2, Name = "FirstPickup" },
	{ Step = 3, Name = "Stack5" },
	{ Step = 4, Name = "FirstBank" },
	{ Step = 5, Name = "FirstUpgrade" },
	{ Step = 6, Name = "Played5Min" },
	{ Step = 7, Name = "UnlockedYard" },
	{ Step = 8, Name = "Played10Min" },
	{ Step = 9, Name = "Stack25" },
	{ Step = 10, Name = "UnlockedFarm" },
}

local stepByName = {}
for _, step in Analytics.Funnel do
	stepByName[step.Name] = step
end

local function log(...)
	if DEBUG then
		print("[Analytics]", ...)
	end
end

function Analytics.funnel(player: Player, profile, name: string)
	local step = stepByName[name]
	if not step or profile.Funnel[name] then
		return
	end
	profile.Funnel[name] = true
	-- Only players whose first session is this one belong in the onboarding funnel.
	if profile.Stats.Sessions > 1 then
		return
	end
	log("funnel", player.UserId, step.Step, name)
	pcall(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, player, step.Step, name)
end

function Analytics.source(player: Player, amount: number, balance: number, transactionType: string, sku: string)
	log("source", player.UserId, amount, transactionType, sku)
	pcall(
		AnalyticsService.LogEconomyEvent,
		AnalyticsService,
		player,
		Enum.AnalyticsEconomyFlowType.Source,
		"Coins",
		amount,
		balance,
		transactionType,
		sku
	)
end

function Analytics.sink(player: Player, amount: number, balance: number, transactionType: string, sku: string)
	log("sink", player.UserId, amount, transactionType, sku)
	pcall(
		AnalyticsService.LogEconomyEvent,
		AnalyticsService,
		player,
		Enum.AnalyticsEconomyFlowType.Sink,
		"Coins",
		amount,
		balance,
		transactionType,
		sku
	)
end

function Analytics.progression(player: Player, path: string, level: number, levelName: string)
	log("progression", player.UserId, path, level, levelName)
	pcall(AnalyticsService.LogProgressionCompleteEvent, AnalyticsService, player, path, level, levelName)
end

function Analytics.custom(player: Player, name: string, value: number?)
	log("custom", player.UserId, name, value)
	pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, name, value or 1)
end

return Analytics
