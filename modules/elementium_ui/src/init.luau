local Players = game:GetService "Players"

local app = require "@self/app"
local fluid = require "./roblox_packages/fluid"

local mounted = false
local function mount()
	if mounted then return end
	mounted = true
	fluid.mount(app :: any, Players.LocalPlayer:WaitForChild "PlayerGui")
end

return {
	app = app,
	mount = mount,
}
