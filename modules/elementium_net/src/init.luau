local Players = game:GetService "Players"
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local RunService = game:GetService "RunService"

export type Host = "server" | Player

export type Sender = Host

export type Target = {
	read to: Host,
	read id: number,
}

export type GenericActionData = {
	user: Sender,
	action: string,
}

export type EventInstance = {
	read server: RemoteEvent,
}

export type RemoteConnection<T> = {
	read id: number,
	read namespace: string,
	read identifier: string,

	callback: (Sender, T) -> (),
	events: { RBXScriptConnection },

	permission_data: (Sender, Target, T) -> GenericActionData,

	read set_permission_data: (
		RemoteConnection<T>,
		fn: (Sender, Target, T) -> GenericActionData
	) -> (),
	read on_event: (
		RemoteConnection<T>,
		fn: (sender: Sender, packet: T) -> ()
	) -> (),
	read disconnect: (RemoteConnection<T>) -> (),
}

export type Remote<T> = {
	read namespace: string,
	read identifier: string,

	permissions: {
		process: (
			sender: Sender,
			target: Target,
			packet: T,
			connection: RemoteConnection<T>
		) -> boolean,
	},

	read fire: (Remote<T>, target: Target, value: T) -> (),
	read connect: (Remote<T>, as: number) -> RemoteConnection<T>,
}

local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

local PACKET_TARGET = if IS_SERVER then "server" else Players.LocalPlayer

local REMOTES_LOCATION: Instance?

local AUTH: (any) -> boolean = function() return RunService:IsStudio() end

local function CHECK(data: GenericActionData)
	if data.user == "server" then return true end
	return AUTH(data)
end

local function get_event(namespace: string, identifier: string): EventInstance?
	local function create_remotes_location()
		if REMOTES_LOCATION then return end
		if IS_CLIENT then
			return ReplicatedStorage:WaitForChild "elementium_net" :: any
		end

		REMOTES_LOCATION = Instance.new "Folder"
		assert(REMOTES_LOCATION)
		REMOTES_LOCATION.Name = "elementium_net"
		REMOTES_LOCATION.Parent = ReplicatedStorage
	end

	local function ensure_remotes_location()
		if REMOTES_LOCATION then return end

		REMOTES_LOCATION = ReplicatedStorage:FindFirstChild "elementium_net"
		if not REMOTES_LOCATION then create_remotes_location() end
	end

	local function create_namespace(namespace: string)
		ensure_remotes_location()

		if not REMOTES_LOCATION then return end
		if REMOTES_LOCATION:FindFirstChild(namespace) then return end
		if IS_CLIENT then
			return ReplicatedStorage:WaitForChild(namespace) :: any
		end

		local folder = Instance.new "Folder"
		folder.Name = namespace
		folder.Parent = REMOTES_LOCATION
	end

	local function get_namespace(namespace: string): Folder?
		create_namespace(namespace)
		if not REMOTES_LOCATION then return nil end
		return REMOTES_LOCATION:FindFirstChild(namespace) :: Folder
	end

	local function create_event(
		namespace: string,
		identifier: string
	): EventInstance?
		if IS_CLIENT then return nil end

		local remote = Instance.new "Folder"
		local server = Instance.new "RemoteEvent"

		server.Name = "server"
		remote.Name = identifier

		server.Parent = remote
		remote.Parent = get_namespace(namespace)

		return remote :: any
	end

	local category = get_namespace(namespace)
	if not category then return nil end

	local remote = category:FindFirstChild(identifier)
	if not remote and IS_SERVER then
		return create_event(namespace, identifier)
	else
		return remote :: any
	end
end

local function set_permission_data<T>(
	connection: RemoteConnection<T>,
	fn: (
		sender: Sender,
		target: Target,
		value: T
	) -> GenericActionData
)
	connection.permission_data = fn
end

local function event_fire<T>(remote: Remote<T>, target: Target, value: T)
	local event = get_event(remote.namespace, remote.identifier)
	if not event then
		task.delay(0.1, event_fire, remote, target, value)
		return
	end
	assert(event)

	if target.to ~= "server" and PACKET_TARGET == "server" then
		event.server:FireClient(target.to, "server", target, value)
	else
		event.server:FireServer(target, value)
	end
end

local function event_on_event<T>(
	connection: RemoteConnection<T>,
	fn: (sender: Sender, packet: T) -> ()
)
	connection.callback = fn
end

local function event_disconnect<T>(connection: RemoteConnection<T>)
	for _, event in connection.events do
		event:Disconnect()
	end

	connection.events = {}
end

local function event_connect<T>(remote: Remote<T>, id: number): RemoteConnection<T>
	local event = get_event(remote.namespace, remote.identifier)
	local events = {}

	local connection: RemoteConnection<T> = {
		id = id,
		namespace = remote.namespace,
		identifier = remote.identifier,

		callback = function(sender: Sender, packet: T) print(sender, packet) end,
		events = events,

		permission_data = function(sender: Sender, target: Target, data: T)
			return { user = sender, action = "unknown" }
		end,

		set_permission_data = set_permission_data,
		on_event = event_on_event,
		disconnect = event_disconnect,
	}

	local function process_event(sender: Sender, target: Target, value: T)
		if target.to == PACKET_TARGET and target.id == connection.id then
			if
				not remote.permissions.process(
					sender,
					target,
					value,
					connection
				)
			then
				return
			end

			connection.callback(sender, value)
		end
	end

	if IS_SERVER and event then
		table.insert(events, event.server.OnServerEvent:Connect(process_event))
	elseif event then
		table.insert(events, event.server.OnClientEvent:Connect(process_event))
	end

	return connection
end

local function default_permission<T>(
	sender: Sender,
	target: Target,
	packet: T,
	connection: RemoteConnection<T>
)
	return CHECK(connection.permission_data(sender, target, packet))
end

local CACHED_EVENTS: { [string]: Remote<unknown> } = {}

local function event_create<T>(namespace: string, identifier: string): Remote<T>
	local key = `{namespace}:{identifier}`
	if CACHED_EVENTS[key] then return CACHED_EVENTS[key] end

	local remote: Remote<T> = {
		namespace = namespace,
		identifier = identifier,

		permissions = { process = default_permission },

		fire = event_fire,
		connect = event_connect,
	}

	return remote
end

return {
	set_auth = function(fn: (any) -> boolean) AUTH = fn end,
	event_create = event_create,
}
