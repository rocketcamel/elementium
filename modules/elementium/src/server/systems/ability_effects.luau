local ecs = require "../../../ReplicatedStorage/shared/ecs"
local jecs = require "../../../ReplicatedStorage/roblox_packages/jecs"
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
	net.server.on_movement_report(function(player, movement)
		if movement == "dash" then
			dash(player)
		elseif movement == "dash_endjump" then
			dash_endjump(player)
		end
	end)

	net.server.on_ability_report(function(player, kind, target)
		local entity = world:entity()
		local character = player.Character :: ecs.CharacterModel
		assert(character)

		local position = character.HumanoidRootPart.CFrame
			* Vector3.new(0, 0, -3)
		local direction = (target - position).Unit
		local cframe = CFrame.new(position, position + direction)
		local now = workspace:GetServerTimeNow()

		jecs.bulk_insert(world, entity, {
			components.Projectile,
			components.Velocity,
		}, {
			{
				kind = "simple" :: "simple",
				definition = "firey_blow" :: "firey_blow",

				origin = cframe,
				initial_velocity = direction * 80,
				acceleration = Vector3.zero,
				spawn_time = now,
			},
			direction * 80,
		})
	end)
end

return {
	phase = "startup",
	system = ability_effects,
}
