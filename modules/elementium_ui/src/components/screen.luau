local fluid = require "../../roblox_packages/fluid"

local create = fluid.create

type Can<T> = T | () -> T

return function(p: {
	name: Can<string>?,
	enabled: Can<boolean>?,
})
	return create "ScreenGui" {
		Name = p.name,
		Enabled = p.enabled,

		unpack(p :: any),
	}
end
