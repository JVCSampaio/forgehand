local T = _G.T
local LOD = require("../src/shared/StackLOD")

T.describe("Tower level of detail", function()
	T.it("preserves every item's height and newest item at 999", function()
		local codes = {}
		for i = 1, 999 do
			codes[i] = tostring(i)
		end
		local plan = LOD.plan(codes, function(code)
			return tonumber(code) % 3 + 0.5
		end, 48, 24)
		local total, count, expected = 0, 0, 0
		for _, segment in plan do
			total += segment.Height
			count += segment.Count
		end
		for _, code in codes do
			expected += tonumber(code) % 3 + 0.5
		end
		T.near(total, expected, 0.001)
		T.eq(count, 999)
		T.eq(plan[#plan].Code, "999")
		T.truthy(#plan <= 72)
	end)
	T.it("keeps small towers fully detailed", function()
		local plan = LOD.plan({ "a", "b", "c" }, function()
			return 2
		end, 48, 24)
		T.eq(#plan, 3)
		for _, segment in plan do
			T.eq(segment.Count, 1)
		end
	end)
end)
