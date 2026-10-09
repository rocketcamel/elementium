local net = require "../ecs/net"

local function noop() end

export type FireyBlow = Model & {
	FPart: BasePart & {
		FireballEffectCore: Attachment & {
			FireballMid: ParticleEmitter,
			FireballEnd: ParticleEmitter,
			FireballStart: ParticleEmitter,
			FireballScatter: ParticleEmitter,
			FireballAll: ParticleEmitter,
		},
		FireballExplosion: Attachment,
	},
}

type Storage = ReplicatedStorage & {
	storage: Folder & {
		firey_blow: FireyBlow,
	},
}

local ability = {
	trigger = "release" :: "release" | "press",
	max_charge = 2,
	cooldown = 1,
	fire = noop,
	finish = noop,
}

function ability.fire(direction: Vector3)
	net.client.report_ability("firey_blow", direction)
end

function ability.finish(object: FireyBlow)
	local instance = Instance.new "Sound"
	instance.Parent = object.FPart
	instance.SoundId = "rbxassetid://134526200875251"
	instance:Play()

	local particles = object.FPart.FireballEffectCore
	particles.FireballMid.Enabled = false
	particles.FireballEnd.Enabled = false
	particles.FireballStart.Enabled = false
	particles.FireballScatter.Enabled = false
	particles.FireballAll.Enabled = false

	task.delay(3, function() object:Destroy() end)
end

return ability
