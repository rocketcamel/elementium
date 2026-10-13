local ecs = require "../../ecs"
local jecs = require "../../../roblox_packages/jecs"
local util = require "../../util"

return function(
	context: unknown,
	players: { Player },
	field: string,
	value: unknown
)
	for _, player in players do
		local entity_id = player:GetAttribute "entity_id" :: jecs.Entity?
		local character = util.get_character(player) :: any

		if
			not character
			or not util.validate_character(character)
			or not entity_id
		then
			return "invalid inputs"
		end

		print(value, character[field], typeof(value), typeof(character[field]))
		if typeof(value) == typeof(character[field]) then
			character[field] = value
			ecs.world:set(entity_id, ecs.components.Character, character)
		end
	end

	return "updated fields"
end
