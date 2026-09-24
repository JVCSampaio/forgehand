-- Opens a built place file and checks that the DataModel has everything the
-- scripts expect at runtime: scripts with the right classes, every remote,
-- and every module a script requires by name.
--   rojo build default.project.json -o build/Stackhead.rbxl
--   lune run tools/verify_place.luau build/Stackhead.rbxl

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local path = process.args[1] or "build/Stackhead.rbxl"
local game = roblox.deserializePlace(fs.readFile(path))
local failures = {}

local function expect(condition: any, message: string)
	if not condition then
		table.insert(failures, message)
	end
end

local function find(root, dotted: string)
	local node = root
	for name in string.gmatch(dotted, "[^%.]+") do
		if name == "Parent" then
			node = node and node.Parent
		else
			node = node and node:FindFirstChild(name)
		end
	end
	return node
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local serverMain = find(ServerScriptService, "Server.Main")
expect(serverMain and serverMain.ClassName == "Script", "ServerScriptService.Server.Main must be a Script")
local clientMain = find(StarterPlayer, "StarterPlayerScripts.Client.Main")
expect(clientMain and clientMain.ClassName == "LocalScript", "Client.Main must be a LocalScript")

-- Remotes referenced in Shared/Remotes must exist with the right class.
local remotesModule = find(ReplicatedStorage, "Shared.Remotes")
expect(remotesModule ~= nil, "Shared.Remotes module missing")
if remotesModule then
	local source = remotesModule.Source
	for name, class in string.gmatch(source, 'WaitForChild%("(%w+)"%) :: (%w+)') do
		local remote = find(ReplicatedStorage, "Remotes." .. name)
		expect(remote and remote.ClassName == class, "Remote " .. name .. " should be a " .. class)
	end
end

-- Every module listed in the two entry points must exist as a ModuleScript.
local function checkOrder(main, folder, label)
	if not main or not folder then
		return
	end
	for name in string.gmatch(main.Source, '\t"(%w+)",') do
		local module = folder:FindFirstChild(name)
		expect(module and module.ClassName == "ModuleScript", label .. " module missing: " .. name)
	end
end
checkOrder(serverMain, find(ServerScriptService, "Server.Services"), "Server")
checkOrder(clientMain, find(StarterPlayer, "StarterPlayerScripts.Client.Controllers"), "Client")

-- Static `require(script.Parent.X)` / `require(Shared.X)` targets must exist.
local checked = 0
for _, instance in game:GetDescendants() do
	if instance:IsA("LuaSourceContainer") then
		for target in string.gmatch(instance.Source, "require%(script%.Parent%.([%w%.]+)%)") do
			checked += 1
			expect(find(instance.Parent, target) ~= nil, instance:GetFullName() .. " requires missing script.Parent." .. target)
		end
		for target in string.gmatch(instance.Source, "require%(Shared%.([%w%.]+)%)") do
			checked += 1
			expect(find(ReplicatedStorage, "Shared." .. target) ~= nil, instance:GetFullName() .. " requires missing Shared." .. target)
		end
	end
end
expect(checked > 20, "expected to verify many requires, only saw " .. checked)

for _, failure in failures do
	print("FAIL " .. failure)
end
print(string.format("place check: %d requires verified, %d failures", checked, #failures))
if #failures > 0 then
	process.exit(1)
end
