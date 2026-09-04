local Players = game:GetService "Players"

local ecs = require "../../shared/ecs"
local jecs = require "../../roblox_packages/jecs"

local world = ecs.world

export type Impulse = {
	group: "dash" | "slide" | "wallrun" | "air",
	direction: Vector3,
	velocity: number,
	friction: number?,
	threshold: number?,
	lifetime: number,

	steerable: boolean?,
	max_turn_rate: number?,
	control_window: number?,

	exclusive: boolean?,
	vector_velocity: Vector3?,
}

export type State = {
	impulses: { Impulse },
	handle: LinearVelocity,
}

local VelocityState = world:component<<State>>()

world:set(VelocityState, jecs.Name, "VelocityState")

world:set(VelocityState, VelocityState, {
	impulses = {},
	handle = nil :: any,
})

local function add_impulse(impulse: Impulse): number
	local state = world:get(VelocityState, VelocityState) :: State
	local index = #state.impulses + 1
	state.impulses[index] = impulse

	world:set(VelocityState, VelocityState, state)
	return index
end

local function update(id: number, patch: unknown)
	local state = world:get(VelocityState, VelocityState) :: State
	local impulse = state.impulses[id]

	if impulse and typeof(patch) == "table" then
		for k, value in patch do
			(impulse :: any)[k] = value
		end
	end
end

local function remove_impulse(id: number)
	local state = world:get(VelocityState, VelocityState) :: State
	local impulse = state.impulses[id]

	if impulse then state.impulses[id] = nil end
end

local function remove_group(name: string)
	local state = world:get(VelocityState, VelocityState) :: State

	for index, impulse in state.impulses do
		if impulse.group == name then state.impulses[index] = nil end
	end
	world:set(VelocityState, VelocityState, state)
end

local function velocity_compose(delta: number)
	local now = os.clock()
	local result = Vector3.zero
	local active = 0
	local target = Players.LocalPlayer.Character :: ecs.CharacterModel

	if not target or not target:FindFirstChild "Humanoid" then return end

	local state = world:get(VelocityState, VelocityState) :: State

	for id, impulse in state.impulses do
		local lifetime = math.max(0, impulse.lifetime - now)
		local friction = impulse.friction or 0

		if
			lifetime <= 0
			or (impulse.threshold and impulse.velocity <= impulse.threshold)
		then
			state.impulses[id] = nil
		else
			local controllable = if impulse.control_window
					and (impulse.control_window - os.clock()) <= 0
				then false
				else true

			if impulse.steerable and controllable then
				local input_direction = Vector3.new(
					target.Humanoid.MoveDirection.X,
					0,
					target.Humanoid.MoveDirection.Z
				).Unit
				local direction = Vector3.new(
					impulse.direction.X,
					0,
					impulse.direction.Z
				).Unit

				local max_turn_rate = impulse.max_turn_rate or 2
				local angle =
					math.acos(math.clamp(direction:Dot(input_direction), -1, 1))

				local max_step = max_turn_rate * delta
				local alpha = math.min(1, max_step / angle)

				if angle > 1e-4 then
					impulse.direction =
						impulse.direction:Lerp(input_direction, alpha)
				end
			end

			impulse.velocity = math.max(0, impulse.velocity - friction * delta)

			if impulse.exclusive then
				assert(impulse.vector_velocity)
				result = impulse.vector_velocity
			else
				result += impulse.direction * impulse.velocity
			end
			active += 1
		end
	end

	local should_force = active > 0 and result.Magnitude > 0.5

	if not state.handle or state.handle.Parent ~= target then
		local force = Instance.new "LinearVelocity"
		force.Parent = target
		force.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		force.MaxAxesForce = Vector3.new(50000, 0, 50000)
		force.Attachment0 = target.HumanoidRootPart.RootAttachment

		state.handle = force
	end

	local handle = state.handle

	if should_force then
		handle.Enabled = true

		if math.abs(result.Y) > 100 then
			handle.MaxAxesForce = Vector3.new(50000, 50000, 50000)
		else
			handle.MaxAxesForce = Vector3.new(50000, 0, 50000)
		end

		handle.VectorVelocity = result
	else
		handle.Enabled = false
		handle.VectorVelocity = Vector3.zero
	end
end

return {
	phase = "post_simulation",
	system = velocity_compose,

	add_impulse = add_impulse,
	update = update,
	remove_impulse = remove_impulse,
	remove_group = remove_group,
}
