local jabby = require "./roblox_packages/jabby"

type System = (delta: number) -> ()

export type Info = {
	id: number,
	system: System,
	delta: number,
}

export type Phase = "startup" | "pre_simulation" | "input" | "post_simulation"

export type SystemDeclaration = {
	name: string?,
	system: System,
	phase: Phase,
}

local PHASE_ORDER: { Phase } = { "pre_simulation", "input", "post_simulation" }

local function scheduler()
	local jabby_scheduler = jabby.scheduler.create()
	local started = false

	local systems: { [Phase]: { Info } } = {
		["startup"] = {},
		["pre_simulation"] = {},
		["input"] = {},
		["post_simulation"] = {},
	}

	local function scheduler_add_system(node: SystemDeclaration)
		local name = node.name or debug.info(node.system, "n")
		local source, l = debug.info(node.system, "sl")

		local id = jabby_scheduler:register_system {
			name = name or `{source}:{l}`,
			phase = node.phase,
			paused = false,
		}

		table.insert(systems[node.phase], {
			id = id,
			system = node.system,
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
		for _, info in systems[phase] do
			jabby_scheduler:run(info.id, function()
				local now = os.clock()

				info.system(delta)
				info.delta = (os.clock() - now)
			end)
		end
	end

	local function run(delta: number)
		if not started then
			run_phase("startup", delta)
			started = true

			for _, info in systems["startup"] do
				jabby_scheduler:set_system_data(info.id, {
					paused = true,
				})
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
