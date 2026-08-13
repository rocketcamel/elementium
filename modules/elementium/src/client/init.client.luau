local ContextActionService = game:GetService "ContextActionService"
local Players = game:GetService "Players"

local ecs = require "../ReplicatedStorage/shared/ecs"
local net = require "../ReplicatedStorage/shared/ecs/net"
local services = require "./client/services"
local systems = require "./client/systems"

net.client.create()

ecs.create()
systems.register()
services.register()

local world = ecs.world
local components = ecs.components
local jecs = require "./roblox_packages/jecs"

ContextActionService:BindAction("dash", function(_, state)
	if state ~= Enum.UserInputState.Begin then return nil end

	local entity_id =
		Players.LocalPlayer:GetAttribute "client_entity_id" :: number?
	assert(entity_id)

	local ability = world:entity()

	local dash = {
		from = "rocketcamel2",
		velocity = 100,
		lifetime = 0.15,
		active = false,
	}

	local target = workspace:WaitForChild "rocketcamel2" :: ecs.CharacterModel

	print(ability, dash, target)

	jecs.bulk_insert(
		ecs.world,
		ability,
		{ components.Dash, components.DashTarget },
		{ dash, target }
	)

	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.Q)
