-- Number formatting for UI. Big numbers are part of the fun, so they get
-- short suffixes instead of long digit strings.

local Format = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi" }

local function trimDecimals(text: string): string
	if string.find(text, ".", 1, true) then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return text
end

function Format.short(n: number): string
	n = math.floor(n)
	if math.abs(n) < 1000 then
		return tostring(n)
	end
	local index = 0
	local value = n
	while math.abs(value) >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	local text
	if math.abs(value) >= 100 then
		text = string.format("%d", math.floor(value))
	elseif math.abs(value) >= 10 then
		text = string.format("%.1f", math.floor(value * 10) / 10)
	else
		text = string.format("%.2f", math.floor(value * 100) / 100)
	end
	return trimDecimals(text) .. SUFFIXES[index]
end

function Format.commas(n: number): string
	local text = tostring(math.floor(n))
	local sign, digits = string.match(text, "^(-?)(%d+)$")
	if not digits then
		return text
	end
	local out = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1,")))
	out = string.gsub(out, "^,", "")
	return sign .. out
end

function Format.multiplier(m: number): string
	return "x" .. trimDecimals(string.format("%.2f", m))
end

function Format.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local m = seconds // 60
	local s = seconds % 60
	return string.format("%d:%02d", m, s)
end

return Format
