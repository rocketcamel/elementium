local ReplicatedStorage = game:GetService "ReplicatedStorage"
local RunService = game:GetService "RunService"

type CmdrClient = {
	SetActivationKeys: (self: CmdrClient, { Enum.KeyCode }) -> (),
	Registry: any,
}

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
	if RunService:IsServer() then
		local cmdr = require "../roblox_packages/cmdr";

		(cmdr :: any).Registry:RegisterDefaultCommands()
		cmdr.Registry:RegisterCommandsIn(script.commands)
		cmdr.Registry:RegisterTypesIn(script.types)

		local before_run = require "@self/hooks/before_run"
		before_run(cmdr.Registry)
	else
		local cmdr_client = require(
			ReplicatedStorage:WaitForChild "CmdrClient" :: any
		) :: CmdrClient

		local before_run = require "@self/hooks/before_run_client"
		before_run(cmdr_client.Registry)
		cmdr_client:SetActivationKeys { Enum.KeyCode.F2 }
	end
end

return {
	create = create,
}
