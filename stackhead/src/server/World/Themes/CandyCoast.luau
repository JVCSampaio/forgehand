-- Candy Coast: sweets by the sea. Candy shops and lollipop trees near the
-- bank, cupcake houses and giant donuts on Bakery Row, palms and parasols on
-- Sugar Beach, and a funfair pier with a ferris wheel.

local Props = require(script.Parent.Parent.Props)

local C = Color3.fromRGB
local M = Enum.Material

local Theme = {}

local PASTELS = { C(255, 170, 205), C(170, 225, 255), C(190, 250, 200), C(255, 235, 150), C(215, 185, 255), C(255, 200, 160) }
local BRIGHT = { C(255, 80, 150), C(80, 190, 255), C(90, 220, 130), C(255, 200, 40), C(170, 100, 255), C(255, 130, 60) }

local function pick(kit, list)
	return list[kit.rng:NextInteger(1, #list)]
end

local function candyCane(kit, base: Vector3, height: number)
	local segments = math.floor(height / 1.2)
	for i = 0, segments - 1 do
		kit:column(base + Vector3.new(0, i * 1.2, 0), 1.2, 0.8, if i % 2 == 0 then C(230, 40, 60) else C(255, 255, 255))
	end
	kit:ball(base + Vector3.new(0, segments * 1.2 + 0.4, 0), 1.3, C(255, 230, 130), M.Neon, { CanCollide = false })
end

local function gumdrop(kit, base: Vector3, size: number)
	kit:ball(base, size, pick(kit, BRIGHT), M.Glass, { Transparency = 0.1 })
end

local function candyShop(kit, cf: CFrame)
	local wall = pick(kit, PASTELS)
	local w, d, h = 12, 10, 8
	kit:block(cf * CFrame.new(0, h / 2, 0), Vector3.new(w, h, d), wall)
	-- Frosting roof: a thick slab with drips.
	local icing = pick(kit, { C(255, 250, 250), C(255, 190, 220), C(120, 70, 50) })
	kit:block(cf * CFrame.new(0, h + 0.8, 0), Vector3.new(w + 1.2, 1.6, d + 1.2), icing)
	for x = -w / 2, w / 2, 2 do
		kit:ball((cf * CFrame.new(x, h + 0.1, -d / 2 - 0.4)).Position, 1.3, icing, nil, { CanCollide = false })
	end
	kit:ball((cf * CFrame.new(0, h + 2.3, 0)).Position, 2.6, C(220, 20, 50))
	-- Striped awning over the window.
	for i = 0, 5 do
		kit:wedge({ CFrame = cf * CFrame.new(-3.75 + i * 1.5, 5.6, -d / 2 - 1.2), Size = Vector3.new(1.5, 1.2, 2.4), Color = if i % 2 == 0 then pick(kit, BRIGHT) else C(255, 255, 255) })
	end
	kit:block(cf * CFrame.new(-2.5, 2.8, -d / 2 - 0.1), Vector3.new(4, 3, 0.2), C(190, 235, 255), M.Glass)
	kit:block(cf * CFrame.new(3, 2.4, -d / 2 - 0.1), Vector3.new(2.4, 4.8, 0.3), C(255, 255, 255))
end

local function cupcakeHouse(kit, cf: CFrame)
	local base = cf.Position
	kit:column(base, 9, 14, pick(kit, PASTELS))
	for i = 0, 11 do
		local a = i / 12 * 360
		kit:block(CFrame.new(base + kit.polar(a, 6.9, 4.5)) * CFrame.Angles(0, -math.rad(a), 0), Vector3.new(0.4, 9, 1.2), C(255, 255, 255), nil, { CanCollide = false })
	end
	local frosting = pick(kit, { C(255, 170, 210), C(190, 250, 220), C(255, 240, 200), C(150, 90, 60) })
	kit:ball(base + Vector3.new(0, 11, 0), 16, frosting, nil, { CanCollide = false })
	kit:ball(base + Vector3.new(0, 17.5, 0), 9, frosting:Lerp(C(255, 255, 255), 0.2), nil, { CanCollide = false })
	kit:ball(base + Vector3.new(0, 22.5, 0), 3.4, C(220, 20, 50))
	kit:block(cf * CFrame.new(0, 2.6, -7.1), Vector3.new(3, 5.2, 0.4), C(120, 70, 50))
	for i = 1, 14 do
		local a = kit.rng:NextNumber(0, 6.28)
		local y = kit.rng:NextNumber(10, 17)
		kit:block(CFrame.new(base + Vector3.new(math.cos(a) * 7.2, y, math.sin(a) * 7.2)) * CFrame.Angles(0, a, 0.6), Vector3.new(0.3, 1.1, 0.3), pick(kit, BRIGHT), nil, { CanCollide = false })
	end
end

local function donut(kit, base: Vector3, radius: number)
	kit:column(base, radius * 0.7, radius * 2, C(225, 165, 95))
	kit:column(base + Vector3.new(0, radius * 0.7 - 0.05, 0), 0.5, radius * 1.85, pick(kit, { C(255, 120, 180), C(120, 70, 50), C(255, 250, 250) }))
	kit:column(base + Vector3.new(0, radius * 0.7, 0), 0.6, radius * 0.7, C(60, 35, 25))
	for i = 1, 16 do
		local a = kit.rng:NextNumber(0, 6.28)
		local d = kit.rng:NextNumber(radius * 0.45, radius * 0.85)
		kit:block(CFrame.new(base + Vector3.new(math.cos(a) * d, radius * 0.7 + 0.5, math.sin(a) * d)) * CFrame.Angles(0, a, 0), Vector3.new(0.3, 0.3, 1.2), pick(kit, BRIGHT), nil, { CanCollide = false })
	end
end

local function palm(kit, base: Vector3, height: number)
	local lean = kit.rng:NextNumber(-0.25, 0.25)
	local top = base
	for i = 0, 5 do
		local segment = CFrame.new(base) * CFrame.Angles(lean, 0, lean * 0.6) * CFrame.new(0, i * height / 6 + height / 12, 0)
		kit:cylinder(segment * CFrame.Angles(0, 0, math.rad(90)), height / 6 + 0.1, 1.3 - i * 0.1, C(170, 120, 75), M.Wood)
		top = (CFrame.new(base) * CFrame.Angles(lean, 0, lean * 0.6) * CFrame.new(0, height, 0)).Position
	end
	for k = 0, 6 do
		local frond = CFrame.new(top) * CFrame.Angles(0, k * 2 * math.pi / 7, 0) * CFrame.Angles(math.rad(-25), 0, 0) * CFrame.new(0, 0, -3.2)
		kit:block(frond, Vector3.new(1.6, 0.2, 6.5), C(70, 190, 90), M.Grass, { CanCollide = false })
	end
	kit:ball(top - Vector3.new(0, 0.6, 0), 1.2, C(140, 90, 50))
end

local function parasol(kit, base: Vector3)
	local color = pick(kit, BRIGHT)
	kit:column(base, 7, 0.3, C(250, 250, 250))
	kit:column(base + Vector3.new(0, 6.6, 0), 0.6, 8, color, nil, { CanCollide = false })
	kit:column(base + Vector3.new(0, 6.9, 0), 0.6, 4, C(255, 255, 255), nil, { CanCollide = false })
	local towel = CFrame.new(base + Vector3.new(2.5, 0.08, 0)) * CFrame.Angles(0, kit.rng:NextNumber(0, 3), 0)
	kit:block(towel, Vector3.new(2.4, 0.1, 5), pick(kit, PASTELS), M.Fabric, { CanCollide = false })
end

local function ferrisWheel(kit, base: Vector3, facing: Vector3)
	local frame = CFrame.lookAt(base, base + facing)
	local radius = 22
	local hub = frame * CFrame.new(0, radius + 4, 0)
	for _, x in { -3, 3 } do
		kit:block(frame * CFrame.new(x, (radius + 4) / 2, -6) * CFrame.Angles(math.rad(14), 0, 0), Vector3.new(1, radius + 6, 1), C(255, 255, 255), M.Metal)
		kit:block(frame * CFrame.new(x, (radius + 4) / 2, 6) * CFrame.Angles(math.rad(-14), 0, 0), Vector3.new(1, radius + 6, 1), C(255, 255, 255), M.Metal)
	end
	kit:cylinder(hub, 7, 3, C(255, 90, 170), M.Metal)
	local cars = 12
	for i = 0, cars - 1 do
		local a = i / cars * math.pi * 2
		local spoke = hub * CFrame.Angles(a, 0, 0)
		kit:block(spoke * CFrame.new(0, radius / 2, 0), Vector3.new(0.5, radius, 0.5), C(255, 255, 255), M.Metal, { CanCollide = false })
		-- Rim segment.
		kit:block(spoke * CFrame.new(0, radius, 0), Vector3.new(0.8, 0.8, 2 * math.pi * radius / cars + 0.6), C(255, 120, 190), M.Neon, { CanCollide = false })
		local carPos = (spoke * CFrame.new(0, radius, 0)).Position - Vector3.new(0, 2, 0)
		kit:block(CFrame.new(carPos) * frame.Rotation, Vector3.new(5, 2.6, 3.4), BRIGHT[(i % #BRIGHT) + 1], nil, { CanCollide = false })
		kit:block(CFrame.new(carPos + Vector3.new(0, 1.9, 0)) * frame.Rotation, Vector3.new(5.4, 0.4, 3.8), C(255, 255, 255), nil, { CanCollide = false })
	end
	kit:obstacle(base, 12)
end

local function carousel(kit, base: Vector3)
	kit:column(base, 1.2, 22, C(255, 240, 250))
	kit:column(base + Vector3.new(0, 1.2, 0), 9, 1.4, C(255, 200, 60), M.Metal)
	kit:column(base + Vector3.new(0, 10, 0), 1.6, 24, C(255, 120, 190))
	for i = 0, 11 do
		local a = i / 12 * 360
		kit:block(CFrame.new(base + kit.polar(a, 11.4, 11.2)) * CFrame.Angles(0, -math.rad(a), 0), Vector3.new(0.4, 1.2, 6), if i % 2 == 0 then C(255, 255, 255) else C(255, 90, 170), nil, { CanCollide = false })
	end
	kit:ball(base + Vector3.new(0, 12.5, 0), 7, C(255, 170, 210))
	for i = 0, 7 do
		local a = i / 8 * 360
		local p = base + kit.polar(a, 8)
		kit:column(p + Vector3.new(0, 1.2, 0), 9, 0.3, C(255, 220, 80), M.Metal, { CanCollide = false })
		kit:block(CFrame.new(p + Vector3.new(0, 3.6, 0)) * CFrame.Angles(0, -math.rad(a), 0), Vector3.new(1, 1.6, 3), PASTELS[(i % #PASTELS) + 1])
	end
end

local function sweets(kit)
	local top = kit:top(1)
	for _, angle in kit.roadAngles do
		for _, r in { 44, 66 } do
			for _, side in { -1, 1 } do
				local cf = kit:roadside(angle, r, side * (kit.roadHalfWidth + 9), top)
				candyShop(kit, cf)
				kit:obstacle(cf.Position, 7.5)
			end
		end
		for r = 32, 286, 18 do
			local index = 1
			for i, zone in kit.zones do
				if r >= zone.InnerRadius and r < zone.OuterRadius then
					index = i
				end
			end
			for _, side in { -1, 1 } do
				local p = kit:roadside(angle, r, side * (kit.roadHalfWidth + 1.6), kit:top(index)).Position
				candyCane(kit, p, 9.6)
				kit:obstacle(p, 1.4)
			end
		end
	end
	for _, angle in { 45, 135, 225, 315 } do
		local center = kit.polar(angle, 58, top)
		Props.fountain(kit, center, C(255, 220, 235), C(120, 70, 50))
		kit:obstacle(center, 8)
	end
	kit:scatter(1, 16, 3, function(p)
		Props.lollipop(kit, p, kit.rng:NextNumber(7, 10), pick(kit, BRIGHT), C(255, 255, 255))
	end)
	kit:scatter(1, 14, 2, function(p)
		gumdrop(kit, p, kit.rng:NextNumber(2.5, 4))
	end)
end

local function bakery(kit)
	local top = kit:top(2)
	for _, angle in kit.roadAngles do
		for _, r in { 102, 132 } do
			for _, side in { -1, 1 } do
				local cf = kit:roadside(angle, r, side * (kit.roadHalfWidth + 12), top)
				cupcakeHouse(kit, cf)
				kit:obstacle(cf.Position, 9)
			end
		end
	end
	for _, angle in { 45, 135, 225, 315 } do
		local p = kit.polar(angle, 118, top)
		donut(kit, p, 9)
		kit:obstacle(p, 10)
	end
	kit:scatter(2, 18, 3, function(p)
		Props.lollipop(kit, p, kit.rng:NextNumber(8, 12), pick(kit, BRIGHT), pick(kit, PASTELS))
	end)
	kit:scatter(2, 16, 2.5, function(p)
		gumdrop(kit, p, kit.rng:NextNumber(3, 5))
	end)
end

local function beach(kit)
	kit:scatter(3, 30, 3, function(p)
		palm(kit, p, kit.rng:NextNumber(10, 15))
	end)
	kit:scatter(3, 22, 3, function(p)
		parasol(kit, p)
	end)
	kit:scatter(3, 8, 3, function(p)
		kit:block(CFrame.new(p + Vector3.new(0, 1, 0)), Vector3.new(4, 2, 4), C(240, 210, 150), M.Sand)
		for _, offset in { Vector3.new(1.4, 0, 1.4), Vector3.new(-1.4, 0, -1.4), Vector3.new(1.4, 0, -1.4), Vector3.new(-1.4, 0, 1.4) } do
			kit:column(p + offset + Vector3.new(0, 2, 0), 1.6, 1.2, C(240, 210, 150), M.Sand)
		end
		kit:column(p + Vector3.new(0, 2, 0), 3, 1.8, C(240, 210, 150), M.Sand)
	end)
	-- Lifeguard towers on two diagonals.
	for _, angle in { 45, 225 } do
		local p = kit.polar(angle, 190, kit:top(3))
		for _, x in { -1.5, 1.5 } do
			for _, z in { -1.5, 1.5 } do
				kit:column(p + Vector3.new(x, 0, z), 7, 0.4, C(255, 255, 255))
			end
		end
		kit:block(CFrame.new(p + Vector3.new(0, 7.5, 0)), Vector3.new(4.4, 1, 4.4), C(255, 90, 80))
		kit:block(CFrame.new(p + Vector3.new(0, 10, 0)), Vector3.new(4.8, 0.3, 4.8), C(255, 255, 255))
		kit:obstacle(p, 4)
	end
end

local function pier(kit)
	local top = kit:top(4)
	ferrisWheel(kit, kit.polar(45, 256, top), kit.polar(135, 1))
	carousel(kit, kit.polar(225, 255, top))
	kit:obstacle(kit.polar(225, 255, top), 13)
	for _, angle in kit.roadAngles do
		for _, r in { 238, 270 } do
			for _, side in { -1, 1 } do
				local cf = kit:roadside(angle, r, side * (kit.roadHalfWidth + 6.5), top)
				Props.stall(kit, cf, pick(kit, BRIGHT), C(255, 255, 255))
				kit:obstacle(cf.Position, 5.5)
			end
		end
	end
	kit:scatter(4, 16, 2, function(p)
		gumdrop(kit, p, kit.rng:NextNumber(2, 3.5))
	end)
	kit:scatter(4, 14, 3, function(p)
		Props.lollipop(kit, p, kit.rng:NextNumber(8, 12), pick(kit, BRIGHT), C(255, 255, 255))
	end)
	-- Ice-cream carts.
	kit:scatter(4, 8, 3, function(p)
		local cf = CFrame.new(p) * CFrame.Angles(0, kit.rng:NextNumber(0, 6.28), 0)
		kit:block(cf * CFrame.new(0, 2, 0), Vector3.new(5, 2.4, 2.6), C(255, 255, 255))
		kit:block(cf * CFrame.new(0, 2, -1.35), Vector3.new(4.4, 1.2, 0.1), pick(kit, BRIGHT))
		for _, x in { -1.8, 1.8 } do
			kit:cylinder(cf * CFrame.new(x, 0.8, 0) * CFrame.Angles(0, math.pi / 2, 0), 2.8, 1.6, C(60, 60, 70))
		end
		kit:column((cf * CFrame.new(0, 3.2, 0)).Position, 4, 0.25, C(250, 250, 250))
		kit:column((cf * CFrame.new(0, 7, 0)).Position, 0.5, 6, pick(kit, BRIGHT), nil, { CanCollide = false })
		for k = 0, 2 do
			kit:ball((cf * CFrame.new(-1.2 + k * 1.2, 3.8, 0)).Position, 1, PASTELS[k + 1], nil, { CanCollide = false })
		end
	end)
	kit:pilings(9, C(255, 170, 210), M.SmoothPlastic)
	for i, angle in { 20, 160, 250, 340 } do
		local cf = CFrame.lookAt(kit.polar(angle, 318, -0.4), kit.polar(angle + 10, 318, -0.4))
		Props.boat(kit, cf, BRIGHT[i], C(255, 255, 255))
	end
end

function Theme.build(kit)
	kit:floors()
	kit:roads(C(120, 72, 52), C(255, 240, 250), M.SmoothPlastic, C(255, 150, 200))
	kit:bank()
	kit:zoneSigns(function()
		return C(255, 110, 170)
	end, C(255, 255, 255))
	sweets(kit)
	bakery(kit)
	beach(kit)
	pier(kit)
	kit:boundary(M.Glass, 0.15)
	-- Giant lollipops and candy islands on the horizon.
	for i = 0, 9 do
		local angle = i * 36 + kit.rng:NextNumber(-10, 10)
		local r = kit.rng:NextNumber(420, 700)
		if i % 2 == 0 then
			Props.lollipop(kit, kit.polar(angle, r, -2), kit.rng:NextNumber(60, 110), BRIGHT[(i % #BRIGHT) + 1], C(255, 255, 255))
		else
			Props.island(kit, kit.polar(angle, r), kit.rng:NextNumber(35, 60), C(255, 170, 210), C(250, 230, 180))
		end
	end
end

return Theme
