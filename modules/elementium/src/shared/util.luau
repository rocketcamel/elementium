local ReplicatedStorage = game:GetService "ReplicatedStorage" :: Storage
local RunService = game:GetService "RunService"

local ecs = require "./ecs"
local jecs = require "../roblox_packages/jecs"

local world = ecs.world
local components = ecs.components

export type Storage = ReplicatedStorage & {
	animations: Folder & {
		dash: StringValue,
		dash_endjump: StringValue,
	},
}

local function entity_id(player: Player): jecs.Entity
	local entity_id = if RunService:IsServer()
		then player:GetAttribute "entity_id" :: jecs.Entity?
		else player:GetAttribute "client_entity_id" :: jecs.Entity?
	assert(entity_id, "player has no entity id")

	return entity_id
end

export type Animation = "dash" | "dash_endjump" | "double_jump"

local function retrieve_animation(name: Animation): string
	local result =
		ReplicatedStorage.animations:FindFirstChild(name) :: StringValue?
	assert(result)

	return `rbxassetid://{result.Value}`
end

local function get_character(player: Player): ecs.Character?
	local entity_id = if RunService:IsServer()
		then player:GetAttribute "entity_id" :: jecs.Entity
		else player:GetAttribute "client_entity_id" :: jecs.Entity
	if not entity_id then return nil end

	local character = world:get(entity_id, components.Character)
	if not character then return nil end

	return character
end

local function validate_character(character: ecs.Character?)
	if
		character
		and character.instance.Parent
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

export type Signal<T...> = {
	Connect: (
		self: Signal<T...>,
		callback: (T...) -> ()
	) -> RBXScriptConnection,
}

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
	get_character = get_character,
	validate_character = validate_character,
	character_hip_height = character_hip_height,
	retrieve_animation = retrieve_animation,
	entity_id = entity_id,
}
