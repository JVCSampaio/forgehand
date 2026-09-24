-- Server-wide Item Rain: automatic on a timer, or bought by a player for
-- everyone. Purchases during a rain extend it instead of stacking.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)
local WorldIndex = require(Shared.WorldIndex)
local ItemSpawnService = require(script.Parent.ItemSpawnService)
local MonetizationService = require(script.Parent.MonetizationService)

local EventService = {}

local RAIN = GameConfig.Events.ItemRain
local rainEndsAt = 0
local raining = false

local function broadcast(text: string)
	Remotes.Notify:FireAllClients({ Kind = "Event", Text = text })
end

local function runRain()
	raining = true
	workspace:SetAttribute("RainEndsAt", workspace:GetServerTimeNow() + (rainEndsAt - os.clock()))
	while os.clock() < rainEndsAt do
		-- Rain falls on every world that currently has players in it.
		local occupied = {}
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				occupied[WorldIndex:at(root.Position)] = true
			end
		end
		for world in occupied do
			for _ = 1, RAIN.ItemsPerSecond do
				ItemSpawnService.spawnRainDrop(world, RAIN.RarityBoost)
			end
		end
		task.wait(1)
	end
	raining = false
	workspace:SetAttribute("RainEndsAt", 0)
end

function EventService.startRain(byName: string?)
	local now = os.clock()
	rainEndsAt = math.max(rainEndsAt, now) + RAIN.Duration
	broadcast(if byName then string.format("%s made it RAIN ITEMS for everyone!", byName) else "ITEM RAIN! Grab everything!")
	if raining then
		workspace:SetAttribute("RainEndsAt", workspace:GetServerTimeNow() + (rainEndsAt - now))
	else
		task.spawn(runRain)
	end
end

function EventService.init()
	MonetizationService.setRainHandler(function(player)
		EventService.startRain(player.DisplayName)
	end)
	if RAIN.Interval > 0 then
		task.spawn(function()
			while true do
				task.wait(RAIN.Interval)
				if #Players:GetPlayers() > 0 then
					EventService.startRain(nil)
				end
			end
		end)
	end
end

return EventService
