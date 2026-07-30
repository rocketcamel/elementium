local ecs = require "../../ReplicatedStorage/shared/ecs"
local scheduler = require "../../ReplicatedStorage/roblox_packages/scheduler"

type VisitState = {
	nodes: { scheduler.SystemDeclaration },
}

local function visit_system(state: VisitState, node: Instance)
	if not node:IsA "ModuleScript" then return end

	local declaration = require(node) :: scheduler.SystemDeclaration

	if not declaration then
		error(`missing system declaration for: {node:GetFullName()}`)
	end

	table.insert(state.nodes, declaration)
end

local function visit(state: VisitState, root: Instance)
	for _, node in root:GetChildren() do
		if node:IsA "Folder" then
			visit(state, node)
		else
			visit_system(state, node)
		end
	end
end

return {
	register = function()
		local state: VisitState = {
			nodes = {},
		}

		visit(state, script)
		ecs.scheduler.add_systems(state.nodes)
	end,
}
