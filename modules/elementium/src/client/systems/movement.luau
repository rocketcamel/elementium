local Players = game:GetService "Players"

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
		local tracks = animation_tracks[target]
		local node = tracks[data.animation_slot]

		if node then
			node.track:Stop()
			tracks[data.animation_slot] = nil
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

	data.force_handle:Destroy()
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
		local tracks = animation_tracks[target]
		local node = tracks[data.n]

		if node then
			node.track:Stop()
			tracks[data.n] = nil
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

	data.force_handle:Destroy()
	data.orient_handle:Destroy()
end)

local function movement_dash(
	entity: jecs.Entity,
	target: ecs.CharacterModel,
	dash: ecs.Dash
)
	local force = Instance.new "LinearVelocity"
	force.Parent = target
	force.Attachment0 = target.HumanoidRootPart.RootAttachment
	force.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	force.MaxAxesForce = Vector3.new(50000, 0, 50000)

	dash.force_handle = force
	dash.started = os.clock()

	dash_n += 1
	dash.n = dash_n
	track_slot += 1
	dash.animation_slot = track_slot

	world:set(entity, components.Dash, dash)

	target.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)

	local animation = Instance.new "Animation"
	animation.AnimationId = "rbxassetid://85240720810252"

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
	local force = Instance.new "LinearVelocity"
	force.Parent = target
	force.Attachment0 = target.HumanoidRootPart.RootAttachment
	force.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	force.MaxAxesForce = Vector3.new(50000, 0, 50000)

	local orient = Instance.new "AlignOrientation"
	orient.Parent = target
	orient.Attachment0 = target.HumanoidRootPart.RootAttachment
	orient.MaxTorque = 50000
	orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orient.RigidityEnabled = true

	slide.force_handle = force
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

local dash_query =
	world:query(components.Dash, components.AbilityTarget):cached()
local slide_query =
	world:query(components.Slide, components.AbilityTarget):cached()

local function movement(delta: number)
	for entity, dash, target in dash_query do
		if dash.from ~= Players.LocalPlayer.Name then continue end

		if dash.active then
			if dash.ending then
				if dash.velocity > 20 then
					dash.velocity = math.max(0, dash.velocity - 250 * delta)
				else
					world:delete(entity)
					continue
				end
			end

			local look_vector = target.HumanoidRootPart.CFrame.LookVector
			dash.force_handle.VectorVelocity = look_vector * dash.velocity

			if (os.clock() - dash.started) >= dash.lifetime then
				dash.ending = true
			end
		else
			dash.active = true
			movement_dash(entity, target, dash)
		end
	end

	for entity, slide, target in slide_query do
		if slide.active then
			local look_vector = target.Humanoid.MoveDirection
			look_vector = Vector3.new(look_vector.X, 0, look_vector.Z)

			local alpha = math.min(2 * delta, 1)
			slide.direction = slide.direction:Lerp(look_vector, alpha).Unit

			slide.velocity =
				math.max(slide.velocity - 5 * slide.velocity ^ 0.5 * delta, 0)

			if slide.velocity < 5 then
				world:delete(entity)
				continue
			end

			slide.force_handle.VectorVelocity = slide.direction * slide.velocity
			slide.orient_handle.CFrame =
				CFrame.lookAt(Vector3.zero, slide.direction)
		else
			slide.active = true
			movement_slide(entity, target, slide)
		end
	end
end

return {
	phase = "post_simulation",
	system = movement,
}
