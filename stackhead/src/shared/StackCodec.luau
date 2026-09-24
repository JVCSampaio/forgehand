-- Stack contents replicate as a compact string attribute: "apl,cans,pigg".
-- Each code is a 3-char item id followed by an optional rarity suffix.

local StackCodec = {}

function StackCodec.code(itemId: string, suffix: string?): string
	return itemId .. (suffix or "")
end

function StackCodec.parse(code: string): (string, string)
	return string.sub(code, 1, 3), string.sub(code, 4)
end

function StackCodec.encode(codes: { string }): string
	return table.concat(codes, ",")
end

function StackCodec.decode(value: string?): { string }
	local codes = {}
	if value == nil or value == "" then
		return codes
	end
	for code in string.gmatch(value, "[^,]+") do
		table.insert(codes, code)
	end
	return codes
end

return StackCodec
