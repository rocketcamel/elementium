local ecs = require "../../shared/ecs"
local net = require "../../shared/ecs/net"

local world = ecs.world

local components = {}

for _, component in ecs.components :: any do
	components[tostring(component)] = component
end

local server_entity_map = {}

type Snapshot = net.Snapshot

local function networking()
	local snapshots = {}
	local n = 0

	net.client.on_replicate_snapshot(function(snapshot)
		table.insert(snapshots, snapshot)
		n += 1
	end)

	local function iter(): ...Snapshot
		if n == 0 then return end
		n -= 1

		return table.remove(snapshots, 1) :: any
	end

	return function()
		for snapshot in iter do
			for component_id, storage in snapshot do
				local component = components[component_id]

				for index, id in storage.set_ids do
					local client_id = server_entity_map[id]

					if not client_id then
						local entity = world:entity()
						server_entity_map[id] = entity
						client_id = entity
					end

					world:set(client_id, component, storage.set_values[index])
				end
			end
		end
	end
end

return {
	phase = "post_simulation",
	system = networking(),
}
