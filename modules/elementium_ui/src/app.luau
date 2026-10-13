local container = require "./components/container"
local hotbar = require "./widgets/hotbar"
local screen = require "./components/screen"

return function()
	return screen {
		name = "Elementium UI",
		enabled = true,

		container {
			ws = 1,
			hs = 1,

			flex = { justify = "fill", align = "bottom" },

			hotbar {},
		},
	}
end
