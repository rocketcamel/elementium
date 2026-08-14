local Players = game:GetService "Players"

local ecs = require "../../shared/ecs"
local jecs = require "../../roblox_packages/jecs"
local transitions = require "./character_transition"

local world = ecs.world
local components = ecs.components

local animation_tracks: { [ecs.CharacterModel]: { animation: Animation, track: AnimationTrack } } =
	{}

local n = 0

world:set(components.Dash, jecs.OnRemove, function(entity, id)
	local data = world:get(entity, components.Dash)
	local target = world:get(entity, components.DashTarget)
	if not data then return end

	local character_state = world:get(
		components.CharacterState,
		components.CharacterState
	) :: ecs.CharacterState

	if target then
		local node = animation_tracks[target]

		if node then
			node.track:Destroy()
			animation_tracks[target] = nil
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

	world:set(entity, components.Dash, dash)

	target.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)

	local animation = Instance.new "Animation"
	animation.AnimationId = "rbxassetid://85240720810252"

	local track = target.Humanoid.Animator:LoadAnimation(animation)
	track:Play()

	animation_tracks[target] = { animation = animation, track = track }

	local camera =
		world:get(components.CameraFOV, components.CameraFOV) :: ecs.CameraFOV
	camera.kick()
end

local query = world:query(components.Dash, components.DashTarget):cached()

local function movement(delta: number)
	for entity, dash, target in query do
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
end

return {
	phase = "post_simulation",
	system = movement,
}
