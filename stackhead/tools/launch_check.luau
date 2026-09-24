-- Pre-launch gate: lists what still has to be set up outside the code.
--   lune run tools/launch_check.luau          (report, exit 0)
--   lune run tools/launch_check.luau --strict (exit 1 if anything is missing)
-- The game runs fine with these unset (shop items hide, sounds are engine
-- placeholders); this is about not launching without them.

local process = require("@lune/process")
local roblox = require("@lune/roblox")
Vector3 = roblox.Vector3
Color3 = roblox.Color3

local MonetizationConfig = require("../src/shared/Config/MonetizationConfig")
local SoundConfig = require("../src/shared/Config/SoundConfig")

local missing = 0

local function section(title: string, list: { string })
	table.sort(list)
	if #list == 0 then
		print("OK    " .. title)
		return
	end
	missing += #list
	print(string.format("TODO  %s (%d): %s", title, #list, table.concat(list, ", ")))
end

local passes = {}
for key, pass in MonetizationConfig.GamePasses do
	if pass.Id == 0 then
		table.insert(passes, key)
	end
end
section("Game pass ids (Creator Dashboard > Monetization > Passes)", passes)

local products = {}
for key, product in MonetizationConfig.Products do
	if product.Id == 0 then
		table.insert(products, key)
	end
end
section("Developer product ids (Creator Dashboard > Monetization > Developer Products)", products)

local sounds = {}
for key, sound in SoundConfig do
	if string.sub(sound.Id, 1, 11) == "rbxasset://" then
		table.insert(sounds, key)
	end
end
section("Sounds still using engine placeholders (swap for Creator Store audio)", sounds)

print(if missing == 0 then "\nReady to launch." else string.format("\n%d item(s) to set up before launch.", missing))
if missing > 0 and table.find(process.args, "--strict") then
	process.exit(1)
end
