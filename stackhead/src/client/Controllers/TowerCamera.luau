-- Keep Roblox's orbit, input and occlusion camera. Overview is opt-in and
-- leaves automatically on movement, banking or respawn.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Framing = require(Shared.CameraFraming)
local Config = require(Shared.Config.GameConfig)
local HUD = require(script.Parent.HUD)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.ClientState)
local TowerCamera = {}
local player = Players.LocalPlayer
function TowerCamera.init()
	local overview = false
	local returning = false
	local distance = Config.Camera.MaxZoom
	local offset = Vector3.zero
	local currentHumanoid: Humanoid? = nil
	local button = UIKit.button({
		Name = "TowerView",
		Text = "VIEW TOWER [C]",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -88),
		Size = UDim2.fromOffset(156, 36),
		BackgroundColor3 = UIKit.Colors.PanelLight,
		Parent = HUD.gui(),
	})
	UIKit.textLimit(button, 16)
	local function setOverview(enabled)
		if overview == enabled then
			return
		end
		overview = enabled
		returning = not enabled
		local camera = Workspace.CurrentCamera
		if camera then
			distance = (camera.CFrame.Position - camera.Focus.Position).Magnitude
		end
		button.Text = if enabled then "BACK TO PLAY" elseif HUD.isTouch then "VIEW TOWER" else "VIEW TOWER [C]"
		button.BackgroundColor3 = if enabled then UIKit.Colors.Purple else UIKit.Colors.PanelLight
	end
	button.Activated:Connect(function()
		setOverview(not overview)
	end)
	ContextActionService:BindAction("ViewTower", function(_, state)
		if game:GetService("UserInputService"):GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			setOverview(not overview)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.C, Enum.KeyCode.ButtonR3)
	player.CameraMinZoomDistance = 8
	player.CameraMaxZoomDistance = Config.Camera.MaxZoom
	RunService:BindToRenderStep("TowerFraming", Enum.RenderPriority.Camera.Value - 1, function(dt)
		local camera = Workspace.CurrentCamera
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not camera or not humanoid then
			return
		end
		if humanoid ~= currentHumanoid then
			currentHumanoid = humanoid
			overview, returning = false, false
			offset = Vector3.zero
			button.Text = if HUD.isTouch then "VIEW TOWER" else "VIEW TOWER [C]"
			button.BackgroundColor3 = UIKit.Colors.PanelLight
			player.CameraMinZoomDistance = 8
			player.CameraMaxZoomDistance = Config.Camera.MaxZoom
		end
		local height = State.stackHeight()
		if overview and (height <= 0 or humanoid.MoveDirection.Magnitude > 0.1 or humanoid.Health <= 0) then
			setOverview(false)
		end
		button.Visible = height > 0
		local reduced = GuiService.ReducedMotionEnabled or (State.Data and State.Data.Settings.ReducedMotion)
		local alpha = if reduced then 1 else 1 - math.exp(-5 * math.min(dt, 0.1))
		local targetDistance, targetY = Config.Camera.MaxZoom, math.min(height * 0.12, 3)
		if overview then
			targetDistance, targetY =
				Framing.overview(height, camera.ViewportSize.X / math.max(camera.ViewportSize.Y, 1), camera.FieldOfView)
		end
		offset = offset:Lerp(Vector3.new(0, targetY, 0), alpha)
		humanoid.CameraOffset = offset
		if overview or returning then
			distance += (targetDistance - distance) * alpha
			-- Raise max first, lower min first: never temporarily invert limits.
			player.CameraMinZoomDistance = 0.5
			player.CameraMaxZoomDistance = math.max(8, distance)
			player.CameraMinZoomDistance = math.max(8, distance)
			if returning and math.abs(distance - targetDistance) < 0.2 then
				returning = false
				player.CameraMinZoomDistance = 8
				player.CameraMaxZoomDistance = Config.Camera.MaxZoom
			end
		end
	end)
end
return TowerCamera
