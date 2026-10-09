local ReplicatedStorage = game:GetService "ReplicatedStorage"
local RunService = game:GetService "RunService"

local ecs = require "../ecs"
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

export type Snapshot = {
	[string]: {
		set: { jecs.Entity }?,
		values: { unknown }?,
		removed: { jecs.Entity }?,
		pair: true,
		relation: jecs.Entity,
		target: jecs.Entity,
	} | {
		set: { jecs.Entity }?,
		values: { unknown }?,
		removed: { jecs.Entity }?,
		pair: false,
	},
}

export type RemoteIndex = {
	replicate_snapshot: RemoteEvent,
	report_movement: RemoteEvent,
	report_ability: RemoteEvent,
}

export type ReportAbilityReplyPacket =
	{
		status: "ok",
		kind: ecs.AbilityKind,
	}
	| {
		status: "err",
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
		report_movement = remote "report_movement",
		report_ability = remote "report_ability",
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
		report_movement = remote "report_movement",
		report_ability = remote "report_ability",
	}

	remotes = remote_index
	net.client.initialized = true
end

function net.server.replicate_snapshot(player: Player, snapshot: unknown)
	assert_run_context "server"
	assert(net.server.initialized, "server not initialized")

	remotes.replicate_snapshot:FireClient(player, snapshot)
end

function net.server.on_movement_report(fn: (
	player: Player,
	ability: ecs.MovementKind
) -> ())
	assert_run_context "server"
	assert(net.server.initialized)

	remotes.report_movement.OnServerEvent:Connect(fn)
end

function net.server.on_ability_report(fn: (
	player: Player,
	kind: ecs.AbilityKind,
	target: Vector3
) -> ())
	assert_run_context "server"
	assert(net.server.initialized)

	remotes.report_ability.OnServerEvent:Connect(fn)
end

function net.server.report_successful_ability(
	player: Player,
	kind: ecs.AbilityKind
)
	assert_run_context "server"
	assert(net.server.initialized)

	local packet: ReportAbilityReplyPacket = {
		status = "ok",
		kind = kind,
	}

	remotes.report_ability:FireClient(player, packet)
end

function net.client.on_ability_report_reply(fn: (
	info: ReportAbilityReplyPacket
) -> ())
	assert_run_context "client"
	assert(net.client.initialized)

	remotes.report_ability.OnClientEvent:Connect(fn)
end

function net.client.report_ability(kind: ecs.AbilityKind, direction: Vector3)
	assert_run_context "client"
	assert(net.client.initialized)

	remotes.report_ability:FireServer(kind, direction)
end

function net.client.on_replicate_snapshot(fn: (snapshot: Snapshot) -> ())
	assert_run_context "client"
	assert(net.client.initialized)

	remotes.replicate_snapshot.OnClientEvent:Connect(fn)
end

function net.client.report_movement(ability: ecs.MovementKind)
	assert_run_context "client"
	assert(net.client.initialized)

	remotes.report_movement:FireServer(ability)
end

return net
