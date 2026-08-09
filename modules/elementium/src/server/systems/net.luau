local Players = game:GetService "Players"
local ecs = require "../../../ReplicatedStorage/shared/ecs"
local jecs = require "../../../ReplicatedStorage/roblox_packages/jecs"
local net = require "../../../ReplicatedStorage/shared/ecs/net"

local world = ecs.world
local components = ecs.components

type Signal<T...> = {
	Connect: (
		self: Signal<T...>,
		callback: (T...) -> ()
	) -> RBXScriptConnection,
}

local function collect<T...>(signal: Signal<T...>): (() -> T..., RBXScriptConnection)
	local queue = {}
	local n = 0

	local connection = signal:Connect(function(...)
		table.insert(queue, { ... })
		n += 1
	end)

	return function(): any
		if n == 0 then return end
		n -= 1

		local args: any = table.remove(queue, 1)
		return unpack(args)
	end,
		connection
end

local function net_send()
	local storages: { [jecs.Entity]: { [jecs.Entity]: any } } = {}
	local networked_components = {}

	for component in world:each(components.Networked) do
		local name = world:get(component, jecs.Name)
		assert(name)

		storages[component] = {}
		networked_components[name] = component
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
			function(entity) storage[entity] = "jecs.Remove" :: any end
		)
	end

	local players_added = collect(Players.PlayerAdded :: any)

	return function()
		local initial_snapshot = {}

		for player in players_added do
			print(player.Name)
			local set_ids = {}

			print(storages)
			for component, storage in storages do
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
					set_ids = set_ids,
					set_values = set_values,
				}

				initial_snapshot[tostring(component)] = map
			end

			net.server.replicate_snapshot(player, initial_snapshot)
		end

		local set_ids = {}
		local removed_ids = {}
		local snapshot = {}

		for component, storage in storages do
			local set_values = {}
			local set_index = 0
			local remove_index = 0

			local is_tag = jecs.is_tag(world, component)

			for entity, value in storage do
				if value ~= "jecs.Remove" then
					set_index += 1
					set_ids[set_index] = entity
					set_values[set_index] = if is_tag then 0 else value
				elseif world:contains(entity) then
					remove_index += 1
					removed_ids[remove_index] = entity
				end
			end

			table.clear(storage)

			local dirty = if set_index > 0 then true else false

			if dirty then
				local set = table.move(set_ids, 1, set_index, 1, {})

				local map = {
					set_ids = if set_index > 0 then set else nil,
					set_values = if set_index > 0 then set_values else nil,
				}

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
	system = net_send(),
	phase = "pre_simulation",
}
