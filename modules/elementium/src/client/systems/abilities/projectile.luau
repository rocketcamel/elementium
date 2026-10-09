local ReplicatedStorage = game:GetService "ReplicatedStorage" :: Storage
local Workspace = game:GetService "Workspace" :: WorkspaceStorage

local abilities = require "../../../shared/abilities"
local ecs = require "../../../shared/ecs"
local jecs = require "../../../roblox_packages/jecs"
local util = require "../../../roblox_packages/util"

type Storage = ReplicatedStorage & {
	storage: Folder & {
		firey_blow: Model,
	},
}

type WorkspaceStorage = Workspace & {
	projectiles: Folder,
}

local world = ecs.world
local components = ecs.components

local setup = world:entity()

local setup_query = world:query(components.Projectile):without(setup):cached()
local query = world
	:query(components.Projectile, components.Renderable)
	:with(components.Transform)
	:cached()

world:set(components.Projectile, jecs.OnRemove, function(entity, id)
	local projectile = world:get(entity, components.Projectile)
	local renderable = world:get(entity, components.Renderable)
	if not projectile or not renderable then return end

	local definition = abilities[projectile.definition]
	definition.finish(renderable)
end)

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

local function evaluate_simple(
	projectile: ecs.SimpleProjectile,
	render_time: number
): CFrame
	local age = math.max(0, render_time - projectile.spawn_time)

	local displacement = projectile.initial_velocity * age
		+ 0.5 * projectile.acceleration * age * age

	return projectile.origin + displacement
end

local function evaluate_interpolated(
	snapshots: { ecs.PositionSnapshot },
	render_time: number
): CFrame
	while #snapshots >= 2 and snapshots[2].server_time <= render_time do
		table.remove(snapshots, 1)
	end

	local a = snapshots[1]
	local b = snapshots[2]

	if render_time <= a.server_time or not b then return a.cframe end

	local alpha = (render_time - a.server_time)
		/ (b.server_time - a.server_time)

	return a.cframe:Lerp(b.cframe, math.clamp(alpha, 0, 1))
end

local function evaluate_collision(
	entity: jecs.Entity,
	next_position: Vector3,
	renderable: PVInstance
): RaycastResult?
	local previous_position = world:get(entity, components.PreviousPosition)
	local params = world:get(entity, components.Raycast)

	if not params then
		params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { Workspace.projectiles }
		world:set(entity, components.Raycast, params)
	end

	if not previous_position then
		world:set(entity, components.PreviousPosition, next_position)
		return nil
	end

	local displacement = next_position - previous_position
	local collision = workspace:Raycast(previous_position, displacement, params)

	return collision
end

local function projectile(delta: number)
	for entity, projectile in setup_query do
		local instance = create_projectile(projectile.definition)
		instance.Parent = Workspace.projectiles

		local result
		local now = workspace:GetServerTimeNow()

		if projectile.kind == "simple" then
			result = evaluate_simple(projectile, now)
		elseif projectile.kind == "interpolated" then
			local replicated_position =
				world:get(entity, components.ReplicatedPosition)
			if not replicated_position then continue end

			result = replicated_position.cframe
		end

		jecs.bulk_insert(world, entity, {
			components.Renderable,
			components.Transform,
			setup,
		}, { instance, result })
	end

	for entity, projectile, renderable in query do
		local result: CFrame
		local now = workspace:GetServerTimeNow()

		if projectile.kind == "simple" then
			result = evaluate_simple(projectile, now)
		elseif projectile.kind == "interpolated" then
			local snapshots = world:get(entity, components.Snapshots)

			if snapshots then
				result = evaluate_interpolated(snapshots, now - 0.1)
			end
		end

		if result then world:set(entity, components.Transform, result) end

		if evaluate_collision(entity, result.Position, renderable) then
			world:delete(entity)
		end
	end
end

return {
	phase = "pre_simulation",
	system = projectile,
}
