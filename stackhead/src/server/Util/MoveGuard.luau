-- Server-side movement validation. The client owns its character physics, so
-- the server keeps the last position it accepted and a distance budget that
-- refills at the allowed speed. A move that overdraws the budget is rejected:
-- the caller snaps the character back and keeps using the accepted position,
-- so a teleport can never reach the bank, pick up items or bump anyone.
--
-- The budget absorbs lag bursts (a client that stalls and then catches up
-- spends what it saved) but not sustained speed or warps. Pure: no `game`.

local MoveGuard = {}
MoveGuard.__index = MoveGuard

export type Config = {
	BurstSeconds: number, -- how much unused movement can be saved up
	Slack: number, -- starting budget and extra headroom for replication jitter
	GiveUpSeconds: number, -- rejected this long in a row: accept, but penalise
}

export type MoveGuard = typeof(setmetatable(
	{} :: {
		config: Config,
		accepted: Vector3?,
		budget: number,
		rejectedFor: number,
	},
	MoveGuard
))

-- "ok": accepted. "rejected": snap back to `accepted`. "forced": the player
-- could not be pulled back for GiveUpSeconds; the new spot is accepted but the
-- caller should drop the stack so nothing earned on the way is kept.
export type Verdict = "ok" | "rejected" | "forced"

function MoveGuard.new(config: Config): MoveGuard
	return setmetatable({
		config = config,
		accepted = nil :: Vector3?,
		budget = config.Slack,
		rejectedFor = 0,
	}, MoveGuard)
end

-- Sanctioned server moves (spawn, travel) and respawns start clean.
function MoveGuard.reset(self: MoveGuard, position: Vector3?)
	self.accepted = position
	self.budget = self.config.Slack
	self.rejectedFor = 0
end

function MoveGuard.position(self: MoveGuard): Vector3?
	return self.accepted
end

-- Horizontal only: falling and jumping are left to the physics engine.
function MoveGuard.check(self: MoveGuard, position: Vector3, dt: number, allowedSpeed: number): Verdict
	local accepted = self.accepted
	if not accepted then
		self.accepted = position
		return "ok"
	end
	local cap = allowedSpeed * self.config.BurstSeconds + self.config.Slack
	self.budget = math.min(self.budget + allowedSpeed * dt, cap)
	local dx, dz = position.X - accepted.X, position.Z - accepted.Z
	local moved = math.sqrt(dx * dx + dz * dz)
	if moved <= self.budget then
		self.budget -= moved
		self.accepted = position
		self.rejectedFor = 0
		return "ok"
	end
	self.rejectedFor += dt
	if self.rejectedFor >= self.config.GiveUpSeconds then
		self:reset(position)
		return "forced"
	end
	return "rejected"
end

return MoveGuard
