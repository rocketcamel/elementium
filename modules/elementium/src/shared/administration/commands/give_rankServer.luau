local storage = require "../../../../ServerScriptService/server/storage"

local function display(player: Player): string
	if player.DisplayName ~= player.Name then
		return `{player.DisplayName} @({player.Name})`
	else
		return player.DisplayName
	end
end

local function give_rank_action(player: Player, rank: string)
	local session = storage.get_session(player)
	assert(session)

	session:patch(function(data)
		local meta = data.meta

		if not meta then
			meta = {
				permissions = { rank },
			}
		else
			table.insert(meta.permissions, rank)
		end

		return data
	end)
end

local function give_rank(
	context: unknown,
	players: { Player },
	rank: string
): string
	local names = {}
	local issues = {}

	for _, player in players do
		local ok = pcall(give_rank_action, player, rank)
		if not ok then table.insert(issues, display(player)) end
	end

	local success = `gave rank {rank} to {table.concat(names, ",")}`
	if #issues > 0 then
		return `{success}, failed: {table.concat(issues, ",")}`
	else
		return success
	end
end

return give_rank
