local types = require "./types"

export type Abilities = {
	[types.AbilityKind]: {
		trigger: "release",
		max_charge: number,
		cooldown: number,
		fire: () -> (),
	},
}

local function noop() end

local abilities: Abilities = {
	["fireball"] = {
		trigger = "release",
		max_charge = 2,
		cooldown = 1,
		fire = noop,
	},
}

function abilities.fireball.fire() print "result" end

return abilities
