local ContextActionService = game:GetService "ContextActionService"
local Players = game:GetService "Players"

local ecs = require "../../shared/ecs"
local transitions = require "./character_transition"

local world = ecs.world
local components = ecs.components

local function keys()
	ContextActionService:BindAction("dash", function(_, state)
		if state ~= Enum.UserInputState.Begin then return nil end
		local character_state = world:get(
			components.CharacterState,
			components.CharacterState
		) :: ecs.CharacterState
		character_state.change "dashing"

		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Q)

	ContextActionService:BindAction("slide", function(_, state)
		if state == Enum.UserInputState.Begin then
			local character_state = world:get(
				components.CharacterState,
				components.CharacterState
			) :: ecs.CharacterState
			character_state.change "sliding"

			return Enum.ContextActionResult.Pass
		else
			local character_state = world:get(
				components.CharacterState,
				components.CharacterState
			) :: ecs.CharacterState

			for entity, slide in world:query(components.Slide) do
				world:delete(entity)
			end

			character_state.change(
				transitions.resolve_character_state(
					Players.LocalPlayer.Character :: ecs.CharacterModel
				)
			)

			return Enum.ContextActionResult.Pass
		end
	end, false, Enum.KeyCode.LeftShift)
end

return {
	phase = "startup",
	system = keys,
}
