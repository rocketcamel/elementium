local ecs = require "../../shared/ecs"
local jecs = require "../../roblox_packages/jecs"
local net = require "../../shared/ecs/net"

local world = ecs.world

local server_entity_map = {}

local function networking()
	net.client.on_replicate_snapshot(function(snapshot) print(snapshot) end)
end

return {
	phase = "startup",
	system = networking,
}
