const Players = game:GetService "Players"

const camera = require "./camera"
const client_util = require "../util"
const ecs = require "../../shared/ecs"
const net = require "../../shared/net"
const util = require "../../shared/util"

const world = ecs.world
const components = ecs.components

world:set(components.Movement, components.Movement, { air_jump = 1 })

const DASH_VELOCITY = 80

const function GET(): ecs.Movement
	return world:get(components.Movement, components.Movement) :: ecs.Movement
end

const function SET(data: ecs.Movement)
	world:set(components.Movement, components.Movement, data)
end

const function CHARACTER_GET(): ecs.Character?
	const entity_id =
		Players.LocalPlayer:GetAttribute "client_entity_id" :: number

	if entity_id then
		const character =
			world:get(entity_id, components.Character, components.Character)
		return character
	end

	return nil
end

const function grounded(character: ecs.Character)
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character.instance }

	const root = character.instance.HumanoidRootPart
	const hip_height = util.character_hip_height(character.instance)
	const direction = hip_height + 1

	const result =
		workspace:Raycast(root.Position, Vector3.yAxis * -direction, params)

	return result and result.Distance <= hip_height + 0.2
end

const function MOVEMENT_END(movement: ecs.Movement): ecs.MovementKind?
	if not movement.current then return nil end
	const character = CHARACTER_GET()

	movement.previous = movement.current.kind

	const current = movement.current
	const kind = movement.current.kind

	if current.kind == "dash" then
		if current.linear_velocity then current.linear_velocity:Destroy() end
		current.animation_track:Stop()
	elseif current.kind == "dash_endjump" then
		current.animation_track:Stop()
		if current.linear_velocity then current.linear_velocity:Destroy() end
	elseif current.kind == "side_dash" or current.kind == "double_jump" then
		if current.linear_velocity then current.linear_velocity:Destroy() end
	elseif current.kind == "wallrun" then
		if current.linear_velocity then current.linear_velocity:Destroy() end
		current.animation_track:Stop()

		if character and util.validate_character(character) then
			client_util.state_jump(character.instance, true)
		end
	end

	movement.current = nil

	return kind
end

const function ensure_linear_velocity(
	character: ecs.CharacterModel,
	movement: ecs.Movement
): LinearVelocity
	assert(movement.current)

	local linear_velocity = movement.current.linear_velocity :: LinearVelocity
	const current = movement.current

	if not linear_velocity then
		linear_velocity = Instance.new "LinearVelocity"
		linear_velocity.Parent = character
		linear_velocity.MaxForce = 50000
		linear_velocity.Attachment0 = character.HumanoidRootPart.RootAttachment

		if current.kind == "double_jump" then
			linear_velocity.VelocityConstraintMode =
				Enum.VelocityConstraintMode.Line
			linear_velocity.LineDirection = Vector3.yAxis
		end

		movement.current.linear_velocity = linear_velocity
	end

	if current.kind == "double_jump" then
		linear_velocity.LineVelocity = movement.current.vector.Y
	else
		linear_velocity.VectorVelocity = movement.current.vector
	end

	return linear_velocity
end

const function get_dash_vector(character: ecs.CharacterModel): Vector3
	const forward_vector = character.HumanoidRootPart.CFrame.LookVector
	return Vector3.new(forward_vector.X, 0, forward_vector.Z) * DASH_VELOCITY
end

const function movement()
	const movement, character = GET(), CHARACTER_GET()

	if not character or not util.validate_character(character) then return end
	if grounded(character) then movement.air_jump = 1 end
	if not movement.current then return end

	const current = movement.current

	if current.kind == "dash" then
		const dash_vector = get_dash_vector(character.instance)
		current.vector = dash_vector
	end

	if current.kind == "wallrun" then
		const wall = client_util.wallrun.get_wall(character.instance)
		if not wall then
			MOVEMENT_END(movement)
			return
		end

		const tangent =
			client_util.wallrun.wall_tangent(character.instance, wall)
		const result = client_util.wallrun.correct(
			character.instance,
			wall,
			tangent,
			character.instance.HumanoidRootPart.AssemblyLinearVelocity
		)

		current.vector = result
	end

	ensure_linear_velocity(character.instance, movement)

	if
		current.kind == "dash"
		or current.kind == "dash_endjump"
		or current.kind == "side_dash"
		or current.kind == "double_jump"
	then
		if (current.lifetime - os.clock()) <= 0 then MOVEMENT_END(movement) end
	end
end

const function dash(lifetime: number)
	const movement, character = GET(), CHARACTER_GET()

	if not character or not util.validate_character(character) then return end
	MOVEMENT_END(movement)

	const dash_vector = character.instance.HumanoidRootPart.CFrame.LookVector
		* DASH_VELOCITY

	const animation = Instance.new "Animation"
	animation.AnimationId = util.retrieve_animation "dash"

	const track = character.instance.Humanoid.Animator:LoadAnimation(animation)

	movement.current = {
		kind = "dash" :: "dash",
		vector = dash_vector,
		animation_track = track,
		lifetime = os.clock() + lifetime,
		linear_velocity = nil,
	} :: ecs.Dash

	net.client.report_movement "dash"
	camera.set_fov(80, lifetime)
	track:Play()

	SET(movement)
end

const function dash_endjump()
	const movement, character = GET(), CHARACTER_GET()

	if not character or not util.validate_character(character) then return end
	MOVEMENT_END(movement)

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
		linear_velocity = nil,
	} :: ecs.Dash_EndJump

	net.client.report_movement "dash_endjump"
	camera.set_fov(75, 0.2)
	track:Play()

	SET(movement)
end

const function side_dash(direction: "left" | "right")
	const movement, character = GET(), CHARACTER_GET()
	if not character or not util.validate_character(character) then return end
	MOVEMENT_END(movement)

	const cframe = character.instance.HumanoidRootPart.CFrame
	const direction_vector = if direction == "left"
		then -cframe.RightVector
		else cframe.RightVector

	const result = direction_vector * 40

	movement.current = {
		kind = "side_dash",
		vector = result,
		lifetime = os.clock() + 0.2,
		linear_velocity = nil,
	} :: ecs.SideDash

	SET(movement)
end

const JUMP_MAGNITUDE = 50

const function double_jump()
	local movement = GET()
	local character = CHARACTER_GET()

	if
		not character
		or movement.air_jump == 0
		or not util.validate_character(character)
	then
		return
	end

	MOVEMENT_END(movement)

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

	SET(movement)
end

const function wallrun()
	const movement, character = GET(), CHARACTER_GET()

	if not character or not util.validate_character(character) then return end

	const wall, side = client_util.wallrun.get_wall(character.instance)
	if not wall then return end
	MOVEMENT_END(movement)
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

	SET(movement)
end

const function wallrun_end()
	const movement = GET()

	if not movement then return end
	local current = movement.current

	if current and current.kind == "wallrun" then MOVEMENT_END(movement) end
end

const function current_movement(): ecs.MovementKind?
	const movement = GET()
	if movement.current then return movement.current.kind end

	return nil
end

const function previous_movement(): ecs.MovementKind?
	const movement = GET()
	if movement.previous then return movement.previous end

	return nil
end

return {
	phase = "update",
	system = movement,

	dash = dash,
	dash_endjump = dash_endjump,
	side_dash = side_dash,
	double_jump = double_jump,
	wallrun = wallrun,
	wallrun_end = wallrun_end,
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

		return grounded(character)
	end,

	current = current_movement,
	previous = previous_movement,
}
