local net = require "../ecs/net"

local function noop() end

type Storage = ReplicatedStorage & {
	storage: Folder & {
		firey_blow: Model & {
			Primary: BasePart,
		},
	},
}

local ability = {
	trigger = "release" :: "release" | "press",
	max_charge = 2,
	cooldown = 1,
	fire = noop,
}

function ability.fire(direction: Vector3)
	net.client.report_ability("firey_blow", direction)
end

return ability
