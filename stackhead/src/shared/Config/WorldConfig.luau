-- The worlds. Each world is a round island with a bank in the middle and four
-- rings of rising item tiers. Worlds sit far apart in the same place and
-- players travel between the ones they've unlocked.
--
-- Tiers are global (1..16): Strength level N lets a player lift tier N items,
-- so every fourth Strength level opens the next world.

local WorldConfig = {}

WorldConfig.Spacing = 2400

-- Shared ring layout (studs from the world centre). Keeping it identical
-- across worlds keeps walking distances, and therefore pacing, comparable.
local RINGS = {
	{ Inner = 26, Outer = 85, MaxItems = 110 },
	{ Inner = 85, Outer = 150, MaxItems = 90 },
	{ Inner = 150, Outer = 220, MaxItems = 80 },
	{ Inner = 220, Outer = 290, MaxItems = 60 },
}

local function zones(firstTier: number, specs)
	local list = {}
	for i, spec in specs do
		list[i] = {
			Id = spec.Id,
			DisplayName = spec.DisplayName,
			InnerRadius = RINGS[i].Inner,
			OuterRadius = RINGS[i].Outer,
			MaxItems = RINGS[i].MaxItems,
			Tier = firstTier + i - 1,
			GroundColor = spec.GroundColor,
			Material = spec.Material or "SmoothPlastic",
		}
	end
	return list
end

