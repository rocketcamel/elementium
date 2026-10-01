local Players = game:GetService "Players"

local camera = require "./camera"
local ecs = require "../../shared/ecs"
local net = require "../../shared/ecs/net"
local util = require "../../shared/util"

local world = ecs.world
local components = ecs.components

world:set(components.Ability, components.Ability, {})

local DASH_VELOCITY = 80

local function GET(): ecs.Ability
	return world:get(components.Ability, components.Ability) :: ecs.Ability
end

local function SET(data: ecs.Ability)
	world:set(components.Ability, components.Ability, data)
end

local function CHARACTER_GET(): ecs.Character?
	local entity_id =
		Players.LocalPlayer:GetAttribute "client_entity_id" :: number

	if entity_id then
		local character =
			world:get(entity_id, components.Character, components.Character)
		return character
	end

	return nil
end

local function grounded(character: ecs.Character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character.instance }

	local root = character.instance.HumanoidRootPart
	local hip_height = util.character_hip_height(character.instance)
	local direction = hip_height + 1

	local result =
		workspace:Raycast(root.Position, Vector3.yAxis * -direction, params)

	return result and result.Distance <= hip_height + 0.2
end

local function ABILITY_END(ability: ecs.Ability): ecs.AbilityKind?
	if not ability.current then return nil end

	ability.previous = ability.current.kind

	local current = ability.current
	local kind = ability.current.kind

	if current.kind == "dash" then
		if current.linear_velocity then current.linear_velocity:Destroy() end
		current.animation_track:Stop()
	elseif current.kind == "dash_endjump" then
		current.animation_track:Stop()
		if current.linear_velocity then current.linear_velocity:Destroy() end
	elseif current.kind == "double_jump" then
		if current.linear_velocity then current.linear_velocity:Destroy() end
	end

	ability.current = nil

	return kind
end

local function ensure_linear_velocity(
	character: ecs.CharacterModel,
	ability: ecs.Ability
): LinearVelocity
	assert(ability.current)

	local linear_velocity = ability.current.linear_velocity :: LinearVelocity
	local current = ability.current

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

		ability.current.linear_velocity = linear_velocity
	end

	if current.kind == "double_jump" then
		linear_velocity.LineVelocity = ability.current.vector.Y
	else
		linear_velocity.VectorVelocity = ability.current.vector
	end

	return linear_velocity
end

local function get_dash_vector(character: ecs.CharacterModel): Vector3
	local forward_vector = character.HumanoidRootPart.CFrame.LookVector
	return Vector3.new(forward_vector.X, 0, forward_vector.Z) * DASH_VELOCITY
end

local function movement()
	local ability = GET()
	local character = CHARACTER_GET()

	if
		not ability.current
		or not (character and util.validate_character(character))
	then
		return
	end

	local current = ability.current

	if current.kind == "dash" then
		local dash_vector = get_dash_vector(character.instance)
		current.vector = dash_vector
	end

	ensure_linear_velocity(character.instance, ability)

	if (current.lifetime - os.clock()) <= 0 then ABILITY_END(ability) end
end

local function dash(lifetime: number)
	local ability = GET()
	local character = CHARACTER_GET()

	if not character then return end
	ABILITY_END(ability)

	local dash_vector = character.instance.HumanoidRootPart.CFrame.LookVector
		* DASH_VELOCITY

	local animation = Instance.new "Animation"
	animation.AnimationId = "rbxassetid://127131740639392"

	local track = character.instance.Humanoid.Animator:LoadAnimation(animation)

	ability.current = {
		kind = "dash" :: "dash",
		vector = dash_vector,
		animation_track = track,
		lifetime = os.clock() + lifetime,
		linear_velocity = nil,
	} :: ecs.Dash

	net.client.report_ability "dash"
	camera.set_fov(80, lifetime)
	track:Play()

	SET(ability)
end

local function dash_endjump()
	local ability = GET()
	local character = CHARACTER_GET()

	if not character then return end
	ABILITY_END(ability)

	local look_vector = character.instance.HumanoidRootPart.CFrame.LookVector

	local forward = Vector3.new(look_vector.X, 0, look_vector.Z).Unit

	local angle = math.rad(30)
	local direction = forward * math.cos(angle)
		+ Vector3.yAxis * math.sin(angle)

	local result = direction * DASH_VELOCITY

	local animation = Instance.new "Animation"
	animation.AnimationId = "rbxassetid://78316629769786"

	local track = character.instance.Humanoid.Animator:LoadAnimation(animation)

	ability.current = {
		kind = "dash_endjump",
		vector = result,
		lifetime = os.clock() + 0.2,
		animation_track = track,
		linear_velocity = nil,
	} :: ecs.Dash_EndJump

	net.client.report_ability "dash_endjump"
	camera.set_fov(75, 0.2)
	track:Play()

	SET(ability)
end

local JUMP_MAGNITUDE = 50

local function double_jump()
	local ability = GET()
	local character = CHARACTER_GET()

	if not character then return end
	ABILITY_END(ability)

	local result = Vector3.yAxis * JUMP_MAGNITUDE

	ability.current = {
		kind = "double_jump" :: "double_jump",
		vector = result,
		lifetime = os.clock() + 0.2,
		linear_velocity = nil,
	} :: ecs.DoubleJump

	net.client.report_ability "double_jump"

	SET(ability)
end

local function current_ability(): ecs.AbilityKind?
	local ability = GET()
	if ability.current then return ability.current.kind end

	return nil
end

return {
	phase = "post_simulation",
	system = movement,

	dash = dash,
	dash_endjump = dash_endjump,
	double_jump = double_jump,

	grounded = function(): boolean?
		local character = CHARACTER_GET()
		if not character or not util.validate_character(character) then
			return nil
		end

		return grounded(character)
	end,

	current = current_ability,
}
