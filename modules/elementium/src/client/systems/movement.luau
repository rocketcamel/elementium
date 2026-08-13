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
end

local query = world:query(components.Dash, components.DashTarget):cached()

local function movement(delta: number)
	for entity, dash, target in query do
		if dash.from ~= Players.LocalPlayer.Name then continue end

		if dash.active then
			if dash.ending then
				if dash.velocity > 20 then
					dash.velocity = math.max(0, dash.velocity - 250 * delta)
				else
					world:delete(entity)
					continue
				end
			end

			local look_vector = target.HumanoidRootPart.CFrame.LookVector
			dash.force_handle.VectorVelocity = look_vector * dash.velocity

			if (os.clock() - dash.started) >= dash.lifetime then
				dash.ending = true
			end
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
