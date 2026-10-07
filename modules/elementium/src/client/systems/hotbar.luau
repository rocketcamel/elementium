local Players = game:GetService "Players"
local UserInputService = game:GetService "UserInputService"

local abilities = require "../../shared/abilities"
local ecs = require "../../shared/ecs"
local jecs = require "../../roblox_packages/jecs"
local util = require "../../shared/util"

local world = ecs.world
local components = ecs.components

type AbilityKind = ecs.AbilityKind

local ability_entity_map = {}

world:set(components.Hotbar, jecs.OnRemove, function(entity, id)
	local data = world:get(entity, components.Hotbar)
	if data and data.binding then data.binding:Destroy() end
end)

local function get_mouse_vector(character: ecs.Character): Vector3
	local camera = workspace.CurrentCamera
	assert(camera)

	local location = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(location.X, location.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character.instance }

	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)

	local target = if result
		then result.Position
		else ray.Origin + ray.Direction * 1000

	return target
end

local function get_direction_fatal(): Vector3
	local character = util.get_character(Players.LocalPlayer) :: ecs.Character
	assert(util.validate_character(character))

	return get_mouse_vector(character)
end

local function cooldown(duration: number): number return os.clock() + duration end

local function activate(item: ecs.Hotbar)
	local kind = item.kind
	if item.cooldown then return end

	local definition = abilities[kind]
	local direction = get_direction_fatal()

	if definition.trigger == "press" then
		definition.fire(direction)
	else
		item.charge = os.clock()
	end
end

local function deactivate(item: ecs.Hotbar)
	local definition = abilities[item.kind]
	local direction = get_direction_fatal()
	if item.cooldown or not item.charge then return end

	if definition.trigger ~= "release" then return end

	definition.fire(direction)

	item.charge = nil
	item.cooldown = cooldown(item.cooldown_duration)
end

local function grant(kind: AbilityKind, container: Instance, name: string)
	if ability_entity_map[kind] then return end

	local item: ecs.Hotbar = {
		kind = kind,
		name = name,
		cooldown_duration = 1,
	}

	local instance = Instance.new "Tool"
	instance.Parent = container
	instance.Name = name
	instance.RequiresHandle = false
	instance.CanBeDropped = false

	instance.Activated:Connect(function() activate(item) end)
	instance.Deactivated:Connect(function() deactivate(item) end)

	item.binding = instance

	local entity = world:entity()
	world:set(entity, components.Hotbar, item)

	ability_entity_map[kind] = entity
end

local function revoke(kind: AbilityKind)
	local entity = ability_entity_map[kind]

	if entity and world:contains(entity) then world:delete(entity) end

	ability_entity_map[kind] = nil
end

local function reconcile_cooldown(item: ecs.Hotbar)
	if not item.binding then return end

	if item.cooldown then
		local remaining = item.cooldown - os.clock()

		if remaining >= 0 then
			item.binding.Name =
				`{item.name} ({string.format("%.1f", remaining)})`
		else
			item.cooldown = nil
		end
	else
		item.binding.Name = item.name
	end
end

local query = world:query(components.Hotbar):cached()

local function hotbar()
	for entity, hotbar in query do
		reconcile_cooldown(hotbar)
	end
end

return {
	phase = "post_simulation",
	system = hotbar,
	create_abilities = function(player: Player)
		local container = player.Backpack

		grant("firey_blow", container, "Firey blow")
	end,

	grant = grant,
	revoke = revoke,
}
