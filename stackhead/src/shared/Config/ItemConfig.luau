-- Every stackable item. Adding an item = adding one entry here.
--
-- Id       short code used in replicated stack strings (keep it 3 chars, unique)
-- Tier     global tier 1..16 (see WorldConfig); Strength level required to lift it
-- Value    coins before height and rarity multipliers
-- Height   studs it adds to the stack (affects wobble)
-- Weight   relative spawn weight inside its zone
-- Parts    primitive geometry, offsets relative to the item centre
--
-- Shapes: Block, Ball, Wedge, VCylinder (upright: Size = {diameter, height, diameter}),
-- HCylinder (lying along X: Size = {length, diameter, diameter}).

local ItemConfig = {}

ItemConfig.Items = {
	-- Tier 1 — Market Street -------------------------------------------------
	{
		Id = "apl",
		Name = "Apple",
		Tier = 1,
		Value = 1,
		Height = 1,
		Weight = 30,
		Parts = {
			{ Shape = "Ball", Size = { 1, 1, 1 }, Color = { 222, 45, 45 } },
			{ Shape = "Block", Size = { 0.14, 0.35, 0.14 }, Offset = { 0, 0.6, 0 }, Color = { 96, 64, 32 } },
			{ Shape = "Block", Size = { 0.35, 0.08, 0.2 }, Offset = { 0.18, 0.62, 0 }, Color = { 70, 170, 60 } },
		},
	},
	{
		Id = "can",
		Name = "Soda Can",
		Tier = 1,
		Value = 1,
		Height = 1.2,
		Weight = 28,
		Parts = {
			{ Shape = "VCylinder", Size = { 0.8, 1.2, 0.8 }, Color = { 40, 110, 230 } },
			{ Shape = "VCylinder", Size = { 0.7, 0.06, 0.7 }, Offset = { 0, 0.62, 0 }, Color = { 200, 200, 210 }, Material = "Metal" },
		},
	},
	{
		Id = "bok",
		Name = "Book",
		Tier = 1,
		Value = 2,
		Height = 0.5,
		Weight = 20,
		Parts = {
			{ Shape = "Block", Size = { 1.6, 0.5, 1.2 }, Color = { 120, 60, 180 } },
			{ Shape = "Block", Size = { 1.45, 0.4, 1.22 }, Offset = { 0.1, 0, 0 }, Color = { 245, 240, 225 } },
		},
	},
	{
		Id = "piz",
		Name = "Pizza Box",
		Tier = 1,
		Value = 3,
		Height = 0.35,
		Weight = 13,
		Parts = {
			{ Shape = "Block", Size = { 2, 0.35, 2 }, Color = { 205, 165, 110 } },
			{ Shape = "Block", Size = { 1, 0.02, 0.6 }, Offset = { 0, 0.18, 0 }, Color = { 210, 50, 40 } },
		},
	},
	{
		Id = "mel",
		Name = "Watermelon",
		Tier = 1,
		Value = 5,
		Height = 1.5,
		Weight = 8,
		Parts = {
			{ Shape = "Ball", Size = { 1.5, 1.5, 1.5 }, Color = { 40, 140, 50 } },
			{ Shape = "Block", Size = { 0.2, 1.52, 0.2 }, Color = { 120, 200, 90 } },
		},
	},

	-- Tier 2 — Yard Sale -----------------------------------------------------
	{
		Id = "tir",
		Name = "Old Tire",
		Tier = 2,
		Value = 5,
		Height = 0.9,
		Weight = 22,
		Parts = {
			{ Shape = "VCylinder", Size = { 2.2, 0.9, 2.2 }, Color = { 35, 35, 38 } },
			{ Shape = "VCylinder", Size = { 1.2, 0.92, 1.2 }, Color = { 150, 150, 155 }, Material = "Metal" },
		},
	},
	{
		Id = "chr",
		Name = "Chair",
		Tier = 2,
		Value = 7,
		Height = 2.2,
		Weight = 20,
		Parts = {
			{ Shape = "Block", Size = { 1.6, 0.25, 1.6 }, Offset = { 0, -0.1, 0 }, Color = { 190, 120, 60 } },
			{ Shape = "Block", Size = { 1.6, 1.1, 0.22 }, Offset = { 0, 0.55, -0.7 }, Color = { 190, 120, 60 } },
			{ Shape = "Block", Size = { 0.2, 0.9, 1.4 }, Offset = { 0.65, -0.65, 0 }, Color = { 150, 90, 45 } },
			{ Shape = "Block", Size = { 0.2, 0.9, 1.4 }, Offset = { -0.65, -0.65, 0 }, Color = { 150, 90, 45 } },
		},
	},
	{
		Id = "tvs",
		Name = "Old TV",
		Tier = 2,
		Value = 9,
		Height = 1.8,
		Weight = 18,
		Parts = {
			{ Shape = "Block", Size = { 2.2, 1.8, 1.6 }, Color = { 110, 110, 118 } },
			{ Shape = "Block", Size = { 1.6, 1.2, 0.05 }, Offset = { -0.15, 0.05, 0.81 }, Color = { 40, 60, 70 }, Material = "Glass" },
			{ Shape = "Block", Size = { 0.2, 0.2, 0.05 }, Offset = { 0.85, 0.4, 0.81 }, Color = { 230, 60, 60 }, Material = "Neon" },
		},
	},
	{
		Id = "lmp",
		Name = "Lamp",
		Tier = 2,
		Value = 8,
		Height = 2.8,
		Weight = 14,
		Parts = {
			{ Shape = "VCylinder", Size = { 1, 0.2, 1 }, Offset = { 0, -1.3, 0 }, Color = { 60, 60, 60 } },
			{ Shape = "VCylinder", Size = { 0.18, 2, 0.18 }, Offset = { 0, -0.2, 0 }, Color = { 60, 60, 60 } },
			{ Shape = "VCylinder", Size = { 1.3, 0.8, 1.3 }, Offset = { 0, 1, 0 }, Color = { 250, 225, 150 } },
		},
	},
	{
		Id = "gno",
		Name = "Garden Gnome",
		Tier = 2,
		Value = 12,
		Height = 1.9,
		Weight = 8,
		Parts = {
			{ Shape = "VCylinder", Size = { 1, 0.9, 1 }, Offset = { 0, -0.5, 0 }, Color = { 50, 90, 200 } },
			{ Shape = "Ball", Size = { 0.7, 0.7, 0.7 }, Offset = { 0, 0.25, 0 }, Color = { 255, 205, 170 } },
			{ Shape = "Block", Size = { 0.5, 0.7, 0.5 }, Offset = { 0, 0.75, 0 }, Color = { 220, 40, 40 } },
			{ Shape = "Block", Size = { 0.6, 0.35, 0.2 }, Offset = { 0, 0.05, 0.3 }, Color = { 245, 245, 245 } },
		},
	},

	-- Tier 3 — Old Farm ------------------------------------------------------
	{
		Id = "hay",
		Name = "Hay Bale",
		Tier = 3,
		Value = 20,
		Height = 1.8,
		Weight = 24,
		Parts = {
			{ Shape = "Block", Size = { 2.6, 1.8, 1.8 }, Color = { 232, 200, 90 }, Material = "Fabric" },
			{ Shape = "Block", Size = { 0.1, 1.82, 1.82 }, Offset = { 0.6, 0, 0 }, Color = { 150, 110, 50 } },
			{ Shape = "Block", Size = { 0.1, 1.82, 1.82 }, Offset = { -0.6, 0, 0 }, Color = { 150, 110, 50 } },
		},
	},
	{
		Id = "pmk",
		Name = "Pumpkin",
		Tier = 3,
		Value = 18,
		Height = 1.7,
		Weight = 22,
		Parts = {
			{ Shape = "Ball", Size = { 1.8, 1.8, 1.8 }, Color = { 240, 130, 30 } },
			{ Shape = "VCylinder", Size = { 0.25, 0.4, 0.25 }, Offset = { 0, 0.95, 0 }, Color = { 80, 120, 40 } },
		},
	},
	{
		Id = "mlk",
		Name = "Milk Can",
		Tier = 3,
		Value = 16,
		Height = 2,
		Weight = 20,
		Parts = {
			{ Shape = "VCylinder", Size = { 1.2, 1.6, 1.2 }, Offset = { 0, -0.2, 0 }, Color = { 205, 210, 215 }, Material = "Metal" },
			{ Shape = "VCylinder", Size = { 0.8, 0.4, 0.8 }, Offset = { 0, 0.8, 0 }, Color = { 205, 210, 215 }, Material = "Metal" },
			{ Shape = "VCylinder", Size = { 1.22, 0.2, 1.22 }, Offset = { 0, 0.1, 0 }, Color = { 50, 110, 200 } },
		},
	},
	{
		Id = "pig",
		Name = "Pig",
		Tier = 3,
		Value = 32,
		Height = 1.7,
		Weight = 12,
		Parts = {
			{ Shape = "Block", Size = { 2.4, 1.3, 1.4 }, Offset = { 0, 0.1, 0 }, Color = { 250, 170, 185 } },
			{ Shape = "Block", Size = { 0.9, 0.9, 1 }, Offset = { 1.45, 0.3, 0 }, Color = { 250, 170, 185 } },
			{ Shape = "Block", Size = { 0.2, 0.4, 0.5 }, Offset = { 1.95, 0.2, 0 }, Color = { 235, 120, 140 } },
			{ Shape = "Block", Size = { 1.9, 0.4, 1.1 }, Offset = { 0, -0.65, 0 }, Color = { 235, 150, 165 } },
		},
	},
	{
		Id = "egg",
		Name = "Egg Basket",
		Tier = 3,
		Value = 26,
		Height = 1.3,
		Weight = 10,
		Parts = {
			{ Shape = "VCylinder", Size = { 1.8, 0.8, 1.8 }, Offset = { 0, -0.25, 0 }, Color = { 170, 120, 70 }, Material = "Wood" },
			{ Shape = "Ball", Size = { 0.6, 0.6, 0.6 }, Offset = { 0.3, 0.3, 0 }, Color = { 250, 245, 230 } },
			{ Shape = "Ball", Size = { 0.6, 0.6, 0.6 }, Offset = { -0.3, 0.3, 0.2 }, Color = { 245, 225, 195 } },
		},
	},

	-- Tier 4 — The Docks -----------------------------------------------------
	{
		Id = "crt",
		Name = "Cargo Crate",
		Tier = 4,
		Value = 60,
		Height = 2.4,
		Weight = 26,
		Parts = {
			{ Shape = "Block", Size = { 2.4, 2.4, 2.4 }, Color = { 170, 120, 70 }, Material = "Wood" },
			{ Shape = "Block", Size = { 2.45, 0.3, 2.45 }, Offset = { 0, 0.9, 0 }, Color = { 120, 80, 45 }, Material = "Wood" },
			{ Shape = "Block", Size = { 2.45, 0.3, 2.45 }, Offset = { 0, -0.9, 0 }, Color = { 120, 80, 45 }, Material = "Wood" },
		},
	},
	{
		Id = "brl",
		Name = "Barrel",
		Tier = 4,
		Value = 55,
		Height = 2.6,
		Weight = 24,
		Parts = {
			{ Shape = "VCylinder", Size = { 1.8, 2.6, 1.8 }, Color = { 150, 95, 55 }, Material = "Wood" },
			{ Shape = "VCylinder", Size = { 1.85, 0.2, 1.85 }, Offset = { 0, 0.8, 0 }, Color = { 70, 70, 75 }, Material = "Metal" },
			{ Shape = "VCylinder", Size = { 1.85, 0.2, 1.85 }, Offset = { 0, -0.8, 0 }, Color = { 70, 70, 75 }, Material = "Metal" },
		},
	},
	{
		Id = "anc",
		Name = "Anchor",
		Tier = 4,
		Value = 90,
		Height = 3,
		Weight = 12,
		Parts = {
			{ Shape = "Block", Size = { 0.35, 2.6, 0.35 }, Offset = { 0, 0.1, 0 }, Color = { 60, 65, 75 }, Material = "Metal" },
			{ Shape = "Block", Size = { 1.6, 0.3, 0.35 }, Offset = { 0, 0.9, 0 }, Color = { 60, 65, 75 }, Material = "Metal" },
			{ Shape = "Block", Size = { 2.4, 0.4, 0.4 }, Offset = { 0, -1.2, 0 }, Color = { 60, 65, 75 }, Material = "Metal" },
			{ Shape = "VCylinder", Size = { 0.7, 0.3, 0.7 }, Offset = { 0, 1.4, 0 }, Color = { 60, 65, 75 }, Material = "Metal" },
		},
	},
	{
		Id = "chs",
		Name = "Treasure Chest",
		Tier = 4,
		Value = 160,
		Height = 1.9,
		Weight = 6,
		Parts = {
			{ Shape = "Block", Size = { 2.4, 1.3, 1.6 }, Offset = { 0, -0.3, 0 }, Color = { 130, 80, 40 }, Material = "Wood" },
			{ Shape = "Block", Size = { 2.45, 0.6, 1.65 }, Offset = { 0, 0.62, 0 }, Color = { 150, 95, 50 }, Material = "Wood" },
			{ Shape = "Block", Size = { 0.4, 0.5, 0.1 }, Offset = { 0, 0.3, 0.83 }, Color = { 250, 200, 60 }, Material = "Metal" },
		},
	},
	{
		Id = "car",
		Name = "Tiny Car",
		Tier = 4,
		Value = 300,
		Height = 2.2,
		Weight = 3,
		Parts = {
			{ Shape = "Block", Size = { 3.6, 1, 1.9 }, Offset = { 0, -0.3, 0 }, Color = { 220, 40, 50 } },
			{ Shape = "Block", Size = { 2, 0.9, 1.7 }, Offset = { -0.2, 0.6, 0 }, Color = { 160, 210, 240 }, Material = "Glass" },
			{ Shape = "HCylinder", Size = { 0.5, 0.9, 0.9 }, Offset = { 1.1, -0.75, 0 }, Rot = { 0, 90, 0 }, Color = { 30, 30, 30 } },
			{ Shape = "HCylinder", Size = { 0.5, 0.9, 0.9 }, Offset = { -1.1, -0.75, 0 }, Rot = { 0, 90, 0 }, Color = { 30, 30, 30 } },
		},
	},

	-- Tier 5 — Frostpeak: Snowy Village --------------------------------------
	{
		Id = "snb",
		Name = "Snowball",
		Tier = 5,
		Value = 180,
		Height = 1.2,
		Weight = 30,
		Parts = {
			{ Shape = "Ball", Size = { 1.2, 1.2, 1.2 }, Color = { 245, 250, 255 }, Material = "Snow" },
		},
	},
	{
		Id = "coc",
		Name = "Hot Cocoa",
		Tier = 5,
		Value = 220,
		Height = 1.3,
		Weight = 26,
		Parts = {
			{ Shape = "VCylinder", Size = { 1, 1.2, 1 }, Offset = { 0, -0.05, 0 }, Color = { 210, 50, 50 } },
			{ Shape = "VCylinder", Size = { 0.86, 0.05, 0.86 }, Offset = { 0, 0.56, 0 }, Color = { 110, 60, 35 } },
			{ Shape = "Block", Size = { 0.2, 0.6, 0.5 }, Offset = { 0.6, 0, 0 }, Color = { 210, 50, 50 } },
			{ Shape = "Block", Size = { 0.25, 0.2, 0.25 }, Offset = { 0.15, 0.63, 0.1 }, Color = { 255, 250, 245 } },
			{ Shape = "Block", Size = { 0.25, 0.2, 0.25 }, Offset = { -0.2, 0.63, -0.1 }, Color = { 255, 240, 245 } },
		},
	},
	{
		Id = "prs",
		Name = "Present",
		Tier = 5,
		Value = 260,
		Height = 1.4,
		Weight = 22,
		Parts = {
			{ Shape = "Block", Size = { 1.4, 1.2, 1.4 }, Offset = { 0, -0.1, 0 }, Color = { 60, 170, 90 } },
			{ Shape = "Block", Size = { 0.3, 1.22, 1.42 }, Offset = { 0, -0.1, 0 }, Color = { 220, 40, 50 } },
			{ Shape = "Block", Size = { 1.42, 1.22, 0.3 }, Offset = { 0, -0.1, 0 }, Color = { 220, 40, 50 } },
			{ Shape = "Ball", Size = { 0.45, 0.45, 0.45 }, Offset = { 0.2, 0.6, 0 }, Color = { 230, 50, 60 } },
			{ Shape = "Ball", Size = { 0.45, 0.45, 0.45 }, Offset = { -0.2, 0.6, 0 }, Color = { 230, 50, 60 } },
		},
	},
	{
		Id = "mit",
		Name = "Mitten",
		Tier = 5,
		Value = 200,
		Height = 0.5,
		Weight = 20,
		Parts = {
			{ Shape = "Block", Size = { 1.2, 0.5, 1.5 }, Color = { 60, 110, 220 }, Material = "Fabric" },
			{ Shape = "Block", Size = { 0.45, 0.45, 0.7 }, Offset = { 0.75, 0, -0.2 }, Color = { 60, 110, 220 }, Material = "Fabric" },
			{ Shape = "Block", Size = { 1.3, 0.55, 0.4 }, Offset = { 0, 0, 0.85 }, Color = { 245, 245, 250 }, Material = "Fabric" },
		},
	},

	-- Tier 6 — Frostpeak: Ski Lodge ------------------------------------------
	{
		Id = "ski",
		Name = "Skis",
		Tier = 6,
		Value = 520,
		Height = 0.35,
		Weight = 26,
		Parts = {
			{ Shape = "Block", Size = { 0.35, 0.12, 3.4 }, Offset = { -0.3, -0.08, 0 }, Color = { 230, 50, 60 } },
			{ Shape = "Block", Size = { 0.35, 0.12, 3.4 }, Offset = { 0.3, -0.08, 0 }, Color = { 230, 50, 60 } },
			{ Shape = "Block", Size = { 1, 0.22, 0.6 }, Offset = { 0, 0.08, 0 }, Color = { 40, 40, 48 } },
		},
	},
	{
		Id = "sld",
		Name = "Sled",
		Tier = 6,
		Value = 640,
		Height = 0.8,
		Weight = 22,
		Parts = {
			{ Shape = "Block", Size = { 1.6, 0.2, 2.8 }, Offset = { 0, 0.2, 0 }, Color = { 190, 130, 75 }, Material = "Wood" },
			{ Shape = "Block", Size = { 0.15, 0.4, 3 }, Offset = { 0.65, -0.15, 0 }, Color = { 200, 40, 40 }, Material = "Metal" },
			{ Shape = "Block", Size = { 0.15, 0.4, 3 }, Offset = { -0.65, -0.15, 0 }, Color = { 200, 40, 40 }, Material = "Metal" },
			{ Shape = "Wedge", Size = { 1.6, 0.6, 0.5 }, Offset = { 0, 0.3, -1.5 }, Rot = { 0, 180, 0 }, Color = { 190, 130, 75 }, Material = "Wood" },
		},
	},
	{
		Id = "snm",
		Name = "Snowman",
		Tier = 6,
		Value = 720,
		Height = 2.7,
		Weight = 18,
		Parts = {
			{ Shape = "Ball", Size = { 1.4, 1.4, 1.4 }, Offset = { 0, -0.65, 0 }, Color = { 248, 250, 255 }, Material = "Snow" },
			{ Shape = "Ball", Size = { 1.05, 1.05, 1.05 }, Offset = { 0, 0.35, 0 }, Color = { 248, 250, 255 }, Material = "Snow" },
			{ Shape = "Ball", Size = { 0.75, 0.75, 0.75 }, Offset = { 0, 1.05, 0 }, Color = { 248, 250, 255 }, Material = "Snow" },
			{ Shape = "Block", Size = { 0.12, 0.12, 0.45 }, Offset = { 0, 1.05, -0.5 }, Color = { 255, 140, 30 } },
			{ Shape = "VCylinder", Size = { 0.55, 0.45, 0.55 }, Offset = { 0, 1.5, 0 }, Color = { 30, 30, 35 } },
		},
	},
	{
		Id = "lan",
		Name = "Lantern",
		Tier = 6,
		Value = 560,
		Height = 1.7,
		Weight = 14,
		Parts = {
			{ Shape = "VCylinder", Size = { 0.9, 1, 0.9 }, Color = { 255, 210, 110 }, Material = "Neon" },
			{ Shape = "VCylinder", Size = { 1.1, 0.2, 1.1 }, Offset = { 0, -0.6, 0 }, Color = { 40, 40, 45 }, Material = "Metal" },
			{ Shape = "VCylinder", Size = { 1.1, 0.25, 1.1 }, Offset = { 0, 0.6, 0 }, Color = { 40, 40, 45 }, Material = "Metal" },
			{ Shape = "Block", Size = { 0.1, 0.25, 0.7 }, Offset = { 0, 0.8, 0 }, Color = { 40, 40, 45 }, Material = "Metal" },
		},
	},

	-- Tier 7 — Frostpeak: Ice Caves ------------------------------------------
	{
		Id = "ice",
		Name = "Ice Block",
		Tier = 7,
		Value = 1300,
		Height = 1.6,
		Weight = 28,
		Parts = {
			{ Shape = "Block", Size = { 1.6, 1.6, 1.6 }, Color = { 170, 225, 255 }, Material = "Ice", Transparency = 0.15 },
		},
	},
	{
		Id = "cry",
		Name = "Ice Crystal",
		Tier = 7,
		Value = 1700,
		Height = 2.2,
		Weight = 20,
		Parts = {
			{ Shape = "Block", Size = { 1.1, 1.1, 1.1 }, Rot = { 45, 0, 45 }, Color = { 120, 230, 255 }, Material = "Glass", Transparency = 0.1 },
			{ Shape = "Block", Size = { 0.5, 0.5, 0.5 }, Rot = { 45, 0, 45 }, Color = { 200, 250, 255 }, Material = "Neon" },
		},
	},
	{
		Id = "fsh",
		Name = "Frozen Fish",
		Tier = 7,
		Value = 1450,
		Height = 1,
		Weight = 22,
		Parts = {
			{ Shape = "Block", Size = { 2, 1, 1.1 }, Color = { 190, 235, 255 }, Material = "Ice", Transparency = 0.35 },
			{ Shape = "Block", Size = { 1.1, 0.45, 0.35 }, Offset = { -0.1, 0, 0 }, Color = { 255, 150, 60 } },
			{ Shape = "Wedge", Size = { 0.3, 0.5, 0.45 }, Offset = { 0.65, 0, 0 }, Rot = { 0, 90, 0 }, Color = { 255, 130, 50 } },
		},
	},
	{
		Id = "geo",
		Name = "Frost Geode",
		Tier = 7,
		Value = 1600,
		Height = 1.3,
		Weight = 14,
		Parts = {
			{ Shape = "Ball", Size = { 1.4, 1.4, 1.4 }, Color = { 110, 110, 125 }, Material = "Slate" },
			{ Shape = "Block", Size = { 0.35, 0.8, 0.35 }, Offset = { 0.2, 0.35, -0.45 }, Rot = { 20, 0, 15 }, Color = { 180, 120, 255 }, Material = "Neon" },
			{ Shape = "Block", Size = { 0.3, 0.6, 0.3 }, Offset = { -0.2, 0.35, -0.5 }, Rot = { -15, 0, -20 }, Color = { 140, 200, 255 }, Material = "Neon" },
		},
	},

	-- Tier 8 — Frostpeak: The Summit -----------------------------------------
	{
		Id = "png",
		Name = "Penguin",
		Tier = 8,
		Value = 3600,
		Height = 1.9,
		Weight = 26,
		Parts = {
			{ Shape = "Ball", Size = { 1.5, 1.5, 1.5 }, Offset = { 0, -0.2, 0 }, Color = { 35, 38, 50 } },
			{ Shape = "Ball", Size = { 1.2, 1.2, 1.2 }, Offset = { 0, -0.25, -0.25 }, Color = { 250, 250, 250 } },
			{ Shape = "Ball", Size = { 0.9, 0.9, 0.9 }, Offset = { 0, 0.55, 0 }, Color = { 35, 38, 50 } },
			{ Shape = "Block", Size = { 0.25, 0.15, 0.35 }, Offset = { 0, 0.5, -0.5 }, Color = { 255, 170, 30 } },
			{ Shape = "Block", Size = { 0.9, 0.12, 0.5 }, Offset = { 0, -0.9, -0.2 }, Color = { 255, 170, 30 } },
		},
	},
	{
		Id = "yti",
		Name = "Yeti Plush",
		Tier = 8,
		Value = 4200,
		Height = 2.4,
		Weight = 20,
		Parts = {
			{ Shape = "Block", Size = { 1.6, 1.4, 1.2 }, Offset = { 0, -0.45, 0 }, Color = { 240, 245, 255 }, Material = "Fabric" },
			{ Shape = "Ball", Size = { 1.2, 1.2, 1.2 }, Offset = { 0, 0.55, 0 }, Color = { 240, 245, 255 }, Material = "Fabric" },
			{ Shape = "Block", Size = { 0.7, 0.5, 0.1 }, Offset = { 0, 0.5, -0.56 }, Color = { 120, 170, 230 } },
			{ Shape = "Block", Size = { 0.4, 1.1, 0.45 }, Offset = { 1, -0.35, 0 }, Color = { 240, 245, 255 }, Material = "Fabric" },
			{ Shape = "Block", Size = { 0.4, 1.1, 0.45 }, Offset = { -1, -0.35, 0 }, Color = { 240, 245, 255 }, Material = "Fabric" },
		},
	},
	{
		Id = "gbl",
		Name = "Golden Bell",
		Tier = 8,
		Value = 4800,
		Height = 1.7,
		Weight = 12,
		Parts = {
			{ Shape = "VCylinder", Size = { 1.6, 0.4, 1.6 }, Offset = { 0, -0.55, 0 }, Color = { 255, 200, 50 }, Material = "Foil" },
			{ Shape = "VCylinder", Size = { 1.2, 0.8, 1.2 }, Offset = { 0, 0, 0 }, Color = { 255, 205, 60 }, Material = "Foil" },
			{ Shape = "Ball", Size = { 0.9, 0.9, 0.9 }, Offset = { 0, 0.4, 0 }, Color = { 255, 205, 60 }, Material = "Foil" },
			{ Shape = "Ball", Size = { 0.35, 0.35, 0.35 }, Offset = { 0, -0.8, 0 }, Color = { 200, 60, 50 } },
		},
	},
	{
		Id = "trs",
		Name = "Treasure Sled",
		Tier = 8,
		Value = 7500,
		Height = 1.8,
		Weight = 4,
		Parts = {
			{ Shape = "Block", Size = { 1.8, 0.25, 3 }, Offset = { 0, -0.6, 0 }, Color = { 150, 95, 55 }, Material = "Wood" },
			{ Shape = "Block", Size = { 1.6, 0.9, 1.4 }, Offset = { 0, 0, 0 }, Color = { 120, 70, 40 }, Material = "Wood" },
			{ Shape = "Block", Size = { 1.65, 0.45, 1.45 }, Offset = { 0, 0.62, 0 }, Color = { 255, 200, 50 }, Material = "Foil" },
			{ Shape = "Block", Size = { 0.15, 0.3, 3.2 }, Offset = { 0.8, -0.8, 0 }, Color = { 255, 200, 50 }, Material = "Foil" },
		},
	},

	-- Tier 9 — Candy Coast: Sweet Street -------------------------------------
	{
		Id = "cup",
		Name = "Cupcake",
		Tier = 9,
		Value = 9000,
		Height = 1.5,
		Weight = 30,
		Parts = {
			{ Shape = "VCylinder", Size = { 1.1, 0.7, 1.1 }, Offset = { 0, -0.4, 0 }, Color = { 120, 190, 255 } },
			{ Shape = "Ball", Size = { 1.3, 1.1, 1.3 }, Offset = { 0, 0.2, 0 }, Color = { 255, 170, 210 } },
			{ Shape = "Ball", Size = { 0.35, 0.35, 0.35 }, Offset = { 0, 0.8, 0 }, Color = { 220, 20, 50 } },
		},
	},
	{
		Id = "dnt",
		Name = "Donut",
		Tier = 9,
		Value = 8500,
		Height = 0.6,
		Weight = 26,
		Parts = {
			{ Shape = "VCylinder", Size = { 1.8, 0.55, 1.8 }, Color = { 220, 160, 90 } },
			{ Shape = "VCylinder", Size = { 1.7, 0.1, 1.7 }, Offset = { 0, 0.28, 0 }, Color = { 255, 120, 180 } },
			{ Shape = "VCylinder", Size = { 0.55, 0.12, 0.55 }, Offset = { 0, 0.3, 0 }, Color = { 60, 35, 25 } },
			{ Shape = "Block", Size = { 0.25, 0.06, 0.08 }, Offset = { 0.5, 0.35, 0.3 }, Color = { 255, 255, 120 } },
			{ Shape = "Block", Size = { 0.08, 0.06, 0.25 }, Offset = { -0.45, 0.35, -0.3 }, Color = { 120, 220, 255 } },
		},
	},
	{
		Id = "lol",
		Name = "Lollipop",
		Tier = 9,
		Value = 10500,
		Height = 2.4,
		Weight = 22,
		Parts = {
			{ Shape = "VCylinder", Size = { 0.15, 1.4, 0.15 }, Offset = { 0, -0.5, 0 }, Color = { 250, 250, 250 } },
			{ Shape = "HCylinder", Size = { 0.3, 1.5, 1.5 }, Offset = { 0, 0.45, 0 }, Rot = { 0, 90, 0 }, Color = { 255, 80, 150 } },
			{ Shape = "HCylinder", Size = { 0.34, 0.9, 0.9 }, Offset = { 0, 0.45, 0 }, Rot = { 0, 90, 0 }, Color = { 255, 230, 90 } },
			{ Shape = "HCylinder", Size = { 0.38, 0.35, 0.35 }, Offset = { 0, 0.45, 0 }, Rot = { 0, 90, 0 }, Color = { 120, 220, 255 } },
		},
	},
	{
		Id = "gum",
		Name = "Gumball",
		Tier = 9,
		Value = 9500,
		Height = 1.1,
		Weight = 18,
		Parts = {
			{ Shape = "Ball", Size = { 1.1, 1.1, 1.1 }, Color = { 90, 200, 255 } },
			{ Shape = "Ball", Size = { 0.3, 0.3, 0.3 }, Offset = { 0.22, 0.25, -0.35 }, Color = { 255, 255, 255 } },
		},
	},

	-- Tier 10 — Candy Coast: Bakery Row --------------------------------------
	{
		Id = "cak",
		Name = "Cake Slice",
		Tier = 10,
		Value = 24000,
		Height = 1.3,
		Weight = 26,
		Parts = {
			{ Shape = "Wedge", Size = { 1.3, 1.1, 2 }, Offset = { 0, -0.1, 0 }, Color = { 255, 230, 200 } },
			{ Shape = "Wedge", Size = { 1.32, 0.25, 2.02 }, Offset = { 0, 0.03, 0 }, Color = { 255, 140, 190 } },
			{ Shape = "Ball", Size = { 0.35, 0.35, 0.35 }, Offset = { 0, 0.55, 0.8 }, Color = { 220, 20, 50 } },
		},
	},
	{
		Id = "icc",
		Name = "Ice Cream",
		Tier = 10,
		Value = 26000,
		Height = 2.3,
		Weight = 22,
		Parts = {
			{ Shape = "VCylinder", Size = { 0.7, 1.2, 0.7 }, Offset = { 0, -0.55, 0 }, Color = { 225, 170, 100 }, Material = "Fabric" },
			{ Shape = "Ball", Size = { 1.05, 1.05, 1.05 }, Offset = { 0, 0.2, 0 }, Color = { 160, 240, 200 } },
			{ Shape = "Ball", Size = { 0.95, 0.95, 0.95 }, Offset = { 0, 0.8, 0 }, Color = { 255, 170, 210 } },
		},
	},
	{
		Id = "jel",
		Name = "Jelly",
		Tier = 10,
		Value = 22000,
		Height = 1.3,
		Weight = 20,
		Parts = {
			{ Shape = "VCylinder", Size = { 1.5, 1.2, 1.5 }, Color = { 80, 230, 120 }, Material = "Glass", Transparency = 0.2 },
			{ Shape = "VCylinder", Size = { 1.6, 0.12, 1.6 }, Offset = { 0, -0.6, 0 }, Color = { 245, 245, 250 } },
		},
	},
	{
		Id = "shk",
		Name = "Milkshake",
		Tier = 10,
		Value = 28000,
		Height = 2.2,
		Weight = 14,
		Parts = {
			{ Shape = "VCylinder", Size = { 0.9, 1.5, 0.9 }, Offset = { 0, -0.3, 0 }, Color = { 255, 190, 215 }, Material = "Glass", Transparency = 0.1 },
			{ Shape = "Ball", Size = { 0.95, 0.6, 0.95 }, Offset = { 0, 0.5, 0 }, Color = { 255, 250, 245 } },
			{ Shape = "VCylinder", Size = { 0.12, 1.1, 0.12 }, Offset = { 0.2, 0.7, 0 }, Rot = { 0, 0, -15 }, Color = { 255, 80, 120 } },
		},
	},

	-- Tier 11 — Candy Coast: Sugar Beach -------------------------------------
	{
		Id = "bbl",
		Name = "Beach Ball",
		Tier = 11,
		Value = 60000,
		Height = 1.6,
		Weight = 28,
		Parts = {
			{ Shape = "Ball", Size = { 1.6, 1.6, 1.6 }, Color = { 250, 250, 250 } },
			{ Shape = "VCylinder", Size = { 1.62, 0.35, 1.62 }, Offset = { 0, 0.3, 0 }, Color = { 240, 60, 60 } },
			{ Shape = "VCylinder", Size = { 1.62, 0.35, 1.62 }, Offset = { 0, -0.3, 0 }, Color = { 60, 140, 240 } },
		},
	},
	{
		Id = "sct",
		Name = "Sandcastle",
		Tier = 11,
		Value = 72000,
		Height = 2.2,
		Weight = 20,
		Parts = {
			{ Shape = "Block", Size = { 1.8, 0.9, 1.8 }, Offset = { 0, -0.65, 0 }, Color = { 240, 210, 150 }, Material = "Sand" },
			{ Shape = "VCylinder", Size = { 0.9, 1.1, 0.9 }, Offset = { 0, 0.35, 0 }, Color = { 240, 210, 150 }, Material = "Sand" },
			{ Shape = "VCylinder", Size = { 0.45, 0.6, 0.45 }, Offset = { 0.7, 0, 0.7 }, Color = { 240, 210, 150 }, Material = "Sand" },
			{ Shape = "VCylinder", Size = { 0.45, 0.6, 0.45 }, Offset = { -0.7, 0, -0.7 }, Color = { 240, 210, 150 }, Material = "Sand" },
			{ Shape = "Block", Size = { 0.35, 0.25, 0.05 }, Offset = { 0.18, 1.05, 0 }, Color = { 255, 90, 160 } },
		},
	},
	{
		Id = "srf",
		Name = "Surfboard",
		Tier = 11,
		Value = 64000,
		Height = 0.35,
		Weight = 22,
		Parts = {
			{ Shape = "Block", Size = { 1.1, 0.25, 4 }, Color = { 90, 210, 230 } },
			{ Shape = "Block", Size = { 0.25, 0.27, 3.6 }, Color = { 255, 240, 120 } },
			{ Shape = "Wedge", Size = { 0.08, 0.35, 0.45 }, Offset = { 0, -0.3, 1.5 }, Color = { 40, 40, 50 } },
		},
	},
	{
		Id = "crb",
		Name = "Candy Crab",
		Tier = 11,
		Value = 80000,
		Height = 1.1,
		Weight = 12,
		Parts = {
			{ Shape = "Ball", Size = { 1.6, 0.9, 1.3 }, Color = { 255, 90, 80 } },
			{ Shape = "Ball", Size = { 0.6, 0.6, 0.6 }, Offset = { 0.95, 0.1, -0.5 }, Color = { 255, 110, 90 } },
			{ Shape = "Ball", Size = { 0.6, 0.6, 0.6 }, Offset = { -0.95, 0.1, -0.5 }, Color = { 255, 110, 90 } },
			{ Shape = "Ball", Size = { 0.25, 0.25, 0.25 }, Offset = { 0.25, 0.5, -0.45 }, Color = { 20, 20, 25 } },
			{ Shape = "Ball", Size = { 0.25, 0.25, 0.25 }, Offset = { -0.25, 0.5, -0.45 }, Color = { 20, 20, 25 } },
		},
	},

	-- Tier 12 — Candy Coast: Candy Pier --------------------------------------
	{
		Id = "gmb",
		Name = "Gummy Bear",
		Tier = 12,
		Value = 160000,
		Height = 2.2,
		Weight = 26,
		Parts = {
			{ Shape = "Ball", Size = { 1.4, 1.4, 1.4 }, Offset = { 0, -0.35, 0 }, Color = { 255, 60, 80 }, Material = "Glass", Transparency = 0.15 },
			{ Shape = "Ball", Size = { 1, 1, 1 }, Offset = { 0, 0.6, 0 }, Color = { 255, 60, 80 }, Material = "Glass", Transparency = 0.15 },
			{ Shape = "Ball", Size = { 0.38, 0.38, 0.38 }, Offset = { 0.38, 1.02, 0 }, Color = { 255, 60, 80 }, Material = "Glass", Transparency = 0.15 },
			{ Shape = "Ball", Size = { 0.38, 0.38, 0.38 }, Offset = { -0.38, 1.02, 0 }, Color = { 255, 60, 80 }, Material = "Glass", Transparency = 0.15 },
		},
	},
	{
		Id = "wdc",
		Name = "Party Cake",
		Tier = 12,
		Value = 200000,
		Height = 2.6,
		Weight = 20,
		Parts = {
			{ Shape = "VCylinder", Size = { 2, 0.9, 2 }, Offset = { 0, -0.85, 0 }, Color = { 255, 245, 250 } },
			{ Shape = "VCylinder", Size = { 1.5, 0.8, 1.5 }, Offset = { 0, 0, 0 }, Color = { 255, 200, 225 } },
			{ Shape = "VCylinder", Size = { 1, 0.7, 1 }, Offset = { 0, 0.75, 0 }, Color = { 255, 245, 250 } },
			{ Shape = "VCylinder", Size = { 0.12, 0.4, 0.12 }, Offset = { 0, 1.3, 0 }, Color = { 120, 200, 255 } },
			{ Shape = "Ball", Size = { 0.18, 0.25, 0.18 }, Offset = { 0, 1.55, 0 }, Color = { 255, 200, 60 }, Material = "Neon" },
		},
	},
	{
		Id = "cdc",
		Name = "Candy Chest",
		Tier = 12,
		Value = 180000,
		Height = 1.8,
		Weight = 14,
		Parts = {
			{ Shape = "Block", Size = { 2.2, 1.2, 1.5 }, Offset = { 0, -0.3, 0 }, Color = { 255, 150, 200 } },
			{ Shape = "Block", Size = { 2.25, 0.55, 1.55 }, Offset = { 0, 0.58, 0 }, Color = { 150, 230, 255 } },
			{ Shape = "Ball", Size = { 0.5, 0.5, 0.5 }, Offset = { 0.5, 0.95, 0 }, Color = { 255, 230, 80 } },
			{ Shape = "Ball", Size = { 0.45, 0.45, 0.45 }, Offset = { -0.4, 0.95, 0.2 }, Color = { 120, 255, 160 } },
		},
	},
	{
		Id = "glp",
		Name = "Golden Lollipop",
		Tier = 12,
		Value = 320000,
		Height = 2.6,
		Weight = 4,
		Parts = {
			{ Shape = "VCylinder", Size = { 0.18, 1.5, 0.18 }, Offset = { 0, -0.55, 0 }, Color = { 250, 250, 250 } },
			{ Shape = "HCylinder", Size = { 0.35, 1.7, 1.7 }, Offset = { 0, 0.45, 0 }, Rot = { 0, 90, 0 }, Color = { 255, 200, 40 }, Material = "Foil" },
			{ Shape = "HCylinder", Size = { 0.4, 0.9, 0.9 }, Offset = { 0, 0.45, 0 }, Rot = { 0, 90, 0 }, Color = { 255, 240, 150 }, Material = "Neon" },
		},
	},

	-- Tier 13 — Neon City: Arcade Street -------------------------------------
	{
		Id = "gcr",
		Name = "Game Cartridge",
		Tier = 13,
		Value = 420000,
		Height = 0.45,
		Weight = 30,
		Parts = {
			{ Shape = "Block", Size = { 1.4, 0.4, 1.6 }, Color = { 70, 70, 80 } },
			{ Shape = "Block", Size = { 1, 0.42, 0.9 }, Offset = { 0, 0, -0.2 }, Color = { 255, 60, 180 }, Material = "Neon" },
		},
	},
	{
		Id = "neo",
		Name = "Neon Tube",
		Tier = 13,
		Value = 450000,
		Height = 0.5,
		Weight = 24,
		Parts = {
			{ Shape = "HCylinder", Size = { 3, 0.4, 0.4 }, Color = { 0, 255, 230 }, Material = "Neon" },
			{ Shape = "HCylinder", Size = { 0.3, 0.5, 0.5 }, Offset = { 1.5, 0, 0 }, Color = { 60, 60, 70 }, Material = "Metal" },
			{ Shape = "HCylinder", Size = { 0.3, 0.5, 0.5 }, Offset = { -1.5, 0, 0 }, Color = { 60, 60, 70 }, Material = "Metal" },
		},
	},
	{
		Id = "bat",
		Name = "Mega Battery",
		Tier = 13,
		Value = 400000,
		Height = 1.7,
		Weight = 22,
		Parts = {
			{ Shape = "VCylinder", Size = { 1, 1.5, 1 }, Offset = { 0, -0.1, 0 }, Color = { 60, 220, 110 } },
			{ Shape = "VCylinder", Size = { 1.02, 0.5, 1.02 }, Offset = { 0, 0.4, 0 }, Color = { 30, 30, 36 } },
			{ Shape = "VCylinder", Size = { 0.35, 0.2, 0.35 }, Offset = { 0, 0.75, 0 }, Color = { 200, 200, 210 }, Material = "Metal" },
		},
	},
	{
		Id = "joy",
		Name = "Joystick",
		Tier = 13,
		Value = 480000,
		Height = 1.6,
		Weight = 16,
		Parts = {
			{ Shape = "Block", Size = { 1.6, 0.5, 1.2 }, Offset = { 0, -0.55, 0 }, Color = { 40, 40, 55 } },
			{ Shape = "VCylinder", Size = { 0.2, 0.8, 0.2 }, Offset = { 0, 0.05, 0 }, Color = { 30, 30, 30 } },
			{ Shape = "Ball", Size = { 0.6, 0.6, 0.6 }, Offset = { 0, 0.5, 0 }, Color = { 255, 40, 60 } },
			{ Shape = "VCylinder", Size = { 0.3, 0.1, 0.3 }, Offset = { 0.5, -0.27, 0.2 }, Color = { 0, 220, 255 }, Material = "Neon" },
		},
	},

	-- Tier 14 — Neon City: Tech Mall -----------------------------------------
	{
		Id = "hvb",
		Name = "Hoverboard",
		Tier = 14,
		Value = 1100000,
		Height = 0.45,
		Weight = 26,
		Parts = {
			{ Shape = "Block", Size = { 1.2, 0.25, 3.2 }, Offset = { 0, 0.05, 0 }, Color = { 240, 240, 250 } },
			{ Shape = "Block", Size = { 1, 0.15, 3 }, Offset = { 0, -0.15, 0 }, Color = { 150, 60, 255 }, Material = "Neon" },
		},
	},
	{
		Id = "bbx",
		Name = "Boombox",
		Tier = 14,
		Value = 1200000,
		Height = 1.5,
		Weight = 22,
		Parts = {
			{ Shape = "Block", Size = { 2.4, 1.2, 0.8 }, Offset = { 0, -0.15, 0 }, Color = { 50, 50, 60 } },
			{ Shape = "HCylinder", Size = { 0.1, 0.8, 0.8 }, Offset = { 0.65, -0.15, -0.42 }, Rot = { 0, 90, 0 }, Color = { 0, 230, 255 }, Material = "Neon" },
			{ Shape = "HCylinder", Size = { 0.1, 0.8, 0.8 }, Offset = { -0.65, -0.15, -0.42 }, Rot = { 0, 90, 0 }, Color = { 255, 60, 200 }, Material = "Neon" },
			{ Shape = "Block", Size = { 1.8, 0.15, 0.15 }, Offset = { 0, 0.6, 0 }, Color = { 180, 180, 190 }, Material = "Metal" },
		},
	},
	{
		Id = "arc",
		Name = "Arcade Cabinet",
		Tier = 14,
		Value = 1500000,
		Height = 3,
		Weight = 16,
		Parts = {
			{ Shape = "Block", Size = { 1.6, 3, 1.4 }, Color = { 120, 40, 200 } },
			{ Shape = "Block", Size = { 1.2, 0.9, 0.05 }, Offset = { 0, 0.6, -0.72 }, Color = { 0, 255, 200 }, Material = "Neon" },
			{ Shape = "Wedge", Size = { 1.5, 0.35, 0.6 }, Offset = { 0, -0.1, -0.95 }, Color = { 40, 40, 50 } },
			{ Shape = "Block", Size = { 1.62, 0.3, 1.42 }, Offset = { 0, 1.35, 0 }, Color = { 255, 230, 60 }, Material = "Neon" },
		},
	},
	{
		Id = "sat",
		Name = "Satellite Dish",
		Tier = 14,
		Value = 1300000,
		Height = 2,
		Weight = 14,
		Parts = {
			{ Shape = "Block", Size = { 1, 0.4, 1 }, Offset = { 0, -0.8, 0 }, Color = { 90, 90, 100 }, Material = "Metal" },
			{ Shape = "VCylinder", Size = { 0.2, 0.9, 0.2 }, Offset = { 0, -0.2, 0 }, Color = { 150, 150, 160 }, Material = "Metal" },
			{ Shape = "HCylinder", Size = { 0.15, 1.9, 1.9 }, Offset = { 0, 0.45, 0 }, Rot = { 0, 90, 30 }, Color = { 230, 230, 240 }, Material = "Metal" },
			{ Shape = "Ball", Size = { 0.25, 0.25, 0.25 }, Offset = { 0, 0.75, -0.5 }, Color = { 255, 50, 50 }, Material = "Neon" },
		},
	},

	-- Tier 15 — Neon City: Robot Factory -------------------------------------
	{
		Id = "rbh",
		Name = "Robot Head",
		Tier = 15,
		Value = 3000000,
		Height = 1.9,
		Weight = 26,
		Parts = {
			{ Shape = "Block", Size = { 1.5, 1.3, 1.4 }, Offset = { 0, -0.2, 0 }, Color = { 190, 195, 210 }, Material = "Metal" },
			{ Shape = "Block", Size = { 0.35, 0.25, 0.05 }, Offset = { 0.35, -0.1, -0.72 }, Color = { 0, 255, 230 }, Material = "Neon" },
			{ Shape = "Block", Size = { 0.35, 0.25, 0.05 }, Offset = { -0.35, -0.1, -0.72 }, Color = { 0, 255, 230 }, Material = "Neon" },
			{ Shape = "VCylinder", Size = { 0.1, 0.5, 0.1 }, Offset = { 0, 0.7, 0 }, Color = { 120, 120, 130 }, Material = "Metal" },
			{ Shape = "Ball", Size = { 0.25, 0.25, 0.25 }, Offset = { 0, 0.95, 0 }, Color = { 255, 50, 50 }, Material = "Neon" },
		},
	},
	{
		Id = "srv",
		Name = "Server Rack",
		Tier = 15,
		Value = 2800000,
		Height = 3,
		Weight = 22,
		Parts = {
			{ Shape = "Block", Size = { 1.4, 3, 1.4 }, Color = { 25, 25, 32 } },
			{ Shape = "Block", Size = { 1.1, 0.08, 0.05 }, Offset = { 0, 0.8, -0.72 }, Color = { 0, 255, 120 }, Material = "Neon" },
			{ Shape = "Block", Size = { 1.1, 0.08, 0.05 }, Offset = { 0, 0.2, -0.72 }, Color = { 0, 180, 255 }, Material = "Neon" },
			{ Shape = "Block", Size = { 1.1, 0.08, 0.05 }, Offset = { 0, -0.4, -0.72 }, Color = { 0, 255, 120 }, Material = "Neon" },
			{ Shape = "Block", Size = { 1.1, 0.08, 0.05 }, Offset = { 0, -1, -0.72 }, Color = { 255, 60, 200 }, Material = "Neon" },
		},
	},
	{
		Id = "mch",
		Name = "Mech Arm",
		Tier = 15,
		Value = 3300000,
		Height = 2.6,
		Weight = 16,
		Parts = {
			{ Shape = "VCylinder", Size = { 1.2, 0.4, 1.2 }, Offset = { 0, -1.1, 0 }, Color = { 255, 170, 30 }, Material = "Metal" },
			{ Shape = "Block", Size = { 0.5, 1.4, 0.5 }, Offset = { 0, -0.3, 0 }, Rot = { 0, 0, 20 }, Color = { 255, 170, 30 }, Material = "Metal" },
			{ Shape = "Block", Size = { 0.45, 1.1, 0.45 }, Offset = { 0.45, 0.6, 0 }, Rot = { 0, 0, -30 }, Color = { 255, 170, 30 }, Material = "Metal" },
			{ Shape = "Block", Size = { 0.7, 0.3, 0.3 }, Offset = { 0.85, 1.15, 0 }, Color = { 60, 60, 70 }, Material = "Metal" },
		},
	},
	{
		Id = "lsr",
		Name = "Laser Core",
		Tier = 15,
		Value = 3600000,
		Height = 1.9,
		Weight = 12,
		Parts = {
			{ Shape = "VCylinder", Size = { 1.3, 1.9, 1.3 }, Color = { 200, 220, 255 }, Material = "Glass", Transparency = 0.35 },
			{ Shape = "VCylinder", Size = { 0.5, 1.7, 0.5 }, Color = { 255, 40, 80 }, Material = "Neon" },
			{ Shape = "VCylinder", Size = { 1.4, 0.2, 1.4 }, Offset = { 0, 0.9, 0 }, Color = { 60, 60, 70 }, Material = "Metal" },
			{ Shape = "VCylinder", Size = { 1.4, 0.2, 1.4 }, Offset = { 0, -0.9, 0 }, Color = { 60, 60, 70 }, Material = "Metal" },
		},
	},

	-- Tier 16 — Neon City: Skyline -------------------------------------------
	{
		Id = "ufo",
		Name = "Mini UFO",
		Tier = 16,
		Value = 7500000,
		Height = 1.3,
		Weight = 26,
		Parts = {
			{ Shape = "VCylinder", Size = { 2.6, 0.4, 2.6 }, Offset = { 0, -0.25, 0 }, Color = { 200, 205, 220 }, Material = "Metal" },
			{ Shape = "VCylinder", Size = { 2.7, 0.12, 2.7 }, Offset = { 0, -0.25, 0 }, Color = { 0, 255, 150 }, Material = "Neon" },
			{ Shape = "Ball", Size = { 1.2, 1.2, 1.2 }, Offset = { 0, 0.15, 0 }, Color = { 160, 230, 255 }, Material = "Glass", Transparency = 0.2 },
		},
	},
	{
		Id = "rdg",
		Name = "Robot Dog",
		Tier = 16,
		Value = 8200000,
		Height = 1.7,
		Weight = 22,
		Parts = {
			{ Shape = "Block", Size = { 1, 0.8, 2 }, Offset = { 0, 0, 0 }, Color = { 230, 232, 240 }, Material = "Metal" },
			{ Shape = "Block", Size = { 0.8, 0.7, 0.8 }, Offset = { 0, 0.45, -1.1 }, Color = { 230, 232, 240 }, Material = "Metal" },
			{ Shape = "Block", Size = { 0.6, 0.12, 0.05 }, Offset = { 0, 0.5, -1.52 }, Color = { 0, 220, 255 }, Material = "Neon" },
			{ Shape = "Block", Size = { 0.9, 0.5, 1.6 }, Offset = { 0, -0.6, 0 }, Color = { 60, 60, 70 }, Material = "Metal" },
			{ Shape = "Block", Size = { 0.12, 0.12, 0.7 }, Offset = { 0, 0.35, 1.2 }, Rot = { -30, 0, 0 }, Color = { 60, 60, 70 }, Material = "Metal" },
		},
	},
	{
		Id = "qcb",
		Name = "Quantum Cube",
		Tier = 16,
		Value = 9500000,
		Height = 1.7,
		Weight = 14,
		Parts = {
			{ Shape = "Block", Size = { 1.6, 1.6, 1.6 }, Color = { 180, 140, 255 }, Material = "Glass", Transparency = 0.4 },
			{ Shape = "Block", Size = { 0.8, 0.8, 0.8 }, Rot = { 45, 45, 0 }, Color = { 255, 80, 240 }, Material = "Neon" },
		},
	},
	{
		Id = "gch",
		Name = "Golden Chip",
		Tier = 16,
		Value = 15000000,
		Height = 0.45,
		Weight = 4,
		Parts = {
			{ Shape = "Block", Size = { 2, 0.3, 2 }, Offset = { 0, 0.05, 0 }, Color = { 255, 200, 40 }, Material = "Foil" },
			{ Shape = "Block", Size = { 1.2, 0.34, 1.2 }, Offset = { 0, 0.05, 0 }, Color = { 40, 40, 50 } },
			{ Shape = "Block", Size = { 2.3, 0.1, 0.2 }, Offset = { 0, -0.12, 0.5 }, Color = { 220, 220, 230 }, Material = "Metal" },
			{ Shape = "Block", Size = { 2.3, 0.1, 0.2 }, Offset = { 0, -0.12, -0.5 }, Color = { 220, 220, 230 }, Material = "Metal" },
		},
	},
}

ItemConfig.ById = {}
ItemConfig.ByTier = {}
for index, item in ItemConfig.Items do
	item.Index = index
	assert(ItemConfig.ById[item.Id] == nil, "duplicate item id " .. item.Id)
	ItemConfig.ById[item.Id] = item
	ItemConfig.ByTier[item.Tier] = ItemConfig.ByTier[item.Tier] or {}
	table.insert(ItemConfig.ByTier[item.Tier], item)
end

return ItemConfig
