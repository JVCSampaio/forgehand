local T = _G.T
local Schema = require("../src/server/Util/PlayerDataSchema")
local SessionStore = require("../src/server/Util/SessionStore")
local MemoryStore = require("../src/server/Util/MemoryStore")
local RateLimiter = require("../src/server/Util/RateLimiter")
local EconomyConfig = require("../src/shared/Config/EconomyConfig")
local UpgradeConfig = require("../src/shared/Config/UpgradeConfig")

local function newSession(store, jobId, clock)
	return SessionStore.new({
		store = store,
		jobId = jobId,
		now = function()
			return clock.t
		end,
		wait = function(s)
			clock.t += s
		end,
		loadAttempts = 3,
		saveAttempts = 3,
	})
end

T.describe("PlayerDataSchema", function()
	T.it("defaults are complete and current", function()
		local d = Schema.defaults(EconomyConfig, UpgradeConfig)
		T.eq(d.Version, Schema.CURRENT_VERSION)
		T.eq(d.Upgrades.Strength, 1)
		T.eq(d.Glue, EconomyConfig.StartingGlue)
	end)

	T.it("sanitize repairs corrupt values", function()
		local d = Schema.sanitize({
			Coins = 0 / 0,
			Glue = -5,
			Upgrades = { Speed = 999, Strength = "x" },
			Stats = { BestStack = math.huge },
			Discovered = { apl = true, [5] = true, can = "yes" },
		}, EconomyConfig, UpgradeConfig)
		T.eq(d.Coins, 0)
		T.eq(d.Glue, 0)
		T.eq(d.Upgrades.Speed, UpgradeConfig.Upgrades.Speed.MaxLevel)
		T.eq(d.Upgrades.Strength, 1)
		T.eq(d.Stats.BestStack, 0)
		T.eq(d.Discovered.apl, true)
		T.eq(d.Discovered.can, nil)
	end)

	T.it("sanitize of non-table returns defaults", function()
		T.eq(Schema.sanitize("garbage", EconomyConfig, UpgradeConfig).Coins, EconomyConfig.StartingCoins)
	end)

	T.it("unversioned saves migrate", function()
		local d = Schema.sanitize({ Coins = 50 }, EconomyConfig, UpgradeConfig)
		T.eq(d.Version, Schema.CURRENT_VERSION)
		T.eq(d.Coins, 50)
	end)

	T.it("purchase history is bounded", function()
		local d = Schema.defaults(EconomyConfig, UpgradeConfig)
		for i = 1, 10 do
			Schema.recordPurchase(d, "p" .. i, 4)
		end
		T.eq(#d.PurchaseOrder, 4)
		T.eq(d.Purchases.p1, nil)
		T.eq(d.Purchases.p10, true)
	end)
end)

T.describe("SessionStore", function()
	T.it("new player loads nil and takes the lock", function()
		local store = MemoryStore.new()
		local clock = { t = 1000 }
		local ok, data = newSession(store, "A", clock):load("p1")
		T.eq(ok, true)
		T.eq(data, nil)
		T.eq(store.records.p1.Lock.JobId, "A")
	end)

	T.it("a second server cannot load while the lock is fresh", function()
		local store = MemoryStore.new()
		local clock = { t = 1000 }
		newSession(store, "A", clock):load("p1")
		local ok, reason = newSession(store, "B", clock):load("p1")
		T.eq(ok, false)
		T.eq(reason, "locked")
	end)

	T.it("released locks can be taken by another server with the saved data", function()
		local store = MemoryStore.new()
		local clock = { t = 1000 }
		local a = newSession(store, "A", clock)
		a:load("p1")
		T.eq(a:save("p1", { Coins = 77 }, true), true)
		local ok, data = newSession(store, "B", clock):load("p1")
		T.eq(ok, true)
		T.eq(data.Coins, 77)
	end)

	T.it("stale locks expire", function()
		local store = MemoryStore.new()
		local clock = { t = 1000 }
		newSession(store, "A", clock):load("p1")
		clock.t += 4000
		local ok = newSession(store, "B", clock):load("p1")
		T.eq(ok, true)
	end)

	T.it("a server that lost the lock never overwrites", function()
		local store = MemoryStore.new()
		local clock = { t = 1000 }
		local a = newSession(store, "A", clock)
		a:load("p1")
		a:save("p1", { Coins = 10 }, false)
		clock.t += 4000
		local b = newSession(store, "B", clock)
		b:load("p1")
		b:save("p1", { Coins = 500 }, false)
		local ok, reason = a:save("p1", { Coins = 999999 }, true)
		T.eq(ok, false)
		T.eq(reason, "lost-lock")
		T.eq(store.records.p1.Data.Coins, 500)
	end)

	T.it("transient failures are retried", function()
		local store = MemoryStore.new()
		local clock = { t = 1000 }
		local a = newSession(store, "A", clock)
		store.failNext = 2
		local ok = a:load("p1")
		T.eq(ok, true)
		store.failNext = 2
		T.eq(a:save("p1", { Coins = 3 }, false), true)
		T.eq(store.records.p1.Data.Coins, 3)
	end)

	T.it("gives up after persistent failures", function()
		local store = MemoryStore.new()
		local clock = { t = 1000 }
		store.failNext = 100
		local ok = newSession(store, "A", clock):load("p1")
		T.eq(ok, false)
	end)

	T.it("saved snapshots are isolated from later mutation", function()
		local store = MemoryStore.new()
		local clock = { t = 1000 }
		local a = newSession(store, "A", clock)
		a:load("p1")
		local data = { Coins = 1, Nested = { x = 1 } }
		a:save("p1", data, false)
		data.Nested.x = 2
		T.eq(store.records.p1.Data.Nested.x, 1)
	end)
end)

T.describe("RateLimiter", function()
	T.it("allows bursts up to capacity then refills", function()
		local clock = { t = 0 }
		local limiter = RateLimiter.new(3, 1, function()
			return clock.t
		end)
		T.eq(limiter:allow("p"), true)
		T.eq(limiter:allow("p"), true)
		T.eq(limiter:allow("p"), true)
		T.eq(limiter:allow("p"), false)
		clock.t += 1
		T.eq(limiter:allow("p"), true)
		T.eq(limiter:allow("q"), true)
	end)
end)
