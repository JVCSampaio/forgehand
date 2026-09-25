-- Shop previews use the same primitives as the equipped base.
local Shared = game:GetService("ReplicatedStorage").Shared
local ItemBuilder = require(Shared.ItemBuilder)
local Preview = {}

function Preview.attach(parent: Instance, base)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "ActualBasePreview"
	viewport.Position = UDim2.fromOffset(0, 62)
	viewport.Size = UDim2.fromOffset(120, 86)
	viewport.BackgroundTransparency = 1
	viewport.ZIndex = 12
	viewport.Ambient = Color3.fromRGB(180, 180, 190)
	viewport.LightColor = Color3.new(1, 0.96, 0.85)
	local model = ItemBuilder.buildParts(base.Parts, base.Name)
	ItemBuilder.pivot(model, CFrame.identity)
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 38
	camera.CFrame = CFrame.lookAt(Vector3.new(4, 3, 5), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.Parent = parent
end

return Preview
