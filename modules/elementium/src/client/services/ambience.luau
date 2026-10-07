local TweenService = game:GetService "TweenService"

export type Ambience = string | {
	id: string,
	volume: number,
}

local ambience: { Ambience } = {
	{ id = "rbxassetid://9112781689", volume = 1 },
	"rbxassetid://72067625698084",
}

local function choose_background(): Ambience
	return ambience[math.random(1, #ambience)]
end

local function get_settings(ambience: Ambience): { id: string, volume: number }
	if typeof(ambience) == "string" then
		return { id = ambience, volume = 0.5 }
	else
		return ambience
	end
end

local ease_info =
	TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.In)

local function ease_volume(instance: Sound, volume: number)
	local result = TweenService:Create(instance, ease_info, { Volume = volume })
	result:Play()
end

return function()
	local ambience = choose_background()
	local settings = get_settings(ambience)

	local instance = Instance.new "Sound"
	instance.Parent = workspace
	instance.SoundId = settings.id
	instance.Volume = 0
	instance:Play()

	ease_volume(instance, settings.volume)

	while true do
		instance.Ended:Wait()

		ambience = choose_background()
		settings = get_settings(ambience)

		instance.SoundId = settings.id
		instance.Volume = 0
		instance:Play()

		ease_volume(instance, settings.volume)
	end
end
