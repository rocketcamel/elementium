local ReplicatedStorage = game:GetService "ReplicatedStorage"
local RunService = game:GetService "RunService"
local ecs = require "../ecs"
local jecs = require "../../roblox_packages/jecs"

local world = ecs.world
local components = ecs.components

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
	replicate_entity: RemoteEvent,
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

export type ComponentPacket = {
	name: string,
	data: unknown,
}

export type ReplicateEntityPacket = {
	entity_id: jecs.Entity,
	components: { ComponentPacket },
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
		replicate_entity = remote "replicate_entity",
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
		replicate_entity = remote "replicate_entity",
	}

	remotes = remote_index
	net.client.initialized = true
end

function net.server.replicate_entity(
	player: Player,
	entity_id: jecs.Entity,
	components: { [string]: jecs.Component }?
)
	assert_run_context "server"
	assert(net.server.initialized, "server not initialized")

	local component_packet = {}

	if components then
		for name, component in components do
			table.insert(component_packet, {
				name = name,
				data = component,
			})
		end
	end

	local packet: ReplicateEntityPacket = {
		entity_id = entity_id,
		components = component_packet,
	}

	print(`constructed packet for {player.Name}`, packet)

	remotes.replicate_entity:FireClient(player, packet)
end

function net.client.on_replicate_entity()
end

return net
