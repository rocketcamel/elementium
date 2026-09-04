local task = require "../shared/task"

local CURRENT_REVISION = 1
local EXPONENT_BACKOFF = 2
local MAX_BACKOFF = 30

export type PlayerMeta = {
	permissions: { string },
}

export type Store = {
	shards: number,
	meta: PlayerMeta?,
}

export type StoredData<T> = {
	rev: number,
	lock: {
		owner: string,
		expires: number,
	}?,

	data: T,
}

export type Session<T> = {
	key: string,
	store: DataStore,
	data: T,
	listener: (T) -> (),

	_: {
		locked: boolean,
		attempt: number,
	},

	commit: (session: Session<T>) -> (),
	updated: (session: Session<T>, fn: (T) -> ()) -> (),
	patch: <U...>(session: Session<T>, (T, U...) -> T, U...) -> (),
	lock: (session: Session<T>) -> (),
	unlock: (session: Session<T>) -> (),
	get_player_permissions: (session: Session<T>) -> { string }?,
}

local session_player_map = {}
local DataStoreService = if game
	then game:GetService "DataStoreService"
	else nil

local owner = if game then game.JobId else tostring(math.random(1, 100000))

local function noop() end

local function clone<T>(x: T): T
	if typeof(x) == "table" then
		local t = table.clone(x) :: any

		for k, v in t do
			if typeof(k) == "table" or typeof(v) == "table" then
				t[clone(k)] = clone(v)
			end
		end

		return t
	else
		return x
	end
end

local MIGRATIONS: { [number]: (Store) -> Store } = {}

local function migrate_store(store: StoredData<Store>): StoredData<Store>
	while store.rev < CURRENT_REVISION do
		local migrate = MIGRATIONS[store.rev]
		assert(migrate, `missing migration for rev {store.rev}`)

		store.data = migrate(store.data)
		store.rev += 1

		print("applied migration", store.rev)
	end

	return store
end

local function default_storage(): StoredData<Store>
	return {
		rev = CURRENT_REVISION,
		lock = nil,
		data = { shards = 200 },
	}
end

local function lock_taken<T>(store: StoredData<T>): boolean
	return if store
			and store.lock
			and store.lock.owner == owner
		then true
		else false
end

local function lock<T>(session: Session<T>)
	local n = 0

	local function attempt()
		n += 1
		session._.attempt = n

		return session.store:UpdateAsync(
			session.key,
			function(store: StoredData<Store>?)
				if not store then store = default_storage() end
				assert(store)

				if store.lock and store.lock.expires > os.time() and n <= 5 then
					return
				end

				store.lock = {
					owner = owner,
					expires = os.time() + 5 * 60,
				}

				local data = migrate_store(store)

				return data
			end
		) :: StoredData<Store>
	end

	local store = attempt()

	if not lock_taken(store) then
		local backoff = 0.5

		repeat
			task.wait(math.min(backoff * EXPONENT_BACKOFF, MAX_BACKOFF))
			backoff *= EXPONENT_BACKOFF
			store = attempt()
		until lock_taken(store)
	end

	session.data = store.data
	session._.locked = true

	print("updated store", store)
end

local function unlock<T>(session: Session<T>)
	session.store:UpdateAsync(session.key, function(store: StoredData<Store>)
		if not store.lock or store.lock.owner ~= owner then return end

		store.data = session.data
		store.lock = nil

		session._.locked = false
		return store
	end)
end

local function commit_store<T>(session: Session<T>)
	session.store:UpdateAsync(session.key, function(store: StoredData<Store>)
		store.data = session.data
		return store
	end)
end

local function run_updated<T>(session: Session<T>)
	local data = session.data
	local copy = clone(data)
	local fn = session.listener

	fn(copy)
end

local function updated<T>(session: Session<T>, fn: (T) -> ())
	session.listener = fn
	run_updated(session)
end

local function patch<T, U...>(session: Session<T>, fn: (T, U...) -> T, ...: U...)
	local data = fn(session.data, ...)
	session.data = data

	run_updated(session)
end

local function get_session(player: Player): Session<Store>?
	return session_player_map[player.User.Id]
end

local function get_player_permissions(session: Session<Store>): { string }?
	local meta = session.data.meta
	if not meta then return nil end

	return meta.permissions
end

local function wrap<T>(fn: (session: Session<T>) -> ())
	return function(session: Session<T>) task.spawn(fn, session) end
end

local function initialize(player: Player): Session<Store>
	assert(DataStoreService)

	local key = `player_store#{player.User.Id}`
	local store = DataStoreService:GetDataStore "player_storage"

	local session: Session<Store> = {
		key = key,
		store = store,
		data = { shards = 0 },
		listener = noop,

		_ = { locked = false, attempt = 0 },

		commit = commit_store,
		updated = updated,
		patch = patch,
		lock = lock,
		unlock = unlock,
		get_player_permissions = get_player_permissions,
	}

	session:lock()
	session_player_map[player.User.Id] = session

	return session
end

local function initialize_raw(id: number): Session<Store>
	assert(DataStoreService)

	local key = `player_store#{id}`
	local store = DataStoreService:GetDataStore "player_storage"

	local session: Session<Store> = {
		key = key,
		store = store,
		data = { shards = 0 },
		listener = noop,

		_ = { locked = false, attempt = 0 },

		commit = commit_store,
		updated = updated,
		patch = patch,
		lock = noop,
		unlock = noop,
		get_player_permissions = get_player_permissions,
	}

	session.lock = wrap(lock)
	session.unlock = wrap(unlock)

	return session
end

local function cleanup(player: Player)
	local session = session_player_map[player.User.Id]

	if session then session:unlock() end
end

return {
	initialize = initialize,
	initialize_raw = initialize_raw,
	cleanup = cleanup,

	get_session = get_session,

	mock = function(value) DataStoreService = value end,
	owner = function(value) owner = value end,
}
