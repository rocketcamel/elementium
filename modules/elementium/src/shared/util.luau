local ecs = require "./ecs"

type Signal<T...> = {
	Connect: (
		self: Signal<T...>,
		callback: (T...) -> ()
	) -> RBXScriptConnection,
}

local function validate_character(character: ecs.Character)
	if
		character.instance.Parent
		and character.instance:FindFirstChild "Humanoid"
	then
		return true
	else
		return false
	end
end

local function character_hip_height(character: ecs.CharacterModel): number
	local root = character.HumanoidRootPart
	local size_y = root.Size.Y
	local base_height = character.Humanoid.HipHeight + size_y

	return base_height + size_y * 0.5
end

local function collect<T...>(signal: Signal<T...>): (() -> T..., RBXScriptConnection)
	local queue = {}
	local n = 0

	local connection = signal:Connect(function(...)
		table.insert(queue, { ... })
		n += 1
	end)

	return function(): any
		if n == 0 then return end
		n -= 1

		local args: any = table.remove(queue, 1)
		return unpack(args)
	end,
		connection
end

return {
	collect = collect,
	validate_character = validate_character,
	character_hip_height = character_hip_height,
}
