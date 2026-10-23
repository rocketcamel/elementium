local Players = game:GetService "Players"

local profile_store = require "../roblox_server_packages/profile_store"

export type Meta = {
	permissions: { string },
}

export type Store = {
	shards: number,
	meta: Meta?,
}

type Display = Folder & {
	Shards: IntValue,
}

export type Session = {
	player: Player,
	profile: profile_store.Profile<Store>,
	listener: (Store) -> (),
	display: Display?,

	patch: <U...>(session: Session, (Store, U...) -> Store, U...) -> (),
	updated: (session: Session, (Store) -> ()) -> (),
}

local template = {
	shards = 200,
}

local store = profile_store.New("player_data", template)
local session_player_map: { [Player]: Session } = {}

local function noop() end

local function clone<T>(x: T)
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

local function get_session(player: Player): Session?
	return session_player_map[player]
end

local function run_updated(session: Session)
	local data = clone(session.profile.Data)
	session.listener(data)
end

local function updated(session: Session, fn: (Store) -> ())
	session.listener = fn
	run_updated(session)
end

local function patch<U...>(session: Session, fn: (Store, U...) -> Store, ...: U...)
	local data = clone(session.profile.Data)
	local result = fn(data, ...)

	session.profile.Data = result :: any
end

local function get_data(player: Player): Store
	local session = get_session(player)
	assert(session)

	return session.profile.Data
end

local function initialize(player: Player): Session?
	local profile = store:StartSessionAsync(
		`player_{player.User.Id}`,
		{ Cancel = function() return player.Parent ~= Players end }
	) :: profile_store.Profile<Store>

	if not profile then return player:Kick "data load fail" end

	profile:AddUserId(player.User.Id)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		session_player_map[player] = nil
		player:Kick "session ended"
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return nil
	end

	local session: Session = {
		player = player,
		profile = profile,
		listener = noop,

		patch = patch,
		updated = updated,
	}

	session_player_map[player] = session

	return session
end

local function cleanup(player: Player)
	local session = get_session(player)
	if not session then return end

	session.profile:EndSession()
end

local function create_display(session: Session)
	local data = session.profile.Data

	local folder = Instance.new "Folder"
	folder.Parent = session.player
	folder.Name = "leaderstats"

	local shards = Instance.new "IntValue"
	shards.Parent = folder
	shards.Name = "Shards"
	shards.Value = data.shards

	session.display = folder
end

local function update_display(session: Session)
	local data = session.profile.Data
	local display = session.display
	assert(display, "no display")

	display.Shards.Value = data.shards
end

return {
	initialize = initialize,
	cleanup = cleanup,
	get_session = get_session,
	get_data = get_data,
	display = create_display,
	update_display = update_display,
}
