local net_util = require "../../../ReplicatedStorage/shared/net"
local replication = require "../../../ReplicatedStorage/shared/ecs/replication"

local function net()
	local snapshot = replication.generate_snapshot()
	if next(snapshot) then net_util.server.replicate(snapshot) end
end

return {
	system = net,
	phase = "post_simulation",
}
