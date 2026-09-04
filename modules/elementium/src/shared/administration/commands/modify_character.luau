local conch = require "../../../roblox_packages/conch"
local ecs = require "../../../shared/ecs"
local jecs = require "../../../roblox_packages/jecs"
local types = require "../types"

local world = ecs.world
local components = ecs.components

--FIXME: types
local function modify_character()
	conch.register(
		"modify_character",
		{
			description = "modify character(s)",
			permissions = { "debug" },
			arguments = function()
				return conch.args.players(
					"player(s)",
					"the player(s) character's to modify"
				),
					types.character_info("field", "the field to modify"),
					conch.args.any("value", "the value to set")
			end,

			callback = function(players: { Player }, field, value)
				for _, player in players do
					local entity_id =
						player:GetAttribute "entity_id" :: jecs.Entity
					if not entity_id then return end

					local data =
						world:get(entity_id, components.Character) :: any

					if data and typeof(value) == typeof(data[field]) then
						data[field] = value
						world:set(entity_id, components.Character, data)

						return "updated" :: any
					else
						error "invalid inputs"
					end
				end
			end,
		} :: any
	)
end

return modify_character
