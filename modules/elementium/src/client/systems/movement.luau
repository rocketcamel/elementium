local ecs = require "../../shared/ecs"

local world = ecs.world
local components = ecs.components

local function dash(character: ecs.Character)
	local force = Instance.new "LinearVelocity"
	force.Attachment0 = character.instance.HumanoidRootPart.RootAttachment
	force.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	force.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	force.MaxForce = math.huge

	force.LineVelocity = 50
end

local function movement() end

return {
	phase = "post_simulation",
	system = movement,
}
