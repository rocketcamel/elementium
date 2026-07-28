local jabby = require "./roblox_packages/jabby"

type System = () -> ()

export type Info = {
	id: number,
	system: System,
	priority: number,
	delta: number,
}

export type SystemDeclaration = {
	priority: number,
	system: System,
}

local function scheduler()
	local system_info: { Info } = {}
	local jabby_scheduler = jabby.scheduler.create()
	local n = 0

	local function add_system(node: SystemDeclaration)
		n += 1
		table.insert(system_info, {
			id = n,
			system = node.system,
			priority = 0,
			delta = 0,
		})

		local name, l = debug.info(2, "sl")
		jabby_scheduler:register_system {
			name = `{name}:{l}`,
			phase = "PostSimulation",
			paused = false,
		}

		table.sort(
			system_info,
			function(a, b) return (a :: any).priority < b.priority end
		)
	end

	local function add_systems(nodes: { SystemDeclaration })
		if #nodes == 0 then return end

		for _, node in nodes do
			n += 1
			table.insert(system_info, {
				id = n,
				system = node.system,
				priority = node.priority,
				delta = 0,
			})

			local name, l = debug.info(2, "sl")
			jabby_scheduler:register_system {
				name = `{name}:{l}`,
				phase = "PostSimulation",
				paused = false,
			}
		end

		table.sort(
			system_info,
			function(a, b) return (a :: any).priority < b.priority end
		)
	end

	local function run_system(info: Info)
		local now = os.clock()

		info.system()
		info.delta = (os.clock() - now)
	end

	local function run()
		for _, system in system_info do
			jabby_scheduler:run(system.id, function() run_system(system) end)
		end
	end

	return {
		add_system = add_system,
		add_systems = add_systems,
		run = run,
		jabby_scheduler = jabby_scheduler,
	}
end

return {
	create = scheduler,
}
