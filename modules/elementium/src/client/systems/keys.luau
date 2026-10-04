local ReplicatedStorage = game:GetService "ReplicatedStorage"

local ecs = require "../../shared/ecs"
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

local movement_cooldown_map = {}

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

local function apply_cooldown(kind: ecs.MovementKind, duration: number)
	movement_cooldown_map[kind] = os.clock() + duration
end

local function cooldown(kind: ecs.MovementKind)
	local result = movement_cooldown_map[kind]

	if result then
		local remaining = result - os.clock()
		return remaining >= 0
	end

	return false
end

return {
	phase = "startup",
	system = function()
		local registry = create()

		registry:register("dash", Enum.InputActionType.Bool, function(pressed)
			assert(typeof(pressed) == "boolean")

			if pressed and not cooldown "dash" then
				movement.dash(0.38)
				apply_cooldown("dash", 2)
			end
		end, Enum.KeyCode.Q)

		registry:register(
			"dash_endjump",
			Enum.InputActionType.Bool,
			function(pressed)
				assert(typeof(pressed) == "boolean")

				if pressed and movement.current() == "dash" then
					movement.dash_endjump()
				elseif
					pressed
					and not movement.current()
					and not movement.grounded()
				then
					movement.double_jump()
				end
			end,
			Enum.KeyCode.Space
		)
	end,
}
