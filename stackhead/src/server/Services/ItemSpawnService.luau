-- Owns every pickup in the world: zone respawns, loose items that fall off
-- collapsed stacks, and item rain. The server registry is the source of
-- truth; models in workspace.Items are just its visible side.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage").Shared
local GameConfig = require(Shared.Config.GameConfig)
local ItemConfig = require(Shared.Config.ItemConfig)
local ItemBuilder = require(Shared.ItemBuilder)
local StackCodec = require(Shared.StackCodec)
local WorldService = require(script.Parent.WorldService)

local ItemSpawnService = {}

export type ItemInfo = {
	Code: string,
	Def: any,
	RarityMult: number,
	Zone: string?,
	-- Loose items (fallen from a stack / rain)
	Owner: number?,
	OwnerUntil: number?,
	ExpiresAt: number?,
	ReadyAt: number,
}

local registry: { [Model]: ItemInfo } = {}
local rootToModel: { [BasePart]: Model } = {}
local zoneCounts: { [string]: number } = {}
local itemsFolder: Folder
local rng = Random.new()
local overlapParams = OverlapParams.new()

local raritySuffixMult = {}
for _, rarity in GameConfig.Spawning.Rarities do
	raritySuffixMult[rarity.Suffix] = rarity.ValueMult
end

function ItemSpawnService.rarityMult(code: string): number
	local _, suffix = StackCodec.parse(code)
	return raritySuffixMult[suffix] or 1
end

local function rollRarity(boost: number): string
	for _, rarity in GameConfig.Spawning.Rarities do
		if rng:NextNumber() < rarity.Chance * boost then
			return rarity.Suffix
		end
	end
	return ""
end

