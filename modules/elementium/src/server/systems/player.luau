local GroupService = game:GetService "GroupService"
local Players = game:GetService "Players"

local ecs = require "../../../ReplicatedStorage/shared/ecs"
local jecs = require "../../../ReplicatedStorage/roblox_packages/jecs"
local net = require "../../../ReplicatedStorage/shared/net"
local storage = require "../storage"
local util = require "../../../ReplicatedStorage/shared/util"

local world = ecs.world
local components = ecs.components

local function update_character(character: ecs.Character)
	local humanoid = character.instance.Humanoid

	humanoid.WalkSpeed = character.walk_speed
	humanoid.MaxHealth = character.max_health
	humanoid.Health = character.health
	humanoid.JumpPower = character.jump_power
end

world:changed(
	components.Character,
	function(entity, _, data) update_character(data) end
)

local function initialize_data_lifecycle(player: Player, entity: jecs.Entity)
	local session = storage.initialize(player)
	assert(session)

	-- apply ranks
	local result =
		GroupService:GetRolesInGroupAsync(player.User, 524756377) :: {
			IsMember: boolean,
			Roles: { { Id: number, Name: string, Rank: number } },
		}

	for _, role in result.Roles do
		if role.Rank == 254 then
			session:patch(function(data)
				local meta = data.meta

				local function add(rank: string)
					assert(meta)

					if not table.find(meta.permissions, rank) then
						table.insert(meta.permissions, rank)
					end
				end

				if not meta then
					meta = {
						permissions = { "owner", "admin" },
					}
					data.meta = meta
				else
					add "owner"
					add "admin"
				end

				return data
			end)
		end
	end

	storage.display(session)

	session:updated(function() storage.update_display(session) end)

	local meta = session.profile.Data.meta
	if meta and meta.permissions then
		world:set(entity, components.Meta, {
			permissions = meta.permissions,
		})

		print(
			"assigned rank(s)",
			table.concat(meta.permissions, ","),
			"to player",
			player
		)
	end
end

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

local players_added = util.collect(Players.PlayerAdded)

local function player()
	for player in players_added do
		local entity = world:entity()
		world:set(entity, components.Player, player)

		player:SetAttribute("entity_id", entity)
		create_character(entity, player)
		task.spawn(initialize_data_lifecycle, player, entity)

		world:set(entity, components.Element, {
			{ kind = "fiery_blow" :: "fiery_blow" },
		})
	end
end

Players.PlayerRemoving:Connect(function(player)
	local entity_id = player:GetAttribute "entity_id" :: jecs.Entity
	world:delete(entity_id)
	net.server.report_entity_deletion("all", entity_id)
end)

return {
	phase = "update",
	system = player,
}
