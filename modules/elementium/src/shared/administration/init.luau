local RunService = game:GetService "RunService"

local conch = require "../roblox_packages/conch"
local conch_ui = require "../roblox_packages/conch_ui"

local function visit_command(node: ModuleScript)
	if not node:IsA "ModuleScript" then return end
	local result = require(node) :: () -> ()

	result()
end

local function visit(root: Instance)
	for _, node in root:GetChildren() do
		if node:IsA "Folder" then
			visit(node)
		else
			visit_command(node :: ModuleScript)
		end
	end
end

local function create()
	conch.initiate_default_lifecycle()

	visit(script.commands)

	if RunService:IsServer() then
		conch.set_role_permissions("administration", "handout", "debug")
	else
		conch_ui.bind_to(Enum.KeyCode.F2)
	end
end

return {
	create = create,
}
