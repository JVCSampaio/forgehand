-- Frostpeak: a snowy mountain village. Log cabins and skating rinks near the
-- bank, a ski lodge and lift in the pines, glittering ice caves, and a summit
-- camp ringed by snow-capped peaks.

local Props = require(script.Parent.Parent.Props)

local C = Color3.fromRGB
local M = Enum.Material

local Theme = {}

local LOG = C(140, 92, 58)
local SNOW = C(248, 252, 255)
local ICE = C(160, 220, 250)

local function cabin(kit, cf: CFrame, trim: Color3)
	local w, d, h = 11, 9, 7
	kit:block(cf * CFrame.new(0, h / 2, 0), Vector3.new(w, h, d), LOG, M.Wood)
	-- Log courses.
	for y = 1, h - 1, 1.4 do
		kit:block(cf * CFrame.new(0, y, -d / 2 - 0.05), Vector3.new(w + 0.4, 0.25, 0.2), LOG:Lerp(C(80, 50, 30), 0.35), M.Wood)
	end
	local roof = C(90, 60, 45)
	for _, spec in { { -d / 4 - 0.4, 0 }, { d / 4 + 0.4, math.pi } } do
		local wedgeCF = cf * CFrame.new(0, h + 2.2, spec[1]) * CFrame.Angles(0, spec[2], 0)
		kit:wedge({ CFrame = wedgeCF, Size = Vector3.new(w + 1.6, 4.4, d / 2 + 0.9), Color = roof })
		kit:wedge({ CFrame = wedgeCF * CFrame.new(0, 0.35, 0), Size = Vector3.new(w + 1.8, 4.4, d / 2 + 0.9), Color = SNOW, Material = M.Snow })
	end
	kit:block(cf * CFrame.new(0, 2.4, -d / 2 - 0.1), Vector3.new(2.4, 4.8, 0.3), C(110, 40, 40), M.Wood)
	kit:ball((cf * CFrame.new(0, 5.6, -d / 2 - 0.3)).Position, 1.4, C(40, 120, 60), nil, { CanCollide = false })
	for _, x in { -3.3, 3.3 } do
		kit:block(cf * CFrame.new(x, 3.6, -d / 2 - 0.1), Vector3.new(2.2, 2.2, 0.2), C(255, 210, 120), M.Neon)
		kit:block(cf * CFrame.new(x, 3.6, -d / 2 - 0.15), Vector3.new(2.7, 2.7, 0.1), trim)
	end
	kit:block(cf * CFrame.new(w / 2 - 2, h + 4, d / 4), Vector3.new(1.4, 3.6, 1.4), C(120, 110, 110), M.Cobblestone)
end

local function skatingRink(kit, center: Vector3)
	kit:column(center, 0.5, 26, C(230, 238, 248), M.Snow)
	kit:column(center, 0.6, 23, ICE, M.Ice, { Transparency = 0.1 })
	for i = 0, 23 do
		local a = i / 24 * 360
		local p = center + kit.polar(a, 12.2)
		kit:column(p, 1.6, 0.4, C(200, 60, 60), M.Wood)
	end
	Props.pine(kit, center, 1.3, true)
	-- Fairy lights on the central tree.
	for i = 0, 9 do
		local a = i * 2.4
		local y = 2.6 + i * 0.8
		kit:ball(center + Vector3.new(math.cos(a) * (4 - i * 0.3), y, math.sin(a) * (4 - i * 0.3)), 0.5, if i % 2 == 0 then C(255, 80, 80) else C(255, 220, 80), M.Neon, { CanCollide = false })
	end
	kit:obstacle(center, 14)
end

