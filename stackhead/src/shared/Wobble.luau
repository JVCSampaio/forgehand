-- Pure wobble simulation. The server runs it authoritatively at GameConfig.TickRate;
-- the client only renders the replicated value.
--
-- Every tick the meter gains disturbance (velocity changes, walking, jumps),
-- scaled by how tall the stack is and divided by the Balance multiplier,
-- and loses a recovery amount that is much larger while standing still.

local Wobble = {}

export type State = {
	Value: number,
	VelX: number,
	VelY: number,
	VelZ: number,
}

function Wobble.newState(): State
	return { Value = 0, VelX = 0, VelY = 0, VelZ = 0 }
end

function Wobble.heightFactor(height: number, cfg): number
	if height <= cfg.SafeHeight then
		return 0
	end
	return ((height - cfg.SafeHeight) / cfg.HeightScale) ^ cfg.HeightExponent
end

function Wobble.balanceMultiplier(balanceLevel: number, cfg): number
	return 1 + balanceLevel * cfg.BalancePerLevel
end

-- input: { Dt, VelX, VelY, VelZ, Height, BalanceMult }
-- Mutates and returns state; state.Value >= 1 means collapse.
function Wobble.step(state: State, input, cfg): State
	local dt = input.Dt
	local dvx = input.VelX - state.VelX
	local dvz = input.VelZ - state.VelZ
	local deltaV = math.sqrt(dvx * dvx + dvz * dvz)
	local speed = math.sqrt(input.VelX * input.VelX + input.VelZ * input.VelZ)

	local disturbance = deltaV * cfg.AccelGain + speed * cfg.MoveGain * dt
	if input.VelY - state.VelY > cfg.JumpVelocity then
		disturbance += cfg.JumpKick
	end

	local factor = Wobble.heightFactor(input.Height, cfg)
	local recovery = if speed < cfg.StillSpeed then cfg.RecoverStill else cfg.RecoverMoving
	-- A deliberate slow walk trades collection speed for control. Bump kicks
	-- remain unchanged, so steady mode does not grant PvP invulnerability.
	if input.Steady then
		disturbance *= cfg.SteadyDisturbanceMult
		recovery = math.max(recovery, cfg.RecoverSteady)
	end

	state.Value =
		math.max(0, state.Value + disturbance * factor / input.BalanceMult - recovery * input.BalanceMult * dt)
	state.VelX = input.VelX
	state.VelY = input.VelY
	state.VelZ = input.VelZ
	return state
end

-- An external kick (bump, dash). Returns the new value.
function Wobble.kick(state: State, amount: number, height: number, balanceMult: number, cfg): number
	local factor = math.max(Wobble.heightFactor(height, cfg), 0)
	state.Value += amount * factor / balanceMult
	return state.Value
end

-- How many items survive a collapse of a stack with `count` items.
function Wobble.keepCount(count: number, cfg): number
	return math.floor(count * cfg.CollapseKeepFraction)
end

return Wobble
