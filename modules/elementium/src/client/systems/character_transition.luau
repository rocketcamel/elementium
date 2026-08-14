local Players = game:GetService "Players"

local ecs = require "../../shared/ecs"
local jecs = require "../../roblox_packages/jecs"

local world = ecs.world
local components = ecs.components

local actions = {}

function actions.sliding() end

function actions.dashing()
	local ability = world:entity()

	local dash = {
		from = Players.LocalPlayer.Name,
		velocity = 100,
		lifetime = 0.15,
		active = false,
	}

	local target = Players.LocalPlayer.Character :: ecs.CharacterModel

	print(ability, dash, target)

	jecs.bulk_insert(
		world,
		ability,
		{ components.Dash, components.AbilityTarget },
		{ dash, target }
	)
end

function actions.running() end
function actions.none() end

local guards: { [ecs.Motion]: { [ecs.Motion]: boolean } } = {
	none = { none = true, running = true, dashing = true, sliding = true },
	running = { none = true, dashing = true, sliding = true },
	dashing = { none = true, running = true, dashing = true, sliding = true },
	sliding = { none = true, running = true },
}

local function resolve_character_state(target: ecs.CharacterModel): ecs.Motion
	if target.Humanoid.MoveDirection.Magnitude > 0 then
		return "running"
	else
		return "none"
	end
end

local function change_motion(new_motion: ecs.Motion)
	local current_state = world:get(
		components.CharacterState,
		components.CharacterState
	) :: ecs.CharacterState
	assert(current_state)

	local guard = guards[current_state.motion]

	if guard[new_motion] then
		current_state.motion = new_motion

		world:set(
			components.CharacterState,
			components.CharacterState,
			current_state
		)

		actions[new_motion]()
	end
end

local function character_transitions()
	world:set(components.CharacterState, components.CharacterState, {
		motion = "none" :: "none",
		change = change_motion,
	})
end

return {
	system = character_transitions,
	phase = "startup",

	resolve_character_state = resolve_character_state,
}
