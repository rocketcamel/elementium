local air_physics = require "../air_physics"
local composer = require "../velocity_compose"
local ecs = require "../../../shared/ecs"
local jecs = require "../../../roblox_packages/jecs"
local util = require "../../util"

local world = ecs.world
local components = ecs.components

local WALLRUN_DISTANCE = 6
local WALLRUN_MIN_SPEED = 20
local WALLRUN_LOCK_SPEED = 15
local WALLRUN_MAX_VERT = 24
local WALLRUN_MIN_VERT = -45
local WALLRUN_CONSERVE = 0.5

world:set(components.Wallrun, jecs.OnRemove, function(entity, id)
	local wallrun = world:get(entity, components.Wallrun)
	local target = world:get(entity, components.AbilityTarget)
	if not wallrun then return end

	if target then
		if wallrun.animation_slot then
			util.stop_track(wallrun.animation_slot, target)
		end

		target.Humanoid:SetStateEnabled(
			Enum.HumanoidStateType.FallingDown,
			true
		)

		local velocity = target.HumanoidRootPart.AssemblyLinearVelocity

		if wallrun.active and velocity.Magnitude > 20 then
			local air_entity = world:entity()

			world:set(air_entity, air_physics.AirMomentum, {
				source = "wallrun" :: "wallrun",
				velocity = velocity,
			})
		end
	end

	composer.remove_impulse(wallrun.id)

	if wallrun.orient_handle then wallrun.orient_handle:Destroy() end
end)

local function movement_wallrun(
	entity: jecs.Entity,
	target: ecs.CharacterModel,
	wallrun: ecs.Wallrun
)
	local orient = Instance.new "AlignOrientation"
	orient.Parent = target
	orient.Attachment0 = target.HumanoidRootPart.RootAttachment
	orient.MaxTorque = 50000
	orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orient.RigidityEnabled = true

	wallrun.orient_handle = orient

	local animation_slot =
		util.animate("rbxassetid://118646674087775", target, { loop = true })
	wallrun.animation_slot = animation_slot

	world:set(entity, components.Wallrun, wallrun)

	target.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
end

local function get_wall(
	target: ecs.CharacterModel,
	side: "left" | "right"
): RaycastResult
	local root = target.HumanoidRootPart

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { target }

	local direction = if side == "right"
		then root.CFrame.RightVector
		else -root.CFrame.RightVector

	return workspace:Raycast(
		root.Position,
		direction * WALLRUN_DISTANCE,
		params
	) :: RaycastResult
end

local function find_wall(
	target: ecs.CharacterModel
): (RaycastResult?, "left" | "right"?)
	local right = get_wall(target, "right")

	if right and math.abs(right.Normal.Y) < 0.2 then return right, "right" end

	local left = get_wall(target, "left")

	if left and math.abs(left.Normal.Y) < 0.2 then return left, "left" end

	return nil, nil
end

local function wallrun_get_vector(
	entity: jecs.Entity,
	target: ecs.CharacterModel,
	wallrun: ecs.Wallrun,
	delta: number
): (Vector3?, ("left" | "right")?)
	local wall, side = find_wall(target)

	if not wall or math.abs(wall.Normal.Y) >= 0.2 then
		world:delete(entity)
		return nil, nil
	end

	local tangent = wall.Normal:Cross(Vector3.yAxis).Unit

	assert(wallrun.vector)
	assert(wallrun.velocity)
	assert(wallrun.vertical_velocity)

	if tangent:Dot(wallrun.vector) < 0 then tangent = -tangent end

	local distance_error = wall.Distance - 1.5
	local correction = -wall.Normal * math.clamp(distance_error * 10, -8, 8)

	wallrun.vertical_velocity = math.max(
		(wallrun.vertical_velocity or 0) - 45 * delta,
		WALLRUN_MIN_VERT
	)

	return tangent * wallrun.velocity
		+ correction
		+ Vector3.yAxis * wallrun.vertical_velocity,
		side
end

local query = world:query(components.Wallrun, components.AbilityTarget):cached()

local function wallrun(delta: number)
	for entity, wallrun, target in query do
		if not target then continue end

		if not wallrun.active then
			local root = target.HumanoidRootPart
			local wall, side = find_wall(target)

			print(side)

			if not wall or not side then
				world:delete(entity)
				return
			end

			local horizontal_velocity = Vector3.new(
				root.AssemblyLinearVelocity.X,
				0,
				root.AssemblyLinearVelocity.Z
			)

			local speed =
				math.max(horizontal_velocity.Magnitude, WALLRUN_MIN_SPEED)
			local direction = wall.Normal:Cross(Vector3.yAxis).Unit

			if direction:Dot(horizontal_velocity) < 0 then
				direction = -direction
			end

			local vertical_velocity = math.clamp(
				math.max(root.AssemblyLinearVelocity.Y, 0) * WALLRUN_CONSERVE,
				0,
				WALLRUN_MAX_VERT
			)

			local vector_velocity = direction * speed
				+ -wall.Normal * WALLRUN_LOCK_SPEED
				+ Vector3.yAxis * vertical_velocity

			local id = composer.add_impulse {
				group = "wallrun",
				velocity = 0,
				direction = Vector3.zero,
				vector_velocity = vector_velocity,
				lifetime = math.huge,
				exclusive = true,
			}

			wallrun.active = true
			wallrun.id = id
			wallrun.vector = vector_velocity
			wallrun.velocity = speed
			wallrun.vertical_velocity = vertical_velocity
			wallrun.side = side

			world:set(entity, components.Wallrun, wallrun)

			movement_wallrun(entity, target, wallrun)
		end

		if target.Humanoid.FloorMaterial ~= Enum.Material.Air then
			world:delete(entity)
			continue
		end

		local vector_velocity, side =
			wallrun_get_vector(entity, target, wallrun, delta)

		if vector_velocity and side then
			wallrun.side = side
			wallrun.vector = vector_velocity

			composer.update(wallrun.id, {
				vector_velocity = vector_velocity,
			})
		end

		assert(wallrun.orient_handle)
		local wallrun_vector = wallrun.vector :: Vector3

		wallrun.orient_handle.CFrame = CFrame.lookAt(
			Vector3.zero,
			Vector3.new(wallrun_vector.X, 0, wallrun_vector.Z).Unit
		)
	end
end

return {
	phase = "movement",
	system = wallrun,

	near_wall = function(target: ecs.CharacterModel?)
		if not target or not target:FindFirstChild "Humanoid" then
			return false
		end

		return find_wall(target) ~= nil
	end,
}