local function pickItem(tier: number)
	local pool = ItemConfig.ByTier[tier]
	local total = 0
	for _, def in pool do
		total += def.Weight
	end
	local roll = rng:NextNumber(0, total)
	for _, def in pool do
		roll -= def.Weight
		if roll <= 0 then
			return def
		end
	end
	return pool[#pool]
end

local function tooCloseToItems(position: Vector3): boolean
	local spacing = GameConfig.Spawning.MinSpacing
	local hits = Workspace:GetPartBoundsInRadius(position, spacing, overlapParams)
	return #hits > 0
end

local function findSpot(inner: number, outer: number): Vector3?
	for _ = 1, GameConfig.Spawning.PlacementAttempts do
		local point = WorldService.randomPointInRing(rng, inner + 2, outer - 2)
		if not WorldService.isNearObstacle(point, 2) and not tooCloseToItems(point) then
			return point
		end
	end
	return nil
end

local function place(code: string, groundPosition: Vector3, info: ItemInfo, attributes: { [string]: any }?): Model?
	local model = ItemBuilder.build(code)
	if not model then
		return nil
	end
	-- Attributes are set before parenting so clients receive them atomically.
	if attributes then
		for name, value in attributes do
			model:SetAttribute(name, value)
		end
	end
	local def = info.Def
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local floor = WorldService.groundTopAt(groundPosition)
	ItemBuilder.pivot(model, CFrame.new(groundPosition.X, floor + def.Height / 2 + 0.05, groundPosition.Z) * yaw)
	local root = model.PrimaryPart :: BasePart
	-- Only the root is queryable so each item is one overlap hit.
	root.CanQuery = true
	model:SetAttribute("Tier", def.Tier)
	registry[model] = info
	rootToModel[root] = model
	model.Parent = itemsFolder
	return model
end

function ItemSpawnService.spawnInZone(zone, rarityBoost: number?): Model?
	local spot = findSpot(zone.InnerRadius, zone.OuterRadius)
	if not spot then
		return nil
	end
	local def = pickItem(zone.Tier)
	local code = StackCodec.code(def.Id, rollRarity(rarityBoost or 1))
	local model = place(code, spot, {
		Code = code,
		Def = def,
		RarityMult = ItemSpawnService.rarityMult(code),
		Zone = zone.Id,
		ReadyAt = 0,
	})
	if model then
		zoneCounts[zone.Id] = (zoneCounts[zone.Id] or 0) + 1
	end
	return model
end

-- Loose items: fall from `from` and land at `groundPosition` at `readyAt`
-- (server clock). Clients animate the fall using the DropFrom / DropAt attributes.
function ItemSpawnService.spawnLoose(code: string, from: Vector3, groundPosition: Vector3, owner: number?, zone: string?): Model?
	local def = ItemBuilder.definition(code)
	if not def then
		return nil
	end
	local now = Workspace:GetServerTimeNow()
	local readyAt = now + GameConfig.Loose.LandDelay
	local model = place(code, groundPosition, {
		Code = code,
		Def = def,
		RarityMult = ItemSpawnService.rarityMult(code),
		Zone = zone,
		Owner = owner,
		OwnerUntil = if owner then readyAt + GameConfig.Loose.OwnerPickupDelay else nil,
		ExpiresAt = if zone then nil else now + GameConfig.Loose.Lifetime,
		ReadyAt = readyAt,
	}, { DropFrom = from, DropAt = readyAt })
	if model then
		if zone then
			zoneCounts[zone] = (zoneCounts[zone] or 0) + 1
		end
	end
	return model
end

-- Rain drops use the zone pool of whatever ring they land in, and count
-- toward that zone's cap so rain can't flood the map permanently.
function ItemSpawnService.spawnRainDrop(rarityBoost: number): Model?
	local spot = findSpot(GameConfig.Bank.Radius + 4, GameConfig.Zones[#GameConfig.Zones].OuterRadius)
	if not spot then
		return nil
	end
	local zone = WorldService.zoneAt(spot)
	if not zone then
		return nil
	end
	local def = pickItem(zone.Tier)
	local code = StackCodec.code(def.Id, rollRarity(rarityBoost))
	return ItemSpawnService.spawnLoose(code, spot + Vector3.new(0, GameConfig.Events.ItemRain.DropHeight, 0), spot, nil, zone.Id)
end

-- Items whose root parts are within `radius` of `position`.
function ItemSpawnService.query(position: Vector3, radius: number): { Model }
	local found = {}
	for _, part in Workspace:GetPartBoundsInRadius(position, radius, overlapParams) do
		local model = rootToModel[part :: BasePart]
		if model then
			table.insert(found, model)
		end
	end
	return found
end

function ItemSpawnService.info(model: Model): ItemInfo?
	return registry[model]
end

-- Removes an item from the world and returns its info. Returns nil if it was
-- already taken this frame (prevents double pickups).
function ItemSpawnService.take(model: Model): ItemInfo?
	local info = registry[model]
	if not info then
		return nil
	end
	registry[model] = nil
	if model.PrimaryPart then
		rootToModel[model.PrimaryPart] = nil
	end
	if info.Zone then
		zoneCounts[info.Zone] = math.max(0, (zoneCounts[info.Zone] or 1) - 1)
	end
	model:Destroy()
	return info
end

function ItemSpawnService.canPickUp(info: ItemInfo, player: Player, strength: number, now: number): boolean
	if info.Def.Tier > strength then
		return false
	end
	if now < info.ReadyAt then
		return false
	end
	if info.Owner == player.UserId and info.OwnerUntil and now < info.OwnerUntil then
		return false
	end
	return true
end

function ItemSpawnService.init()
	itemsFolder = Workspace:WaitForChild("Items") :: Folder
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { itemsFolder }

	-- Fill every zone at start so the world never looks empty.
	for _, zone in GameConfig.Zones do
		zoneCounts[zone.Id] = 0
		for _ = 1, zone.MaxItems do
			ItemSpawnService.spawnInZone(zone)
		end
	end

	task.spawn(function()
		while true do
			task.wait(GameConfig.Spawning.RespawnInterval)
			for _, zone in GameConfig.Zones do
				for _ = 1, GameConfig.Spawning.RespawnBatch do
					if (zoneCounts[zone.Id] or 0) < zone.MaxItems then
						ItemSpawnService.spawnInZone(zone)
					end
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			local now = Workspace:GetServerTimeNow()
			for model, info in registry do
				if info.ExpiresAt and now > info.ExpiresAt then
					ItemSpawnService.take(model)
				end
			end
		end
	end)

end

return ItemSpawnService
