-- Server entry point. Order matters: data first, then the world, then the
-- systems that depend on both.

local Services = script.Parent.Services

local order = {
	"DataService",
	"MonetizationService",
	"StatsService",
	"WorldService",
	"ItemSpawnService",
	"StackService",
	"UpgradeService",
	"TravelService",
	"SessionService",
	"EventService",
	"LeaderboardService",
}

for _, name in order do
	local started = os.clock()
	require(Services[name]).init()
	print(string.format("[Stackhead] %s ready (%.0f ms)", name, (os.clock() - started) * 1000))
end
