local ReplicatedStorage = game:GetService "ReplicatedStorage"
local RunService = game:GetService "RunService"

local ecs = require "./ecs"
local jecs = require "../roblox_packages/jecs"

local world = ecs.world
local components = ecs.components

local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

export type Animation =
	"dash"
	| "dash_endjump"
	| "double_jump"
	| "wallrun_l"
	| "wallrun_r"

local function retrieve_animation(name: Animation): string
	local result =
		ReplicatedStorage.animations:FindFirstChild(name) :: StringValue?
	assert(result)

	return `rbxassetid://{result.Value}`
end

local function player_entity_id(player: Player): jecs.Entity?
	return if IS_SERVER
		then player:GetAttribute "entity_id" :: jecs.Entity?
		else player:GetAttribute "client_entity_id" :: jecs.Entity?
end

local function player_entity_id_fatal(player: Player): jecs.Entity
	local entity_id = if IS_SERVER
		then player:GetAttribute "entity_id" :: jecs.Entity?
		else player:GetAttribute "client_entity_id" :: jecs.Entity?
	assert(entity_id, "player has no entity id")

	return entity_id
end

local function get_character(player: Player): ecs.Character?
	local entity_id = player_entity_id(player)
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

export type Signal<T... = ...any> = {
	Connect: (
		self: Signal<T...>,
		callback: (T...) -> ()
	) -> RBXScriptConnection,
	ConnectParallel: (
		self: Signal<T...>,
		callback: (T...) -> ()
	) -> RBXScriptConnection,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> RBXScriptConnection,
	Wait: (self: Signal<T...>) -> T...,
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
	player_entity_id = player_entity_id,
	player_entity_id_fatal = player_entity_id_fatal,
	get_character = get_character,
	validate_character = validate_character,
	character_hip_height = character_hip_height,
	retrieve_animation = retrieve_animation,
}
