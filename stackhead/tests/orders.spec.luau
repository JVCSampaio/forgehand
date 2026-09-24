local T = _G.T
local Orders = require("../src/shared/Orders")
local ItemConfig = require("../src/shared/Config/ItemConfig")

T.describe("Orders", function()
	T.it("generates three distinct kinds deterministically per day", function()
		local a = Orders.generate(20000, 3, 40, 40, ItemConfig)
		local b = Orders.generate(20000, 3, 40, 40, ItemConfig)
		T.eq(#a, 3)
		local seen = {}
		for i = 1, 3 do
			T.eq(a[i].Kind, b[i].Kind)
			T.eq(a[i].Target, b[i].Target)
			T.truthy(not seen[a[i].Kind], "duplicate kind")
			seen[a[i].Kind] = true
		end
		T.eq(a[3].RewardGlue, 1)
	end)

	T.it("different days usually differ", function()
		local differ = false
		for day = 1, 10 do
			local a, b = Orders.generate(day, 2, 20, 6, ItemConfig), Orders.generate(day + 1, 2, 20, 6, ItemConfig)
			if a[1].Kind ~= b[1].Kind or a[2].Kind ~= b[2].Kind then
				differ = true
			end
		end
		T.truthy(differ)
	end)

	T.it("collect orders only ask for liftable items", function()
		for day = 1, 200 do
			for _, order in Orders.generate(day, 5, 50, 700, ItemConfig) do
				if order.Kind == "Collect" then
					T.truthy(ItemConfig.ById[order.ItemId].Tier <= 5, order.ItemId)
				end
			end
		end
	end)

	T.it("advances by kind", function()
		local bank = { Count = 12, Codes = { "apl", "apls", "can", "aplg" }, Coins = 300 }
		T.eq(Orders.advance({ Kind = "Stack", Target = 10 } :: any, 5, bank), 12)
		T.eq(Orders.advance({ Kind = "Stack", Target = 10 } :: any, 20, bank), 20)
		T.eq(Orders.advance({ Kind = "Items", Target = 10 } :: any, 5, bank), 17)
		T.eq(Orders.advance({ Kind = "Collect", Target = 10, ItemId = "apl" } :: any, 0, bank), 3)
		T.eq(Orders.advance({ Kind = "Rare", Target = 2 } :: any, 0, bank), 2)
		T.eq(Orders.advance({ Kind = "Coins", Target = 1000 } :: any, 100, bank), 400)
	end)

	T.it("describes every kind", function()
		for _, kind in { "Stack", "Items", "Collect", "Rare", "Coins" } do
			local text = Orders.describe({ Kind = kind, Target = 3, ItemId = "apl", RewardCoins = 1, RewardGlue = 0 }, "Apple")
			T.truthy(text ~= "?", kind)
		end
	end)
end)
