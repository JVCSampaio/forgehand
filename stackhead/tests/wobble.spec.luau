local T = _G.T
local Wobble = require("../src/shared/Wobble")
local GameConfig = require("../src/shared/Config/GameConfig")

local cfg = GameConfig.Wobble

local function walk(state, height, balance, seconds, vx, vz)
	local dt = 1 / GameConfig.TickRate
	for _ = 1, math.floor(seconds / dt) do
		Wobble.step(state, { Dt = dt, VelX = vx, VelY = 0, VelZ = vz, Height = height, BalanceMult = balance }, cfg)
	end
	return state.Value
end

T.describe("Wobble", function()
	T.it("short stacks never wobble", function()
		local state = Wobble.newState()
		for _ = 1, 50 do
			walk(state, cfg.SafeHeight, 1, 0.3, 16, 0)
			walk(state, cfg.SafeHeight, 1, 0.3, -16, 0)
		end
		T.eq(state.Value, 0)
	end)

	T.it("standing still drains wobble", function()
		local state = Wobble.newState()
		state.Value = 0.8
		walk(state, 60, 1, 3, 0, 0)
		T.eq(state.Value, 0)
	end)

	T.it("a sharp reversal hurts tall stacks more than short ones", function()
		local short, tall = Wobble.newState(), Wobble.newState()
		walk(short, 20, 1, 1, 16, 0)
		walk(tall, 80, 1, 1, 16, 0)
		local s0, t0 = short.Value, tall.Value
		walk(short, 20, 1, 0.1, -16, 0)
		walk(tall, 80, 1, 0.1, -16, 0)
		T.truthy(tall.Value - t0 > (short.Value - s0) * 2, "tall stack should gain much more wobble")
	end)

	T.it("balance upgrades reduce wobble gain", function()
		local weak, strong = Wobble.newState(), Wobble.newState()
		local strongMult = Wobble.balanceMultiplier(10, cfg)
		for _ = 1, 6 do
			walk(weak, 70, 1, 0.5, 16, 0)
			walk(weak, 70, 1, 0.5, 0, 16)
			walk(strong, 70, strongMult, 0.5, 16, 0)
			walk(strong, 70, strongMult, 0.5, 0, 16)
		end
		T.truthy(strong.Value < weak.Value, "balanced player wobbles less")
	end)

	T.it("a ~25 item stack survives steady walking with turns", function()
		local state = Wobble.newState()
		-- ~25 market items is about 20 studs tall.
		for _ = 1, 10 do
			walk(state, 22, 1, 2, 16, 0)
			walk(state, 22, 1, 2, 0, 16)
		end
		T.truthy(state.Value < 1, "value " .. state.Value)
	end)

	T.it("a 100-stud stack with no balance collapses from zig-zagging", function()
		local state = Wobble.newState()
		for _ = 1, 20 do
			walk(state, 100, 1, 0.3, 16, 0)
			walk(state, 100, 1, 0.3, -16, 0)
		end
		T.truthy(state.Value >= 1, "value " .. state.Value)
	end)

	T.it("jumps add a kick", function()
		local state = Wobble.newState()
		Wobble.step(state, { Dt = 0.1, VelX = 0, VelY = 0, VelZ = 0, Height = 60, BalanceMult = 1 }, cfg)
		Wobble.step(state, { Dt = 0.1, VelX = 0, VelY = 50, VelZ = 0, Height = 60, BalanceMult = 1 }, cfg)
		T.truthy(state.Value > 0.1)
	end)

	T.it("kicks scale with height", function()
		local a, b = Wobble.newState(), Wobble.newState()
		Wobble.kick(a, 0.5, 30, 1, cfg)
		Wobble.kick(b, 0.5, 120, 1, cfg)
		T.truthy(b.Value > a.Value * 3)
		local c = Wobble.newState()
		Wobble.kick(c, 0.5, cfg.SafeHeight, 1, cfg)
		T.eq(c.Value, 0)
	end)

	T.it("collapse keeps the bottom half", function()
		T.eq(Wobble.keepCount(10, cfg), 5)
		T.eq(Wobble.keepCount(1, cfg), 0)
	end)
end)
