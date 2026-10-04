local Players = game:GetService "Players"

local ecs = require "../../../ReplicatedStorage/shared/ecs"
local net = require "../../../ReplicatedStorage/shared/ecs/net"
local util = require "../../../ReplicatedStorage/shared/util"

local world = ecs.world
local components = ecs.components

local function character_get(player: Player)
	local entity_id = player:GetAttribute "entity_id" :: number

	if entity_id then
		local character =
			world:get(entity_id, components.Character, components.Character)
		return character
	end

	return nil
end

local function play_sound(root: Instance, id: string)
	local instance = Instance.new "Sound"
	instance.Parent = root
	instance.SoundId = id
	instance.Volume = 1
	instance:Play()

	task.delay(instance.TimeLength, function() instance:Destroy() end)
end

local function dash(player: Player)
	local character = character_get(player)
	if not character or not util.validate_character(character) then return end
	play_sound(
		character.instance.HumanoidRootPart,
		"rbxassetid://116541827502640"
	)
end
local function dash_endjump(player: Player)
	local character = character_get(player)
	if not character or not util.validate_character(character) then return end
	play_sound(character.instance.HumanoidRootPart, "rbxassetid://6128977275")
end

local function ability_effects()
	net.server.on_ability_report(function(player, ability)
		if ability == "dash" then
			dash(player)
		elseif ability == "dash_endjump" then
			dash_endjump(player)
		end
	end)
end

return {
	phase = "startup",
	system = ability_effects,
}
