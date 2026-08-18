local conch = require "../../../roblox_packages/conch"
local storage = require "../../storage"
local types = require "../types"

type Session<T> = storage.Session<T>
type Store = storage.Store

local function give_role_action(data: Store, role: string): Store
	if not data.meta then
		data.meta = {
			permissions = { role },
		}
	else
		if not table.find(data.meta.permissions, role) then
			table.insert(data.meta.permissions, role)
		end
	end

	return data
end

local function give_role()
	conch.register("give_role", {
		description = "gives a player the specified role",
		permissions = { "handout" },
		arguments = function()
			return conch.args.player("player", "the player receiving the role"),
				types.roles()
		end,

		callback = function(player, role)
			local session = storage.get_session(player)
			if not session then
				error(
					`player has no session, wait until they have fully loaded`
				)
			end

			session:patch(give_role_action, role)

			return `gave role {role}`
		end,
	})
end

return give_role
