local ecs = require "../../shared/ecs"

local world = ecs.world
local components = ecs.components

type Kick = {
	started: number,
	duration: number,
	amount: number,
}

type CameraState = {
	value: number,
	velocity: number,
	kicks: { Kick },
	frequency: number,
	damping: number,
}

local state: CameraState = {
	value = 0,
	velocity = 0,
	kicks = {},
	frequency = 9,
	damping = 0.9,
}

local function pulse_curve(t: number): number
	if t <= 0 or t >= 1 then return 0 end

	if t < 0.15 then
		local u = t / 0.15
		return u * u * (3 - 2 * u)
	end

	local u = (t - 0.15) / 0.85
	local inv = 1 - u
	return inv * inv
end

local function spring_step(
	x: number,
	v: number,
	target: number,
	delta: number,
	frequency: number,
	damping: number
): (number, number)
	local omega = 2 * math.pi * frequency
	local f = 1 + 2 * delta * damping * omega
	local oo = omega * omega
	local hoo = delta * oo
	local hhoo = delta * hoo
	local det_inv = 1 / (f + hhoo)

	local next_x = (f * x + delta * v + hhoo * target) * det_inv
	local next_v = (v + hoo * (target - x)) * det_inv

	return next_x, next_v
end

local function kick(amount: number?, duration: number?)
	table.insert(state.kicks, {
		started = os.clock(),
		duration = duration or 0.21,
		amount = amount or 8,
	})
end

local function create(camera: Camera): ecs.CameraFOV
	world:set(
		components.CameraFOV,
		components.CameraFOV,
		{ fov = camera.FieldOfView, kick = kick }
	)

	return world:get(
			components.CameraFOV,
			components.CameraFOV
		) :: ecs.CameraFOV
end

local function camera(delta: number)
	local camera = workspace.CurrentCamera
	if not camera then return end

	local data =
		world:get(components.CameraFOV, components.CameraFOV) :: ecs.CameraFOV

	if not data then data = create(camera) end
	assert(data)

	local now = os.clock()
	local target = 0
	local active_kicks = table.create(#state.kicks) :: { Kick }

	for i, effect in state.kicks do
		local t = (now - effect.started) / effect.duration
		if t < 1 then
			target += effect.amount * pulse_curve(t)
			active_kicks[i] = effect
		end
	end

	state.kicks = active_kicks
	state.value, state.velocity = spring_step(
		state.value,
		state.velocity,
		target,
		delta,
		state.frequency,
		state.damping
	)

	camera.FieldOfView = data.fov + state.value
end

return {
	phase = "post_simulation",
	system = camera,
}
