local conch = require "../../../roblox_packages/conch"
local storage = require "../../storage"
local types = require "../types"

type Session<T> = storage.Session<T>
type Store = storage.Store

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

			if not session.data.meta then
				session.data.meta = {
					permissions = { role },
				}
			else
				if not table.find(session.data.meta.permissions, role) then
					table.insert(session.data.meta.permissions, role)

					return `gave role {role}`
				end
			end
		end,
	})
end

return give_role
