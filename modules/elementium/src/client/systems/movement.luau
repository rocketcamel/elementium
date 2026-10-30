const Players = game:GetService "Players"

const ecs = require "../../shared/ecs"
const net = require "../../shared/net"
const util = require "../../shared/util"
const camera = require "./camera"
const client_util = require "../util"

local world = ecs.world
local components = ecs.components

export type MovementKind =
	"dash"
	| "dash_endjump"
	| "side_dash"
	| "double_jump"
	| "wallrun"

export type Movement = {
	previous: MovementKind?,
	current: (Dash | Dash_EndJump | SideDash | DoubleJump | Wallrun)?,
	air_jump: number,
}

export type Dash = {
	kind: "dash",
	vector: Vector3,
	lifetime: number,
	animation_track: AnimationTrack,
}

export type Dash_EndJump = {
	kind: "dash_endjump",
	vector: Vector3,
	lifetime: number,
	animation_track: AnimationTrack,
}

export type SideDash = {
	kind: "side_dash",
	vector: Vector3,
	lifetime: number,
	animation_track: AnimationTrack,
}

export type DoubleJump = {
	kind: "double_jump",
	vector: Vector3,
	lifetime: number,
}

export type Wallrun = {
	kind: "wallrun",
	vector: Vector3,
	animation_track: AnimationTrack,
}

export type VectorBase = {
	kind: "air" | "ground",
	vector: Vector3?,
	movement: Movement,
	linear_velocity: LinearVelocity?,
}

export type MovementType = "additive" | "exclusive"

const movement_type_map: { [MovementKind]: MovementType } = {
	dash = "additive",
	dash_endjump = "additive",
	side_dash = "additive",
	double_jump = "exclusive",
	wallrun = "exclusive",
}

const VectorBase = ecs.component<<VectorBase>> "Movement"

const function GET(): VectorBase
	return world:get(VectorBase, VectorBase) :: VectorBase
end

const function SET(base: VectorBase) world:set(VectorBase, VectorBase, base) end

const function CHARACTER_GET(): ecs.Character?
	return util.get_character(Players.LocalPlayer)
end

const function flat(v: Vector3) return Vector3.new(v.X, 0, v.Z) end

SET {
	kind = "ground",
	movement = {
		air_jump = 1,
	},
}

const function grounded(character: ecs.CharacterModel): boolean
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	const root = character.HumanoidRootPart
	const hip_height = util.character_hip_height(character)
	const direction = hip_height + 1

	const result = workspace:Shapecast(root, Vector3.yAxis * -direction, params)

	return result and result.Distance <= hip_height + 0.2 or false
end

const function handle_air(
	base: VectorBase,
	delta: number,
	character: ecs.CharacterModel
): Vector3
	const movement = base.movement
	const root = character.HumanoidRootPart

	const assembly = root.AssemblyLinearVelocity
	const move_direction = character.Humanoid.MoveDirection
	const horizontal = flat(assembly) + flat(move_direction)
	const speed = horizontal.Magnitude

	const next_horizontal = if horizontal.Magnitude > 0
		then horizontal * (math.max(0, speed - 25 * delta) / speed)
		else Vector3.zero

	const movement_vector = next_horizontal
		+ Vector3.yAxis * (assembly.Y - workspace.Gravity * delta)

	const current = movement.current
	if not current then return movement_vector end

	return movement_vector
end

const function handle_ground(
	base: VectorBase,
	character: ecs.Character
): Vector3?
	const movement = base.movement
	const current = movement.current

	return current and current.vector or nil
end

const function update_linear_velocity(
	linear_velocity: LinearVelocity?,
	value: unknown
)
	if linear_velocity then
		linear_velocity.Enabled = value and true or false
	end
end

const function update_base(base: VectorBase, character: ecs.CharacterModel)
	local value = base.vector

	local linear_velocity: LinearVelocity =
		character:FindFirstChild "MovementLinearVelocity" :: LinearVelocity

	update_linear_velocity(linear_velocity, value)
	if not value then return end

	if not linear_velocity then
		local instance = Instance.new "LinearVelocity"
		instance.Parent = character
		instance.Name = "MovementLinearVelocity"
		instance.MaxForce = 50000
		instance.Attachment0 = character.HumanoidRootPart.RootAttachment

		linear_velocity = instance
		base.linear_velocity = linear_velocity
	end

	linear_velocity.VectorVelocity = value
end

const function lifetime_end(movement: Movement): boolean
	const current = movement.current
	if not current then return false end

	if
		current.kind == "dash"
		or current.kind == "dash_endjump"
		or current.kind == "side_dash"
		or current.kind == "double_jump"
	then
		return (current.lifetime - os.clock()) <= 0
	end

	return false
end

const function movement_end(movement: Movement)
	if not movement.current then return end

	const current = movement.current
	const kind = movement.current.kind

	if
		current.kind == "dash"
		or current.kind == "dash_endjump"
		or current.kind == "side_dash"
		or current.kind == "wallrun"
	then
		current.animation_track:Stop()
	end

	movement.current = nil
	movement.previous = kind
end

const function update_movement(
	character: ecs.CharacterModel,
	movement: Movement,
	grounded: boolean
)
	if grounded then movement.air_jump = 1 end
	const current = movement.current
	if not current then return end

	if current.kind == "dash" then
		const result = client_util.dash.get_dash_vector(character)
		current.vector = result
	end

	if current.kind == "wallrun" then
		const wall = client_util.wallrun.get_wall(character)
		if not wall then return movement_end(movement) end

		const tangent = client_util.wallrun.wall_tangent(character, wall)
		const result = client_util.wallrun.correct(
			character,
			wall,
			tangent,
			character.HumanoidRootPart.AssemblyLinearVelocity
		)

		current.vector = result
	end
