-- Daily orders: three small goals per day, generated deterministically from
-- the day number and scaled to the player's progress when first seen that
-- day. Pure (configs injected) so it is unit tested.
--
-- Kinds:
--   Stack   bank one stack of at least Target items
--   Items   bank Target items in total today
--   Collect bank Target items of ItemId
--   Rare    bank Target shiny/golden items
--   Coins   earn Target coins from banking

local Orders = {}

export type Order = {
	Kind: string,
	Target: number,
	ItemId: string?,
	RewardCoins: number,
	RewardGlue: number,
}

local KINDS = { "Stack", "Items", "Collect", "Rare", "Coins" }
local REWARD_SCALE = { 120, 200, 350 }

local function lcg(seed: number)
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
end

local function roundTo(n: number, step: number): number
	return math.max(step, math.floor(n / step + 0.5) * step)
end

-- strength: current Strength level; best: best stack; tierScale: coins per
-- minute-ish at this tier (EconomyConfig.TierScale[strength]).
function Orders.generate(day: number, strength: number, best: number, tierScale: number, itemConfig): { Order }
	local random = lcg(day * 7919 + 17)
	local kinds = table.clone(KINDS)
	local list = {}
	for i = 1, 3 do
		local kind = table.remove(kinds, math.floor(random() * #kinds) + 1)
		local order: Order = {
			Kind = kind,
			Target = 1,
			ItemId = nil,
			RewardCoins = REWARD_SCALE[i] * tierScale,
			RewardGlue = if i == 3 then 1 else 0,
		}
		if kind == "Stack" then
			order.Target = roundTo(math.clamp(best * 0.7, 10, 400), 5)
		elseif kind == "Items" then
			order.Target = roundTo(60 + best * 1.5, 10)
		elseif kind == "Collect" then
			-- An item the player can lift, favouring their highest tier.
			local tier = math.max(1, strength - math.floor(random() * 2))
			local pool = itemConfig.ByTier[tier] or itemConfig.ByTier[1]
			local item = pool[math.floor(random() * #pool) + 1]
			order.ItemId = item.Id
			order.Target = 8 + math.floor(random() * 3) * 4
		elseif kind == "Rare" then
			order.Target = 1 + math.floor(random() * 2)
		elseif kind == "Coins" then
			order.Target = roundTo(tierScale * 25, tierScale)
		end
		list[i] = order
	end
	return list
end

-- How much a bank advances an order. bank = { Count, Codes, Coins }.
-- Stack progress is the best single stack, the rest accumulate.
function Orders.advance(order: Order, progress: number, bank): number
	if order.Kind == "Stack" then
		return math.max(progress, bank.Count)
	elseif order.Kind == "Items" then
		return progress + bank.Count
	elseif order.Kind == "Coins" then
		return progress + bank.Coins
	elseif order.Kind == "Collect" then
		local n = 0
		for _, code in bank.Codes do
			if string.sub(code, 1, 3) == order.ItemId then
				n += 1
			end
		end
		return progress + n
	elseif order.Kind == "Rare" then
		local n = 0
		for _, code in bank.Codes do
			if #code > 3 then
				n += 1
			end
		end
		return progress + n
	end
	return progress
end

function Orders.describe(order: Order, itemName: string?): string
	if order.Kind == "Stack" then
		return string.format("Bank a %d stack", order.Target)
	elseif order.Kind == "Items" then
		return string.format("Bank %d items today", order.Target)
	elseif order.Kind == "Collect" then
		return string.format("Bank %d %s", order.Target, itemName or order.ItemId or "?")
	elseif order.Kind == "Rare" then
		return if order.Target == 1 then "Bank a shiny or golden item" else string.format("Bank %d shiny or golden items", order.Target)
	elseif order.Kind == "Coins" then
		return string.format("Earn %d coins from banking", order.Target)
	end
	return "?"
end

return Orders
