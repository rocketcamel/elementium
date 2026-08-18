local Players = game:GetService "Players"

local conch = require "../../../ReplicatedStorage/roblox_packages/conch"
local ecs = require "../../../ReplicatedStorage/shared/ecs"
local jecs = require "../../../ReplicatedStorage/roblox_packages/jecs"
local storage = require "../../../ReplicatedStorage/shared/storage"

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

		local session = storage.initialize(player)
		local permissions = session:get_player_permissions()

		world:set(entity, components.Session, session.data)

		session:updated(
			function(data) world:set(entity, components.Session, data) end
		)

		if permissions then
			local user = conch.get_user(player)
			conch.give_roles(user, unpack(permissions))

			world:set(entity, components.Meta, {
				permissions = permissions,
			})

			print(
				"assigned role(s)",
				table.concat(permissions, ","),
				"to player",
				player
			)
		end
	end)

	Players.PlayerRemoving:Connect(function(player) storage.cleanup(player) end)
end

return {
	phase = "startup",
	system = client,
}
