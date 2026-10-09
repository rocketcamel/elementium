local ecs = require "../../../ReplicatedStorage/shared/ecs"

local world = ecs.world
local components = ecs.components

local query = world:query(components.Projectile, components.Velocity):cached()

local function evaluate_simple(
	projectile: ecs.SimpleProjectile,
	server_time: number
): Vector3
	local age = math.max(0, server_time - projectile.spawn_time)

	local displacement = projectile.initial_velocity * age
		+ 0.5 * projectile.acceleration * age * age

	return projectile.origin.Position + displacement
end

local function projectile(delta: number)
	local now = workspace:GetServerTimeNow()

	for entity, projectile, velocity in query do
		if projectile.kind == "simple" then
			local next_position = evaluate_simple(projectile, now)
			local previous_position =
				world:get(entity, components.PreviousPosition)

			if not previous_position then
				world:set(entity, components.PreviousPosition, next_position)
				continue
			end

			local displacement = next_position - previous_position
			local result = workspace:Raycast(previous_position, displacement)

			if result then
				world:delete(entity)
				continue
			else
				previous_position = next_position
			end

			world:set(entity, components.PreviousPosition, previous_position)
		elseif projectile.kind == "interpolated" then
			local replicated_position =
				world:get(entity, components.ReplicatedPosition)
			if not replicated_position then continue end

			local next_position = replicated_position.cframe + velocity * delta

			replicated_position.cframe = next_position
			replicated_position.server_time = workspace:GetServerTimeNow()

			world:set(
				entity,
				components.ReplicatedPosition,
				replicated_position
			)
		end
	end
end

return {
	phase = "pre_simulation",
	system = projectile,
}
