-- Global "Tallest Stack" board (OrderedDataStore) shown next to the bank.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage").Shared
local GameConfig = require(Shared.Config.GameConfig)
local StackService = require(script.Parent.StackService)

local LeaderboardService = {}

local CFG = GameConfig.Leaderboard
local store: OrderedDataStore? = nil
local pending: { [number]: number } = {}
local nameCache: { [number]: string } = {}
local rows: { TextLabel } = {}

local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	local name = player and player.DisplayName
	if not name then
		local ok, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		name = if ok then result else "???"
	end
	nameCache[userId] = name
	return name
end

local function buildBoard()
	local board = Workspace:WaitForChild("Map"):WaitForChild("Leaderboard")
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = gui
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 70)
	title.BackgroundTransparency = 1
	title.Text = "TALLEST STACKS"
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 215, 80)
	title.Parent = gui
	for i = 1, CFG.Entries do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(0.92, 0, 0, 34)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.new(1, 1, 1)
		row.Text = string.format("%d.  —", i)
		row.LayoutOrder = i
		row.Parent = gui
		rows[i] = row
	end
	gui.Parent = board
end

local function refresh()
	if not store then
		return
	end
	for userId, best in pending do
		pending[userId] = nil
		pcall(function()
			(store :: OrderedDataStore):UpdateAsync(tostring(userId), function(old)
				if type(old) == "number" and old >= best then
					return nil
				end
				return best
			end)
		end)
	end
	local ok, pages = pcall(function()
		return (store :: OrderedDataStore):GetSortedAsync(false, CFG.Entries)
	end)
	if not ok then
		return
	end
	for i, entry in pages:GetCurrentPage() do
		if rows[i] then
			local userId = tonumber(entry.key)
			rows[i].Text = string.format("%d.  %s — %d", i, if userId then nameFor(userId) else "?", entry.value)
		end
	end
end

function LeaderboardService.init()
	buildBoard()
	local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, CFG.StoreName)
	if ok then
		store = result
	end
	StackService.onBanked(function(player, profile, count)
		if count >= profile.Stats.BestStack then
			pending[player.UserId] = profile.Stats.BestStack
		end
	end)
	task.spawn(function()
		while true do
			pcall(refresh)
			task.wait(CFG.RefreshInterval)
		end
	end)
end

return LeaderboardService