end

const function movement(delta: number)
	const base, character = GET(), CHARACTER_GET()
	const movement = base.movement
	if not character or not util.validate_character(character) then return end

	const grounded = grounded(character.instance)
	base.kind = if grounded then "ground" else "air"

	update_movement(character.instance, movement, grounded)

	local result: Vector3?
	if base.kind == "air" then
		result = handle_air(base, delta, character.instance)
	else
		result = handle_ground(base, character)
	end

	-- case where grounded & no movement active
	if not result then
		base.vector = nil
		update_base(base, character.instance)
	end

	base.vector = result
	update_base(base, character.instance)

	if lifetime_end(movement) then movement_end(movement) end
end

--------------------------------------------------------------------------------
-- implementations
--------------------------------------------------------------------------------

const DASH_VELOCITY = client_util.dash.DASH_VELOCITY

const function dash()
	const base, character = GET(), CHARACTER_GET()
	const movement = base.movement

	if not character or not util.validate_character(character) then return end
	movement_end(movement)

	const dash_vector = character.instance.HumanoidRootPart.CFrame.LookVector
		* DASH_VELOCITY

	const animation = Instance.new "Animation"
	animation.AnimationId = util.retrieve_animation "dash"

	const track = character.instance.Humanoid.Animator:LoadAnimation(animation)

	movement.current = {
		kind = "dash" :: "dash",
		vector = dash_vector,
		animation_track = track,
		lifetime = os.clock() + 0.38,
	} :: ecs.Dash

	net.client.report_movement "dash"
	camera.set_fov(80, 0.38)
	track:Play()

	SET(base)
end

const function dash_endjump()
	const base, character = GET(), CHARACTER_GET()
	const movement = base.movement

	if not character or not util.validate_character(character) then return end
	movement_end(movement)

	const look_vector = character.instance.HumanoidRootPart.CFrame.LookVector

	const forward = Vector3.new(look_vector.X, 0, look_vector.Z).Unit

	const angle = math.rad(30)
	const direction = forward * math.cos(angle)
		+ Vector3.yAxis * math.sin(angle)

	const result = direction * DASH_VELOCITY

	const animation = Instance.new "Animation"
	animation.AnimationId = util.retrieve_animation "dash_endjump"

	const track = character.instance.Humanoid.Animator:LoadAnimation(animation)

	movement.current = {
		kind = "dash_endjump",
		vector = result,
		lifetime = os.clock() + 0.2,
		animation_track = track,
	} :: ecs.Dash_EndJump

	net.client.report_movement "dash_endjump"
	camera.set_fov(75, 0.2)
	track:Play()

	SET(base)
end

const JUMP_MAGNITUDE = 50

const function double_jump()
	const base, character = GET(), CHARACTER_GET()
	const movement = base.movement

	if
		not character
		or movement.air_jump == 0
		or not util.validate_character(character)
	then
		return
	end

	movement_end(movement)

	const result = Vector3.yAxis * JUMP_MAGNITUDE

	const animation = Instance.new "Animation"
	animation.AnimationId = util.retrieve_animation "double_jump"

	const track = character.instance.Humanoid.Animator:LoadAnimation(animation)

	movement.current = {
		kind = "double_jump" :: "double_jump",
		vector = result,
		lifetime = os.clock() + 0.3,
		linear_velocity = nil,
	} :: ecs.DoubleJump

	net.client.report_movement "double_jump"
	movement.air_jump -= 1
	track:Play()

	SET(base)
end

const function wallrun()
	const base, character = GET(), CHARACTER_GET()
	const movement = base.movement
	if not character or not util.validate_character(character) then return end

	const wall, side = client_util.wallrun.get_wall(character.instance)
	if not wall then return end
	movement_end(movement)
	client_util.state_jump(character.instance, false)

	const tangent = client_util.wallrun.wall_tangent(character.instance, wall)
	const result = client_util.wallrun.correct(
		character.instance,
		wall,
		tangent,
		character.instance.HumanoidRootPart.AssemblyLinearVelocity
	)

	const animation = Instance.new "Animation"
	if side == "left" then
		animation.AnimationId = util.retrieve_animation "wallrun_l"
	else
		animation.AnimationId = util.retrieve_animation "wallrun_r"
	end

	const track = character.instance.Humanoid.Animator:LoadAnimation(animation)

	movement.current = {
		kind = "wallrun" :: "wallrun",
		vector = result,
		animation_track = track,
		linear_velocity = nil,
	} :: ecs.Wallrun

	net.client.report_movement "wallrun"
	track:Play()

	SET(base)
end

const function wallrun_end()
	const movement = GET().movement
	const current = movement.current

	if current and current.kind == "wallrun" then movement_end(movement) end
end

const function current_movement(): ecs.MovementKind?
	const movement = GET().movement
	return movement.current and movement.current.kind or nil
end

const function previous_movement(): ecs.MovementKind?
	const movement = GET().movement
	return movement.previous or nil
end

return {
	system = movement,
	phase = "update",

	dash = dash,
	dash_endjump = dash_endjump,
	double_jump = double_jump,
	wallrun = wallrun,
	wallrun_end = wallrun_end,

	current = current_movement,
	previous = previous_movement,

	near_wall = function()
		const character = CHARACTER_GET()
		if not character or not util.validate_character(character) then
			return false
		end

		return client_util.wallrun.near_wall(character.instance)
	end,

	grounded = function(): boolean?
		const character = CHARACTER_GET()
		if not character or not util.validate_character(character) then
			return nil
		end

		return grounded(character.instance)
	end,
}
