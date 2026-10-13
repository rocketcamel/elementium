local storage = require "../../storage"

return function(registry)
	registry:RegisterHook("BeforeRun", function(context): string?
		local command_rank = string.lower(context.Group)
		local session = storage.get_session(context.Executor)
		if not session then return "not fully loaded yet" end

		local permissions = session:get_player_permissions()

		if not permissions or not table.find(permissions, command_rank) then
			return "no permission"
		end

		return nil
	end)
end
