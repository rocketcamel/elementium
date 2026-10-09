local Players = game:GetService "Players"
local ecs = require "../../../ReplicatedStorage/shared/ecs"
local jecs = require "../../../ReplicatedStorage/roblox_packages/jecs"
local net = require "../../../ReplicatedStorage/shared/ecs/net"
local util = require "../../../ReplicatedStorage/shared/util"

local world = ecs.world
local components = ecs.components

local storages: { [jecs.Entity]: { [jecs.Entity]: unknown } } = {}

local function get_storage(id: jecs.Entity)
	local storage = storages[id]
	if not storage then
		storage = {}
		storages[id] = storage
	end

	return storage
end

local function net_send()
	local networked_components = {}
	local networked_pairs = {}

	for component in world:each(components.Networked) do
		local name = world:get(component, jecs.Name)
		assert(name)

		storages[component] = {}
		networked_components[name] = component
	end

	for relation in world:each(components.NetworkedPair) do
		local name = world:get(relation, jecs.Name)
		assert(name)
		table.insert(networked_pairs, relation)
	end

	for name, component in networked_components do
		local storage = storages[component]

		if jecs.is_tag(world, component) then
			world:added(
				component,
				function(entity, _, data) storage[entity] = true end
			)
		else
			world:added(
				component,
				function(entity, _, data) storage[entity] = data end
			)

			world:changed(
				component,
				function(entity, _, data) storage[entity] = data end
			)
		end

		world:removed(
			component,
			function(entity) storage[entity] = "jecs.Remove" end
		)
	end

	for _, relation in networked_pairs do
		world:added(relation, function(entity, id, value)
			local is_tag = jecs.is_tag(world, id)
			local storage = get_storage(id)

			if is_tag then
				storage[entity] = true
			else
				storage[entity] = value
			end
		end)

		world:changed(relation, function(entity, id, value)
			local is_tag = jecs.is_tag(world, id)
			if is_tag then return end
			local storage = get_storage(id)

			storage[entity] = value
		end)

		world:removed(relation, function(entity, id)
			local storage = get_storage(id)
			storage[entity] = "jecs.Remove"
		end)
	end

	local players_added = util.collect(Players.PlayerAdded)

	return function()
		local initial_snapshot = {}

		for player in players_added do
			for component, storage in storages do
				local set_ids = {}
				local set_values = {}
				local set_index = 0

				local query = world:query(component)
				local is_tag = jecs.is_tag(world, component)

				for _, archetype in query:archetypes() do
					local entities = archetype.entities
					local entities_len = #entities

					table.move(
						entities,
						1,
						entities_len,
						set_index + 1,
						set_ids
					)

					if not is_tag then
						local column = archetype.columns_map[component]
						table.move(
							column,
							1,
							entities_len,
							set_index + 1,
							set_values
						)
					end

					set_index += entities_len
				end

				local map = {
					set = set_ids,
					values = set_values,
				}

				if jecs.IS_PAIR(component) then
					map.relation = jecs.pair_first(world, component)
					map.target = jecs.pair_second(world, component)
					map.pair = true
				end

				initial_snapshot[tostring(component)] = map
			end

			net.server.replicate_snapshot(player, initial_snapshot)
		end

		local snapshot = {}

		for component, storage in storages do
			local set_ids = {}
			local set_values = {}
			local removed_ids = {}
			local set_index = 0
			local remove_index = 0

			local is_tag = jecs.is_tag(world, component)

			for entity, value in storage do
				if value ~= "jecs.Remove" then
					set_index += 1
					set_ids[set_index] = entity
					set_values[set_index] = if is_tag then 0 else value
				else
					remove_index += 1
					removed_ids[remove_index] = entity
				end
			end

			table.clear(storage)

			local dirty = if set_index > 0 or remove_index > 0
				then true
				else false

			if dirty then
				local map = {
					set = if set_index > 0 then set_ids else nil,
					values = if set_index > 0 then set_values else nil,
					removed = if remove_index > 0 then removed_ids else nil,
				}

				if jecs.IS_PAIR(component) then
					map.relation = jecs.pair_first(world, component)
					map.target = jecs.pair_second(world, component)
					map.pair = true
				end

				snapshot[tostring(component)] = map
			end
		end

		if next(snapshot) ~= nil then
			for _, player in Players:GetPlayers() do
				net.server.replicate_snapshot(player, snapshot)
			end
		end
	end
end

return {
	name = "networking",
	system = net_send(),
	phase = "pre_simulation",
}
