local Players = game:GetService "Players"
local ecs = require "../ReplicatedStorage/shared/ecs"

ecs.create()

Players.PlayerAdded:Connect(function(player)
	local entity = ecs.world:entity()
	ecs.world:set(entity, ecs.components.Player, player)

	player:SetAttribute("entity_id", entity)
end)
