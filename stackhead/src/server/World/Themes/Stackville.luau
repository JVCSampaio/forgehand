-- Stackville: a sunny little town. Market streets around the bank, a suburb
-- of houses with yard sales, farm fields, and a harbour on the outer ring.

local CollectionService = game:GetService("CollectionService")

local Props = require(script.Parent.Parent.Props)

local C = Color3.fromRGB
local M = Enum.Material

local WALLS = { C(255, 236, 210), C(210, 232, 255), C(255, 214, 214), C(220, 245, 210), C(250, 240, 180), C(235, 220, 250) }
local ROOFS = { C(200, 70, 60), C(70, 110, 170), C(90, 140, 90), C(150, 90, 70), C(110, 90, 150) }
local AWNINGS = { C(230, 60, 70), C(60, 150, 230), C(60, 180, 110), C(255, 170, 40), C(170, 90, 220) }

local Theme = {}

local function pick(kit, list)
	return list[kit.rng:NextInteger(1, #list)]
end

local function plaza(kit)
	local top = kit:top(1)
	kit:disc(33, top + 0.06, C(240, 226, 196), M.SmoothPlastic, "Plaza")
	kit:disc(24, top + 0.08, C(222, 206, 170), M.SmoothPlastic, "PlazaRing")
	for _, angle in { 135, 225, 315 } do
		local p = kit.polar(angle, 30.5, top + 0.06)
		Props.flowerBed(kit, p, 2.4)
		kit:obstacle(p, 3.2)
	end
	-- Leaderboard board on the fourth diagonal; LeaderboardService fills it.
	local position = kit.polar(45, 38, top)
	local board = kit:block(CFrame.lookAt(position + Vector3.new(0, 9, 0), Vector3.new(0, 9, 0)), Vector3.new(14, 16, 0.6), C(52, 64, 110))
	board.Name = "Leaderboard"
	CollectionService:AddTag(board, "Leaderboard")
	local frame = CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
	for _, x in { -6, 6 } do
		kit:block(frame * CFrame.new(x, 0.6, 0), Vector3.new(0.8, 1.6, 0.8), C(52, 64, 110))
	end
	kit:block(frame * CFrame.new(0, 17.4, 0), Vector3.new(14.6, 0.8, 1), C(255, 200, 60), M.Neon)
	kit:obstacle(position, 9)
end

local function streetLamps(kit)
	for _, angle in kit.roadAngles do
		local side = 1
		for r = 32, 286, 18 do
			local index = 1
			for i, zone in kit.zones do
				if r >= zone.InnerRadius and r < zone.OuterRadius then
					index = i
				end
			end
			local cf = kit:roadside(angle, r, side * (kit.roadHalfWidth + 1.6), kit:top(index))
			Props.lamp(kit, cf.Position)
			kit:obstacle(cf.Position, 1.5)
			side = -side
		end
	end
end

local function market(kit)
	local top = kit:top(1)
	for _, angle in kit.roadAngles do
		for _, r in { 42, 56, 70 } do
			for _, side in { -1, 1 } do
				local cf = kit:roadside(angle, r, side * (kit.roadHalfWidth + 6.5), top)
				Props.stall(kit, cf, pick(kit, AWNINGS), C(255, 250, 240))
				kit:obstacle(cf.Position, 5.5)
			end
		end
	end
	for _, angle in { 45, 135, 225, 315 } do
		local center = kit.polar(angle, 60, top)
		Props.fountain(kit, center)
		kit:obstacle(center, 8)
		for i = 0, 3 do
			local a = angle + 45 + i * 90
			local p = center + kit.polar(a, 9.5)
			Props.bench(kit, CFrame.lookAt(p, center) * CFrame.Angles(0, math.pi, 0))
			kit:obstacle(p, 3)
		end
	end
	kit:scatter(1, 10, 3.5, function(p)
		Props.tree(kit, p, kit.rng:NextNumber(0.8, 1.05))
	end)
end

local function yardSaleTable(kit, cf: CFrame)
	kit:block(cf * CFrame.new(0, 1.5, 0), Vector3.new(5, 0.25, 2.2), C(245, 245, 245))
	for _, x in { -2.2, 2.2 } do
		kit:block(cf * CFrame.new(x, 0.75, 0), Vector3.new(0.25, 1.5, 2), C(200, 200, 200))
	end
	local junk = { C(120, 60, 180), C(40, 110, 230), C(230, 60, 60), C(110, 110, 118), C(255, 200, 60) }
	for i = 0, 3 do
		kit:block(cf * CFrame.new(-1.8 + i * 1.2, 1.95, kit.rng:NextNumber(-0.5, 0.5)), Vector3.new(0.9, 0.7, 0.9), junk[i + 1], nil, { CanCollide = false })
	end
end

local function suburb(kit)
	local top = kit:top(2)
	for _, angle in kit.roadAngles do
		for _, r in { 100, 130 } do
			for _, side in { -1, 1 } do
				local cf = kit:roadside(angle, r, side * (kit.roadHalfWidth + 12), top)
				Props.house(kit, cf, pick(kit, WALLS), pick(kit, ROOFS))
				kit:obstacle(cf.Position, 9)
				-- Picket fence along the street with a gap for the path.
				local front = kit:roadside(angle, r, side * (kit.roadHalfWidth + 4.5), top)
				local along = (kit:roadside(angle, r + 1, side * (kit.roadHalfWidth + 4.5), top).Position - front.Position).Unit
				Props.fenceRun(kit, front.Position - along * 8, front.Position - along * 1.8)
				Props.fenceRun(kit, front.Position + along * 1.8, front.Position + along * 8)
				-- Mailbox by the gate.
				local box = front.Position + along * 2.6
				kit:block(CFrame.new(box + Vector3.new(0, 1.2, 0)), Vector3.new(0.3, 2.4, 0.3), C(90, 70, 50), M.Wood)
				kit:block(CFrame.new(box + Vector3.new(0, 2.6, 0)) * front.Rotation, Vector3.new(0.8, 0.7, 1.3), C(40, 90, 200))
				if kit.rng:NextNumber() < 0.6 then
					local tableCF = kit:roadside(angle, r + 5, side * (kit.roadHalfWidth + 7), top)
					yardSaleTable(kit, tableCF)
				end
			end
		end
	end
	kit:scatter(2, 34, 3.2, function(p)
		Props.tree(kit, p, kit.rng:NextNumber(0.9, 1.35))
	end)
	-- Playground in one diagonal.
	local play = kit.polar(135, 118, top)
	local frame = CFrame.lookAt(play, Vector3.new(0, top, 0))
	kit:block(frame * CFrame.new(-4, 0.05, 0), Vector3.new(14, 0.1, 10), C(240, 210, 150), M.Sand, { CanCollide = false })
	kit:wedge({ CFrame = frame * CFrame.new(-7, 2, 0), Size = Vector3.new(2.4, 4, 7), Color = C(250, 90, 80) })
	kit:block(frame * CFrame.new(-7, 2, -4.2), Vector3.new(2.4, 4, 1.4), C(80, 150, 240))
	for _, x in { -1, 5 } do
		kit:block(frame * CFrame.new(x, 3, 0), Vector3.new(0.4, 6, 0.4), C(250, 200, 60), M.Metal)
	end
	kit:block(frame * CFrame.new(2, 6, 0), Vector3.new(6.4, 0.4, 0.4), C(250, 200, 60), M.Metal)
	for _, x in { 0.6, 3.4 } do
		kit:block(frame * CFrame.new(x, 1.6, 0), Vector3.new(1.4, 0.2, 0.8), C(60, 60, 70))
	end
	kit:obstacle(play, 10)
	kit:scatter(2, 10, 2.5, function(p)
		Props.flowerBed(kit, p, 1.8)
	end)
end

local CROPS = {
	{ Name = "Wheat", Row = C(236, 200, 90), Height = 1.6, Ball = false },
	{ Name = "Cabbage", Row = C(110, 190, 90), Height = 0.9, Ball = true },
	{ Name = "Pumpkin", Row = C(245, 140, 40), Height = 1.1, Ball = true },
	{ Name = "Corn", Row = C(90, 160, 60), Height = 2.8, Ball = false },
}

local function field(kit, center: Vector3, crop, width: number, depth: number)
	local frame = CFrame.lookAt(center, Vector3.new(0, center.Y, 0))
	kit:block(frame * CFrame.new(0, 0.1, 0), Vector3.new(width, 0.2, depth), C(125, 88, 58), M.Ground, { CanCollide = false })
	local rows = math.floor(width / 2.6)
	for i = 0, rows - 1 do
		local x = -width / 2 + 1.3 + i * 2.6
		if crop.Ball then
			for z = -depth / 2 + 1.2, depth / 2 - 1.2, 2.2 do
				kit:ball((frame * CFrame.new(x, 0.2 + crop.Height / 2, z)).Position, crop.Height, crop.Row:Lerp(C(255, 255, 255), kit.rng:NextNumber(0, 0.12)), nil, { CanCollide = false })
			end
		else
			kit:block(frame * CFrame.new(x, 0.2 + crop.Height / 2, 0), Vector3.new(1.3, crop.Height, depth - 1.5), crop.Row, M.Grass, { CanCollide = false })
		end
	end
	local corners = {
		(frame * CFrame.new(-width / 2 - 1, 0, -depth / 2 - 1)).Position,
		(frame * CFrame.new(width / 2 + 1, 0, -depth / 2 - 1)).Position,
		(frame * CFrame.new(width / 2 + 1, 0, depth / 2 + 1)).Position,
		(frame * CFrame.new(-width / 2 - 1, 0, depth / 2 + 1)).Position,
	}
	for i = 1, 4 do
		Props.fenceRun(kit, corners[i], corners[i % 4 + 1], C(150, 110, 70), 2)
	end
	kit:obstacle(center, math.max(width, depth) / 2 + 1)
end

local function barn(kit, cf: CFrame)
	local red = C(186, 48, 42)
	kit:block(cf * CFrame.new(0, 7, 0), Vector3.new(22, 14, 18), red, M.WoodPlanks)
	kit:wedge({ CFrame = cf * CFrame.new(0, 17.5, -4.75), Size = Vector3.new(23, 7, 9.5), Color = C(80, 70, 70) })
	kit:wedge({ CFrame = cf * CFrame.new(0, 17.5, 4.75) * CFrame.Angles(0, math.pi, 0), Size = Vector3.new(23, 7, 9.5), Color = C(80, 70, 70) })
	kit:block(cf * CFrame.new(0, 5, -9.1), Vector3.new(8, 10, 0.4), C(245, 240, 230))
	kit:block(cf * CFrame.new(0, 5, -9.2), Vector3.new(0.5, 10, 0.3), red)
	kit:block(cf * CFrame.new(0, 12, -9.1), Vector3.new(3.5, 2.5, 0.4), C(245, 240, 230))
	-- Silo beside it.
	local silo = (cf * CFrame.new(15, 0, 3)).Position
	kit:column(silo, 24, 8, C(205, 210, 215), M.Metal)
	kit:ball(silo + Vector3.new(0, 24, 0), 8, C(190, 60, 50))
	for i = 1, 3 do
		kit:column(silo + Vector3.new(0, i * 6, 0), 0.5, 8.3, C(150, 155, 160), M.Metal)
	end
end

local function windmill(kit, base: Vector3)
	for i = 0, 5 do
		kit:column(base + Vector3.new(0, i * 4, 0), 4, 9 - i * 0.9, C(245, 238, 225))
	end
	kit:ball(base + Vector3.new(0, 24.5, 0), 4.6, C(190, 60, 50))
	local hub = CFrame.lookAt(base + Vector3.new(0, 21, 0), Vector3.new(0, base.Y + 21, 0)) * CFrame.new(0, 0, -3.2)
	kit:column((hub).Position - Vector3.new(0, 0.5, 0), 1, 1.4, C(90, 70, 50), M.Wood)
	for i = 0, 3 do
		local blade = hub * CFrame.Angles(0, 0, math.rad(20 + i * 90)) * CFrame.new(0, 7, 0)
		kit:block(blade, Vector3.new(2.6, 13, 0.3), C(250, 250, 245), M.Fabric)
		kit:block(blade * CFrame.new(0, 0, -0.2), Vector3.new(0.4, 13.5, 0.4), C(110, 80, 55), M.Wood)
	end
end

local function tractor(kit, cf: CFrame)
	kit:block(cf * CFrame.new(0, 2.2, 0), Vector3.new(3.4, 2, 6), C(60, 160, 70))
	kit:block(cf * CFrame.new(0, 4, 1.2), Vector3.new(3, 2.4, 2.6), C(60, 160, 70))
	kit:block(cf * CFrame.new(0, 4.2, 1.2), Vector3.new(2.8, 1.6, 2.7), C(170, 215, 245), M.Glass)
	kit:column((cf * CFrame.new(0.5, 3.3, -1.8)).Position, 2, 0.35, C(40, 40, 40), M.Metal)
	for _, spec in { { 2.2, 1.6, 3.6 }, { -2.2, 1.6, 3.6 }, { 2.1, -2, 2.2 }, { -2.1, -2, 2.2 } } do
		local wheel = cf * CFrame.new(spec[1], spec[3] / 2, spec[2])
		kit:cylinder(wheel, 1, spec[3], C(35, 35, 38))
		kit:cylinder(wheel, 1.05, spec[3] * 0.45, C(250, 200, 50), M.Metal)
	end
end

local function farm(kit)
	local top = kit:top(3)
	for i, angle in { 45, 135, 225, 315 } do
		for j, spec in { { -17, 174 }, { 13, 172 }, { -2, 204 } } do
			local crop = CROPS[((i + j) % #CROPS) + 1]
			field(kit, kit.polar(angle + spec[1], spec[2], top), crop, 32, 20)
		end
	end
	barn(kit, kit:roadside(0, 186, kit.roadHalfWidth + 17, top))
	barn(kit, kit:roadside(180, 190, -(kit.roadHalfWidth + 17), top))
	kit:obstacle(kit:roadside(0, 186, kit.roadHalfWidth + 20, top).Position, 17)
	kit:obstacle(kit:roadside(180, 190, -(kit.roadHalfWidth + 20), top).Position, 17)
	local mill = kit:roadside(90, 185, kit.roadHalfWidth + 12, top).Position
	windmill(kit, mill)
	kit:obstacle(mill, 6)
	local tractorCF = kit:roadside(270, 180, kit.roadHalfWidth + 9, top)
	tractor(kit, tractorCF)
	kit:obstacle(tractorCF.Position, 4)
	kit:scatter(3, 10, 2.5, function(p)
		for k = 0, 2 do
			kit:block(CFrame.new(p + Vector3.new(k * 2.7 - 2.7, 0.9, 0)), Vector3.new(2.6, 1.8, 1.8), C(232, 200, 90), M.Fabric)
		end
		kit:block(CFrame.new(p + Vector3.new(-1.35, 2.7, 0)), Vector3.new(2.6, 1.8, 1.8), C(232, 200, 90), M.Fabric)
	end)
	kit:scatter(3, 16, 3, function(p)
		Props.tree(kit, p, kit.rng:NextNumber(1, 1.5))
	end)
end

local CONTAINER_COLORS = { C(210, 70, 50), C(40, 110, 190), C(60, 160, 90), C(240, 170, 40), C(120, 80, 170), C(230, 230, 235) }

local function containers(kit, center: Vector3)
	local frame = CFrame.lookAt(center, Vector3.new(0, center.Y, 0)) * CFrame.Angles(0, math.rad(90), 0)
	for row = 0, 2 do
		local height = kit.rng:NextInteger(1, 3)
		for level = 0, height - 1 do
			local color = pick(kit, CONTAINER_COLORS)
			local cf = frame * CFrame.new(row * 8.4 - 8.4, 4 + level * 8.1, 0)
			kit:block(cf, Vector3.new(8, 8, 18), color, M.CorrodedMetal)
			kit:block(cf * CFrame.new(0, 0, -9.05), Vector3.new(7.2, 7.2, 0.1), color:Lerp(C(0, 0, 0), 0.2), M.Metal)
		end
	end
	kit:obstacle(center, 14)
end

local function crane(kit, base: Vector3)
	local yellow = C(245, 190, 40)
	local frame = CFrame.lookAt(base, Vector3.new(0, base.Y, 0))
	for _, x in { -2.5, 2.5 } do
		for _, z in { -2.5, 2.5 } do
			kit:block(frame * CFrame.new(x, 20, z), Vector3.new(0.9, 40, 0.9), yellow, M.Metal)
		end
	end
	for y = 6, 36, 10 do
		kit:block(frame * CFrame.new(0, y, 0), Vector3.new(6, 0.7, 6), yellow, M.Metal)
	end
	kit:block(frame * CFrame.new(0, 41, 8), Vector3.new(3, 3, 36), yellow, M.Metal)
	kit:block(frame * CFrame.new(0, 43.5, -8), Vector3.new(4, 5, 5), C(70, 70, 75), M.Metal)
	kit:block(frame * CFrame.new(0, 31, 22), Vector3.new(0.3, 18, 0.3), C(40, 40, 40))
	kit:block(frame * CFrame.new(0, 21.5, 22), Vector3.new(1.4, 1, 1.4), C(230, 60, 40), M.Metal)
	kit:obstacle(base, 5)
end

local function warehouse(kit, cf: CFrame)
	kit:block(cf * CFrame.new(0, 7, 0), Vector3.new(26, 14, 18), C(170, 180, 190), M.CorrodedMetal)
	kit:wedge({ CFrame = cf * CFrame.new(0, 15.5, -4.5), Size = Vector3.new(27, 3, 9), Color = C(90, 100, 110) })
	kit:wedge({ CFrame = cf * CFrame.new(0, 15.5, 4.5) * CFrame.Angles(0, math.pi, 0), Size = Vector3.new(27, 3, 9), Color = C(90, 100, 110) })
	kit:block(cf * CFrame.new(0, 5, -9.1), Vector3.new(10, 10, 0.3), C(220, 170, 40), M.CorrodedMetal)
	kit:block(cf * CFrame.new(0, 12, -9.2), Vector3.new(16, 2.2, 0.3), C(40, 60, 110))
	kit:obstacle(cf.Position, 15)
end

local function docks(kit)
	local top = kit:top(4)
	for _, angle in { 45, 135, 225, 315 } do
		containers(kit, kit.polar(angle - 12, 250, top))
		containers(kit, kit.polar(angle + 13, 262, top))
	end
	crane(kit, kit:roadside(0, 268, kit.roadHalfWidth + 10, top).Position)
	crane(kit, kit:roadside(180, 268, -(kit.roadHalfWidth + 10), top).Position)
	warehouse(kit, kit:roadside(90, 245, kit.roadHalfWidth + 17, top))
	warehouse(kit, kit:roadside(270, 245, -(kit.roadHalfWidth + 17), top))
	kit:scatter(4, 18, 3, function(p)
		Props.crateStack(kit, p, kit.rng:NextInteger(3, 6))
	end)
	-- Forklifts parked between the stacks.
	kit:scatter(4, 6, 3, function(p)
		local cf = CFrame.new(p) * CFrame.Angles(0, kit.rng:NextNumber(0, math.pi * 2), 0)
		kit:block(cf * CFrame.new(0, 1.6, 0), Vector3.new(2.6, 1.6, 3.6), C(245, 180, 30))
		kit:block(cf * CFrame.new(0, 3.3, 0.6), Vector3.new(2.4, 0.2, 2.2), C(40, 40, 45), M.Metal)
		for _, x in { -1, 1 } do
			kit:block(cf * CFrame.new(x, 2.5, 1.6), Vector3.new(0.2, 1.6, 0.2), C(40, 40, 45), M.Metal)
			kit:block(cf * CFrame.new(x * 0.6, 2.3, -2.4), Vector3.new(0.2, 4.6, 0.2), C(60, 60, 65), M.Metal)
			kit:block(cf * CFrame.new(x * 0.6, 0.3, -3.3), Vector3.new(0.3, 0.15, 2), C(60, 60, 65), M.Metal)
		end
		for _, spec in { { 1.4, 1 }, { -1.4, 1 }, { 1.4, -1 }, { -1.4, -1 } } do
			kit:cylinder(cf * CFrame.new(spec[1], 0.6, spec[2]), 0.5, 1.2, C(30, 30, 32))
		end
	end)
	-- Fishing nets and buoys drying on the quay.
	kit:scatter(4, 8, 2.5, function(p)
		kit:block(CFrame.new(p + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, kit.rng:NextNumber(0, 3), 0), Vector3.new(4, 0.6, 3), C(70, 110, 90), M.Fabric)
		kit:ball(p + Vector3.new(1.4, 0.9, 1), 1, C(255, 90, 40))
		kit:ball(p + Vector3.new(-1.2, 0.9, 1.2), 1, C(255, 230, 60))
	end)
	kit:scatter(4, 8, 2.5, function(p)
		Props.barrels(kit, p, kit.rng:NextInteger(3, 5))
	end)
	-- Bollards along the quay edge.
	local edge = kit.zones[4].OuterRadius - 1.5
	for i = 0, 71 do
		local angle = i * 5
		local p = kit.polar(angle, edge, top)
		if not kit:onRoad(p, 1) then
			kit:column(p, 1.3, 0.9, C(40, 40, 45), M.Metal)
			kit:ball(p + Vector3.new(0, 1.3, 0), 1.1, C(40, 40, 45), M.Metal)
		end
	end
	kit:pilings(9, C(95, 70, 50))
	-- Piers continue the streets out over the water, with a boat at each.
	for _, angle in kit.roadAngles do
		local a = math.rad(angle)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local rot = CFrame.lookAt(Vector3.zero, dir)
		kit:block(CFrame.new(dir * 318 + Vector3.new(0, top - 0.2, 0)) * rot, Vector3.new(10, 0.6, 56), C(170, 130, 90), M.WoodPlanks, { CanCollide = false })
		for r = 294, 344, 10 do
			for _, side in { -1, 1 } do
				local p = dir * r + Vector3.new(-dir.Z, 0, dir.X) * side * 4.6
				kit:column(p + Vector3.new(0, -3, 0), 3.6, 1, C(95, 70, 50), M.Wood)
			end
		end
		local boatCF = CFrame.lookAt(dir * 322 + Vector3.new(-dir.Z, 0, dir.X) * 12, dir * 340 + Vector3.new(-dir.Z, 0, dir.X) * 12)
		Props.boat(kit, boatCF + Vector3.new(0, -0.4, 0), pick(kit, { C(240, 240, 240), C(200, 60, 60), C(60, 110, 190) }), C(250, 250, 245))
	end
	Props.lighthouse(kit, kit.polar(45, 345, 1))
	-- Distant islands on the horizon.
	for i = 0, 5 do
		local angle = i * 60 + 30
		Props.island(kit, kit.polar(angle, kit.rng:NextNumber(520, 720)), kit.rng:NextNumber(40, 70))
	end
end

function Theme.build(kit)
	kit:floors()
	kit:roads(C(78, 80, 90), C(250, 250, 250), M.Asphalt, C(210, 210, 205))
	kit:bank({ SpawnLocations = true })
	plaza(kit)
	streetLamps(kit)
	kit:zoneSigns(function(zone)
		return C(55, 60, 85):Lerp(zone.GroundColor, 0.3)
	end)
	market(kit)
	suburb(kit)
	farm(kit)
	docks(kit)
	kit:boundary()
end

return Theme
