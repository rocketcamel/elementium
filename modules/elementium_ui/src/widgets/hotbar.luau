local component = require "../util/component"
local container = require "../components/container"
local fluid = require "../../roblox_packages/fluid"

local create = fluid.create

return component(function(p: {}, _)
	return container {
		h = 200,
	}
end)
