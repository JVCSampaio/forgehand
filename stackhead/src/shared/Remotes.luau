-- Single place that names every remote. The instances themselves are
-- declared in default.project.json so they exist before any script runs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:WaitForChild("Remotes")

local Remotes = {
	-- client -> server
	Dash = folder:WaitForChild("Dash") :: RemoteEvent,
	UseGlue = folder:WaitForChild("UseGlue") :: RemoteEvent,
	ClaimDaily = folder:WaitForChild("ClaimDaily") :: RemoteEvent,
	BuyUpgrade = folder:WaitForChild("BuyUpgrade") :: RemoteFunction,
	Travel = folder:WaitForChild("Travel") :: RemoteEvent,
	ClaimOrder = folder:WaitForChild("ClaimOrder") :: RemoteEvent,
	EquipCosmetic = folder:WaitForChild("EquipCosmetic") :: RemoteEvent,
	-- server -> client
	DataSync = folder:WaitForChild("DataSync") :: RemoteEvent,
	Notify = folder:WaitForChild("Notify") :: RemoteEvent,
	Banked = folder:WaitForChild("Banked") :: RemoteEvent,
	Collapsed = folder:WaitForChild("Collapsed") :: RemoteEvent,
	PickedUp = folder:WaitForChild("PickedUp") :: RemoteEvent,
	Bumped = folder:WaitForChild("Bumped") :: RemoteEvent,
}

return Remotes
