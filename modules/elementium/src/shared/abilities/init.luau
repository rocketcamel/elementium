local ecs = require "../shared/ecs"

export type Trigger = "release" | "press"

export type AbilityKind = "projectile"

export type Projectile = {
	kind: AbilityKind,
	name: string,
	trigger: Trigger,
	max_charge: number,
	cooldown: number,
	velocity: number,
	fire: <U...>(U...) -> (),
	finish: <T>(T) -> (),
	get_instance: () -> PVInstance,
}

export type AbilityType = Projectile

local abilities: { [ecs.AbilityKind]: AbilityType } = {
	fiery_blow = require "@self/fiery_blow" :: any,
}

return abilities
