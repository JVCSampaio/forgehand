-- Pure economy maths shared by server (authoritative) and client (previews).
-- No Roblox APIs so it can be unit tested and simulated outside the engine.

local Economy = {}

function Economy.heightMultiplier(count: number, heightBonus): number
	return math.min(1 + count * heightBonus.PerItem, heightBonus.Max)
end

-- entries: array of { Value: number, RarityMult: number }
function Economy.stackBaseValue(entries): number
	local total = 0
	for _, entry in entries do
		total += entry.Value * entry.RarityMult
	end
	return total
end

function Economy.bankPayout(entries, coinMult: number, heightBonus)
	local base = Economy.stackBaseValue(entries)
	local heightMult = Economy.heightMultiplier(#entries, heightBonus)
	local total = math.floor(base * heightMult * coinMult + 0.5)
	return total, base, heightMult
end

-- Cost of buying the next level when currently at `level`. nil when maxed.
function Economy.upgradeCost(def, level: number): number?
	if level >= def.MaxLevel then
		return nil
	end
	if def.Costs then
		return def.Costs[level - def.StartLevel + 1]
	end
	return math.floor(def.BaseCost * def.Growth ^ (level - def.StartLevel) + 0.5)
end

function Economy.upgradeValue(def, level: number): number
	return def.Base + def.PerLevel * level
end

function Economy.tierScale(strength: number, economyConfig): number
	local scales = economyConfig.TierScale
	return scales[math.clamp(strength, 1, #scales)]
end

function Economy.dayIndex(unixTime: number): number
	return math.floor(unixTime / 86400)
end

-- Returns (canClaim, newStreak) for a claim happening on `today`.
function Economy.nextStreak(lastClaimDay: number, streak: number, today: number): (boolean, number)
	if lastClaimDay >= today then
		return false, streak
	end
	if lastClaimDay == today - 1 then
		return true, streak + 1
	end
	return true, 1
end

function Economy.dailyReward(streak: number, economyConfig)
	local rewards = economyConfig.DailyRewards
	return rewards[((streak - 1) % #rewards) + 1]
end

-- Milestones newly reached when the best stack goes from oldBest to newBest.
function Economy.newMilestones(oldBest: number, newBest: number, economyConfig)
	local reached = {}
	for _, milestone in economyConfig.Milestones do
		if oldBest < milestone.Stack and newBest >= milestone.Stack then
			table.insert(reached, milestone)
		end
	end
	return reached
end

function Economy.titleFor(best: number, economyConfig): string?
	local title = nil
	for _, milestone in economyConfig.Milestones do
		if best >= milestone.Stack then
			title = milestone.Title
		end
	end
	return title
end

return Economy
