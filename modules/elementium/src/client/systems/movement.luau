local Players = game:GetService "Players"

local ecs = require "../../shared/ecs"
local jecs = require "../../roblox_packages/jecs"

local world = ecs.world
local components = ecs.components

world:set(components.Dash, jecs.OnRemove, function(entity, id)
	local data = world:get(entity, components.Dash)
	if not data then return end

	data.force_handle:Destroy()
end)

local function movement_dash(
	entity: jecs.Entity,
	target: ecs.CharacterModel,
	dash: ecs.Dash
)
	local force = Instance.new "LinearVelocity"
	force.Parent = target
	force.Attachment0 = target.HumanoidRootPart.RootAttachment
	force.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	force.MaxAxesForce = Vector3.new(math.huge, 0, math.huge)

	dash.force_handle = force
	dash.started = os.clock()
	world:set(entity, components.Dash, dash)

	task.delay(dash.lifetime, function() world:delete(entity) end)
end

local query = world:query(components.Dash, components.DashTarget):cached()

local function movement()
	for entity, dash, target in query do
		if dash.from ~= Players.LocalPlayer.Name then continue end

		if dash.active then
			local t =
				math.clamp((os.clock() - dash.started) / dash.lifetime, 0, 1)
			local mult = (1.5 - t) ^ 2

			local look_vector = target.HumanoidRootPart.CFrame.LookVector
			dash.force_handle.VectorVelocity = look_vector
				* (dash.velocity * mult)
		else
			dash.active = true
			movement_dash(entity, target, dash)
		end
	end
end

return {
	phase = "post_simulation",
	system = movement,
}
