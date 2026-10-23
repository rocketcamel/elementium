local storage = require "../../../../ServerScriptService/server/storage"

local function get_player_permissions(player: Player): { string }?
	local session = storage.get_session(player)
	if not session then return nil end

	local meta = session.profile.Data.meta
	return meta and meta.permissions or nil
end

return function(registry)
	registry:RegisterHook("BeforeRun", function(context): string?
		local command_rank = string.lower(context.Group)
		local ok, permissions = pcall(get_player_permissions, context.Executor)

		if not ok then return `player has not loaded yet` end

		if not permissions or not table.find(permissions, command_rank) then
			return "no permission"
		end

		return nil
	end)
end
