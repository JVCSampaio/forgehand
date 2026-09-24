-- Tiny helpers for building UI in code, plus the shared visual style.

local UIKit = {}

UIKit.Colors = {
	Panel = Color3.fromRGB(28, 30, 48),
	PanelLight = Color3.fromRGB(46, 50, 76),
	Text = Color3.fromRGB(255, 255, 255),
	SubText = Color3.fromRGB(190, 195, 220),
	Gold = Color3.fromRGB(255, 205, 60),
	Green = Color3.fromRGB(80, 210, 110),
	Red = Color3.fromRGB(240, 80, 80),
	Blue = Color3.fromRGB(70, 150, 255),
	Purple = Color3.fromRGB(170, 100, 255),
	Disabled = Color3.fromRGB(90, 92, 110),
	Stroke = Color3.fromRGB(12, 12, 24),
}

UIKit.Fonts = {
	Display = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamBold,
}

-- create("Frame", { Size = ..., Parent = ... }, { children })
function UIKit.create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UIKit.corner(radius: number?): UICorner
	return UIKit.create("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function UIKit.stroke(thickness: number?, color: Color3?): UIStroke
	return UIKit.create("UIStroke", {
		Thickness = thickness or 2,
		Color = color or UIKit.Colors.Stroke,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function UIKit.padding(px: number): UIPadding
	return UIKit.create("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
	})
end

function UIKit.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = UIKit.Fonts.Display,
		TextColor3 = UIKit.Colors.Text,
		TextScaled = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	local label = UIKit.create("TextLabel", defaults)
	UIKit.stroke(2).Parent = label
	return label
end

function UIKit.button(props: { [string]: any }): TextButton
	local defaults = {
		AutoButtonColor = true,
		BackgroundColor3 = UIKit.Colors.Blue,
		Font = UIKit.Fonts.Display,
		TextColor3 = UIKit.Colors.Text,
		TextScaled = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	local button = UIKit.create("TextButton", defaults)
	UIKit.corner(14).Parent = button
	local stroke = UIKit.create("UIStroke", {
		Thickness = 3,
		Color = UIKit.Colors.Stroke,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	stroke.Parent = button
	UIKit.create("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
	}).Parent = button
	return button
end

function UIKit.textLimit(parent: Instance, max: number)
	UIKit.create("UITextSizeConstraint", { MaxTextSize = max, Parent = parent })
end

-- Quick scale "pop" feedback.
function UIKit.pop(guiObject: GuiObject, amount: number?)
	local scale = guiObject:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = UIKit.create("UIScale", { Parent = guiObject })
	end
	local TweenService = game:GetService("TweenService")
	scale.Scale = 1 + (amount or 0.15)
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

return UIKit
