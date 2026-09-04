local Players = game:GetService "Players"

local composer = require "./velocity_compose"
local ecs = require "../../shared/ecs"
local jecs = require "../../roblox_packages/jecs"

local world = ecs.world
local components = ecs.components

export type Source = "dash" | "slide" | "wallrun"

export type AirMomentum = {
	id: number?,
	velocity: Vector3?,
	source: Source,
	friction: number?,
}

export type AirProfile = {
	conserve: number,
	friction: number,
	threshold: number,
	max_turn_rate: number,
}

local AirMomentum = world:component<<AirMomentum>>()

world:set(AirMomentum, jecs.Name, "AirMomentum")

local PROFILES: { [Source]: AirProfile } = {
	dash = {
		conserve = 0.85,
		friction = 75,
		threshold = 8,
		max_turn_rate = 2,
	},
	wallrun = {
		conserve = 1.1,
		friction = 80,
		threshold = 10,
		max_turn_rate = 4,
	},
}

local query = world:query(AirMomentum):cached()

local function apply_air(
	horizontal_velocity: Vector3,
	profile: AirProfile
): number
	composer.remove_group "air"

	return composer.add_impulse {
		group = "air",
		direction = horizontal_velocity.Unit,
		velocity = horizontal_velocity.Magnitude * profile.conserve,
		friction = profile.friction,
		threshold = profile.threshold,
		steerable = true,
		max_turn_rate = profile.max_turn_rate,
		lifetime = math.huge,
	}
end

local function air_physics()
	for entity, momentum in query do
		local target = Players.LocalPlayer.Character :: ecs.CharacterModel

		if not target or not target:FindFirstChild "Humanoid" then
			world:delete(entity)
			continue
		end

		local airborne = target.Humanoid.FloorMaterial == Enum.Material.Air

		if airborne and not momentum.id then
			local profile = PROFILES[momentum.source]
			local velocity = momentum.velocity or Vector3.zero

			if velocity.Magnitude <= profile.threshold then
				world:delete(entity)
				continue
			end

			local id = apply_air(velocity, profile)

			momentum.id = id
			momentum.friction = profile.friction

			continue
		elseif not airborne and momentum.id then
			composer.remove_impulse(momentum.id)
			world:delete(entity)
		end
	end
end

return {
	phase = "post_simulation",
	system = air_physics,

	AirMomentum = AirMomentum,
}
