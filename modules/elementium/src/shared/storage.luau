local DataStoreService = game:GetService "DataStoreService"

local CURRENT_REVISION = 1
local EXPONENT_BACKOFF = 2
local MAX_BACKOFF = 30

export type Store = {
	shards: number,
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
	local function attempt()
		return session.store:UpdateAsync(
			session.key,
			function(store: StoredData<Store>?)
				if not store then store = default_storage() end
				assert(store)

				if store.lock and store.lock.expires > os.time() then return end

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

local function initialize(player: Player): Session<Store>
	local key = `player_store#{player.User.Id}`
	local store = DataStoreService:GetDataStore "player_storage"

	local session: Session<Store> = {
		key = key,
		store = store,
		data = { shards = 0 },
		commit = commit_store,
	}

	lock_store(session)
	session_player_map[player.User.Id] = session

	return session
end

local function cleanup(player: Player)
	local session = session_player_map[player.User.Id]
	unlock_store(session)
end

return {
	initialize = initialize,
	cleanup = cleanup,
}
