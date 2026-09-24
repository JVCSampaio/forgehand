-- Pure lookups over WorldConfig: which world/zone a position is in, where a
-- world's bank is, which world a tier belongs to. No Roblox services, so it
-- is unit tested; use WorldIndex for the ready-made instance.

local Worlds = {}
Worlds.__index = Worlds

function Worlds.new(config)
	local self = setmetatable({
		config = config,
		list = config.Worlds,
		byId = {},
		zoneByTier = {},
		worldByTier = {},
	}, Worlds)
	for _, world in config.Worlds do
		self.byId[world.Id] = world
		for _, zone in world.Zones do
			self.zoneByTier[zone.Tier] = zone
			self.worldByTier[zone.Tier] = world
		end
	end
	return self
end

-- The world whose island a position belongs to (nearest origin along X).
function Worlds:at(position: Vector3)
	local index = math.floor(position.X / self.config.Spacing + 0.5) + 1
	return self.list[math.clamp(index, 1, #self.list)]
end

-- Horizontal distance from the world centre.
function Worlds:radius(world, position: Vector3): number
	local dx = position.X - world.Origin.X
	local dz = position.Z - world.Origin.Z
	return math.sqrt(dx * dx + dz * dz)
end

function Worlds:zoneAt(position: Vector3)
	local world = self:at(position)
	local r = self:radius(world, position)
	for index, zone in world.Zones do
		if r >= zone.InnerRadius and r < zone.OuterRadius then
			return zone, world, index
		end
	end
	return nil, world, nil
end

function Worlds:get(id: string)
	return self.byId[id]
end

function Worlds:zoneForTier(tier: number)
	return self.zoneByTier[tier]
end

function Worlds:worldForTier(tier: number)
	return self.worldByTier[tier]
end

function Worlds:isUnlocked(world, strength: number): boolean
	return strength >= world.FirstTier
end

function Worlds:maxTier(): number
	local last = self.list[#self.list]
	return last.Zones[#last.Zones].Tier
end

return Worlds
