local ReplicatedStorage = game:GetService "ReplicatedStorage" :: Storage

local ecs = require "../../../shared/ecs"
local jecs = require "../../../roblox_packages/jecs"
local util = require "../../../roblox_packages/util"

type Storage = ReplicatedStorage & {
	storage: Folder & {
		firey_blow: Model,
	},
}

local world = ecs.world
local components = ecs.components

local setup = world:entity()

local setup_query = world
	:query(components.Projectile, components.ReplicatedPosition)
	:without(setup)
	:cached()
local query = world
	:query(
		components.Projectile,
		components.ReplicatedPosition,
		components.Snapshots,
		components.Transform
	)
	:with(components.Renderable)
	:cached()

local function create_projectile(
	definition: ecs.ProjectileDefinition
): PVInstance
	local instance = ReplicatedStorage.storage[definition] :: PVInstance?
	assert(instance)

	return instance:Clone()
end

util.observer(world:query(components.ReplicatedPosition), function(entity)
	local snapshots =
		world:get(entity, components.Snapshots) :: { ecs.PositionSnapshot }
	local replicated_position = world:get(entity, components.ReplicatedPosition)
	if not replicated_position then return end

	if not snapshots then
		snapshots = {}
		world:set(entity, components.Snapshots, snapshots)
	end

	local latest = snapshots[#snapshots] :: ecs.PositionSnapshot?

	if latest and replicated_position.server_time <= latest.server_time then
		return
	end

	table.insert(snapshots, {
		cframe = replicated_position.cframe,
		server_time = replicated_position.server_time,
	})

	if #snapshots > 30 then table.remove(snapshots, 1) end
end)

local function interpolate_entity(
	entity: jecs.Entity,
	render_time: number,
	a: ecs.PositionSnapshot,
	b: ecs.PositionSnapshot
): CFrame
	if render_time <= a.server_time or not b then return a.cframe end

	local alpha = (render_time - a.server_time)
		/ (b.server_time - a.server_time)

	return a.cframe:Lerp(b.cframe, math.clamp(alpha, 0, 1))
end

local function projectile(delta: number)
	for entity, projectile, replicated_position in setup_query do
		local instance = create_projectile(projectile.definition)
		instance.Parent = workspace

		jecs.bulk_insert(world, entity, {
			components.Renderable,
			components.Transform,
			setup,
		}, { instance, replicated_position.cframe })
	end

	for entity, projectile, replicated_position, snapshots, transform in query do
		if projectile.kind ~= "simple" or #snapshots == 0 then continue end

		local render_time = workspace:GetServerTimeNow() - 0.1

		while #snapshots >= 2 and snapshots[2].server_time <= render_time do
			table.remove(snapshots, 1)
		end

		local a = snapshots[1]
		local b = snapshots[2]

		if render_time <= a.server_time or not b then continue end

		local result = interpolate_entity(entity, render_time, a, b)

		world:set(entity, components.Transform, result)
	end
end

return {
	phase = "pre_simulation",
	system = projectile,
}
