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
	Humanoid: Humanoid,
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

export type AbilityKind = "dash"

export type Ability = {
	kind: AbilityKind,
}

local components = {
	Player = world:component<<Player>>(),
	Character = world:component<<Character>>(),
	Ability = world:component<<Ability>>(),
}

for name, component in components :: any do
	world:set(component, jecs.Name, name)
end

local ecs_scheduler = scheduler.create()

local function create()
	local function server()
		RunService.PostSimulation:Connect(function() ecs_scheduler:run() end)
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

		RunService.PostSimulation:Connect(function() ecs_scheduler:run() end)
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
