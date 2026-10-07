local ecs = require "../../../ReplicatedStorage/shared/ecs"

local world = ecs.world
local components = ecs.components

local query = world
	:query(
		components.Projectile,
		components.Velocity,
		components.ReplicatedPosition
	)
	:cached()

local function projectile(delta: number)
	for entity, projectile, velocity, replicated_position in query do
		if projectile.kind ~= "simple" then continue end

		local next_position = replicated_position.cframe + velocity * delta

		replicated_position.cframe = next_position
		replicated_position.server_time = workspace:GetServerTimeNow()

		world:set(entity, components.ReplicatedPosition, replicated_position)
	end
end

return {
	phase = "pre_simulation",
	system = projectile,
}
