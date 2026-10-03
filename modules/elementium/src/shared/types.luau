export type AbilityKind = "fireball"

export type Ability = {
	kind: AbilityKind,
	name: string,
	casted: boolean,
	cooldown_duration: number,
	cooldown: number?,
	charge: number?,
	binding: Tool?,
}

return nil
