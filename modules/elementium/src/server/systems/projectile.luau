local ecs = require "../../../ReplicatedStorage/shared/ecs"

local world = ecs.world
local components = ecs.components

local query = world:query(components.Projectile, components.Velocity):cached()

local function evaluate_simple(
	projectile: ecs.SimpleProjectile,
	server_time: number
): CFrame
	local age = math.max(0, server_time - projectile.spawn_time)

	local displacement = projectile.initial_velocity * age
		+ 0.5 * projectile.acceleration * age * age

	return projectile.origin + displacement
end

local function projectile(delta: number)
	local now = workspace:GetServerTimeNow()

	for entity, projectile, velocity in query do
		if projectile.kind == "simple" then
			local result = evaluate_simple(projectile, now)
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
