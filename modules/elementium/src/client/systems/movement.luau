local composer = require "./velocity_compose"
local ecs = require "../../shared/ecs"
local jecs = require "../../roblox_packages/jecs"
local transitions = require "./character_transition"

local world = ecs.world
local components = ecs.components

local animation_tracks: { [ecs.CharacterModel]: { { animation: Animation, track: AnimationTrack } } } =
	{}

local track_slot = 0

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
			local tracks = animation_tracks[target]
			local node = tracks[data.animation_slot]

			if node then
				node.track:Stop()
				tracks[data.animation_slot] = nil
			end
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
		if data.n then
			local tracks = animation_tracks[target]
			local node = tracks[data.n]

			if node then
				node.track:Stop()
				tracks[data.n] = nil
			end
		end

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

world:set(components.Wallrun, jecs.OnRemove, function(entity, id)
	local wallrun = world:get(entity, components.Wallrun)
	local target = world:get(entity, components.AbilityTarget)
	if not wallrun then return end

	if target then
		if wallrun.animation_slot then
			local tracks = animation_tracks[target]
			local node = tracks[wallrun.animation_slot]

			if node then
				node.track:Stop()
				tracks[wallrun.animation_slot] = nil
			end
		end

		target.Humanoid:SetStateEnabled(
			Enum.HumanoidStateType.FallingDown,
			true
		)
	end

	composer.remove_impulse(wallrun.id)

	if wallrun.orient_handle then wallrun.orient_handle:Destroy() end
end)

local function movement_dash(
	entity: jecs.Entity,
	target: ecs.CharacterModel,
	dash: ecs.Dash
)
	dash.started = os.clock()

	dash_n += 1
	dash.n = dash_n
	track_slot += 1
	dash.animation_slot = track_slot

	world:set(entity, components.Dash, dash)

	target.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)

	local animation = Instance.new "Animation"
	animation.AnimationId = "rbxassetid://103216546035460"

	local track = target.Humanoid.Animator:LoadAnimation(animation)
	track:Play()

	if not animation_tracks[target] then animation_tracks[target] = {} end

	animation_tracks[target][track_slot] =
		{ animation = animation, track = track }

	local camera =
		world:get(components.CameraFOV, components.CameraFOV) :: ecs.CameraFOV
	camera.kick()
end

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

	track_slot += 1
	slide.n = track_slot

	world:set(entity, components.Slide, slide)

	target.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	target.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	target.Humanoid.AutoRotate = false

	local animation = Instance.new "Animation"
	animation.AnimationId = "rbxassetid://75583895817610"

	local track = target.Humanoid.Animator:LoadAnimation(animation)
	track.Looped = true
	track:Play()

	if not animation_tracks[target] then animation_tracks[target] = {} end

	animation_tracks[target][track_slot] =
		{ animation = animation, track = track }
end

local WALLRUN_DISTANCE = 4
local WALLRUN_MIN_SPEED = 20
local WALLRUN_LOCK_SPEED = 15

local function movement_wallrun(
	entity: jecs.Entity,
	target: ecs.CharacterModel,
	wallrun: ecs.Wallrun
)
	local orient = Instance.new "AlignOrientation"
	orient.Parent = target
	orient.Attachment0 = target.HumanoidRootPart.RootAttachment
	orient.MaxTorque = 50000
	orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orient.RigidityEnabled = true
	-- orient.Enabled = false

	wallrun.orient_handle = orient

	track_slot += 1
	wallrun.animation_slot = track_slot

	world:set(entity, components.Wallrun, wallrun)

	target.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)

	local animation = Instance.new "Animation"
	animation.AnimationId = "rbxassetid://118646674087775"

	local track = target.Humanoid.Animator:LoadAnimation(animation)
	track.Looped = true
	track:Play()

	if not animation_tracks[target] then animation_tracks[target] = {} end

	animation_tracks[target][track_slot] =
		{ animation = animation, track = track }
end

