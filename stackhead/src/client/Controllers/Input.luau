-- Dash (Q / button / gamepad X) and glue (G / button / gamepad Y).
-- The dash moves the character locally for responsiveness; the server only
-- uses its own record of the dash to decide bumps.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)
local Audio = require(script.Parent.Audio)
local ClientState = require(script.Parent.ClientState)
local HUD = require(script.Parent.HUD)
local UIKit = require(script.Parent.UIKit)

local Input = {}

local player = Players.LocalPlayer
local lastDash = -math.huge

local function dash()
	local now = os.clock()
	if now - lastDash < GameConfig.Dash.Cooldown then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	lastDash = now
	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = root.CFrame.LookVector
	end
	direction = Vector3.new(direction.X, 0, direction.Z).Unit

	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.PlaneVelocity = Vector2.new(direction.X, direction.Z) * GameConfig.Dash.Impulse
	velocity.MaxForce = root.AssemblyMass * 4000
	velocity.Parent = root
	task.delay(0.22, function()
		velocity:Destroy()
		attachment:Destroy()
	end)

	Remotes.Dash:FireServer()
	Audio.play("Dash")
	local button = HUD.dashButton()
	UIKit.pop(button, 0.2)
	button.BackgroundColor3 = UIKit.Colors.Disabled
	task.delay(GameConfig.Dash.Cooldown, function()
		button.BackgroundColor3 = UIKit.Colors.Blue
	end)
end

local function toggleGlue()
	local data = ClientState.Data
	if not data then
		return
	end
	local armed = ClientState.glueArmed()
	if not armed and data.Glue <= 0 then
		HUD.toast("No glue left! Get more from daily rewards and records.", "Error")
		Audio.play("Error")
		return
	end
	Audio.play("Glue", if armed then 0.8 else 1.2)
	Remotes.UseGlue:FireServer(not armed)
end

function Input.init()
	HUD.dashButton().Activated:Connect(dash)
	HUD.glueButton().Activated:Connect(toggleGlue)
	ContextActionService:BindAction("StackheadDash", function(_, state)
		if state == Enum.UserInputState.Begin then
			dash()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
	ContextActionService:BindAction("StackheadGlue", function(_, state)
		if state == Enum.UserInputState.Begin then
			toggleGlue()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.G, Enum.KeyCode.ButtonY)
end

return Input
