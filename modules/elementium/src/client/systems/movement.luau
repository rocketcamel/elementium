local Players = game:GetService "Players"

local ecs = require "../../shared/ecs"
local jecs = require "../../roblox_packages/jecs"
local transitions = require "./character_transition"

local world = ecs.world
local components = ecs.components

local animation_tracks: { [ecs.CharacterModel]: { { animation: Animation, track: AnimationTrack } } } =
	{}

local track_slot = 0

local n = 0

world:set(components.Dash, jecs.OnRemove, function(entity, id)
	local data = world:get(entity, components.Dash)
	local target = world:get(entity, components.AbilityTarget)
	if not data then return end

	local character_state = world:get(
		components.CharacterState,
		components.CharacterState
	) :: ecs.CharacterState

	if target then
		local tracks = animation_tracks[target]
		local node = tracks[data.animation_slot]

		if node then
			node.track:Destroy()
			node = nil
		end

		if data.n == n then
			character_state.change(transitions.resolve_character_state(target))

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
	if not data then return end

	data.force_handle:Destroy()
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

	n += 1
	dash.n = n
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

	slide.force_handle = force
	world:set(entity, components.Slide, slide)

	target.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
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
