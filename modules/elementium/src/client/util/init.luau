const character = require "@self/character"
const wallrun = require "@self/wallrun"
const ecs = require "../shared/ecs"

const DASH_VELOCITY = 80

const function get_dash_vector(character: ecs.CharacterModel): Vector3
	const forward_vector = character.HumanoidRootPart.CFrame.LookVector
	return Vector3.new(forward_vector.X, 0, forward_vector.Z) * DASH_VELOCITY
end

return {
	wallrun = wallrun,
	dash = {
		DASH_VELOCITY = DASH_VELOCITY,
		get_dash_vector = get_dash_vector,
	},
	state_jump = character.state_jump,
}
