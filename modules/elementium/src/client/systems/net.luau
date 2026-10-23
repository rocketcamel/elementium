local net_util = require "../../shared/net"
local replication = require "../../shared/ecs/replication"

type Snapshot = replication.Snapshot

local snapshots = {}

net_util.client.on_replicate(
	function(snapshot) table.insert(snapshots, snapshot) end
)

local function iter(): ...Snapshot
	if #snapshots == 0 then return end

	return table.remove(snapshots, 1) :: Snapshot
end

local function net()
	for snapshot in iter do
		replication.apply_snapshot(snapshot)
	end
end

return {
	phase = "pre_simulation",
	system = net,
}
