local ReplicatedStorage = game:GetService "ReplicatedStorage"

local movement = require "./movement"

export type Registry = {
	folder: Folder,
	play_context: InputContext,

	register: (
		self: Registry,
		name: string,
		type: Enum.InputActionType,
		fn: (...unknown) -> (),
		...Enum.KeyCode
	) -> (),
}

local function register(
	registry: Registry,
	name: string,
	type: Enum.InputActionType,
	fn: (...unknown) -> (),
	...: Enum.KeyCode
)
	local action = Instance.new "InputAction"
	action.Parent = registry.play_context
	action.Name = name
	action.Type = type

	for _, key_code in { ... } do
		local binding = Instance.new "InputBinding"
		binding.Parent = action
		binding.Name = "keyboard_bind"
		binding.KeyCode = key_code
	end

	action.StateChanged:Connect(function(...) fn(...) end)
end

local function create(): Registry
	local folder = Instance.new "Folder"
	folder.Parent = ReplicatedStorage
	folder.Name = "inputs"

	local play_context = Instance.new "InputContext"
	play_context.Name = "play_context"
	play_context.Parent = folder

	local registry: Registry = {
		folder = folder,
		play_context = play_context,
		register = register,
	}

	return registry
end

return {
	phase = "startup",
	system = function()
		local registry = create()

		registry:register("dash", Enum.InputActionType.Bool, function(pressed)
			assert(typeof(pressed) == "boolean")

			if pressed then movement.dash(0.38) end
		end, Enum.KeyCode.Q)

		registry:register(
			"dash_endjump",
			Enum.InputActionType.Bool,
			function(pressed)
				assert(typeof(pressed) == "boolean")

				if
					pressed
					and movement.current() == "dash"
					and not movement.grounded()
				then
					movement.dash_endjump()
				end
			end,
			Enum.KeyCode.Space
		)
	end,
}
