local ecs = require "../../shared/ecs"

local world = ecs.world
local components = ecs.components

local query = world:query(components.Cooldown):cached()

local function cooldown()
	for entity, cooldown in query do
		if (cooldown.finish - os.clock()) <= 0 then world:delete(entity) end
	end
end

return {
	phase = "post_simulation",
	system = cooldown,
}
