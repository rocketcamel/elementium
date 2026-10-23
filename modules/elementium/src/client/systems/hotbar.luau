local Players = game:GetService "Players"
local UserInputService = game:GetService "UserInputService"

local definitions = require "../../shared/abilities"
local ecs = require "../../shared/ecs"
local util = require "../../shared/util"

local world = ecs.world
local components = ecs.components

local function GET(): { ecs.ElementMove }?
	local entity = util.player_entity_id(Players.LocalPlayer)
	if not entity then return nil end

	return world:get(entity, components.Element)
end

local function BINDING_GET(kind: ecs.AbilityKind): Tool?
	local entity = util.player_entity_id(Players.LocalPlayer)
	if not entity then return nil end

	local bindings = world:get(entity, components.ElementBindings)
	if not bindings then
		world:set(
			entity,
			components.ElementBindings,
			{} :: { [ecs.AbilityKind]: Tool? }
		)
		return nil
	end

	return bindings[kind]
end

local function BINDING_SET(kind: ecs.AbilityKind, value: Tool)
	local entity = util.player_entity_id(Players.LocalPlayer)
	assert(entity)

	local bindings = world:get(entity, components.ElementBindings)
	if not bindings then return end

	bindings[kind] = value

	world:set(entity, components.ElementBindings, bindings)
end

local function VALID_BINDING(player: Player, binding: Tool)
	local backpack = player.Backpack
	local character = player.Character
	local parent = binding.Parent

	return parent ~= nil
		and (
			(backpack ~= nil and parent == backpack)
			or (character ~= nil and parent == character)
		)
end

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

local function activate(move: ecs.ElementMove)
	if move.cooldown then return end

	local definition = definitions[move.kind]
	local direction = get_direction_fatal()

	if definition.trigger == "press" then
		definition.fire(direction)
	else
		move.charge = os.clock()
	end
end

local function deactivate(move: ecs.ElementMove)
	if move.cooldown or not move.charge then return end

	local definition = definitions[move.kind]
	local direction = get_direction_fatal()

	definition.fire(direction)
	move.charge = nil
	move.cooldown = cooldown(definition.cooldown)
end

local function create_binding(player: Player, move: ecs.ElementMove): Tool
	local definition = definitions[move.kind]

	local instance = Instance.new "Tool"
	instance.Parent = player.Backpack
	instance.Name = definition.name
	instance.RequiresHandle = false
	instance.CanBeDropped = false

	instance.Activated:Connect(function() activate(move) end)
	instance.Deactivated:Connect(function() deactivate(move) end)

	return instance
end

local function reconcile_binding(
	player: Player,
	move: ecs.ElementMove,
	binding: Tool?
)
	if binding and not VALID_BINDING(player, binding) then
		move.binding = nil
		move.charge = nil
		move.cooldown = nil

		binding:Destroy()
		binding = (nil :: any) :: Tool
	end

	if not binding then
		binding = create_binding(player, move)
		BINDING_SET(move.kind, binding)
	end
	assert(binding)

	local definition = definitions[move.kind]

	if move.cooldown then
		local remaining = move.cooldown - os.clock()

		if remaining >= 0 then
			binding.Name =
				`{definition.name} ({string.format("%.1f", remaining)})`
		else
			move.cooldown = nil
		end
	else
		binding.Name = definition.name
	end
end

local function hotbar()
	local moves = GET()
	if not moves then return end

	for _, move in moves do
		local binding = BINDING_GET(move.kind)
		reconcile_binding(Players.LocalPlayer, move, binding)
	end
end

return {
	phase = "update",
	system = hotbar,
}
