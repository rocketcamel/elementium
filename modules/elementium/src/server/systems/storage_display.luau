local ecs = require "../../../ReplicatedStorage/shared/ecs"
local storage = require "../../../ReplicatedStorage/shared/storage"

local world = ecs.world
local components = ecs.components

type Display = Folder & {
	Shards: IntValue,
}

local function create_display(player: Player, data: storage.Store)
	local folder = Instance.new "Folder"
	folder.Name = "leaderstats"
	folder.Parent = player

	local shards = Instance.new "IntValue"
	shards.Parent = folder
	shards.Name = "Shards"
	shards.Value = data.shards
end

local function update_display(player: Player, data: storage.Store)
	local folder = player:FindFirstChild "leaderstats" :: Display
	assert(folder)

	folder.Shards.Value = data.shards
end

local function storage_display()
	world:added(components.Session, function(entity, _, data)
		local player = world:get(entity, components.Player)
		assert(player)

		create_display(player, data)
	end)

	world:changed(components.Session, function(entity, _, data: storage.Store)
		local player = world:get(entity, components.Player)
		assert(player)

		update_display(player, data)
	end)
end

return {
	phase = "startup",
	system = storage_display,
}
