local ContextActionService = game:GetService "ContextActionService"
local RunService = game:GetService "RunService"
local jabby = require "../roblox_packages/jabby"
local jecs = require "../roblox_packages/jecs"
local scheduler = require "../roblox_packages/scheduler"

local world = jecs.world()

local IS_SERVER = RunService:IsServer()

local function component<T>(name: string): jecs.Entity<T>
	local id = world:component<<T>>()
	world:set(id, jecs.Name, name)

	return id
end

export type CharacterModel = Model & {
	Head: BasePart,
	Torso: BasePart,
	HumanoidRootPart: BasePart & {
		RootAttachment: Attachment,
	},
	Humanoid: Humanoid & {
		Animator: Animator,
	},
	["Left Arm"]: BasePart,
	["Right Arm"]: BasePart,
	["Left Leg"]: BasePart,
	["Right Leg"]: BasePart,
}

export type Character = {
	health: number,
	max_health: number,
	walk_speed: number,
	jump_power: number,
	instance: CharacterModel,
}

export type CameraFOV = {
	fov: number,
}

export type CharacterRef = {
	instance: CharacterModel,
	invalidated: boolean,
}

export type Meta = {
	permissions: { string },
}

--------------------------------------------------------------------------------
-- movement
--------------------------------------------------------------------------------

export type MovementKind = "dash" | "dash_endjump" | "double_jump" | "wallrun"

export type Movement = {
	previous: MovementKind?,
	current: (Dash | Dash_EndJump | DoubleJump | Wallrun)?,
	air_jump: number,
}

export type Dash = {
	kind: "dash",
	vector: Vector3,
	lifetime: number,
	animation_track: AnimationTrack,
	linear_velocity: LinearVelocity?,
}

export type Dash_EndJump = {
	kind: "dash_endjump",
	vector: Vector3,
	lifetime: number,
	animation_track: AnimationTrack,
	linear_velocity: LinearVelocity?,
}

export type DoubleJump = {
	kind: "double_jump",
	vector: Vector3,
	lifetime: number,
	linear_velocity: LinearVelocity?,
}

export type Wallrun = {
	kind: "wallrun",
	vector: Vector3,
	animation_track: AnimationTrack,
	linear_velocity: LinearVelocity?,
}

--------------------------------------------------------------------------------
-- abilities
--------------------------------------------------------------------------------

export type AbilityKind = "fiery_blow"

export type ElementMove = {
	kind: AbilityKind,
	cooldown: number?,
	charge: number?,
	binding: Tool?,
}

export type Hotbar = {
	kind: AbilityKind,
	name: string,
	cooldown: number?,
	cooldown_duration: number,
	charge: number?,
	binding: Tool?,
}

export type PositionSnapshot = {
	cframe: CFrame,
	server_time: number,
}

export type ProjectileDefinition = "fiery_blow"

export type SimpleProjectile = {
	kind: "simple",
	definition: ProjectileDefinition,

	origin: CFrame,
	initial_velocity: Vector3,
	acceleration: Vector3,
	spawn_time: number,
}

export type InterpolatedProjectile = {
	kind: "interpolated",
	definition: ProjectileDefinition,
}

export type Projectile = SimpleProjectile | InterpolatedProjectile

local components = {
	Player = component<<Player>> "Player",
	Character = component<<Character>> "Character",
	Session = component<<storage.Store>> "Session",
	CharacterRef = component<<CharacterRef>> "CharacterRef",
	Motion = component<<MotionRequest>> "Motion",

	Movement = component<<Movement>> "Movement",
	Dash = component<<Dash>> "Dash",

	Ability = component<<Ability>> "Ability",
	Element = component<<{ ElementMove }>> "Element",
	ElementBindings = component<<{ [ecs.AbilityKind]: Tool? }>> "ElementBindings",

	ReplicatedPosition = component<<PositionSnapshot>> "ReplicatedPosition",
	Snapshots = component<<{ PositionSnapshot }>> "Snapshots",
	Transform = component<<CFrame>> "Transform",
	Velocity = component<<Vector3>> "Velocity",
	Renderable = component<<PVInstance>> "Renderable",
	Projectile = component<<Projectile>> "Projectile",
	PreviousPosition = component<<Vector3>> "PreviousPosition",
	Raycast = component<<RaycastParams>> "Raycast",
	Owner = component<<Instance>> "Owner",

	AbilityTarget = component<<CharacterModel>> "AbilityTarget",
	Networked = world:entity(),
	NetworkedPair = world:entity(),
	CameraFOV = component "CameraFOV",
	Meta = component<<Meta>> "Meta",
}

world:add(components.Character, components.Networked)
world:add(components.Player, components.Networked)
world:add(components.Meta, components.Networked)
world:add(components.Session, components.Networked)
world:add(components.ReplicatedPosition, components.Networked)
world:add(components.Velocity, components.Networked)
world:add(components.Projectile, components.Networked)
world:add(components.Owner, components.Networked)
world:add(components.Element, components.Networked)

local ecs_scheduler = scheduler.create()

local function create()
	local function server()
		RunService.PostSimulation:Connect(
			function(delta) ecs_scheduler.run(delta) end
		)
	end

	local function client()
		local jabby_client = jabby.obtain_client()

		local function spawn_applet(_, state: Enum.UserInputState)
			if state ~= Enum.UserInputState.Begin then return end
			jabby_client.spawn_app(jabby_client.apps.home :: any, nil)
		end

		ContextActionService:BindAction(
			"open jabby",
			spawn_applet :: any,
			false,
			Enum.KeyCode.F4
		)

		RunService.PostSimulation:Connect(
			function(delta) ecs_scheduler.run(delta) end
		)
	end

	jabby.register({
		applet = jabby.applets.world,
		name = "world",
		configuration = {
			world = world,
		},
	} :: any)

	jabby.register({
		applet = jabby.applets.scheduler,
		name = "scheduler",
		configuration = {
			scheduler = ecs_scheduler.jabby_scheduler,
		},
	} :: any)

	jabby.set_check_function(function(player)
		local entity_id = if IS_SERVER
			then player:GetAttribute "entity_id" :: number?
			else player:GetAttribute "client_entity_id" :: number?

		if entity_id then
			local meta = world:get(entity_id, components.Meta)

			if meta and table.find(meta.permissions, "owner") then
				return true
			end
		end

		return false
	end)

	if RunService:IsServer() then
		server()
	else
		client()
	end
end

return {
	world = world,
	components = components,
	scheduler = ecs_scheduler,
	create_component = component,

	create = create,
}
