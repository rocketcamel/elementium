local DataStoreService = game:GetService "DataStoreService"

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

	commit: (session: Session<T>) -> (),
	get_player_permissions: (session: Session<T>) -> { string }?,
}

local session_player_map = {}

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
			and store.lock.owner == game.JobId
		then true
		else false
end

local function lock_store<T>(session: Session<T>)
	local n = 0

	local function attempt()
		n += 1

		return session.store:UpdateAsync(
			session.key,
			function(store: StoredData<Store>?)
				if not store then store = default_storage() end
				assert(store)

				if store.lock and store.lock.expires > os.time() and n <= 5 then
					return
				end

				store.lock = {
					owner = game.JobId,
					expires = os.time() + 5 * 60,
				}

				return store
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

	print("updated store", store)
end

local function unlock_store<T>(session: Session<T>)
	session.store:UpdateAsync(session.key, function(store: StoredData<Store>)
		if not store.lock or store.lock.owner ~= game.JobId then return end

		store.data = session.data
		store.lock = nil
		return store
	end)
end

local function commit_store<T>(session: Session<T>)
	session.store:UpdateAsync(session.key, function(store: StoredData<Store>)
		store.data = session.data
		return store
	end)
end

local function get_session(player: Player): Session<Store>
	return session_player_map[player.User.Id]
end

local function get_player_permissions(session: Session<Store>): { string }?
	local meta = session.data.meta
	if not meta then return nil end

	return meta.permissions
end

local function initialize(player: Player): Session<Store>
	local key = `player_store#{player.User.Id}`
	local store = DataStoreService:GetDataStore "player_storage"

	local session: Session<Store> = {
		key = key,
		store = store,
		data = { shards = 0 },
		commit = commit_store,
		get_player_permissions = get_player_permissions,
	}

	lock_store(session)
	session_player_map[player.User.Id] = session

	return session
end

local function cleanup(player: Player)
	local session = session_player_map[player.User.Id]

	if session then unlock_store(session :: any) end
end

return {
	initialize = initialize,
	cleanup = cleanup,

	get_session = get_session,
}
