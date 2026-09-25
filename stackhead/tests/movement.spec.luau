local T = _G.T
local Guard = require("../src/shared/MovementGuard")

T.describe("Movement budget", function()
	T.it("allows ordinary movement and bounded replication jitter", function()
		local credit = 8
		for _ = 1, 100 do
			local ok
			ok, credit = Guard.step(credit, 1.6, 16, 0.1)
			T.truthy(ok)
		end
		local ok = Guard.step(credit, 5, 16, 0.1)
		T.truthy(ok)
	end)
	T.it("rejects teleporting to a bank and nonfinite positions", function()
		T.eq(Guard.step(8, 100, 16, 0.1), false)
		T.eq(Guard.step(8, 0 / 0, 16, 0.1), false)
	end)
	T.it("does not allow repeated 1.5x speed through per-tick slack", function()
		local credit, rejected = 8, false
		for _ = 1, 30 do
			local ok
			ok, credit = Guard.step(credit, 2.4, 16, 0.1)
			rejected = rejected or not ok
		end
		T.truthy(rejected)
	end)
end)
