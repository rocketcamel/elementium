local ContextActionService = game:GetService "ContextActionService"
local RunService = game:GetService "RunService"
local jabby = require "../roblox_packages/jabby"
local jecs = require "../roblox_packages/jecs"
local scheduler = require "../roblox_packages/scheduler"

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
	from: string,
	velocity: number,
	active: boolean,
	lifetime: number,
	started: number,
	n: number,
	generation: number,
	animation_slot: number,
	ending: boolean?,
	force_handle: LinearVelocity,
}

export type Slide = {
	velocity: number,
	direction: Vector3,
	active: boolean,
	started: number,
	lifetime: number,
	n: number,
	generation: number,
	force_handle: LinearVelocity,
}

export type CameraFOV = {
	fov: number,
	kick: () -> (),
}

export type Motion = "none" | "running" | "dashing" | "sliding"
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

local components = {
	Player = world:component<<Player>>(),
	Character = world:component<<Character>>(),
	Motion = world:component<<MotionRequest>>(),
	AbilitySpawn = world:component<<AbilitySpawn>>(),
	Dash = world:component<<Dash>>(),
	Slide = world:component<<Slide>>(),
	AbilityTarget = world:component<<CharacterModel>>(),
	Networked = world:component(),
	CameraFOV = world:component(),
	CharacterState = world:component<<CharacterState>>(),
}

world:add(components.Character, components.Networked)
world:add(components.Player, components.Networked)

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

	create = create,
}