local function snowman(kit, base: Vector3)
	kit:ball(base + Vector3.new(0, 1.6, 0), 3.4, SNOW, M.Snow)
	kit:ball(base + Vector3.new(0, 4, 0), 2.5, SNOW, M.Snow)
	kit:ball(base + Vector3.new(0, 5.8, 0), 1.8, SNOW, M.Snow)
	kit:block(CFrame.new(base + Vector3.new(0, 5.8, -1.1)), Vector3.new(0.3, 0.3, 1), C(255, 140, 30))
	kit:column(base + Vector3.new(0, 6.6, 0), 1.2, 1.4, C(30, 30, 35))
	kit:column(base + Vector3.new(0, 6.55, 0), 0.15, 2, C(30, 30, 35))
	kit:block(CFrame.new(base + Vector3.new(0, 5, 0)), Vector3.new(2.4, 0.4, 2.4), C(210, 50, 50), M.Fabric)
end

local function village(kit)
	local top = kit:top(1)
	for _, angle in kit.roadAngles do
		for _, r in { 44, 66 } do
			for _, side in { -1, 1 } do
				local cf = kit:roadside(angle, r, side * (kit.roadHalfWidth + 9), top)
				cabin(kit, cf, if side > 0 then C(60, 110, 70) else C(170, 50, 50))
				kit:obstacle(cf.Position, 7.5)
			end
		end
	end
	for _, angle in { 45, 135, 225, 315 } do
		skatingRink(kit, kit.polar(angle, 57, top))
	end
	kit:scatter(1, 6, 2.5, function(p)
		snowman(kit, p)
	end)
	kit:scatter(1, 8, 3, function(p)
		Props.pine(kit, p, kit.rng:NextNumber(1, 1.4), true)
	end)
	-- Lamps with warm light along the streets.
	for _, angle in kit.roadAngles do
		for r = 32, 280, 20 do
			local index = 1
			for i, zone in kit.zones do
				if r >= zone.InnerRadius and r < zone.OuterRadius then
					index = i
				end
			end
			local side = if (r // 20) % 2 == 0 then 1 else -1
			local cf = kit:roadside(angle, r, side * (kit.roadHalfWidth + 1.6), kit:top(index))
			Props.lamp(kit, cf.Position, C(30, 30, 38), C(255, 200, 120))
			kit:obstacle(cf.Position, 1.5)
		end
	end
end

local function lodge(kit, cf: CFrame)
	-- Big A-frame.
	kit:block(cf * CFrame.new(0, 0.5, 0), Vector3.new(26, 1, 22), C(150, 150, 160), M.Cobblestone)
	for _, spec in { { -5.5, 0 }, { 5.5, math.pi } } do
		kit:wedge({ CFrame = cf * CFrame.new(0, 11, spec[1]) * CFrame.Angles(0, spec[2], 0), Size = Vector3.new(24, 20, 11), Color = C(120, 70, 45), Material = M.Wood })
		kit:wedge({ CFrame = cf * CFrame.new(0, 11.4, spec[1]) * CFrame.Angles(0, spec[2], 0), Size = Vector3.new(24.6, 20, 11), Color = SNOW, Material = M.Snow })
	end
	kit:block(cf * CFrame.new(0, 7, -11.2), Vector3.new(10, 12, 0.3), C(255, 210, 130), M.Neon)
	kit:block(cf * CFrame.new(0, 7, -11.3), Vector3.new(0.4, 12, 0.3), C(80, 50, 30), M.Wood)
	kit:block(cf * CFrame.new(0, 3, -11.35), Vector3.new(10.4, 0.4, 0.3), C(80, 50, 30), M.Wood)
	-- Ski racks.
	for _, x in { -9, 9 } do
		kit:block(cf * CFrame.new(x, 1.6, -13), Vector3.new(5, 0.3, 0.3), C(80, 50, 30), M.Wood)
		for k = 0, 4 do
			kit:block(cf * CFrame.new(x - 2 + k, 2, -13.2) * CFrame.Angles(math.rad(-12), 0, 0), Vector3.new(0.25, 4, 0.1), if k % 2 == 0 then C(230, 50, 60) else C(40, 120, 220))
		end
	end
	kit:obstacle(cf.Position, 15)
end

local function skiLift(kit, fromR: number, toR: number, angle: number)
	local top = kit:top(2)
	local previous = nil
	for r = fromR, toR, 16 do
		local base = kit.polar(angle, r, top)
		kit:column(base, 18, 1.2, C(70, 70, 80), M.Metal)
		local head = base + Vector3.new(0, 18, 0)
		kit:block(CFrame.lookAt(head, head + kit.polar(angle + 90, 1)), Vector3.new(0.6, 0.6, 7), C(70, 70, 80), M.Metal)
		if previous then
			for _, side in { -3, 3 } do
				local offset = kit.polar(angle + 90, side)
				local a, b = previous + offset, head + offset
				kit:block(CFrame.lookAt((a + b) / 2, b), Vector3.new(0.15, 0.15, (b - a).Magnitude), C(30, 30, 35), nil, { CanCollide = false })
				local seat = (a + b) / 2 - Vector3.new(0, 2.4, 0)
				kit:block(CFrame.lookAt(seat, seat + kit.polar(angle, 1)), Vector3.new(2.6, 0.3, 1.2), if side > 0 then C(230, 60, 60) else C(60, 120, 230))
				kit:block(CFrame.new(seat + Vector3.new(0, 1.2, 0)), Vector3.new(0.15, 2.4, 0.15), C(30, 30, 35), nil, { CanCollide = false })
			end
		end
		kit:obstacle(base, 2)
		previous = head
	end
end

local function lodgeRing(kit)
	local top = kit:top(2)
	lodge(kit, kit:roadside(0, 118, kit.roadHalfWidth + 16, top))
	lodge(kit, kit:roadside(180, 118, -(kit.roadHalfWidth + 16), top))
	skiLift(kit, 92, 148, 45)
	skiLift(kit, 92, 148, 225)
	for _, angle in { 90, 270 } do
		for _, side in { -1, 1 } do
			for _, r in { 100, 130 } do
				local cf = kit:roadside(angle, r, side * (kit.roadHalfWidth + 9), top)
				cabin(kit, cf, C(60, 110, 150))
				kit:obstacle(cf.Position, 7.5)
			end
		end
	end
	kit:scatter(2, 55, 2.6, function(p)
		Props.pine(kit, p, kit.rng:NextNumber(1.1, 1.8), true)
	end)
end

local function crystal(kit, base: Vector3, size: number)
	local tints = { C(120, 220, 255), C(170, 140, 255), C(140, 255, 240) }
	for i = 1, kit.rng:NextInteger(3, 5) do
		local h = size * kit.rng:NextNumber(1.2, 2.6)
		local tilt = CFrame.Angles(kit.rng:NextNumber(-0.4, 0.4), kit.rng:NextNumber(0, 6.28), kit.rng:NextNumber(-0.4, 0.4))
		local offset = Vector3.new(kit.rng:NextNumber(-size, size), 0, kit.rng:NextNumber(-size, size)) * 0.6
		local tint = tints[(i % #tints) + 1]
		kit:block(CFrame.new(base + offset) * tilt * CFrame.new(0, h / 2, 0), Vector3.new(size * 0.7, h, size * 0.7), tint, M.Glass, { Transparency = 0.15 })
		kit:block(CFrame.new(base + offset) * tilt * CFrame.new(0, h / 2, 0), Vector3.new(size * 0.3, h * 0.8, size * 0.3), tint, M.Neon, { CanCollide = false })
	end
end

local function caves(kit)
	local top = kit:top(3)
	kit:scatter(3, 22, 3.5, function(p)
		crystal(kit, p, kit.rng:NextNumber(1.2, 2.2))
	end)
	-- Ice arches over the streets' shoulders.
	for _, angle in kit.roadAngles do
		for _, r in { 170, 205 } do
			local left = kit:roadside(angle, r, -(kit.roadHalfWidth + 2), top).Position
			local right = kit:roadside(angle, r, kit.roadHalfWidth + 2, top).Position
			kit:block(CFrame.new(left + Vector3.new(0, 7, 0)), Vector3.new(2.5, 14, 2.5), ICE, M.Ice, { Transparency = 0.1 })
			kit:block(CFrame.new(right + Vector3.new(0, 7, 0)), Vector3.new(2.5, 14, 2.5), ICE, M.Ice, { Transparency = 0.1 })
			kit:block(CFrame.lookAt((left + right) / 2 + Vector3.new(0, 14.5, 0), right + Vector3.new(0, 14.5, 0)), Vector3.new(2.5, 2.2, (right - left).Magnitude + 2.5), ICE, M.Ice, { Transparency = 0.1 })
			kit:obstacle(left, 2)
			kit:obstacle(right, 2)
		end
	end
	kit:scatter(3, 6, 9, function(p)
		kit:column(p, 0.3, 18, C(120, 190, 235), M.Ice, { Transparency = 0.05 })
	end)
	kit:scatter(3, 18, 3, function(p)
		kit:ball(p + Vector3.new(0, 0.5, 0), kit.rng:NextNumber(4, 7), C(120, 125, 140), M.Slate)
	end)
end

local function summit(kit)
	local top = kit:top(4)
	kit:scatter(4, 26, 4, function(p)
		local size = kit.rng:NextNumber(5, 10)
		kit:ball(p + Vector3.new(0, size * 0.2, 0), size, C(115, 120, 135), M.Slate)
		kit:ball(p + Vector3.new(size * 0.1, size * 0.45, 0), size * 0.7, SNOW, M.Snow, { CanCollide = false })
	end)
	-- Base camp: tents and flags.
	kit:scatter(4, 8, 3.5, function(p)
		local cf = CFrame.new(p) * CFrame.Angles(0, kit.rng:NextNumber(0, 6.28), 0)
		local color = if kit.rng:NextNumber() < 0.5 then C(250, 130, 40) else C(230, 60, 60)
		kit:wedge({ CFrame = cf * CFrame.new(0, 1.6, -1), Size = Vector3.new(4, 3.2, 2), Color = color, Material = M.Fabric })
		kit:wedge({ CFrame = cf * CFrame.new(0, 1.6, 1) * CFrame.Angles(0, math.pi, 0), Size = Vector3.new(4, 3.2, 2), Color = color, Material = M.Fabric })
	end)
	for _, angle in { 20, 110, 200, 290 } do
		local p = kit.polar(angle, 262, top)
		kit:column(p, 14, 0.4, C(200, 200, 205), M.Metal)
		kit:block(CFrame.new(p + Vector3.new(2, 12.5, 0)), Vector3.new(4, 2.4, 0.15), if angle % 180 == 20 then C(230, 50, 60) else C(60, 120, 230), M.Fabric)
		kit:obstacle(p, 2)
	end
	-- Observatory on the east road.
	local obs = kit:roadside(90, 256, kit.roadHalfWidth + 13, top)
	kit:column(obs.Position, 9, 16, C(225, 228, 235))
	kit:ball(obs.Position + Vector3.new(0, 9, 0), 15, C(200, 205, 215), M.Metal)
	kit:block(obs * CFrame.new(0, 13, -4) * CFrame.Angles(math.rad(35), 0, 0), Vector3.new(2, 2, 9), C(60, 60, 70), M.Metal)
	kit:obstacle(obs.Position, 9)
	kit:pilings(12, C(180, 200, 220), M.Ice)
end

function Theme.build(kit)
	kit:floors()
	kit:roads(C(168, 182, 204), nil, M.Slate, SNOW)
	kit:bank()
	kit:zoneSigns(function(zone)
		return C(40, 70, 120):Lerp(zone.GroundColor, 0.2)
	end, C(90, 60, 40))
	village(kit)
	lodgeRing(kit)
	caves(kit)
	summit(kit)
	kit:boundary(M.Ice, 0.05)
	-- Peaks on the horizon, always clear of the island and its shore.
	for i = 0, 11 do
		local angle = i * 30 + kit.rng:NextNumber(-10, 10)
		local height = kit.rng:NextNumber(110, 210)
		local radius = height * kit.rng:NextNumber(1.1, 1.4)
		local r = 345 + radius + kit.rng:NextNumber(0, 160)
		Props.mountain(kit, kit.polar(angle, r, -2), radius, height, C(84, 92, 118), SNOW)
	end
end

return Theme
