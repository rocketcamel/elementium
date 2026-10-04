local abilities = require "../../shared/abilities"
local ecs = require "../../shared/ecs"
local jecs = require "../../roblox_packages/jecs"
local types = require "../../shared/types"
local util = require "../../shared/util"

local world = ecs.world
local components = ecs.components
local pair = jecs.pair

type AbilityKind = types.AbilityKind
type Ability = types.Ability

local ability_kind_map = {}

local function cooldown(duration: number): number return os.clock() + duration end

local function activate(ability: Ability)
	local kind = ability.kind
	if ability.cooldown then return end

	local definition = abilities[kind]

	if definition.trigger == "press" then
		definition.fire()
	else
		ability.charge = os.clock()
	end
end

local function deactivate(ability: Ability)
	local definition = abilities[ability.kind]
	if ability.cooldown or not ability.charge then return end

	if definition.trigger ~= "release" then return end

	definition.fire()

	ability.casted = true
	ability.charge = nil
	ability.cooldown = cooldown(ability.cooldown_duration)
end

local function grant(kind: AbilityKind, container: Instance, name: string)
	if ability_kind_map[kind] then return end

	local ability: Ability = {
		kind = kind,
		name = name,
		casted = false,
		cooldown_duration = 1,
	}

	local instance = Instance.new "Tool"
	instance.Parent = container
	instance.Name = name
	instance.RequiresHandle = false
	instance.CanBeDropped = false

	instance.Activated:Connect(function() activate(ability) end)
	instance.Deactivated:Connect(function() deactivate(ability) end)

	ability.binding = instance

	ability_kind_map[kind] = ability
end

local function revoke(kind: AbilityKind) ability_kind_map[kind] = nil end

local function reconcile_cooldown(ability: Ability)
	if not ability.binding then return end

	if ability.cooldown then
		local remaining = ability.cooldown - os.clock()

		if remaining >= 0 then
			ability.binding.Name =
				`{ability.name} ({string.format("%.1f", remaining)})`
		else
			ability.cooldown = nil
		end
	else
		ability.binding.Name = ability.name
	end
end

local function hotbar()
	for kind, ability in ability_kind_map do
		reconcile_cooldown(ability)
	end
end

return {
	phase = "post_simulation",
	system = hotbar,
	create_abilities = function(player: Player)
		local container = player.Backpack

		grant("fireball", container, "Firey blow")
	end,

	grant = grant,
	revoke = revoke,
}
