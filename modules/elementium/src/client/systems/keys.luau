local ContextActionService = game:GetService "ContextActionService"

local ecs = require "../../shared/ecs"

local world = ecs.world
local components = ecs.components

world:set(components.Motion, components.Motion, {
	motion = "none" :: "none",
	reason = "input_began" :: "input_began",
	id = 0,
})

local function set_motion(motion: ecs.Motion, reason: ecs.MotionRequestReason)
	local request =
		world:get(components.Motion, components.Motion) :: ecs.MotionRequest
	request.motion = motion
	request.reason = reason
	request.id += 1

	world:set(components.Motion, components.Motion, request)
end

local function keys()
	ContextActionService:BindAction("dash", function(_, state)
		if state ~= Enum.UserInputState.Begin then return nil end
		set_motion("dashing", "input_began")
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Q)

	ContextActionService:BindAction("slide", function(_, state)
		if state == Enum.UserInputState.Begin then
			set_motion("sliding", "input_began")
			return Enum.ContextActionResult.Pass
		else
			set_motion("none", "input_end")
			return Enum.ContextActionResult.Pass
		end
	end, false, Enum.KeyCode.LeftShift)
end

return {
	phase = "startup",
	system = keys,
}
