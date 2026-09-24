-- Session-locked persistence on top of any object exposing
-- UpdateAsync(key, transform) (a DataStore, or a mock in tests).
--
-- Stored record: { Data = profile, Lock = { JobId, Time }?, SavedAt }
-- * load() takes the lock; it refuses while another live server holds it,
--   which prevents two servers from writing the same profile (item/coin dupes).
-- * save() only writes while this server still owns the lock.
-- Pure: clock, wait and job id are injected.

local SessionStore = {}
SessionStore.__index = SessionStore

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

export type Options = {
	store: any,
	jobId: string,
	now: () -> number,
	wait: (number) -> (),
	lockTimeout: number?,
	loadAttempts: number?,
	saveAttempts: number?,
	warn: ((string) -> ())?,
}

function SessionStore.new(options: Options)
	return setmetatable({
		store = options.store,
		jobId = options.jobId,
		now = options.now,
		wait = options.wait,
		lockTimeout = options.lockTimeout or 1800,
		loadAttempts = options.loadAttempts or 6,
		saveAttempts = options.saveAttempts or 4,
		warn = options.warn or function() end,
	}, SessionStore)
end

-- Returns (true, data | nil) on success (nil = brand new player),
-- (false, reason) when the profile could not be locked.
function SessionStore:load(key: string): (boolean, any)
	local lastReason = "unknown"
	for attempt = 1, self.loadAttempts do
		local lockedByOther = false
		local loaded = nil
		local ok, err = pcall(function()
			self.store:UpdateAsync(key, function(record)
				lockedByOther = false
				loaded = nil
				record = if type(record) == "table" then record else {}
				local lock = record.Lock
				if
					type(lock) == "table"
					and lock.JobId ~= self.jobId
					and type(lock.Time) == "number"
					and self.now() - lock.Time < self.lockTimeout
				then
					lockedByOther = true
					return nil
				end
				record.Lock = { JobId = self.jobId, Time = self.now() }
				loaded = record
				return record
			end)
		end)
		if ok and loaded then
			return true, deepCopy(loaded.Data)
		end
		lastReason = if ok then (if lockedByOther then "locked" else "cancelled") else tostring(err)
		self.warn(string.format("load %s attempt %d failed: %s", key, attempt, lastReason))
		if attempt < self.loadAttempts then
			self.wait(math.min(2 ^ attempt, 10))
		end
	end
	return false, lastReason
end

-- Writes data. release=true also drops the lock (player leaving).
-- Returns (true) or (false, reason). "lost-lock" means another server took
-- over and nothing was written.
function SessionStore:save(key: string, data: any, release: boolean): (boolean, string?)
	local snapshot = deepCopy(data)
	local lastReason = "unknown"
	for attempt = 1, self.saveAttempts do
		local lostLock = false
		local ok, err = pcall(function()
			self.store:UpdateAsync(key, function(record)
				lostLock = false
				record = if type(record) == "table" then record else {}
				local lock = record.Lock
				if type(lock) == "table" and lock.JobId ~= self.jobId then
					lostLock = true
					return nil
				end
				record.Data = snapshot
				record.SavedAt = self.now()
				record.Lock = if release then nil else { JobId = self.jobId, Time = self.now() }
				return record
			end)
		end)
		if ok and not lostLock then
			return true
		end
		if lostLock then
			self.warn(string.format("save %s skipped: lock owned by another server", key))
			return false, "lost-lock"
		end
		lastReason = tostring(err)
		self.warn(string.format("save %s attempt %d failed: %s", key, attempt, lastReason))
		if attempt < self.saveAttempts then
			self.wait(math.min(2 ^ attempt, 8))
		end
	end
	return false, lastReason
end

return SessionStore
