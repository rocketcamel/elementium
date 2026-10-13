local component = require "../util/component"
local fluid = require "../../roblox_packages/fluid"

local create = fluid.create
local read = fluid.read

type Can<T> = T | () -> T

return component(function(
	p: {
		color: Can<Color3>?,
		transparency: Can<number>?,
		scaling: boolean?,

		corner: Can<number>?,

		clips: Can<boolean>?,
	},
	_
)
	local properties: any = {
		BackgroundColor3 = p.color,
		ClipsDescendants = p.clips or false,
		Transparency = if p.color then p.transparency else p.transparency or 1,
	}

	if p.corner then
		table.insert(
			properties,
			create "UICorner" {
				CornerRadius = function() return UDim.new(0, read(p.corner)) end,
			}
		)
	end

	return create "Frame"(properties)
end)
