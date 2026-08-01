local Players = game:GetService "Players"

local ecs = require "../../../ReplicatedStorage/shared/ecs"
local jecs = require "../../../ReplicatedStorage/roblox_packages/jecs"
local net = require "../../../ReplicatedStorage/shared/ecs/net"

local world = ecs.world
local components = ecs.components

local function update_character(character: ecs.Character)
	local humanoid = character.instance.Humanoid

	humanoid.WalkSpeed = character.walk_speed
	humanoid.MaxHealth = character.max_health
	humanoid.Health = character.health
	humanoid.JumpPower = character.jump_power
end

world:set(
	components.Character,
	jecs.OnChange,
	function(entity, id, data) update_character(data :: any) end
)

world:set(
	components.Character,
	jecs.OnAdd,
	function(entity, id, data) update_character(data :: any) end
)

local function get_client(entity: jecs.Entity): Player
	local player = world:get(entity, components.Player)
	assert(player, `entity {entity} does not have a player component`)
	return player
end

world:added(components.Character, function(entity, id, data)
	local player = get_client(entity)
	net.server.replicate_entity(player, entity, { Character = data })
end)

world:changed(components.Character, function(entity, id, data)
	local player = get_client(entity)
	net.server.replicate_entity(player, entity, { Character = data })
end)

local function client()
	local function create_character(entity_id: jecs.Entity, player: Player)
		player.CharacterAdded:Connect(
			function(instance)
				world:set(entity_id, components.Character, {
					health = 100,
					max_health = 100,
					walk_speed = 20,
					jump_power = 50,
					instance = instance :: any,
				})
			end
		)
	end

	Players.PlayerAdded:Connect(function(player)
		local entity = world:entity()
		world:set(entity, components.Player, player)

		player:SetAttribute("entity_id", entity)
		create_character(entity, player)
	end)
end

return {
	phase = "startup",
	system = client,
}
