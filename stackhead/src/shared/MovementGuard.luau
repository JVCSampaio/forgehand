-- A bounded distance budget absorbs replication jitter without granting a
-- fresh free teleport allowance on every simulation tick. No engine APIs.
local Guard = {}

function Guard.step(credit: number, distance: number, speed: number, dt: number): (boolean, number)
	if distance ~= distance or distance == math.huge or distance < 0 then
		return false, 0
	end
	local burst = speed * 0.35 + 2
	local available = math.min(credit + speed * 1.1 * math.clamp(dt, 0, 0.5), burst)
	if distance > available then
		return false, available
	end
	return true, available - distance
end

return Guard
