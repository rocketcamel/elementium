local TweenService = game:GetService "TweenService"

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
	exclusive: boolean,
}

local state: CameraState = {
	value = 0,
	velocity = 0,
	kicks = {},
	frequency = 9,
	damping = 0.9,
	exclusive = false,
}

local DEFAULT_FOV = 70

local request_id = 0

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

local active: { Tween } = {}

local function GET(): ecs.CameraFOV
	return world:get(
			components.CameraFOV,
			components.CameraFOV
		) :: ecs.CameraFOV
end

local function SET(data: ecs.CameraFOV)
	world:set(components.CameraFOV, components.CameraFOV, data)
end

local function ID_CREATE(): number
	request_id += 1
	return request_id
end

local function create_tween(
	camera: Camera,
	info: TweenInfo,
	properties: { [string]: unknown }
)
	local result = TweenService:Create(camera, info, properties)

	table.insert(active, result)

	result:Play()
	return result
end

local function resolve_tweens()
	for i, tween in active do
		if tween.PlaybackState ~= Enum.PlaybackState.Playing then
			table.remove(active, i)
		end
	end
end

local function clear_tweens()
	resolve_tweens()

	for _, tween in active do
		tween:Pause()
		tween:Destroy()
	end
end

local function kick(amount: number?, duration: number?)
	table.insert(state.kicks, {
		started = os.clock(),
		duration = duration or 0.21,
		amount = amount or 8,
	})
end

local function return_fov(id: number)
	if id ~= request_id then return end
	local camera = workspace.CurrentCamera
	if not camera then return end

	local result = create_tween(
		camera,
		TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ FieldOfView = DEFAULT_FOV }
	)

	result.Completed:Connect(function()
		state.value = DEFAULT_FOV
		state.exclusive = false
	end)
end

local function set_fov(fov: number, duration: number?)
	local camera = workspace.CurrentCamera
	if not camera then return end
	clear_tweens()

	local result = create_tween(
		camera,
		TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
		{ FieldOfView = fov }
	)
	local id = ID_CREATE()

	state.exclusive = true
	state.value = fov

	if duration then task.delay(duration, function() return_fov(id) end) end

	result:Play()
end

local function create(camera: Camera): ecs.CameraFOV
	SET { fov = camera.FieldOfView }
	return GET()
end

local function camera(delta: number)
	local camera = workspace.CurrentCamera
	if not camera then return end

	local data = GET()

	if not data then data = create(camera) end

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

	if not state.exclusive then
		-- state.value, state.velocity = spring_step(
		-- 	state.value,
		-- 	state.velocity,
		-- 	target,
		-- 	delta,
		-- 	state.frequency,
		-- 	state.damping
		-- )

		-- camera.FieldOfView = data.fov + state.value
	end
end

local function wrap(fn: (id: number) -> ()) fn(ID_CREATE()) end

return {
	phase = "post_simulation",
	system = camera,

	kick = kick,
	set_fov = set_fov,

	return_fov = wrap(return_fov),
}
