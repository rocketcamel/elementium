local Players = game:GetService "Players"
local hotbar = require "./hotbar"

local function spawn()
	local added = {}
	local n = 0

	Players.LocalPlayer.CharacterAdded:Connect(function()
		table.insert(added, Players.LocalPlayer)
		n += 1
	end)

	local function iter(): ...Player
		if n == 0 then return end
		n -= 1

		return table.remove(added, 1) :: Player
	end

	return function()
		for player in iter do
			hotbar.create_abilities(player)
		end
	end
end

return {
	name = "spawn",
	phase = "post_simulation",
	system = spawn(),
}
