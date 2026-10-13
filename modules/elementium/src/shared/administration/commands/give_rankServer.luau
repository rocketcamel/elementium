local storage = require "../../storage"

type Session<T> = storage.Session<T>
type Store = storage.Store

local function give_rank_action(data: Store, rank: string): Store
	if not data.meta then
		data.meta = {
			permissions = { rank },
		}
	else
		if not table.find(data.meta.permissions, rank) then
			table.insert(data.meta.permissions, rank)
		end
	end

	return data
end

local function give_rank(
	context: unknown,
	players: { Player },
	rank: string
): string
	local names = {}

	for _, player in players do
		local session = storage.get_session(player)
		if not session then
			return "player has no session, wait until they have fully loaded"
		end

		session:patch(give_rank_action, rank)
		table.insert(names, player.Name)
	end

	return `gave rank {rank} to {table.concat(names, ",")}`
end

return give_rank
