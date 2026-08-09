local ReplicatedStorage = game:GetService "ReplicatedStorage"
local RunService = game:GetService "RunService"
local jecs = require "../../roblox_packages/jecs"

local run_context: "server" | "client" = if RunService:IsServer()
	then "server"
	else "client"

local function assert_run_context(context: "server" | "client")
	assert(
		run_context == context,
		`expected run context: {context}, but got {run_context}`
	)
end

export type RemoteIndex = {
	replicate_snapshot: RemoteEvent,
}

local remotes: RemoteIndex

local net = {
	server = {
		initialized = false,
	},
	client = {
		initialized = false,
	},
}

export type Snapshot = {
	[string]: {
		set_ids: { jecs.Entity },
		set_values: { unknown },
	},
}

function net.server.create()
	assert_run_context "server"

	local net_folder = ReplicatedStorage:FindFirstChild "networking" :: Instance

	if net_folder == nil then
		net_folder = Instance.new "Folder"
		net_folder.Name = "networking"
		net_folder.Archivable = false
		net_folder.Parent = ReplicatedStorage
	end

	assert(net_folder)

	local function remote(name: string): RemoteEvent
		local instance = net_folder:FindFirstChild(name)
			or Instance.new "RemoteEvent"
		instance.Name = name
		instance.Archivable = false
		instance.Parent = net_folder

		return instance :: any
	end

	local remote_index: RemoteIndex = {
		replicate_snapshot = remote "replicate_snapshot",
	}

	remotes = remote_index
	net.server.initialized = true
end

function net.client.create()
	assert_run_context "client"

	local net_folder = ReplicatedStorage:WaitForChild "networking"

	local function remote(name: string): RemoteEvent
		return net_folder:WaitForChild(name) :: RemoteEvent
	end

	local remote_index: RemoteIndex = {
		replicate_snapshot = remote "replicate_snapshot",
	}

	remotes = remote_index
	net.client.initialized = true
end

function net.server.replicate_snapshot(player: Player, snapshot: unknown)
	assert_run_context "server"
	assert(net.server.initialized, "server not initialized")

	remotes.replicate_snapshot:FireClient(player, snapshot)
end

function net.client.on_replicate_snapshot(fn: (snapshot: Snapshot) -> ())
	assert_run_context "client"
	assert(net.client.initialized)

	remotes.replicate_snapshot.OnClientEvent:Connect(fn)
end

return net
