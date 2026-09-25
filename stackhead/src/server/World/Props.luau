-- Reusable decoration props. Every function takes the Kit and a local
-- position (Y = floor height) and returns nothing; callers register
-- obstacles when the prop should keep items away.

local Props = {}

local C = Color3.fromRGB
local M = Enum.Material

function Props.tree(kit, base: Vector3, scale: number, leafColor: Color3?)
	local rng = kit.rng
	local leaves = leafColor or C(76, 165, 70):Lerp(C(128, 196, 70), rng:NextNumber())
	kit:column(base, 5 * scale, 1.3 * scale, C(112, 78, 48), M.Wood)
	kit:ball(base + Vector3.new(0, 6.2 * scale, 0), 6.4 * scale, leaves, M.SmoothPlastic, { CanCollide = false })
	kit:ball(
		base + Vector3.new(1.6 * scale, 5.2 * scale, 0.8 * scale),
		4 * scale,
		leaves:Lerp(C(40, 120, 50), 0.25),
		M.SmoothPlastic,
		{ CanCollide = false }
	)
	kit:ball(
		base + Vector3.new(-1.4 * scale, 5.6 * scale, -1 * scale),
		3.8 * scale,
		leaves:Lerp(C(160, 210, 90), 0.2),
		M.SmoothPlastic,
		{ CanCollide = false }
	)
end

function Props.pine(kit, base: Vector3, scale: number, snowy: boolean?)
	kit:column(base, 2.5 * scale, 1 * scale, C(95, 65, 40), M.Wood)
	local green = C(40, 105, 70)
	for i, spec in { { 7, 2.6 }, { 5.4, 2.4 }, { 3.8, 2.2 }, { 2.2, 2 } } do
		local y = 2 * scale + (i - 1) * 1.9 * scale
		kit:column(
			base + Vector3.new(0, y, 0),
			spec[2] * scale,
			spec[1] * scale,
			green:Lerp(C(60, 130, 90), i / 5),
			M.SmoothPlastic,
			{ CanCollide = i == 1 }
		)
		if snowy then
			kit:column(
				base + Vector3.new(0, y + spec[2] * scale - 0.2, 0),
				0.35 * scale,
				spec[1] * scale * 0.85,
				C(248, 252, 255),
				M.Snow,
				{ CanCollide = false }
			)
		end
	end
end

function Props.lamp(kit, base: Vector3, poleColor: Color3?, lightColor: Color3?)
	local pole = poleColor or C(40, 60, 50)
	kit:column(base, 0.6, 1.2, pole)
	kit:column(base, 9, 0.45, pole)
	kit:ball(base + Vector3.new(0, 9.3, 0), 1.5, lightColor or C(255, 225, 150), M.Neon, { CanCollide = false })
	kit:column(base + Vector3.new(0, 9.9, 0), 0.3, 1.6, pole, nil, { CanCollide = false })
end

function Props.bench(kit, cf: CFrame, color: Color3?)
	local wood = color or C(170, 110, 60)
	local iron = C(50, 50, 55)
	kit:block(cf * CFrame.new(0, 1.2, 0), Vector3.new(5, 0.3, 1.4), wood, M.Wood)
	kit:block(cf * CFrame.new(0, 2.1, 0.6), Vector3.new(5, 1, 0.25), wood, M.Wood)
	for _, x in { -2.1, 2.1 } do
		kit:block(cf * CFrame.new(x, 0.6, 0), Vector3.new(0.3, 1.2, 1.3), iron, M.Metal)
	end
end

