local ContextActionService = game:GetService "ContextActionService"
local Players = game:GetService "Players"

local ecs = require "../../shared/ecs"
local jecs = require "../../roblox_packages/jecs"

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
end

return {
	phase = "startup",
	system = keys,
}
