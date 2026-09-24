local T = _G.T
local Worlds = require("../src/shared/Worlds")
local WorldConfig = require("../src/shared/Config/WorldConfig")

local index = Worlds.new(WorldConfig)

T.describe("Worlds", function()
	T.it("finds the world a position belongs to", function()
		T.eq(index:at(Vector3.new(0, 0, 0)).Id, "Stackville")
		T.eq(index:at(Vector3.new(WorldConfig.Spacing + 100, 0, -50)).Id, "Frostpeak")
		T.eq(index:at(Vector3.new(-5000, 0, 0)).Id, "Stackville")
		T.eq(index:at(Vector3.new(99999, 0, 0)).Id, WorldConfig.Worlds[#WorldConfig.Worlds].Id)
	end)

	T.it("finds zones relative to each world's centre", function()
		local zone = index:zoneAt(Vector3.new(WorldConfig.Spacing * 2 + 100, 0, 0))
		T.eq(zone.Key, "CandyCoast.Bakery")
		local bank = index:zoneAt(Vector3.new(WorldConfig.Spacing * 2 + 5, 0, 0))
		T.eq(bank, nil)
	end)

	T.it("maps tiers to worlds and unlocks on first tier", function()
		T.eq(index:worldForTier(5).Id, "Frostpeak")
		T.eq(index:zoneForTier(16).Key, "NeonCity.Skyline")
		T.eq(index:isUnlocked(index:get("Frostpeak"), 4), false)
		T.eq(index:isUnlocked(index:get("Frostpeak"), 5), true)
		T.eq(index:maxTier(), 16)
	end)
end)
