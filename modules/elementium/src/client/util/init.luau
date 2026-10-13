local character = require "@self/character"
local wallrun = require "@self/wallrun"

return {
	wallrun = wallrun,
	state_jump = character.state_jump,
}
