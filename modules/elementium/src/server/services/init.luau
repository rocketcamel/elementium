local function visit_service(node: Instance)
	if not node:IsA "ModuleScript" then return end

	local service = require(node) :: () -> ()

	if not service then
		error(`missing service declaration for: {node:GetFullName()}`)
	end
	service()
end

local function visit(root: Instance)
	for _, node in root:GetChildren() do
		if node:IsA "Folder" then
			visit(node)
		else
			visit_service(node)
		end
	end
end

return {
	register = function() visit(script) end,
}
