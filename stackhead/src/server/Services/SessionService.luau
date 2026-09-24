-- Daily login streak rewards and session-length analytics.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local EconomyConfig = require(Shared.Config.EconomyConfig)
local Economy = require(Shared.Economy)
local Remotes = require(Shared.Remotes)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local Analytics = require(script.Parent.Analytics)

local SessionService = {}

local limiter = RateLimiter.new(2, 0.5)

function SessionService.claimDaily(player: Player): boolean
	local profile = DataService.getProfile(player)
	if not profile then
		return false
	end
	local today = Economy.dayIndex(os.time())
	local canClaim, streak = Economy.nextStreak(profile.Daily.LastClaimDay, profile.Daily.Streak, today)
	if not canClaim then
		return false
	end
	local reward = Economy.dailyReward(streak, EconomyConfig)
	local coins = reward.Coins * Economy.tierScale(profile.Upgrades.Strength, EconomyConfig)
	local glue = reward.Glue + MonetizationService.dailyGlueBonus(player)

	profile.Daily.Streak = streak
	profile.Daily.LastClaimDay = today
	profile.Coins += coins
	profile.Glue = math.min(EconomyConfig.MaxGlue, profile.Glue + glue)

	local text = string.format("Day %d reward: +%d coins", streak, coins)
	if glue > 0 then
		text ..= string.format(" and +%d glue", glue)
	end
	Remotes.Notify:FireClient(player, { Kind = "Daily", Text = text })
	Analytics.source(player, coins, profile.Coins, Enum.AnalyticsEconomyTransactionType.Gameplay.Name, "Daily")
	Analytics.custom(player, "DailyStreak", streak)
	DataService.changed(player)
	return true
end

function SessionService.init()
	Remotes.ClaimDaily.OnServerEvent:Connect(function(player)
		if limiter:allow(player) then
			SessionService.claimDaily(player)
		end
	end)

	DataService.onLoaded(function(player, profile)
		if profile.Stats.Sessions == 1 then
			Analytics.funnel(player, profile, "Joined")
		else
			local daysAway = math.floor((os.time() - profile.Stats.FirstJoin) / 86400)
			Analytics.custom(player, "ReturnSession", daysAway)
		end
	end)

	-- Playtime funnel steps.
	task.spawn(function()
		while true do
			task.wait(15)
			for _, player in Players:GetPlayers() do
				local profile = DataService.getProfile(player)
				if profile then
					local minutes = DataService.sessionMinutes(player)
					if minutes >= 5 then
						Analytics.funnel(player, profile, "Played5Min")
					end
					if minutes >= 10 then
						Analytics.funnel(player, profile, "Played10Min")
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		if DataService.getProfile(player) then
			Analytics.custom(player, "SessionMinutes", math.floor(DataService.sessionMinutes(player)))
		end
	end)
end

return SessionService
