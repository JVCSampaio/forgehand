-- Plays SoundConfig entries. 2D UI feedback by default; pass a position for
-- world sounds (collapses heard by everyone nearby).

local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local SoundConfig = require(game:GetService("ReplicatedStorage").Shared.Config.SoundConfig)

local Audio = {}

local templates: { [string]: Sound } = {}

function Audio.init()
	for name, spec in SoundConfig do
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = spec.Id
		sound.Volume = spec.Volume or 0.5
		sound.PlaybackSpeed = spec.Pitch or 1
		sound.Looped = spec.Looped == true
		sound.Parent = SoundService
		templates[name] = sound
	end
end

function Audio.play(name: string, pitch: number?, position: Vector3?)
	local template = templates[name]
	if not template then
		return
	end
	local sound = template:Clone()
	sound.PlaybackSpeed = (SoundConfig[name].Pitch or 1) * (pitch or 1)
	if position then
		local anchor = Instance.new("Attachment")
		anchor.WorldPosition = position
		anchor.Parent = Workspace.Terrain
		sound.RollOffMaxDistance = 250
		sound.Parent = anchor
		sound.Ended:Once(function()
			anchor:Destroy()
		end)
		task.delay(6, function()
			if anchor.Parent then
				anchor:Destroy()
			end
		end)
	else
		sound.Parent = SoundService
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		task.delay(6, function()
			if sound.Parent then
				sound:Destroy()
			end
		end)
	end
	sound:Play()
end

-- Looping sound whose volume the caller drives (e.g. wind while wobbling).
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
