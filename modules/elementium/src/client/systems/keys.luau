local ContextActionService = game:GetService "ContextActionService"
local Players = game:GetService "Players"

local ecs = require "../../shared/ecs"
local jecs = require "../../roblox_packages/jecs"
local wallrun = require "./movement/wallrun"

local world = ecs.world
local components = ecs.components

world:set(components.Motion, components.Motion, {
	motion = "none" :: "none",
	reason = "input_began" :: "input_began",
	id = 0,
})

export type Input = {
	dash: boolean,
	slide: boolean,
}

local Input = ecs.create_component<<Input>> "Input"

world:set(Input, Input, {
	dash = false,
	slide = false,
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
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Q)

	ContextActionService:BindAction("slide", function(_, state)
		if state == Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		else
			return Enum.ContextActionResult.Pass
		end
	end, false, Enum.KeyCode.LeftShift)

	ContextActionService:BindAction("wallrun", function(_, state)
		if
			state == Enum.UserInputState.Begin
			and wallrun.near_wall(
				Players.LocalPlayer.Character :: ecs.CharacterModel
			)
		then
			set_motion("wallrunning", "input_began")
			return Enum.ContextActionResult.Pass
		else
			set_motion("none", "input_end")
			return Enum.ContextActionResult.Pass
		end
	end, false, Enum.KeyCode.Space)
end

return {
	phase = "startup",
	system = keys,
}
