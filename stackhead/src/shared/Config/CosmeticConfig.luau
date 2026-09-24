-- Stack bases: the platform your tower stands on. Visible to everyone, so
-- they are the game's main status cosmetic. Most are earned; a few are sold.
--
-- Unlock kinds:
--   Free                         everyone
--   Record  { Stack = n }        best stack >= n
--   World   { World = id }       that world unlocked
--   Streak  { Days = n }         daily streak reached n
--   Pass    { Pass = key }       owns MonetizationConfig.GamePasses[key]
--   Owned                        granted by a product (stored in the save)

local CosmeticConfig = {}

CosmeticConfig.Bases = {
	{
		Id = "plate",
		Name = "Dinner Plate",
		Icon = "🍽️",
		Unlock = { Kind = "Free" },
		Height = 0.3,
		Parts = {
			{ Shape = "VCylinder", Size = { 2.6, 0.2, 2.6 }, Color = { 245, 245, 250 } },
			{ Shape = "VCylinder", Size = { 2.2, 0.22, 2.2 }, Offset = { 0, 0.02, 0 }, Color = { 225, 230, 240 } },
		},
	},
	{
		Id = "pizza",
		Name = "Pizza Tray",
		Icon = "🍕",
		Unlock = { Kind = "Record", Stack = 25 },
		Height = 0.4,
		Parts = {
			{ Shape = "VCylinder", Size = { 3, 0.3, 3 }, Color = { 190, 190, 200 }, Material = "Metal" },
			{ Shape = "VCylinder", Size = { 2.6, 0.32, 2.6 }, Color = { 240, 190, 90 } },
			{ Shape = "VCylinder", Size = { 2.2, 0.34, 2.2 }, Color = { 220, 60, 40 } },
		},
	},
	{
		Id = "cushion",
		Name = "Royal Cushion",
		Icon = "👑",
		Unlock = { Kind = "Record", Stack = 100 },
		Height = 0.7,
		Parts = {
			{ Shape = "Block", Size = { 2.8, 0.6, 2.8 }, Color = { 160, 30, 50 }, Material = "Fabric" },
			{ Shape = "Ball", Size = { 0.5, 0.5, 0.5 }, Offset = { 1.3, -0.1, 1.3 }, Color = { 255, 200, 60 }, Material = "Foil" },
			{ Shape = "Ball", Size = { 0.5, 0.5, 0.5 }, Offset = { -1.3, -0.1, 1.3 }, Color = { 255, 200, 60 }, Material = "Foil" },
			{ Shape = "Ball", Size = { 0.5, 0.5, 0.5 }, Offset = { 1.3, -0.1, -1.3 }, Color = { 255, 200, 60 }, Material = "Foil" },
			{ Shape = "Ball", Size = { 0.5, 0.5, 0.5 }, Offset = { -1.3, -0.1, -1.3 }, Color = { 255, 200, 60 }, Material = "Foil" },
		},
	},
	{
		Id = "cloud",
		Name = "Cloud Puff",
		Icon = "☁️",
		Unlock = { Kind = "Record", Stack = 200 },
		Height = 0.9,
		Parts = {
			{ Shape = "Ball", Size = { 1.6, 1.6, 1.6 }, Offset = { 0, -0.2, 0 }, Color = { 250, 252, 255 } },
			{ Shape = "Ball", Size = { 1.2, 1.2, 1.2 }, Offset = { 0.9, -0.3, 0.2 }, Color = { 240, 245, 255 } },
			{ Shape = "Ball", Size = { 1.2, 1.2, 1.2 }, Offset = { -0.9, -0.3, -0.2 }, Color = { 240, 245, 255 } },
			{ Shape = "Ball", Size = { 1, 1, 1 }, Offset = { 0, -0.3, 0.9 }, Color = { 245, 248, 255 } },
		},
	},
	{
		Id = "snow",
		Name = "Snowdrift",
		Icon = "❄️",
		Unlock = { Kind = "World", World = "Frostpeak" },
		Height = 0.6,
		Parts = {
			{ Shape = "VCylinder", Size = { 2.8, 0.5, 2.8 }, Color = { 245, 250, 255 }, Material = "Snow" },
			{ Shape = "Block", Size = { 0.5, 0.5, 0.5 }, Offset = { 1, 0.2, 0.6 }, Rot = { 45, 0, 45 }, Color = { 150, 220, 255 }, Material = "Neon" },
		},
	},
	{
		Id = "donut",
		Name = "Donut Float",
		Icon = "🍩",
		Unlock = { Kind = "World", World = "CandyCoast" },
		Height = 0.7,
		Parts = {
			{ Shape = "VCylinder", Size = { 3, 0.6, 3 }, Color = { 225, 165, 95 } },
			{ Shape = "VCylinder", Size = { 2.8, 0.15, 2.8 }, Offset = { 0, 0.3, 0 }, Color = { 255, 120, 180 } },
		},
	},
	{
		Id = "holo",
		Name = "Holo Pad",
		Icon = "🛸",
		Unlock = { Kind = "World", World = "NeonCity" },
		Height = 0.4,
		Parts = {
			{ Shape = "VCylinder", Size = { 2.8, 0.3, 2.8 }, Color = { 30, 30, 40 }, Material = "Metal" },
			{ Shape = "VCylinder", Size = { 3, 0.1, 3 }, Offset = { 0, -0.1, 0 }, Color = { 0, 255, 230 }, Material = "Neon" },
		},
	},
	{
		Id = "star",
		Name = "Streak Star",
		Icon = "⭐",
		Unlock = { Kind = "Streak", Days = 7 },
		Height = 0.5,
		Parts = {
			{ Shape = "VCylinder", Size = { 2.6, 0.4, 2.6 }, Color = { 60, 80, 200 } },
			{ Shape = "Block", Size = { 1.2, 0.42, 1.2 }, Rot = { 0, 45, 0 }, Color = { 255, 220, 60 }, Material = "Neon" },
			{ Shape = "Block", Size = { 1.2, 0.42, 1.2 }, Color = { 255, 220, 60 }, Material = "Neon" },
		},
	},
	{
		Id = "gold",
		Name = "Golden Tray",
		Icon = "🏆",
		Unlock = { Kind = "Pass", Pass = "VIP" },
		Height = 0.4,
		Parts = {
			{ Shape = "VCylinder", Size = { 3, 0.3, 3 }, Color = { 255, 200, 40 }, Material = "Foil" },
			{ Shape = "VCylinder", Size = { 2.6, 0.32, 2.6 }, Color = { 255, 225, 120 }, Material = "Foil" },
		},
	},
	{
		Id = "ufo",
		Name = "UFO Saucer",
		Icon = "🛸",
		Unlock = { Kind = "Pass", Pass = "UfoBase" },
		Height = 0.8,
		Parts = {
			{ Shape = "VCylinder", Size = { 3.4, 0.4, 3.4 }, Color = { 200, 205, 220 }, Material = "Metal" },
			{ Shape = "VCylinder", Size = { 3.6, 0.12, 3.6 }, Color = { 0, 255, 150 }, Material = "Neon" },
			{ Shape = "Ball", Size = { 1.6, 1.6, 1.6 }, Offset = { 0, -0.5, 0 }, Color = { 150, 155, 170 }, Material = "Metal" },
		},
	},
	{
		Id = "flame",
		Name = "Flame Ring",
		Icon = "🔥",
		Unlock = { Kind = "Pass", Pass = "FlameBase" },
		Height = 0.5,
		Fire = true,
		Parts = {
			{ Shape = "VCylinder", Size = { 2.8, 0.4, 2.8 }, Color = { 40, 30, 30 }, Material = "Slate" },
			{ Shape = "VCylinder", Size = { 3, 0.15, 3 }, Offset = { 0, 0.1, 0 }, Color = { 255, 120, 30 }, Material = "Neon" },
		},
	},
	{
		Id = "crate",
		Name = "Starter Crate",
		Icon = "📦",
		Unlock = { Kind = "Owned" },
		Height = 0.8,
		Parts = {
			{ Shape = "Block", Size = { 2.6, 0.7, 2.6 }, Color = { 170, 120, 70 }, Material = "Wood" },
			{ Shape = "Block", Size = { 2.7, 0.15, 2.7 }, Offset = { 0, 0.3, 0 }, Color = { 255, 200, 60 }, Material = "Metal" },
		},
	},
}

CosmeticConfig.ById = {}
for index, base in CosmeticConfig.Bases do
	base.Index = index
	CosmeticConfig.ById[base.Id] = base
end

CosmeticConfig.Default = "plate"

return CosmeticConfig