local function get_wall(
	target: ecs.CharacterModel,
	side: "left" | "right"
): RaycastResult
	local root = target.HumanoidRootPart

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { target }

	local direction = if side == "right"
		then root.CFrame.RightVector
		else -root.CFrame.RightVector

	return workspace:Raycast(
		root.Position,
		direction * WALLRUN_DISTANCE,
		params
	) :: RaycastResult
end

local function find_wall(
	target: ecs.CharacterModel
): (RaycastResult?, "left" | "right"?)
	local right = get_wall(target, "right")

	if right and math.abs(right.Normal.Y) < 0.2 then return right, "right" end

	local left = get_wall(target, "left")

	if left and math.abs(left.Normal.Y) < 0.2 then return left, "left" end

	return nil, nil
end

local function wallrun_get_vector(
	entity: jecs.Entity,
	target: ecs.CharacterModel,
	wallrun: ecs.Wallrun
): (Vector3?, ("left" | "right")?)
	local wall, side = find_wall(target)

	if not wall or math.abs(wall.Normal.Y) >= 0.2 then
		world:delete(entity)
		return nil, nil
	end

	local tangent = wall.Normal:Cross(Vector3.yAxis).Unit

	assert(wallrun.vector)
	assert(wallrun.velocity)

	if tangent:Dot(wallrun.vector) < 0 then tangent = -tangent end

	local distance_error = wall.Distance - 1.5
	local correction = -wall.Normal * math.clamp(distance_error * 10, -8, 8)

	return tangent * wallrun.velocity + correction + Vector3.yAxis * -5, side
end

local dash_query =
	world:query(components.Dash, components.AbilityTarget):cached()
local slide_query =
	world:query(components.Slide, components.AbilityTarget):cached()
local wallrun_query =
	world:query(components.Wallrun, components.AbilityTarget):cached()

local function movement(delta: number)
	for entity, dash, target in dash_query do
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

	for entity, slide, target in slide_query do
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

	for entity, wallrun, target in wallrun_query do
		if not target then continue end

		if not wallrun.active then
			local root = target.HumanoidRootPart
			local wall, side = find_wall(target)

			print(side)

			if not wall or not side then
				world:delete(entity)
				return
			end

			local horizontal_velocity = Vector3.new(
				root.AssemblyLinearVelocity.X,
				0,
				root.AssemblyLinearVelocity.Z
			)

			local speed =
				math.max(horizontal_velocity.Magnitude, WALLRUN_MIN_SPEED)
			local direction = wall.Normal:Cross(Vector3.yAxis).Unit

			if direction:Dot(horizontal_velocity) < 0 then
				direction = -direction
			end

			local vector_velocity = direction * speed
				+ -wall.Normal * WALLRUN_LOCK_SPEED
				+ Vector3.yAxis * 5

			local id = composer.add_impulse {
				group = "wallrun",
				velocity = 0,
				direction = Vector3.zero,
				vector_velocity = vector_velocity,
				lifetime = math.huge,
				exclusive = true,
			}

			wallrun.active = true
			wallrun.id = id
			wallrun.vector = vector_velocity
			wallrun.velocity = speed
			wallrun.side = side

			world:set(entity, components.Wallrun, wallrun)

			movement_wallrun(entity, target, wallrun)
		end

		if target.Humanoid.FloorMaterial ~= Enum.Material.Air then
			world:delete(entity)
			continue
		end

		local vector_velocity, side =
			wallrun_get_vector(entity, target, wallrun)

		if vector_velocity and side then
			wallrun.side = side
			wallrun.vector = vector_velocity

			composer.update(wallrun.id, {
				vector_velocity = vector_velocity,
			})
		end

		assert(wallrun.orient_handle)
		local wallrun_vector = wallrun.vector :: Vector3

		wallrun.orient_handle.CFrame = CFrame.lookAt(
			Vector3.zero,
			Vector3.new(wallrun_vector.X, 0, wallrun_vector.Z).Unit
		)
	end
end

return {
	phase = "post_simulation",
	system = movement,
}
