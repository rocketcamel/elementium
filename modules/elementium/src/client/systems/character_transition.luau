local Players = game:GetService "Players"

local ecs = require "../../shared/ecs"

local world = ecs.world
local components = ecs.components

local guards: { [ecs.Motion]: { [ecs.Motion]: boolean } } = {
	none = {
		none = true,
		running = true,
		dashing = true,
		sliding = true,
		wallrunning = true,
	},
	running = {
		none = true,
		dashing = true,
		sliding = true,
		wallrunning = true,
	},
	dashing = {
		none = true,
		running = true,
		dashing = true,
		sliding = true,
		wallrunning = true,
	},
	sliding = { none = true, running = true, wallrunning = true },
	wallrunning = {
		none = true,
		running = true,
		dashing = true,
		sliding = true,
	},
}

local function resolve_character_state(target: ecs.CharacterModel): ecs.Motion
	if target.Humanoid.MoveDirection.Magnitude > 0 then
		return "running"
	else
		return "none"
	end
end

world:set(components.CharacterState, components.CharacterState, {
	motion = "none" :: "none",
	active_ability_id = nil,
	generation = 0,
})

local function create_spawn(motion: ecs.Motion, generation: number)
	local entity = world:entity()

	local spawn = {
		motion = motion,
		target = Players.LocalPlayer.Character :: ecs.CharacterModel,
		generation = generation,
	}

	world:set(entity, components.AbilitySpawn, spawn)
end

local last_id = 0

local function character_transitions()
	local request =
		world:get(components.Motion, components.Motion) :: ecs.MotionRequest
	local current_state = world:get(
		components.CharacterState,
		components.CharacterState
	) :: ecs.CharacterState

	if request.id <= last_id then return end
	last_id = request.id

	local guard = guards[current_state.motion]

	if guard[request.motion] then
		if current_state.active_ability_id then
			local old_active = current_state.active_ability_id
			current_state.active_ability_id = nil
			world:delete(old_active)
		end

		current_state.motion = request.motion
		current_state.generation += 1

		world:set(
			components.CharacterState,
			components.CharacterState,
			current_state
		)

		if
			current_state.motion == "dashing"
			or current_state.motion == "sliding"
			or current_state.motion == "wallrunning"
		then
			create_spawn(
				current_state.motion :: ecs.Motion,
				current_state.generation
			)
		end
	end
end

return {
	system = character_transitions,
	phase = "pre_simulation",

	resolve_character_state = resolve_character_state,
}
