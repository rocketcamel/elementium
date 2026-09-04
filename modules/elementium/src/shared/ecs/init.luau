local ContextActionService = game:GetService "ContextActionService"
local RunService = game:GetService "RunService"
local jabby = require "../roblox_packages/jabby"
local jecs = require "../roblox_packages/jecs"
local scheduler = require "../roblox_packages/scheduler"
local storage = require "./storage"

local world = jecs.world()

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

export type Dash = {
	id: number,
	velocity: number,
	active: boolean,
	lifetime: number,
	lifecycle: number,
	started: number,
	n: number?,
	generation: number,
	animation_slot: number?,
}

export type Slide = {
	id: number,
	velocity: number,
	direction: Vector3,
	active: boolean,
	started: number?,
	lifetime: number?,
	n: number?,
	generation: number,
	orient_handle: AlignOrientation?,
}

export type Wallrun = {
	id: number,
	active: boolean,
	animation_slot: number?,
	vector: Vector3?,
	velocity: number?,
	vertical_velocity: number?,
	side: "left" | "right",
	orient_handle: AlignOrientation?,
}

export type CameraFOV = {
	fov: number,
	kick: () -> (),
}

export type Motion = "none" | "running" | "dashing" | "sliding" | "wallrunning"
export type MotionRequestReason = "input_began" | "input_end" | "ability_end"

export type MotionRequest = {
	motion: Motion,
	reason: MotionRequestReason,
	id: number,
}

export type AbilitySpawn = {
	motion: Motion,
	target: CharacterModel,
	generation: number,
}

export type CharacterState = {
	motion: Motion,
	active_ability_id: jecs.Entity?,
	generation: number,
}

export type CharacterRef = {
	instance: CharacterModel,
	invalidated: boolean,
}

export type Meta = {
	permissions: { string },
}

local components = {
	Player = world:component<<Player>>(),
	Character = world:component<<Character>>(),
	Session = world:component<<storage.Store>>(),
	CharacterRef = world:component<<CharacterRef>>(),
	Motion = world:component<<MotionRequest>>(),
	AbilitySpawn = world:component<<AbilitySpawn>>(),
	Dash = world:component<<Dash>>(),
	Slide = world:component<<Slide>>(),
	Wallrun = world:component<<Wallrun>>(),
	AbilityTarget = world:component<<CharacterModel>>(),
	Networked = world:component(),
	CameraFOV = world:component(),
	CharacterState = world:component<<CharacterState>>(),
	Meta = world:component<<Meta>>(),
}

world:add(components.Character, components.Networked)
world:add(components.Player, components.Networked)
world:add(components.Meta, components.Networked)
world:add(components.Session, components.Networked)

for name, component in components :: any do
	world:set(component, jecs.Name, name)
end

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
		local entity_id = if RunService:IsServer()
			then player:GetAttribute "entity_id" :: number
			else player:GetAttribute "client_entity_id" :: number

		if entity_id then
			local meta = world:get(entity_id, components.Meta)

			if meta and table.find(meta.permissions, "jabby") then
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

local function create_component<T>(name: string): jecs.Entity<T>
	local id = world:component<<T>>()
	world:set(id, jecs.Name, name)

	return id
end

return {
	world = world,
	components = components,
	scheduler = ecs_scheduler,
	create_component = create_component,

	create = create,
}
