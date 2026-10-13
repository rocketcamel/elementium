local ecs = require "../../shared/ecs"

export type Side = "left" | "right"

local function get_wall(character: ecs.CharacterModel): (RaycastResult?, Side?)
	local root = character.HumanoidRootPart

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local function attempt(side: "left" | "right")
		local direction = if side == "right"
			then root.CFrame.RightVector
			else -root.CFrame.RightVector

		return workspace:Raycast(root.Position, direction * 3, params), side
	end

	local result, side = attempt "left"
	if not result then
		result, side = attempt "right"
	end

	if result and math.abs(result.Normal.Y) > 0.3 then return nil, nil end

	return result, side
end

local function near_wall(character: ecs.CharacterModel): boolean
	return get_wall(character) ~= nil
end

local function wall_tangent(
	character: ecs.CharacterModel,
	wall: RaycastResult
): Vector3
	local tangent = Vector3.yAxis:Cross(wall.Normal).Unit
	local root = character.HumanoidRootPart
	local desired_direction = root.CFrame.LookVector

	-- ensure running direction matches desired
	if tangent:Dot(desired_direction) < 0 then tangent = -tangent end

	return tangent
end

local function correct(
	character: ecs.CharacterModel,
	wall: RaycastResult,
	tangent: Vector3,
	speed: Vector3
): Vector3
	local error = wall.Distance - 1.5
	local correction = -wall.Normal * (error / 0.1)
	local along_wall_velocity = math.max(25, speed:Dot(tangent))

	return tangent * along_wall_velocity + correction
end

return {
	get_wall = get_wall,
	near_wall = near_wall,
	wall_tangent = wall_tangent,
	correct = correct,
}
