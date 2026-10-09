local ecs = require "../shared/ecs"

export type Trigger = "release" | "press"

export type Abilities = {
	[ecs.AbilityKind]: {
		trigger: Trigger,
		max_charge: number,
		cooldown: number,
		fire: (...unknown) -> (),
		finish: (...unknown) -> (),
	},
}

local abilities: Abilities = {
	["firey_blow"] = require "@self/firey_blow",
}

return abilities
