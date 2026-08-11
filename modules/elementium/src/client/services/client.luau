local Players = game:GetService "Players"

local ecs = require "../../shared/ecs"
local jecs = require "../../roblox_packages/jecs"

local function on_add(entity: jecs.Entity, id: number, data: Player)
	if data.Name ~= Players.LocalPlayer.Name then return end

	data:SetAttribute("client_entity_id", entity)
end

return function()
	ecs.world:set(ecs.components.Player, jecs.OnAdd, on_add :: any)
end
