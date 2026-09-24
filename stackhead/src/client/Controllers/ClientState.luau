-- Latest server snapshot of the local player's profile + local stack
-- attributes. Everything UI reads comes from here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local StackCodec = require(ReplicatedStorage.Shared.StackCodec)

local ClientState = {}

local player = Players.LocalPlayer
local changed = Instance.new("BindableEvent")
local stackChanged = Instance.new("BindableEvent")

ClientState.Data = nil :: any
ClientState.SyncedAt = 0
ClientState.Changed = changed.Event
ClientState.StackChanged = stackChanged.Event

function ClientState.stackCodes(): { string }
	return StackCodec.decode(player:GetAttribute("Stack") :: string?)
end

function ClientState.wobble(): number
	return player:GetAttribute("Wobble") or 0
end

function ClientState.stackHeight(): number
	return player:GetAttribute("StackHeight") or 0
end

function ClientState.glueArmed(): boolean
	return player:GetAttribute("GlueArmed") == true
end

function ClientState.boostRemaining(): number
	local data = ClientState.Data
	if not data then
		return 0
	end
	return math.max(0, data.BoostRemaining - (os.clock() - ClientState.SyncedAt))
end

function ClientState.init()
	Remotes.DataSync.OnClientEvent:Connect(function(snapshot)
		ClientState.Data = snapshot
		ClientState.SyncedAt = os.clock()
		changed:Fire(snapshot)
	end)
	for _, name in { "Stack", "GlueArmed" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			stackChanged:Fire()
		end)
	end
end

return ClientState
