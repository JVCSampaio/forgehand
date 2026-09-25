-- Full height and the newest items survive the rendering budget. Middle
-- sections become one simple column each instead of silently disappearing.
local StackLOD = {}

function StackLOD.plan(codes, heightOf, detailBudget: number, proxyBudget: number)
	local plan = {}
	local bottom = math.floor(detailBudget / 2)
	local tail = detailBudget - bottom
	local middleEnd = #codes - tail
	local groupSize = math.max(1, math.ceil((#codes - detailBudget) / proxyBudget))
	local i = 1
	while i <= #codes do
		local last = i
		if #codes > detailBudget and i > bottom and i <= middleEnd then
			last = math.min(middleEnd, i + groupSize - 1)
		end
		local height = 0
		for j = i, last do
			height += heightOf(codes[j])
		end
		table.insert(plan, { Code = codes[i], Height = height, Count = last - i + 1 })
		i = last + 1
	end
	return plan
end

return StackLOD
