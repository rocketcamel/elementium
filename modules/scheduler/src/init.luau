--------------------------------------------------------------------------------
-- scheduler.luau
-- v0.1.2
--------------------------------------------------------------------------------

local jabby = require "./roblox_packages/jabby"

export type Phase =
	"startup"
	| "pre_simulation"
	| "input"
	| "update"
	| "post_simulation"

export type System = (delta: number) -> ()

export type SystemDeclaration = {
	name: string?,
	system: System,
	phase: Phase,
}

export type Info = {
	id: number,
	fn: System,
	delta: number,
}

local PHASE_ORDER: { Phase } =
	{ "startup", "pre_simulation", "input", "update", "post_simulation" }

local function scheduler()
	local jabby_scheduler = jabby.scheduler.create()
	local started = false

	local system_phase_map: { [Phase]: { Info } } = {
		startup = {},
		pre_simulation = {},
		input = {},
		update = {},
		post_simulation = {},
	}

	local function scheduler_add_system(node: SystemDeclaration)
		local name = node.name or debug.info(node.system, "n") :: string
		local source, l = debug.info(node.system, "sl")

		if #name == 0 then name = `{source}:{l}` end

		local id = jabby_scheduler:register_system {
			name = name,
			phase = node.phase,
			paused = false,
		}

		table.insert(system_phase_map[node.phase], {
			id = id,
			fn = node.system,
			delta = 0,
		})
	end

	local function add_systems(nodes: { SystemDeclaration })
		if #nodes == 0 then return end

		for _, node in nodes do
			scheduler_add_system(node)
		end
	end

	local function run_phase(phase: Phase, delta: number)
		for _, system in system_phase_map[phase] do
			jabby_scheduler:run(system.id, function()
				local now = os.clock()

				system.fn(delta)
				system.delta = os.clock() - now
			end)
		end
	end

	local function run(delta: number)
		if not started then
			run_phase("startup", delta)
			started = true

			for _, info in system_phase_map.startup do
				jabby_scheduler:set_system_data(info.id, { paused = true })
			end
		end

		for _, phase in PHASE_ORDER do
			run_phase(phase, delta)
		end
	end

	return {
		add_system = scheduler_add_system,
		add_systems = add_systems,
		run = run,
		jabby_scheduler = jabby_scheduler,
	}
end

return {
	create = scheduler,
}
