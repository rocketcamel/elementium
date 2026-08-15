local Players = game:GetService "Players"

local ecs = require "../../shared/ecs"
local jecs = require "../../roblox_packages/jecs"

local world = ecs.world
local components = ecs.components

local query = world:query(components.AbilitySpawn):cached()

function sliding(entity: jecs.Entity, spawn: ecs.AbilitySpawn)
	local target = spawn.target
	local root = target.HumanoidRootPart

	local slide = {
		velocity = root.AssemblyLinearVelocity.Magnitude,
		direction = root.AssemblyLinearVelocity.Unit,
		generation = spawn.generation,
	}

	print(entity, slide, target)

	jecs.bulk_insert(
		world,
		entity,
		{ components.Slide, components.AbilityTarget },
		{ slide, target }
	)
end

function dashing(entity: jecs.Entity, spawn: ecs.AbilitySpawn)
	local dash = {
		from = Players.LocalPlayer.Name,
		velocity = 100,
		lifetime = 0.15,
		generation = spawn.generation,
		active = false,
	}

	local target = spawn.target

	print(entity, dash, target)

	jecs.bulk_insert(
		world,
		entity,
		{ components.Dash, components.AbilityTarget },
		{ dash, target }
	)
end

local function ability_spawn()
	for entity, spawn in query do
		local character_state = world:get(
			components.CharacterState,
			components.CharacterState
		) :: ecs.CharacterState

		local ability = world:entity()

		if spawn.motion == "dashing" then
			dashing(ability, spawn)
		elseif spawn.motion == "sliding" then
			sliding(ability, spawn)
		end

		character_state.active_ability_id = ability

		world:delete(entity)
	end
end

return {
	phase = "pre_simulation",
	system = ability_spawn,
}
