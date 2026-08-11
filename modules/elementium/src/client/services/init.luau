type VisitState = {
	nodes: { () -> () },
}

local function visit_system(state: VisitState, node: Instance)
	if not node:IsA "ModuleScript" then return end

	local declaration = require(node) :: () -> ()

	if not declaration then
		error(`missing service declaration for: {node:GetFullName()}`)
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

		for _, node in state.nodes do
			task.spawn(node)
		end
	end,
}
