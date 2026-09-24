-- Shared Worlds instance built from WorldConfig.
local Worlds = require(script.Parent.Worlds)
local WorldConfig = require(script.Parent.Config.WorldConfig)

return Worlds.new(WorldConfig)
