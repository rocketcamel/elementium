local ecs = require "../../shared/ecs"

local world = ecs.world
local components = ecs.components

local query = world:query(components.Renderable, components.Transform):cached()

local function render()
	for entity, renderable, transform in query do
		renderable:PivotTo(transform)
	end
end

return {
	phase = "post_simulation",
	system = render,
}
