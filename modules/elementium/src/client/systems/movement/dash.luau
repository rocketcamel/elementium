local composer = require "../velocity_compose"
local ecs = require "../../../shared/ecs"
local jecs = require "../../../roblox_packages/jecs"
local transitions = require "../character_transition"
local util = require "../../util"

local world = ecs.world
local components = ecs.components

local dash_n = 0

world:set(components.Dash, jecs.OnRemove, function(entity, id)
	local data = world:get(entity, components.Dash)
	local target = world:get(entity, components.AbilityTarget)
	if not data then return end

	local request =
		world:get(components.Motion, components.Motion) :: ecs.MotionRequest
	local character_state = world:get(
		components.CharacterState,
		components.CharacterState
	) :: ecs.CharacterState

	if target then
		if data.animation_slot then
			util.stop_track(data.animation_slot, target)
		end

		if character_state.active_ability_id == entity then
			character_state.active_ability_id = nil
			request.motion = transitions.resolve_character_state(target)
			request.reason = "ability_end"

			world:set(components.Motion, components.Motion, request)
		end

		if data.n == dash_n then
			target.Humanoid:SetStateEnabled(
				Enum.HumanoidStateType.FallingDown,
				true
			)
		end
	end
end)

local function movement_dash(
	entity: jecs.Entity,
	target: ecs.CharacterModel,
	dash: ecs.Dash
)
	dash.started = os.clock()

	dash_n += 1
	dash.n = dash_n

	local animation_slot = util.animate("rbxassetid://103216546035460", target)
	dash.animation_slot = animation_slot

	world:set(entity, components.Dash, dash)

	target.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)

	local camera =
		world:get(components.CameraFOV, components.CameraFOV) :: ecs.CameraFOV
	camera.kick()
end

local query = world:query(components.Dash, components.AbilityTarget):cached()

local function dash(delta: number)
	for entity, dash, target in query do
		if dash.velocity < 20 then
			world:delete(entity)
			continue
		end

		if not target then continue end

		if not dash.active then
			local look_vector = target.HumanoidRootPart.CFrame.LookVector

			local id = composer.add_impulse {
				group = "dash",
				direction = look_vector,
				velocity = dash.velocity,
				friction = 250,
				lifetime = os.clock() + dash.lifetime,
			}

			dash.id = id
			dash.active = true

			movement_dash(entity, target, dash)

			world:set(entity, components.Dash, dash)
		end

		if (os.clock() - dash.started) >= dash.lifecycle then
			world:delete(entity)
		end
	end
end

return {
	phase = "movement",
	system = dash,
}
