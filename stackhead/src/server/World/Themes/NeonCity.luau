-- Neon City: a city that never sleeps. Arcades around the bank, glass towers
-- in the Tech Mall, a robot factory, and a skyline of glowing skyscrapers that
-- rings the island. Lit for dusk; neon does the rest.

local Props = require(script.Parent.Parent.Props)

local C = Color3.fromRGB
local M = Enum.Material

local Theme = {}

local NEON = { C(0, 255, 230), C(255, 60, 200), C(255, 220, 40), C(120, 90, 255), C(60, 255, 120), C(255, 90, 60) }
local SIGNS = { "ARCADE", "GAMES", "PIZZA", "STACK", "BYTE", "RAMEN", "PIXEL", "NEON", "LEVEL UP", "COMBO" }

local function pick(kit, list)
	return list[kit.rng:NextInteger(1, #list)]
end

local function sign(kit, cf: CFrame, size: Vector3, text: string, color: Color3)
	local board = kit:block(cf, size, C(20, 18, 30))
	kit:block(cf * CFrame.new(0, 0, size.Z / 2 + 0.05), Vector3.new(size.X + 0.3, size.Y + 0.3, 0.1), color, M.Neon, { CanCollide = false })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = color
		label.Parent = gui
		gui.Parent = board
	end
end

local function arcade(kit, cf: CFrame)
	local h = kit.rng:NextNumber(10, 16)
	local body = pick(kit, { C(40, 36, 60), C(50, 40, 80), C(30, 40, 60) })
	local glow = pick(kit, NEON)
	kit:block(cf * CFrame.new(0, h / 2, 0), Vector3.new(13, h, 11), body, M.SmoothPlastic)
	kit:block(cf * CFrame.new(0, h + 0.2, 0), Vector3.new(13.4, 0.4, 11.4), glow, M.Neon)
	kit:block(cf * CFrame.new(0, 2.8, -5.55), Vector3.new(9, 5, 0.2), glow:Lerp(C(0, 0, 0), 0.4), M.Glass)
	kit:block(cf * CFrame.new(0, 5.6, -5.7), Vector3.new(10, 0.3, 0.3), glow, M.Neon)
	sign(kit, cf * CFrame.new(0, h - 2.5, -5.9), Vector3.new(10, 3, 0.4), pick(kit, SIGNS), glow)
end

local function tower(kit, cf: CFrame, width: number, height: number, body: Color3, trim: Color3, strips: number)
	kit:block(cf * CFrame.new(0, height / 2, 0), Vector3.new(width, height, width), body, M.SmoothPlastic)
	-- Lit window bands on every face.
	local window = body:Lerp(C(150, 200, 255), 0.45)
	for k = 0, 3 do
		local face = cf * CFrame.Angles(0, k * math.pi / 2, 0)
		for _, x in { -width * 0.25, width * 0.25 } do
			kit:block(face * CFrame.new(x, height * 0.52, -width / 2 - 0.05), Vector3.new(width * 0.28, height * 0.86, 0.1), window, M.Glass, { CanCollide = false })
		end
	end
	for i = 1, strips do
		local y = height * i / (strips + 1)
		kit:block(cf * CFrame.new(0, y, 0), Vector3.new(width + 0.3, 0.5, width + 0.3), trim, M.Neon, { CanCollide = false })
	end
	kit:block(cf * CFrame.new(0, height + 0.5, 0), Vector3.new(width * 0.7, 1, width * 0.7), C(40, 40, 55))
	kit:column((cf * CFrame.new(0, height + 1, 0)).Position, height * 0.12, 0.5, C(120, 120, 135), M.Metal)
	kit:ball((cf * CFrame.new(0, height * 1.12 + 1.2, 0)).Position, 1.2, C(255, 40, 60), M.Neon, { CanCollide = false })
end

local function neonTree(kit, base: Vector3)
	local color = pick(kit, NEON)
	kit:column(base, 7, 0.6, C(40, 40, 50), M.Metal)
	for k = 0, 5 do
		local frond = CFrame.new(base + Vector3.new(0, 7, 0)) * CFrame.Angles(0, k * math.pi / 3, 0) * CFrame.Angles(math.rad(-30), 0, 0) * CFrame.new(0, 0, -2.2)
		kit:block(frond, Vector3.new(0.5, 0.2, 4.4), color, M.Neon, { CanCollide = false })
	end
end

local function holoRing(kit, base: Vector3)
	local color = pick(kit, NEON)
	kit:column(base, 0.6, 7, C(40, 40, 55), M.Metal)
	for i = 0, 2 do
		kit:column(base + Vector3.new(0, 3 + i * 3, 0), 0.25, 6 - i * 1.4, color, M.Neon, { CanCollide = false, Transparency = 0.2 })
	end
	kit:ball(base + Vector3.new(0, 12.5, 0), 2.2, color, M.Neon, { CanCollide = false, Transparency = 0.1 })
end

local function hoverCar(kit, position: Vector3, yaw: number)
	local cf = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	local color = pick(kit, { C(240, 240, 250), C(255, 80, 120), C(60, 200, 255), C(255, 200, 60) })
	kit:block(cf, Vector3.new(4, 1.4, 8), color, M.SmoothPlastic, { CanCollide = false })
	kit:block(cf * CFrame.new(0, 1.1, 0.5), Vector3.new(3.4, 1, 4), C(120, 200, 255), M.Glass, { CanCollide = false })
	kit:block(cf * CFrame.new(0, -0.8, 0), Vector3.new(3.6, 0.2, 7.4), pick(kit, NEON), M.Neon, { CanCollide = false })
end

local function factory(kit, cf: CFrame)
	kit:block(cf * CFrame.new(0, 8, 0), Vector3.new(24, 16, 18), C(70, 72, 84), M.DiamondPlate)
	for i = 0, 3 do
		kit:wedge({ CFrame = cf * CFrame.new(-9 + i * 6, 17.5, 0) * CFrame.Angles(0, math.pi / 2, 0), Size = Vector3.new(18, 3, 6), Color = C(90, 92, 105), Material = M.Metal })
	end
	kit:block(cf * CFrame.new(0, 5, -9.1), Vector3.new(12, 10, 0.3), C(255, 190, 40), M.DiamondPlate)
	kit:block(cf * CFrame.new(0, 11, -9.2), Vector3.new(14, 0.5, 0.3), C(255, 60, 60), M.Neon)
	-- Smokestacks with glowing bands.
	for _, x in { -8, 8 } do
		local base = (cf * CFrame.new(x, 16, 6)).Position
		kit:column(base, 18, 3, C(90, 90, 100), M.Metal)
		kit:column(base + Vector3.new(0, 12, 0), 0.8, 3.3, C(255, 60, 60), M.Neon)
		kit:column(base + Vector3.new(0, 16, 0), 0.8, 3.3, C(255, 60, 60), M.Neon)
	end
	-- Pipes along the side.
	for i = 0, 2 do
		kit:cylinder(cf * CFrame.new(12.8, 3 + i * 3, 0) * CFrame.Angles(0, math.pi / 2, 0), 18, 1.2, C(0, 180, 200), M.Metal)
	end
end

local function robotArm(kit, base: Vector3)
	kit:column(base, 1.4, 5, C(255, 170, 30), M.Metal)
	local cf = CFrame.new(base + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, kit.rng:NextNumber(0, 6.28), 0)
	kit:block(cf * CFrame.Angles(0, 0, math.rad(25)) * CFrame.new(0, 3.5, 0), Vector3.new(1.4, 7, 1.4), C(255, 170, 30), M.Metal)
	local elbow = cf * CFrame.Angles(0, 0, math.rad(25)) * CFrame.new(0, 7, 0)
	kit:ball(elbow.Position, 1.8, C(60, 60, 70), M.Metal)
	kit:block(elbow * CFrame.Angles(0, 0, math.rad(-80)) * CFrame.new(0, 2.8, 0), Vector3.new(1.2, 5.6, 1.2), C(255, 170, 30), M.Metal)
	kit:ball((elbow * CFrame.Angles(0, 0, math.rad(-80)) * CFrame.new(0, 5.8, 0)).Position, 1, C(0, 255, 230), M.Neon, { CanCollide = false })
end

local function conveyor(kit, cf: CFrame, length: number)
	kit:block(cf * CFrame.new(0, 1.2, 0), Vector3.new(3.2, 0.4, length), C(30, 30, 36))
	for z = -length / 2 + 1, length / 2 - 1, 2 do
		kit:cylinder(cf * CFrame.new(0, 1, z), 3.4, 0.5, C(150, 150, 160), M.Metal)
	end
	for _, x in { -1.8, 1.8 } do
		kit:block(cf * CFrame.new(x, 0.6, 0), Vector3.new(0.3, 1.2, length), C(255, 200, 40), M.Metal)
	end
	for z = -length / 2 + 2, length / 2 - 2, 4 do
		kit:block(cf * CFrame.new(0, 2, z), Vector3.new(1.4, 1.2, 1.4), pick(kit, NEON), M.Neon, { CanCollide = false })
	end
end

local function arcadeRing(kit)
	local top = kit:top(1)
	for _, angle in kit.roadAngles do
		for _, r in { 44, 66 } do
			for _, side in { -1, 1 } do
				local cf = kit:roadside(angle, r, side * (kit.roadHalfWidth + 9.5), top)
				arcade(kit, cf)
				kit:obstacle(cf.Position, 8)
			end
		end
		for r = 32, 286, 18 do
			local index = 1
			for i, zone in kit.zones do
				if r >= zone.InnerRadius and r < zone.OuterRadius then
					index = i
				end
			end
			local side = if (r // 18) % 2 == 0 then 1 else -1
			local p = kit:roadside(angle, r, side * (kit.roadHalfWidth + 1.6), kit:top(index)).Position
			Props.lamp(kit, p, C(30, 30, 40), pick(kit, NEON))
			kit:obstacle(p, 1.5)
		end
	end
	for _, angle in { 45, 135, 225, 315 } do
		local p = kit.polar(angle, 58, top)
		holoRing(kit, p)
		kit:obstacle(p, 4)
	end
	kit:scatter(1, 14, 2.5, function(p)
		neonTree(kit, p)
	end)
end

local function mall(kit)
	local top = kit:top(2)
	for _, angle in kit.roadAngles do
		for _, r in { 100, 132 } do
			for _, side in { -1, 1 } do
				local cf = kit:roadside(angle, r, side * (kit.roadHalfWidth + 11), top)
				tower(kit, cf, 14, kit.rng:NextNumber(24, 44), pick(kit, { C(70, 90, 140), C(90, 70, 140), C(50, 100, 130) }), pick(kit, NEON), 3)
				kit:obstacle(cf.Position, 9)
			end
		end
	end
	kit:scatter(2, 18, 2.5, function(p)
		neonTree(kit, p)
	end)
	kit:scatter(2, 8, 4, function(p)
		local cf = CFrame.new(p) * CFrame.Angles(0, kit.rng:NextNumber(0, 6.28), 0)
		kit:block(cf * CFrame.new(0, 3, 0), Vector3.new(0.6, 6, 0.6), C(40, 40, 50), M.Metal)
		sign(kit, cf * CFrame.new(0, 8, 0), Vector3.new(9, 4, 0.4), pick(kit, SIGNS), pick(kit, NEON))
	end)
end

local function factoryRing(kit)
	local top = kit:top(3)
	factory(kit, kit:roadside(0, 186, kit.roadHalfWidth + 18, top))
	factory(kit, kit:roadside(180, 186, -(kit.roadHalfWidth + 18), top))
	kit:obstacle(kit:roadside(0, 186, kit.roadHalfWidth + 18, top).Position, 16)
	kit:obstacle(kit:roadside(180, 186, -(kit.roadHalfWidth + 18), top).Position, 16)
	for _, angle in { 45, 135, 225, 315 } do
		local center = kit.polar(angle, 185, top)
		conveyor(kit, CFrame.lookAt(center, Vector3.new(0, top, 0)) * CFrame.Angles(0, math.pi / 2, 0), 26)
		kit:obstacle(center, 14)
	end
	kit:scatter(3, 12, 3.5, function(p)
		robotArm(kit, p)
	end)
	kit:scatter(3, 10, 3, function(p)
		Props.barrels(kit, p, 4, C(0, 150, 170))
	end)
end

local function skylineRing(kit)
	local top = kit:top(4)
	for _, angle in kit.roadAngles do
		for _, r in { 240, 272 } do
			for _, side in { -1, 1 } do
				local cf = kit:roadside(angle, r, side * (kit.roadHalfWidth + 12), top)
				tower(kit, cf, 16, kit.rng:NextNumber(50, 90), pick(kit, { C(45, 55, 95), C(70, 45, 105), C(35, 75, 100) }), pick(kit, NEON), 5)
				kit:obstacle(cf.Position, 10)
			end
		end
	end
	kit:scatter(4, 16, 2.5, function(p)
		holoRing(kit, p)
	end)
	for i = 1, 16 do
		local angle = i * 22.5 + kit.rng:NextNumber(-6, 6)
		hoverCar(kit, kit.polar(angle, kit.rng:NextNumber(60, 280), kit.rng:NextNumber(24, 50)), kit.rng:NextNumber(0, 6.28))
	end
	kit:pilings(10, C(255, 60, 200), M.Neon)
end

function Theme.build(kit)
	kit:floors()
	kit:roads(C(26, 26, 36), C(0, 255, 230), M.SmoothPlastic, C(255, 60, 200))
	kit:bank()
	kit:zoneSigns(function(zone)
		return C(40, 20, 70):Lerp(zone.GroundColor, 0.2)
	end, C(40, 40, 55))
	arcadeRing(kit)
	mall(kit)
	factoryRing(kit)
	skylineRing(kit)
	kit:boundary(M.Glass, 0.05)
	-- The skyline ringing the island.
	for i = 0, 35 do
		local angle = i * 10 + kit.rng:NextNumber(-3, 3)
		local r = kit.rng:NextNumber(360, 560)
		local width = kit.rng:NextNumber(24, 44)
		local height = kit.rng:NextNumber(90, 260)
		local cf = CFrame.lookAt(kit.polar(angle, r, -2), Vector3.new(0, -2, 0))
		tower(kit, cf, width, height, pick(kit, { C(40, 48, 88), C(62, 40, 96), C(32, 66, 92) }), pick(kit, NEON), math.floor(height / 40))
	end
end

return Theme
