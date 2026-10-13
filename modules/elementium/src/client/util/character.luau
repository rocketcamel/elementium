local ecs = require "../../shared/ecs"

local function state_jump(character: ecs.CharacterModel, value: boolean)
	character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, value)
end

return {
	state_jump = state_jump,
}
