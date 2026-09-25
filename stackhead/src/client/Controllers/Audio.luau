-- Bounded voices, separate buses, comedy variation and music ducking.
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Config = game:GetService("ReplicatedStorage").Shared.Config
local SoundConfig = require(Config.SoundConfig)
local Assets = require(Config.AudioAssets)
local ClientState = require(script.Parent.ClientState)
local Audio = {}
local templates: { [string]: Sound } = {}
local groups: { [string]: SoundGroup } = {}
local lastPlayed: { [string]: number } = {}
local active, duckUntil = 0, 0
local rng = Random.new()
local COMEDY = { Meme = true, Bump = true, Collapse = true, Glue = true }
local COOLDOWN = { Pickup = 0.055, Rare = 0.6, Meme = 2.5, Collapse = 1.2, Bump = 0.2, Bank = 0.2 }
local function settings()
	return ClientState.Data and ClientState.Data.Settings or { Sfx = true, Music = true, Memes = true }
end
local function refresh()
	local prefs = settings()
	groups.Sfx.Volume = if prefs.Sfx then 0.7 else 0
	groups.Comedy.Volume = if prefs.Sfx and prefs.Memes then 0.65 else 0
	groups.Music.Volume = if prefs.Music then (if os.clock() < duckUntil then 0.08 else 0.22) else 0
end
function Audio.init()
	for _, name in { "Sfx", "Comedy", "Music" } do
		local group = Instance.new("SoundGroup")
		group.Name = "Stackhead" .. name
		group.Parent = SoundService
		groups[name] = group
	end
	for name, spec in SoundConfig do
		local sound = Instance.new("Sound")
		sound.Name = name
		local id = Assets[name] or 0
		sound.SoundId = if id > 0 then "rbxassetid://" .. tostring(id) else spec.Id
		sound.Volume = spec.Volume or 0.5
		sound.PlaybackSpeed = if id > 0 then 1 else (spec.Pitch or 1)
		sound.Looped = spec.Looped == true
		sound.SoundGroup = if COMEDY[name] then groups.Comedy else groups.Sfx
		sound.Parent = SoundService
		templates[name] = sound
	end
	if Assets.Music > 0 then
		local music = Instance.new("Sound")
		music.Name = "StackheadMusic"
		music.SoundId = "rbxassetid://" .. tostring(Assets.Music)
		music.Looped = true
		music.Volume = 0.6
		music.SoundGroup = groups.Music
		music.Parent = SoundService
		music:Play()
	end
	ClientState.Changed:Connect(refresh)
	refresh()
end
function Audio.play(name: string, pitch: number?, position: Vector3?)
	local template = templates[name]
	local prefs = settings()
	if not template or not prefs.Sfx or (COMEDY[name] and not prefs.Memes) or active >= 16 then
		return
	end
	local now = os.clock()
	if now - (lastPlayed[name] or -math.huge) < (COOLDOWN[name] or 0.05) then
		return
	end
	if position then
		local camera = Workspace.CurrentCamera
		if camera and (camera.CFrame.Position - position).Magnitude > 220 then
			return
		end
	end
	lastPlayed[name] = now
	local sound = template:Clone()
	sound.PlaybackSpeed = template.PlaybackSpeed * (pitch or 1) * rng:NextNumber(0.96, 1.04)
	local owner: Instance = sound
	if position then
		local anchor = Instance.new("Attachment")
		anchor.Position = position
		anchor.Parent = Workspace.Terrain
		sound.RollOffMaxDistance = 220
		sound.RollOffMinDistance = 12
		sound.Parent = anchor
		owner = anchor
	else
		sound.Parent = SoundService
	end
	active += 1
	local done = false
	local function cleanup()
		if done then
			return
		end
		done = true
		active -= 1
		owner:Destroy()
	end
	sound.Ended:Once(cleanup)
	task.delay(6, cleanup)
	sound:Play()
	-- Cartoon pitch slide fallback until the original WAVs are uploaded.
	if (Assets[name] or 0) == 0 and COMEDY[name] then
		local endPitch = if name == "Collapse" then 0.35 elseif name == "Meme" then 1.7 else 0.65
		TweenService:Create(sound, TweenInfo.new(0.28), { PlaybackSpeed = endPitch }):Play()
	end
	if name == "Meme" or name == "Bank" or name == "Collapse" then
		duckUntil = now + 0.8
		refresh()
		task.delay(0.85, refresh)
	end
end
function Audio.loop(name: string): Sound?
	local template = templates[name]
	if not template then
		return nil
	end
	local sound = template:Clone()
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()
	return sound
end
return Audio
