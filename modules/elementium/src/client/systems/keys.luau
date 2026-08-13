local ContextActionService = game:GetService "ContextActionService"
local Players = game:GetService "Players"

local ecs = require "../../shared/ecs"
local jecs = require "../../roblox_packages/jecs"

local world = ecs.world
local components = ecs.components

local function keys()
	ContextActionService:BindAction("dash", function(_, state)
		if state ~= Enum.UserInputState.Begin then return nil end

		local entity_id =
			Players.LocalPlayer:GetAttribute "client_entity_id" :: number?
		assert(entity_id)

		local ability = world:entity()

		local dash = {
			from = Players.LocalPlayer.Name,
			velocity = 100,
			lifetime = 0.15,
			active = false,
		}

		local target =
			workspace:WaitForChild(Players.LocalPlayer.Name) :: ecs.CharacterModel

		print(ability, dash, target)

		jecs.bulk_insert(
			world,
			ability,
			{ components.Dash, components.DashTarget },
			{ dash, target }
		)

		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Q)
end

return {
	phase = "startup",
	system = keys,
}
