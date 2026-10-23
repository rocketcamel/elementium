--------------------------------------------------------------------------------
-- replication.luau
-- v0.2.0
--------------------------------------------------------------------------------

local ecs = require "../ecs"
local jecs = require "../../roblox_packages/jecs"

export type Values =
	{
		ids: { jecs.Entity }?,
		values: { unknown }?,
		removed: { jecs.Entity }?,
		pair: true,
		relation: jecs.Entity,
		target: jecs.Entity,
	}
	| {
		ids: { jecs.Entity }?,
		values: { unknown }?,
		removed: { jecs.Entity }?,
		pair: false,
	}

export type Snapshot = {
	[string]: Values,
}

export type Storage = {
	[jecs.Entity]: { [jecs.Entity]: unknown },
}

local world = ecs.world
local components = ecs.components

local storages: Storage = {}
local networked_components = {}
local networked_pairs = {}

local function get_storage(id: jecs.Entity)
	local storage = storages[id]
	if not storage then
		storage = {}
		storages[id] = storage
	end

	return storage
end

local function setup_components()
	for component in world:each(components.Networked) do
		local name = world:get(component, jecs.Name)
		assert(name)

		networked_components[name] = component
	end

	for relation in world:each(components.NetworkedPair) do
		local name = world:get(relation, jecs.Name)
		assert(name)
		table.insert(networked_pairs, relation)
	end

	for name, component in networked_components do
		local storage = storages[component]
		if not storage then
			storage = {}
			storages[component] = storage
		end

		if jecs.is_tag(world, component) then
			world:added(component, function(entity) storage[entity] = true end)
		else
			world:added(
				component,
				function(entity, _, value) storage[entity] = value end
			)

			world:changed(
				component,
				function(entity, _, value) storage[entity] = value end
			)
		end

		world:removed(
			component,
			function(entity) storage[entity] = "jecs.removed" end
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
			storage[entity] = "jecs.removed"
		end)
	end
end

local function generate_snapshot_hydrate(): Snapshot
	local snapshot: Snapshot = {}

	for _, component in networked_components do
		local ids = {}
		local values = {}
		local ids_n = 0

		local query = world:query(component)
		local is_tag = jecs.is_tag(world, component)

		for _, archetype in query:archetypes() do
			local entities_len = #archetype.entities

			table.move(archetype.entities, 1, entities_len, ids_n + 1, ids)

			if not is_tag then
				table.move(
					archetype.columns_map[component],
					1,
					entities_len,
					ids_n + 1,
					values
				)
			end

			ids_n += entities_len
		end

		local map = {
			ids = ids,
			values = values,
		}

		if jecs.IS_PAIR(component) then
			map.relation = jecs.pair_first(world, component)
			map.target = jecs.pair_second(world, component)
			map.pair = true
		end

		snapshot[tostring(component)] = map :: Values
	end

	return snapshot
end

local function generate_snapshot(): Snapshot
	local snapshot: Snapshot = {}

	for component, storage in storages do
		local ids = {}
		local values = {}
		local removed = {}

		local ids_n = 0
		local removed_n = 0

		local is_tag = jecs.is_tag(world, component)

		for entity, value in storage do
			if value ~= "jecs.removed" then
				ids_n += 1
				ids[ids_n] = entity
				values[ids_n] = if is_tag then 0 else value
			else -- removed
				removed_n += 1
				removed[removed_n] = entity
			end
		end

		table.clear(storage)

		local changed = if ids_n > 0 or removed_n > 0 then true else false

		if changed then
			local map = {
				ids = if ids_n > 0 then ids else nil,
				values = if ids_n > 0 then values else nil,
				removed = if removed_n > 0 then removed else nil,
			}

			if jecs.IS_PAIR(component) then
				map.relation = jecs.pair_first(world, component)
				map.target = jecs.pair_second(world, component)
				map.pair = true
			end

			snapshot[tostring(component)] = map :: Values
		end
	end

	return snapshot
end

local server_entity_map = {}

local function is_component(id: jecs.Id)
	return world:contains(id) and world:get(id, jecs.Name)
end

local function ensure_entity(server_id: jecs.Entity)
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
	server_relation: jecs.Entity,
	server_target: jecs.Entity
): jecs.Entity
	local relation = ensure_entity(server_relation)
	local target = ensure_entity(server_target)

	return jecs.pair(relation, target)
end

local function apply_snapshot(snapshot: Snapshot)
	for component_id, storage in snapshot do
		local component = (tonumber(component_id) :: any) :: jecs.Entity

		if jecs.IS_PAIR(component) and storage.pair then
			component = deserialize_pair(storage.relation, storage.target)
		else
			component = ensure_entity(component)
		end

		if storage.ids and storage.values then
			for index, id in storage.ids do
				local client_id = ensure_entity(id)
				world:set(client_id, component, storage.values[index] :: any)
			end
		end

		if storage.removed then
			for _, id in storage.removed do
				local client_id = server_entity_map[id] :: jecs.Entity

				if client_id and world:contains(client_id) then
					world:remove(client_id, component :: jecs.Entity)
				end
			end
		end
	end
end

setup_components()
return {
	setup_components,
	generate_snapshot_hydrate = generate_snapshot_hydrate,
	generate_snapshot = generate_snapshot,
	apply_snapshot = apply_snapshot,
}
