-- Every stackable item. Adding an item = adding one entry here.
--
-- Id       short code used in replicated stack strings (keep it 3 chars, unique)
-- Tier     Strength level required to pick it up; also which zone spawns it
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
