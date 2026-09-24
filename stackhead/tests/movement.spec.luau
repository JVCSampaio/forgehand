local T = _G.T
local GameConfig = require("../src/shared/Config/GameConfig")
local MoveGuard = require("../src/server/Util/MoveGuard")

local CFG = GameConfig.Movement.Guard
local DT = 1 / GameConfig.TickRate
local WALK = GameConfig.Movement.BaseWalkSpeed
local ALLOWED = WALK * GameConfig.Movement.SpeedTolerance

local function inBank(position: Vector3): boolean
	return math.sqrt(position.X ^ 2 + position.Z ^ 2) <= GameConfig.Bank.Radius
end

T.describe("MoveGuard", function()
	T.it("accepts a full-speed walk from the edge of the island to the bank", function()
		local guard = MoveGuard.new(CFG)
		local x = 280
		guard:check(Vector3.new(x, 3, 0), DT, ALLOWED)
		while x > 0 do
			x = math.max(x - WALK * DT, 0)
			T.eq(guard:check(Vector3.new(x, 3, 0), DT, ALLOWED), "ok")
		end
		T.truthy(inBank(guard:position() :: Vector3))
	end)

	T.it("rejects a warp into the bank and keeps the last accepted position", function()
		local guard = MoveGuard.new(CFG)
		local start = Vector3.new(150, 3, 0)
		guard:check(start, DT, ALLOWED)
		local bank = Vector3.new(0, 3, 0)
		T.eq(guard:check(bank, DT, ALLOWED), "rejected")
		T.eq(guard:position(), start)
		T.truthy(not inBank(guard:position() :: Vector3), "bank never sees the warped position")
	end)

	T.it("a warp that ignores snap-backs never banks, and is forced only after the give-up time", function()
		local guard = MoveGuard.new(CFG)
		guard:check(Vector3.new(120, 3, 0), DT, ALLOWED)
		local elapsed, verdict = 0, "ok"
		repeat
			verdict = guard:check(Vector3.new(0, 3, 0), DT, ALLOWED)
			elapsed += DT
			if verdict == "rejected" then
				T.truthy(not inBank(guard:position() :: Vector3))
			end
		until verdict ~= "rejected" or elapsed > 10
		T.eq(verdict, "forced", "the server stops fighting eventually")
		T.truthy(elapsed >= CFG.GiveUpSeconds - 1e-6, "not before GiveUpSeconds")
		-- StackService drops the whole stack on "forced", so the bank pays 0.
	end)

	T.it("rejects sustained speed hacks and small repeated hops", function()
		for _, speed in { ALLOWED * 1.6, 60 } do
			local guard = MoveGuard.new(CFG)
			local x = 0
			guard:check(Vector3.new(x, 3, 0), DT, ALLOWED)
			local rejected = false
			for _ = 1, 30 do
				x += speed * DT
				if guard:check(Vector3.new(x, 3, 0), DT, ALLOWED) ~= "ok" then
					rejected = true
					break
				end
			end
			T.truthy(rejected, "speed " .. speed .. " caught within 3 s")
		end
	end)

	T.it("absorbs a lag spike where the client catches up in one update", function()
		local guard = MoveGuard.new(CFG)
		guard:check(Vector3.new(0, 3, 0), DT, ALLOWED)
		for _ = 1, 8 do -- 0.8 s without position updates
			T.eq(guard:check(Vector3.new(0, 3, 0), DT, ALLOWED), "ok")
		end
		T.eq(guard:check(Vector3.new(WALK * 0.9, 3, 0), DT, ALLOWED), "ok")
	end)

	T.it("ignores vertical movement (falling, jumping)", function()
		local guard = MoveGuard.new(CFG)
		guard:check(Vector3.new(0, 80, 0), DT, ALLOWED)
		T.eq(guard:check(Vector3.new(0, 3, 0), DT, ALLOWED), "ok")
	end)

	T.it("server-sanctioned moves (travel, spawn pads) are accepted after reset", function()
		local guard = MoveGuard.new(CFG)
		guard:check(Vector3.new(0, 3, 0), DT, ALLOWED)
		guard:reset(Vector3.new(2400, 3, 30))
		T.eq(guard:check(Vector3.new(2400, 3, 30), DT, ALLOWED), "ok")
		guard:reset(nil)
		T.eq(guard:check(Vector3.new(-50, 3, 9), DT, ALLOWED), "ok")
	end)
end)
