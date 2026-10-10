local ecs = require "../../shared/ecs"
local jecs = require "../../roblox_packages/jecs"
local net = require "../../shared/ecs/net"
local util = require "../../shared/util"

local world = ecs.world

local components = {}

for _, component in ecs.components :: any do
	components[tostring(component)] = component
end

local server_entity_map = {}

type Snapshot = net.Snapshot

local function is_component(id: jecs.Id): (string | false)?
	return world:contains(id) and world:get(id, jecs.Name)
end

local function ensure_entity(server_id: jecs.Entity): jecs.Entity
	local id = server_entity_map[server_id]

	if not id then
		if is_component(server_id) then
			id = server_id
		else
			id = world:entity()
			server_entity_map[server_id] = id
		end
	end

	return id
end

local function deserialize_pair(
	relation: jecs.Entity,
	target: jecs.Entity
): jecs.Entity
	local relation_entity = ensure_entity(relation)
	local target_entity = ensure_entity(target)

	return jecs.pair(relation_entity, target_entity)
end

local function networking()
	local snapshots = {}
	local n = 0

	net.client.on_replicate_snapshot(function(snapshot)
		table.insert(snapshots, snapshot)
		n += 1
	end)

	net.client.on_entity_delete(function(id)
		local client_id = server_entity_map[id] :: jecs.Entity
		if not client_id or not world:contains(client_id) then return end
		world:delete(client_id)
	end)

	local function iter(): ...Snapshot
		if n == 0 then return end
		n -= 1

		return table.remove(snapshots, 1) :: any
	end

	return function()
		for snapshot in iter do
			for component_id, storage in snapshot do
				local component = (tonumber(component_id) :: any) :: jecs.Entity

				if jecs.IS_PAIR(component) and storage.pair then
					component =
						deserialize_pair(storage.relation, storage.target)
				else
					component = ensure_entity(component)
				end

				if storage.set and storage.values then
					for index, id in storage.set do
						local client_id = ensure_entity(id)
						world:set(
							client_id,
							component,
							storage.values[index] :: any
						)
					end
				end

				if storage.removed then
					for _, id in storage.removed do
						local client_id = server_entity_map[id] :: jecs.Entity

						if client_id and world:contains(client_id) then
							world:remove(client_id, component)
							server_entity_map[id] = nil
						end
					end
				end
			end
		end
	end
end

return {
	name = "networking",
	phase = "post_simulation",
	system = networking(),
}
