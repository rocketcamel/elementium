local GroupService = game:GetService "GroupService"
local Players = game:GetService "Players"

local ecs = require "../../../ReplicatedStorage/shared/ecs"
local jecs = require "../../../ReplicatedStorage/roblox_packages/jecs"
local net = require "../../../ReplicatedStorage/shared/ecs/net"
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

		local result =
			GroupService:GetRolesInGroupAsync(player.User, 524756377) :: {
				IsMember: boolean,
				Roles: { { Id: number, Name: string, Rank: number } },
			}

		for _, role in result.Roles do
			if role.Rank == 254 then
				session:patch(function(data)
					if not data.meta then
						data.meta = {
							permissions = { "owner", "admin" },
						}
					elseif not table.find(data.meta.permissions, "owner") then
						table.insert(data.meta.permissions, "owner")
					end

					return data
				end)
			end
		end

		if permissions then
			world:set(entity, components.Meta, {
				permissions = permissions,
			})

			print(
				"assigned rank(s)",
				table.concat(permissions, ","),
				"to player",
				player
			)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		storage.cleanup(player)

		local entity_id = player:GetAttribute "entity_id" :: jecs.Entity
		world:delete(entity_id)
		net.server.report_entity_deletion("all", entity_id)
	end)
end

return {
	phase = "startup",
	system = client,
}