function Props.flowerBed(kit, base: Vector3, radius: number, soil: Color3?, colors: { Color3 }?)
	local palette = colors or { C(255, 90, 110), C(255, 210, 60), C(250, 250, 250), C(190, 120, 255), C(255, 150, 60) }
	kit:column(base, 0.8, radius * 2 + 0.6, C(200, 190, 175))
	kit:column(base, 0.95, radius * 2, soil or C(110, 75, 50))
	local count = math.floor(radius * 3)
	for i = 1, count do
		local a = kit.rng:NextNumber(0, math.pi * 2)
		local d = kit.rng:NextNumber(0, radius - 0.5)
		local p = base + Vector3.new(math.cos(a) * d, 1.2, math.sin(a) * d)
		kit:ball(p, kit.rng:NextNumber(0.6, 0.9), palette[(i % #palette) + 1], M.SmoothPlastic, { CanCollide = false })
	end
	kit:ball(base + Vector3.new(0, 1.3, 0), radius * 0.9, C(70, 150, 60), M.SmoothPlastic, { CanCollide = false })
end

function Props.fountain(kit, base: Vector3, stone: Color3?, water: Color3?)
	local s = stone or C(210, 205, 195)
	local w = water or C(90, 180, 240)
	kit:column(base, 1.4, 12, s)
	kit:column(base + Vector3.new(0, 1.2, 0), 0.25, 10.8, w, M.Glass, { CanCollide = false })
	kit:column(base, 4.5, 1.8, s)
	kit:column(base + Vector3.new(0, 4.3, 0), 0.7, 5, s)
	kit:column(base + Vector3.new(0, 4.8, 0), 0.25, 4.2, w, M.Glass, { CanCollide = false })
	kit:column(base + Vector3.new(0, 4.8, 0), 2.2, 0.8, s)
	kit:ball(base + Vector3.new(0, 7.3, 0), 1.3, w, M.Neon, { CanCollide = false, Transparency = 0.3 })
end

function Props.fenceRun(kit, from: Vector3, to: Vector3, color: Color3?, height: number?)
	local col = color or C(245, 245, 240)
	local h = height or 2.4
	local length = (to - from).Magnitude
	local mid = (from + to) / 2
	local rot = CFrame.lookAt(from, to).Rotation
	kit:block(CFrame.new(mid + Vector3.new(0, h * 0.8, 0)) * rot, Vector3.new(0.25, 0.35, length), col)
	kit:block(CFrame.new(mid + Vector3.new(0, h * 0.4, 0)) * rot, Vector3.new(0.25, 0.35, length), col)
	local posts = math.max(2, math.floor(length / 2.5) + 1)
	for i = 0, posts - 1 do
		local p = from:Lerp(to, i / (posts - 1))
		kit:block(CFrame.new(p + Vector3.new(0, h / 2, 0)) * rot, Vector3.new(0.35, h, 0.35), col)
	end
end

function Props.house(kit, cf: CFrame, wall: Color3, roof: Color3, width: number?, depth: number?)
	local w, d = width or 13, depth or 11
	local h = 8.5
	kit:block(cf * CFrame.new(0, 0.3, 0), Vector3.new(w + 1, 0.6, d + 1), C(200, 195, 185))
	kit:block(cf * CFrame.new(0, 0.6 + h / 2, 0), Vector3.new(w, h, d), wall)
	local roofH = 4.5
	kit:wedge({
		CFrame = cf * CFrame.new(0, 0.6 + h + roofH / 2, -d / 4 - 0.25),
		Size = Vector3.new(w + 1.2, roofH, d / 2 + 0.5),
		Color = roof,
	})
	kit:wedge({
		CFrame = cf * CFrame.new(0, 0.6 + h + roofH / 2, d / 4 + 0.25) * CFrame.Angles(0, math.pi, 0),
		Size = Vector3.new(w + 1.2, roofH, d / 2 + 0.5),
		Color = roof,
	})
	-- Front (-Z) faces the street.
	kit:block(cf * CFrame.new(0, 0.6 + 2.6, -d / 2 - 0.1), Vector3.new(2.6, 5.2, 0.3), C(120, 80, 50), M.Wood)
	kit:block(cf * CFrame.new(0.9, 0.6 + 2.6, -d / 2 - 0.3), Vector3.new(0.3, 0.3, 0.2), C(255, 210, 80), M.Metal)
	for _, x in { -w / 2 + 2.6, w / 2 - 2.6 } do
		kit:block(cf * CFrame.new(x, 0.6 + 4.6, -d / 2 - 0.1), Vector3.new(2.6, 2.4, 0.2), C(170, 215, 245), M.Glass)
		kit:block(cf * CFrame.new(x, 0.6 + 4.6, -d / 2 - 0.15), Vector3.new(3.1, 2.9, 0.1), C(250, 250, 250))
	end
	kit:block(cf * CFrame.new(w / 2 - 2.5, 0.6 + h + 3.5, d / 4), Vector3.new(1.6, 4, 1.6), C(150, 80, 60))
end

function Props.stall(kit, cf: CFrame, awningA: Color3, awningB: Color3)
	local wood = C(185, 135, 85)
	kit:block(cf * CFrame.new(0, 1.6, 0), Vector3.new(8, 3.2, 3), wood, M.Wood)
	kit:block(cf * CFrame.new(0, 3.25, -0.2), Vector3.new(8.4, 0.3, 3.6), C(225, 190, 140), M.Wood)
	for _, x in { -3.65, 3.65 } do
		kit:block(cf * CFrame.new(x, 4, 1.15), Vector3.new(0.4, 8, 0.4), C(245, 245, 245))
		kit:block(cf * CFrame.new(x, 3.6, -1.15), Vector3.new(0.4, 3.8, 0.4), C(245, 245, 245))
	end
	-- Striped awning: tall at the back (+Z), sloping to the customer side.
	for i = 0, 5 do
		kit:wedge({
			CFrame = cf * CFrame.new(-3.75 + i * 1.5, 6.4, -0.3),
			Size = Vector3.new(1.5, 1.8, 4.4),
			Color = if i % 2 == 0 then awningA else awningB,
		})
	end
	-- Goods on the counter.
	local goods = { C(230, 50, 50), C(255, 200, 40), C(90, 190, 70), C(255, 140, 40) }
	for i = 0, 4 do
		kit:ball(
			cf * CFrame.new(-3 + i * 1.5, 3.8, -0.3).Position,
			0.9,
			goods[(i % #goods) + 1],
			nil,
			{ CanCollide = false }
		)
	end
end

function Props.crateStack(kit, base: Vector3, count: number)
	for i = 1, count do
		local offset = Vector3.new(kit.rng:NextNumber(-1.5, 1.5), 0, kit.rng:NextNumber(-1.5, 1.5))
		local layer = (i - 1) // 3
		kit:block(
			CFrame.new(base + offset + Vector3.new(0, 1.25 + layer * 2.5, 0))
				* CFrame.Angles(0, kit.rng:NextNumber(-0.4, 0.4), 0),
			Vector3.new(2.5, 2.5, 2.5),
			C(175, 125, 75),
			M.Wood
		)
	end
end

function Props.barrels(kit, base: Vector3, count: number, color: Color3?)
	for i = 1, count do
		local a = i / count * math.pi * 2
		kit:column(
			base + Vector3.new(math.cos(a) * 1.4, 0, math.sin(a) * 1.4),
			2.8,
			1.9,
			color or C(150, 95, 55),
			M.Wood
		)
	end
end

function Props.boat(kit, cf: CFrame, hull: Color3, cabin: Color3)
	-- Hull sits in the water; bow points along -Z.
	kit:block(cf * CFrame.new(0, -0.4, 1.5), Vector3.new(6, 2.6, 13), hull)
	kit:wedge({
		CFrame = cf * CFrame.new(0, -0.4, -7.5) * CFrame.Angles(0, math.pi, 0),
		Size = Vector3.new(6, 2.6, 5),
		Color = hull,
	})
	kit:block(cf * CFrame.new(0, 0.95, 1.5), Vector3.new(5.6, 0.2, 12.4), C(210, 170, 120), M.WoodPlanks)
	kit:block(cf * CFrame.new(0, 2.6, 3.5), Vector3.new(4, 3.2, 4.5), cabin)
	kit:block(cf * CFrame.new(0, 2.9, 1.2), Vector3.new(3.4, 1.4, 0.2), C(170, 215, 245), M.Glass)
	kit:block(cf * CFrame.new(0, 4.4, 3.5), Vector3.new(4.6, 0.4, 5.2), hull)
	kit:column((cf * CFrame.new(0, 1, -2)).Position, 9, 0.35, C(120, 90, 60), M.Wood)
end

function Props.lighthouse(kit, base: Vector3)
	kit:column(base + Vector3.new(0, -3, 0), 4, 16, C(140, 140, 150), M.Slate)
	for i = 0, 5 do
		kit:column(
			base + Vector3.new(0, 1 + i * 4, 0),
			4,
			8 - i * 0.6,
			if i % 2 == 0 then C(245, 245, 245) else C(220, 50, 50)
		)
	end
	kit:column(base + Vector3.new(0, 25, 0), 1, 7, C(40, 40, 45), M.Metal)
	kit:column(base + Vector3.new(0, 26, 0), 3, 4.5, C(255, 240, 170), M.Neon)
	kit:column(base + Vector3.new(0, 29, 0), 1, 5.5, C(220, 50, 50))
	kit:ball(base + Vector3.new(0, 30.2, 0), 3, C(220, 50, 50))
end

-- A small island on the horizon: sand shelf, grass mesa, a few trees.
function Props.island(kit, center: Vector3, radius: number, grass: Color3?, sand: Color3?)
	local base = Vector3.new(center.X, -1.5, center.Z)
	kit:column(base, 2.4, radius * 2, sand or C(240, 220, 160), M.Sand, { CanCollide = false, CanQuery = false })
	kit:column(
		base,
		5 + radius * 0.08,
		radius * 1.6,
		grass or C(100, 170, 80),
		M.Grass,
		{ CanCollide = false, CanQuery = false }
	)
	kit:column(
		base,
		8 + radius * 0.14,
		radius * 0.9,
		(grass or C(100, 170, 80)):Lerp(C(60, 120, 60), 0.3),
		M.Grass,
		{ CanCollide = false, CanQuery = false }
	)
	local top = base + Vector3.new(0, 8 + radius * 0.14, 0)
	for i = 1, 3 do
		local a = i * 2.1
		Props.tree(kit, top + Vector3.new(math.cos(a) * radius * 0.25, 0, math.sin(a) * radius * 0.25), 2.2)
	end
end

-- Square pyramid made of four wedges (tall faces meet in the middle).
function Props.pyramid(kit, base: Vector3, width: number, height: number, color: Color3, material: Enum.Material?)
	for k = 0, 3 do
		local rot = CFrame.new(base) * CFrame.Angles(0, k * math.pi / 2, 0)
		kit:wedge({
			CFrame = rot * CFrame.new(0, height / 2, -width / 4),
			Size = Vector3.new(width, height, width / 2),
			Color = color,
			Material = material or M.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
		})
	end
end

-- Cone from 16 narrow wedges radiating from the centre; their union is a
-- 16-sided pyramid (each wedge is as wide as the rim chord, so no gaps).
function Props.cone(kit, base: Vector3, radius: number, height: number, color: Color3, material: Enum.Material?)
	local sides = 16
	local width = 2 * radius * math.tan(math.pi / sides) * 1.02
	for k = 0, sides - 1 do
		local rot = CFrame.new(base) * CFrame.Angles(0, k * 2 * math.pi / sides, 0)
		kit:wedge({
			CFrame = rot * CFrame.new(0, height / 2, -radius / 2),
			Size = Vector3.new(width, height, radius),
			Color = color,
			Material = material or M.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
		})
	end
end

-- Snow-capped mountain for horizons: rock cone with a snow cone on top
-- (same slope, nudged up so the faces don't z-fight).
function Props.mountain(kit, base: Vector3, radius: number, height: number, rock: Color3, snow: Color3)
	Props.cone(kit, base, radius, height, rock, M.Slate)
	local cap = 0.42
	Props.cone(kit, base + Vector3.new(0, height * (1 - cap) + 0.8, 0), radius * cap, height * cap, snow, M.Snow)
end

function Props.lollipop(kit, base: Vector3, height: number, candy: Color3, swirl: Color3)
	kit:column(base, height, height * 0.06, C(250, 250, 250))
	local size = height * 0.45
	local cf = CFrame.lookAt(base + Vector3.new(0, height + size * 0.35, 0), Vector3.new(0, base.Y + height, 0))
	kit:cylinder(cf * CFrame.Angles(0, math.pi / 2, 0), size * 0.18, size, candy)
	kit:cylinder(cf * CFrame.Angles(0, math.pi / 2, 0), size * 0.2, size * 0.62, swirl)
	kit:cylinder(cf * CFrame.Angles(0, math.pi / 2, 0), size * 0.22, size * 0.28, candy:Lerp(C(255, 255, 255), 0.4))
end

return Props
