-- In-memory stand-in for a DataStore. Used in Studio when API access is
-- disabled, and by the unit tests. failNext lets tests inject errors.

local MemoryStore = {}
MemoryStore.__index = MemoryStore

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[deepCopy(k)] = deepCopy(v)
	end
	return copy
end

function MemoryStore.new()
	return setmetatable({ records = {}, failNext = 0, writes = 0 }, MemoryStore)
end

function MemoryStore:UpdateAsync(key: string, transform)
	if self.failNext > 0 then
		self.failNext -= 1
		error("injected DataStore failure")
	end
	local result = transform(deepCopy(self.records[key]))
	if result ~= nil then
		self.records[key] = deepCopy(result)
		self.writes += 1
	end
	return result
end

function MemoryStore:GetAsync(key: string)
	return deepCopy(self.records[key])
end

return MemoryStore
