-- Minimal test runner for Lune: `lune run tests/runner.luau` from stackhead/.
-- Pure modules (no `game` access) are required directly from src/.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

-- Config modules use Roblox datatypes; Lune provides them.
Vector3 = roblox.Vector3
Color3 = roblox.Color3
CFrame = roblox.CFrame

local results = { passed = 0, failed = 0, failures = {} }
local currentSuite = ""

local T = {}

function T.describe(name: string, body: () -> ())
	currentSuite = name
	body()
end

function T.it(name: string, body: () -> ())
	local ok, err = pcall(body)
	if ok then
		results.passed += 1
	else
		results.failed += 1
		table.insert(results.failures, string.format("%s > %s\n    %s", currentSuite, name, tostring(err)))
	end
end

local function fmt(v)
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

function T.eq(actual, expected, label: string?)
	if actual ~= expected then
		error(string.format("%sexpected %s, got %s", if label then label .. ": " else "", fmt(expected), fmt(actual)), 2)
	end
end

function T.near(actual: number, expected: number, tolerance: number, label: string?)
	if math.abs(actual - expected) > tolerance then
		error(string.format("%sexpected %s ± %s, got %s", if label then label .. ": " else "", fmt(expected), fmt(tolerance), fmt(actual)), 2)
	end
end

function T.truthy(value, label: string?)
	if not value then
		error((label or "expected truthy value") .. ", got " .. fmt(value), 2)
	end
end

_G.T = T

local specs = {}
for _, name in fs.readDir("tests") do
	if string.match(name, "%.spec%.luau$") then
		table.insert(specs, name)
	end
end
table.sort(specs)

for _, name in specs do
	local path = "./" .. string.gsub(name, "%.luau$", "")
	local ok, err = pcall(require, path)
	if not ok then
		results.failed += 1
		table.insert(results.failures, name .. " failed to load: " .. tostring(err))
	end
end

for _, failure in results.failures do
	print("FAIL " .. failure)
end
print(string.format("%d passed, %d failed", results.passed, results.failed))
if results.failed > 0 then
	process.exit(1)
end
