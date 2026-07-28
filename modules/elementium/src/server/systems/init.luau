local ecs = require "../../ReplicatedStorage/shared/ecs"
local scheduler = require "../../ReplicatedStorage/roblox_packages/scheduler"

local nodes = {}

local function visit_system(node: Instance)
	if not node:IsA "ModuleScript" then return end

	local declaration = require(node) :: scheduler.SystemDeclaration

	if not declaration then
		error(`missing system declaration for: {node:GetFullName()}`)
	end

	table.insert(nodes, declaration)
end

local function visit(root: Instance)
	for _, node in root:GetChildren() do
		if node:IsA "Folder" then
			visit(node)
		else
			visit_system(node)
		end
	end
end

visit(script)
ecs.scheduler.add_systems(nodes)
