local ReplicatedStorage = game:GetService "ReplicatedStorage"
local TweenService = game:GetService "TweenService"

local net = require "../net"

local folder =
	ReplicatedStorage.ElementiumVFX_SFX.Elements.Fire.fiery_blow_VFX_SFX

export type FieryBlow = typeof(folder.fiery_blow)

local function fire(direction: Vector3)
	net.client.report_ability("fiery_blow", direction)
end

local function finish(object: FieryBlow)
	local instance = Instance.new "Sound"
	instance.Parent = object.FPart
	instance.SoundId = "rbxassetid://134526200875251"
	instance:Play()

	local particles = object.FPart.fiery_blow_coreVFX
	particles.FireMid.Enabled = false
	particles.FireEnd.Enabled = false
	particles.FireStart.Enabled = false
	particles.Smoke.Enabled = false

	local explosion_particles = object.FPart.fiery_blow_explosionVFX
	explosion_particles.FireEnd:Emit(20)
	explosion_particles.FireFlash:Emit(1)
	explosion_particles.FireMid:Emit(15)
	explosion_particles.FireRing:Emit(2)
	explosion_particles.FireSpark:Emit(2)
	explosion_particles.SmokeSlashes:Emit(20)
	explosion_particles.Smoke:Emit(20)

	object.FPart.Transparency = 1

	local result = TweenService:Create(
		object.FPart.PointLight,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{
			Brightness = 0,
		}
	)
	result:Play()

	task.delay(3, function() object:Destroy() end)
end

local function get_instance(): Model return folder.fiery_blow end

return {
	kind = "projectile",
	name = "Fiery blow",
	trigger = "release",
	max_charge = 2,
	cooldown = 1,
	velocity = 120,
	fire = fire,
	finish = finish,
	get_instance = get_instance,
}
