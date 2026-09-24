local T = _G.T
local Economy = require("../src/shared/Economy")
local EconomyConfig = require("../src/shared/Config/EconomyConfig")
local UpgradeConfig = require("../src/shared/Config/UpgradeConfig")

T.describe("Economy", function()
	T.it("height multiplier grows linearly and caps", function()
		local hb = EconomyConfig.HeightBonus
		T.eq(Economy.heightMultiplier(0, hb), 1)
		T.near(Economy.heightMultiplier(20, hb), 2, 1e-9)
		T.eq(Economy.heightMultiplier(10000, hb), hb.Max)
	end)

	T.it("bank payout applies rarity, height and coin multipliers", function()
		local entries = {}
		for _ = 1, 20 do
			table.insert(entries, { Value = 1, RarityMult = 1 })
		end
		entries[1].RarityMult = 25
		local total, base, mult = Economy.bankPayout(entries, 2, EconomyConfig.HeightBonus)
		T.eq(base, 44)
		T.near(mult, 2, 1e-9)
		T.eq(total, 176)
	end)

	T.it("empty stack pays nothing", function()
		local total = Economy.bankPayout({}, 5, EconomyConfig.HeightBonus)
		T.eq(total, 0)
	end)

	T.it("upgrade costs rise and stop at max level", function()
		local speed = UpgradeConfig.Upgrades.Speed
		T.eq(Economy.upgradeCost(speed, 0), speed.BaseCost)
		T.truthy(Economy.upgradeCost(speed, 1) > speed.BaseCost)
		T.eq(Economy.upgradeCost(speed, speed.MaxLevel), nil)
	end)

	T.it("strength uses explicit costs per level", function()
		local strength = UpgradeConfig.Upgrades.Strength
		T.eq(Economy.upgradeCost(strength, 1), strength.Costs[1])
		T.eq(Economy.upgradeCost(strength, 3), strength.Costs[3])
		T.eq(Economy.upgradeCost(strength, strength.MaxLevel), nil)
	end)

	T.it("every upgrade has a cost for every level below max", function()
		for id, def in UpgradeConfig.Upgrades do
			for level = def.StartLevel, def.MaxLevel - 1 do
				local cost = Economy.upgradeCost(def, level)
				T.truthy(type(cost) == "number" and cost > 0, id .. " level " .. level)
			end
		end
	end)

	T.it("daily streak continues, resets and refuses double claims", function()
		local ok, streak = Economy.nextStreak(0, 0, 100)
		T.eq(ok, true)
		T.eq(streak, 1)
		ok, streak = Economy.nextStreak(100, 1, 101)
		T.eq(ok, true)
		T.eq(streak, 2)
		ok, streak = Economy.nextStreak(101, 2, 101)
		T.eq(ok, false)
		T.eq(streak, 2)
		ok, streak = Economy.nextStreak(101, 5, 104)
		T.eq(ok, true)
		T.eq(streak, 1)
	end)

	T.it("daily rewards loop after a week", function()
		T.eq(Economy.dailyReward(1, EconomyConfig), EconomyConfig.DailyRewards[1])
		T.eq(Economy.dailyReward(8, EconomyConfig), EconomyConfig.DailyRewards[1])
		T.eq(Economy.dailyReward(7, EconomyConfig), EconomyConfig.DailyRewards[7])
	end)

	T.it("milestones fire once when crossed", function()
		local reached = Economy.newMilestones(5, 30, EconomyConfig)
		T.eq(#reached, 2)
		T.eq(#Economy.newMilestones(30, 30, EconomyConfig), 0)
		T.eq(Economy.titleFor(30, EconomyConfig), "Wobbler")
		T.eq(Economy.titleFor(3, EconomyConfig), nil)
	end)

	T.it("tier scale clamps", function()
		T.eq(Economy.tierScale(0, EconomyConfig), EconomyConfig.TierScale[1])
		T.eq(Economy.tierScale(99, EconomyConfig), EconomyConfig.TierScale[#EconomyConfig.TierScale])
	end)
end)
