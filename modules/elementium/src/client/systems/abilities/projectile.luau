local ecs = require "../../../shared/ecs"

local world = ecs.world
local components = ecs.components

local query = world:query(components.Projectile)

local function projectile()
	for entity, projectile in query do
	end
end

return {
	phase = "post_simulation",
	system = projectile,
}
