local Players = game:GetService "Players"

local ecs = require "../../../shared/ecs"
local jecs = require "../../../roblox_packages/jecs"

local world = ecs.world
local components = ecs.components

export type Solver = {
	velocity: Vector3,
	state: "ground" | "air" | "dash" | "slide" | "wallrun",

	vector_handle: LinearVelocity?,
	orientation_handle: AlignOrientation?,
}

local Solver = world:component<<Solver>>()

world:set(Solver, jecs.Name, "Solver")

world:set(Solver, Solver, {
	velocity = Vector3.zero,
	state = "ground" :: "ground",
})

local WALK_SPEED = 26
local JUMP_POWER = 50
local GRAVITY = workspace.Gravity
local MAX_FALL_VELOCITY = 210

local function ensure_handles(
	state: Solver,
	target: ecs.CharacterModel
): (LinearVelocity, AlignOrientation)
	if not state.vector_handle then
		local handle = Instance.new "LinearVelocity"
		handle.Parent = target
		handle.Attachment0 = target.HumanoidRootPart.RootAttachment
		handle.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		handle.MaxAxesForce = Vector3.new(50000, 50000, 50000)

		state.vector_handle = handle
	end

	if not state.orientation_handle then
		local handle = Instance.new "AlignOrientation"
		handle.Parent = target
		handle.Mode = Enum.OrientationAlignmentMode.OneAttachment
		handle.Attachment0 = target.HumanoidRootPart.RootAttachment
		handle.Responsiveness = 25
		handle.MaxTorque = 50000

		state.orientation_handle = handle
	end

	return state.vector_handle :: LinearVelocity,
		state.orientation_handle :: AlignOrientation
end

local function character_hip_height(target: ecs.CharacterModel): number
	local root = target.HumanoidRootPart
	local size_y = root.Size.Y
	local base_height = target.Humanoid.HipHeight + size_y

	return base_height + size_y * 0.5
end

local function get_ground(target: ecs.CharacterModel): {
	grounded: boolean,
	error: number,
	result: RaycastResult?,
}
	local root = target.HumanoidRootPart
	local hip_height = character_hip_height(target)
	local distance = hip_height + 1

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { target }

	local result =
		workspace:Raycast(root.Position, Vector3.yAxis * -distance, params)

	if result then
		return {
			grounded = result.Distance <= hip_height + 0.2,
			error = hip_height - result.Distance,
			result = result,
		}
	else
		return {
			grounded = false,
			error = 0,
			result = nil,
		}
	end
end

local function solver(delta: number)
	local target = Players.LocalPlayer.Character :: ecs.CharacterModel
	if not target or not target:FindFirstChild "Humanoid" then return end

	local state = world:get(Solver, Solver) :: Solver

	local velocity = state.velocity
	local ground = get_ground(target)

	local move_direction = target.Humanoid.MoveDirection
	local horizontal_velocity = move_direction * WALK_SPEED

	if ground.grounded then
		velocity = Vector3.new(horizontal_velocity.X, 0, horizontal_velocity.Z)
		state.state = "ground"
	else
		velocity += Vector3.yAxis * -GRAVITY * delta
		velocity = Vector3.new(
			horizontal_velocity.X,
			math.clamp(velocity.Y, -MAX_FALL_VELOCITY, MAX_FALL_VELOCITY),
			horizontal_velocity.Z
		)

		state.state = "air"
	end

	state.velocity = velocity

	local vector_handle, orientation_handle = ensure_handles(state, target)

	if math.abs(velocity.Y) > 0 then
		vector_handle.MaxAxesForce = Vector3.new(50000, 50000, 50000)
	else
		vector_handle.MaxAxesForce = Vector3.new(50000, 0, 50000)
	end

	vector_handle.VectorVelocity = velocity

	if move_direction.Magnitude > 0.05 then
		local flat = Vector3.new(move_direction.X, 0, move_direction.Z)

		orientation_handle.Enabled = true
		orientation_handle.CFrame = CFrame.new(Vector3.zero, flat)
	else
		orientation_handle.Enabled = false
	end
end

return {
	phase = "movement",
	system = solver,
}
