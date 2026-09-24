-- Pure unlock rules for cosmetics. `view` is a plain snapshot of the player:
-- { BestStack, Strength, DailyStreak, Owned = {id=true}, Passes = {key=true} }
-- plus a `worldFirstTier` lookup function. Used by the server to validate
-- equips and by the shop UI to explain locks.

local Cosmetics = {}

function Cosmetics.isUnlocked(base, view, worldFirstTier: (string) -> number?): boolean
	local unlock = base.Unlock
	if unlock.Kind == "Free" then
		return true
	elseif unlock.Kind == "Record" then
		return view.BestStack >= unlock.Stack
	elseif unlock.Kind == "World" then
		local tier = worldFirstTier(unlock.World)
		return tier ~= nil and view.Strength >= tier
	elseif unlock.Kind == "Streak" then
		return view.DailyStreak >= unlock.Days
	elseif unlock.Kind == "Pass" then
		return view.Passes[unlock.Pass] == true
	elseif unlock.Kind == "Owned" then
		return view.Owned[base.Id] == true
	end
	return false
end

function Cosmetics.requirement(base): string
	local unlock = base.Unlock
	if unlock.Kind == "Record" then
		return string.format("Bank a %d stack", unlock.Stack)
	elseif unlock.Kind == "World" then
		return "Unlock " .. unlock.World
	elseif unlock.Kind == "Streak" then
		return string.format("%d-day login streak", unlock.Days)
	elseif unlock.Kind == "Pass" then
		return "Game pass"
	elseif unlock.Kind == "Owned" then
		return "Starter Pack"
	end
	return ""
end

return Cosmetics