WorldConfig.Worlds = {
	{
		Id = "Stackville",
		DisplayName = "Stackville",
		Tagline = "A sunny little town",
		Icon = "🏘️",
		Theme = "Stackville",
		Seed = 1337,
		Zones = zones(1, {
			{ Id = "Market", DisplayName = "Market Street", GroundColor = Color3.fromRGB(226, 205, 160) },
			{ Id = "Yard", DisplayName = "Yard Sale", GroundColor = Color3.fromRGB(124, 192, 92) },
			{ Id = "Farm", DisplayName = "Old Farm", GroundColor = Color3.fromRGB(206, 186, 110) },
			{ Id = "Docks", DisplayName = "The Docks", GroundColor = Color3.fromRGB(160, 124, 88), Material = "WoodPlanks" },
		}),
		Bank = { Floor = Color3.fromRGB(255, 214, 90), Inner = Color3.fromRGB(255, 238, 180), Glow = Color3.fromRGB(255, 170, 40) },
		Water = Color3.fromRGB(56, 150, 214),
		Lighting = {
			ClockTime = 14.5,
			Brightness = 2.6,
			Ambient = Color3.fromRGB(110, 100, 120),
			OutdoorAmbient = Color3.fromRGB(150, 145, 160),
			AtmosphereColor = Color3.fromRGB(200, 220, 255),
			AtmosphereDecay = Color3.fromRGB(120, 150, 200),
			AtmosphereDensity = 0.28,
			Tint = Color3.fromRGB(255, 255, 255),
			Saturation = 0.18,
		},
	},
	{
		Id = "Frostpeak",
		DisplayName = "Frostpeak",
		Tagline = "Snowy mountain village",
		Icon = "🏔️",
		Theme = "Frostpeak",
		Seed = 2718,
		Zones = zones(5, {
			{ Id = "Village", DisplayName = "Snowy Village", GroundColor = Color3.fromRGB(238, 244, 250), Material = "Snow" },
			{ Id = "Lodge", DisplayName = "Ski Lodge", GroundColor = Color3.fromRGB(214, 228, 242), Material = "Snow" },
			{ Id = "Caves", DisplayName = "Ice Caves", GroundColor = Color3.fromRGB(150, 205, 235), Material = "Ice" },
			{ Id = "Summit", DisplayName = "The Summit", GroundColor = Color3.fromRGB(150, 158, 175), Material = "Slate" },
		}),
		Bank = { Floor = Color3.fromRGB(120, 200, 255), Inner = Color3.fromRGB(225, 245, 255), Glow = Color3.fromRGB(90, 200, 255) },
		Water = Color3.fromRGB(170, 215, 240),
		Lighting = {
			ClockTime = 10,
			Brightness = 2.8,
			Ambient = Color3.fromRGB(120, 135, 160),
			OutdoorAmbient = Color3.fromRGB(165, 180, 205),
			AtmosphereColor = Color3.fromRGB(220, 235, 255),
			AtmosphereDecay = Color3.fromRGB(160, 190, 230),
			AtmosphereDensity = 0.36,
			Tint = Color3.fromRGB(235, 245, 255),
			Saturation = 0.05,
		},
	},
	{
		Id = "CandyCoast",
		DisplayName = "Candy Coast",
		Tagline = "Sweets by the sea",
		Icon = "🍭",
		Theme = "CandyCoast",
		Seed = 4242,
		Zones = zones(9, {
			{ Id = "Sweets", DisplayName = "Sweet Street", GroundColor = Color3.fromRGB(255, 196, 222) },
			{ Id = "Bakery", DisplayName = "Bakery Row", GroundColor = Color3.fromRGB(176, 238, 210) },
			{ Id = "Beach", DisplayName = "Sugar Beach", GroundColor = Color3.fromRGB(250, 226, 170), Material = "Sand" },
			{ Id = "Pier", DisplayName = "Candy Pier", GroundColor = Color3.fromRGB(214, 150, 190), Material = "WoodPlanks" },
		}),
		Bank = { Floor = Color3.fromRGB(255, 120, 190), Inner = Color3.fromRGB(255, 225, 240), Glow = Color3.fromRGB(255, 90, 170) },
		Water = Color3.fromRGB(90, 215, 220),
		Lighting = {
			ClockTime = 16,
			Brightness = 2.7,
			Ambient = Color3.fromRGB(135, 110, 130),
			OutdoorAmbient = Color3.fromRGB(175, 150, 170),
			AtmosphereColor = Color3.fromRGB(255, 215, 235),
			AtmosphereDecay = Color3.fromRGB(230, 160, 200),
			AtmosphereDensity = 0.3,
			Tint = Color3.fromRGB(255, 240, 248),
			Saturation = 0.25,
		},
	},
	{
		Id = "NeonCity",
		DisplayName = "Neon City",
		Tagline = "A city that never sleeps",
		Icon = "🌃",
		Theme = "NeonCity",
		Seed = 9001,
		Zones = zones(13, {
			{ Id = "Arcade", DisplayName = "Arcade Street", GroundColor = Color3.fromRGB(48, 44, 70) },
			{ Id = "Mall", DisplayName = "Tech Mall", GroundColor = Color3.fromRGB(38, 46, 66) },
			{ Id = "Factory", DisplayName = "Robot Factory", GroundColor = Color3.fromRGB(52, 52, 58), Material = "DiamondPlate" },
			{ Id = "Skyline", DisplayName = "Skyline", GroundColor = Color3.fromRGB(30, 30, 44) },
		}),
		Bank = { Floor = Color3.fromRGB(150, 70, 255), Inner = Color3.fromRGB(60, 40, 100), Glow = Color3.fromRGB(0, 255, 230) },
		Water = Color3.fromRGB(20, 30, 70),
		Lighting = {
			ClockTime = 19.4,
			Brightness = 1.6,
			Ambient = Color3.fromRGB(110, 90, 150),
			OutdoorAmbient = Color3.fromRGB(140, 115, 185),
			AtmosphereColor = Color3.fromRGB(120, 90, 200),
			AtmosphereDecay = Color3.fromRGB(60, 30, 120),
			AtmosphereDensity = 0.34,
			Tint = Color3.fromRGB(235, 225, 255),
			Saturation = 0.3,
		},
	},
}

for index, world in WorldConfig.Worlds do
	world.Index = index
	world.Origin = Vector3.new(WorldConfig.Spacing * (index - 1), 0, 0)
	world.FirstTier = world.Zones[1].Tier
	for _, zone in world.Zones do
		zone.WorldId = world.Id
		zone.Key = world.Id .. "." .. zone.Id
	end
end

return WorldConfig
