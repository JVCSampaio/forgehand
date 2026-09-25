-- Framing policy shared by the controller and headless tests.
local CameraFraming = {}
function CameraFraming.overview(height: number, aspect: number, verticalFov: number): (number, number)
	local span = math.max(12, height + 8)
	local vertical = math.rad(math.clamp(verticalFov, 30, 100)) / 2
	local horizontal = math.atan(math.tan(vertical) * math.max(0.3, aspect))
	local halfAngle = math.min(vertical, horizontal)
	return math.max(18, span * 0.65 / math.tan(halfAngle)), math.max(0, height * 0.5)
end
return CameraFraming
