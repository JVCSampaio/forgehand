-- Client entry point.

local Controllers = script.Parent:WaitForChild("Controllers")

local order = {
	"ClientState",
	"Audio",
	"WorldAmbience",
	"StackRenderer",
	"ItemFx",
	"HUD",
	"Menus",
	"Input",
	"Guide",
	"TowerCamera",
}

for _, name in order do
	local ok, err = pcall(function()
		require(Controllers:WaitForChild(name)).init()
	end)
	if not ok then
		warn("[Stackhead] client module failed:", name, err)
	end
end
