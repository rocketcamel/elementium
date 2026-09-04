local composer = require "../velocity_compose"
local ecs = require "../../../shared/ecs"
local jecs = require "../../../roblox_packages/jecs"
local transitions = require "../character_transition"
local util = require "../../util"

local world = ecs.world
local components = ecs.components

world:set(components.Slide, jecs.OnRemove, function(entity, id)
	local data = world:get(entity, components.Slide)
	local target = world:get(entity, components.AbilityTarget)
	if not data then return end

	local request =
		world:get(components.Motion, components.Motion) :: ecs.MotionRequest
	local character_state = world:get(
		components.CharacterState,
		components.CharacterState
	) :: ecs.CharacterState

	if target then
		if data.n then util.stop_track(data.n, target) end

		if character_state.active_ability_id == entity then
			request.motion = transitions.resolve_character_state(target)
			request.reason = "ability_end"

			world:set(components.Motion, components.Motion, request)
		end

		target.Humanoid:SetStateEnabled(
			Enum.HumanoidStateType.FallingDown,
			true
		)
		target.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		target.Humanoid.AutoRotate = true
	end

	composer.remove_impulse(data.id)
	composer.remove_group "air"

	composer.add_impulse {
		group = "air",
		direction = data.direction,
		velocity = data.velocity * 0.80,
		friction = 150,
		threshold = 25,
		steerable = true,
		lifetime = math.huge,
	}

	if data.orient_handle then data.orient_handle:Destroy() end
end)

local function movement_slide(
	entity: jecs.Entity,
	target: ecs.CharacterModel,
	slide: ecs.Slide
)
	local orient = Instance.new "AlignOrientation"
	orient.Parent = target
	orient.Attachment0 = target.HumanoidRootPart.RootAttachment
	orient.MaxTorque = 50000
	orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orient.RigidityEnabled = true

	slide.orient_handle = orient

	local animation_slot =
		util.animate("rbxassetid://75583895817610", target, { loop = true })
	slide.n = animation_slot

	world:set(entity, components.Slide, slide)

	target.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	target.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	target.Humanoid.AutoRotate = false
end

local query = world:query(components.Slide, components.AbilityTarget):cached()

local function slide(delta: number)
	for entity, slide, target in query do
		if slide.velocity < 5 then
			world:delete(entity)
			continue
		end

		local look_vector = target.Humanoid.MoveDirection
		look_vector = Vector3.new(look_vector.X, 0, look_vector.Z)

		if not slide.active then
			local id = composer.add_impulse {
				group = "slide",
				direction = look_vector,
				velocity = slide.velocity,
				friction = 0,
				lifetime = math.huge,
			}

			slide.id = id
			slide.active = true

			movement_slide(entity, target, slide)
		end

		local alpha = math.min(2 * delta, 1)
		slide.direction = slide.direction:Lerp(look_vector, alpha).Unit

		slide.velocity =
			math.max(slide.velocity - 5 * slide.velocity ^ 0.5 * delta, 0)

		composer.update(slide.id, {
			direction = slide.direction,
			velocity = slide.velocity,
		})

		assert(slide.orient_handle)
		slide.orient_handle.CFrame =
			CFrame.lookAt(Vector3.zero, slide.direction)
	end
end

return {
	phase = "movement",
	system = slide,
}
