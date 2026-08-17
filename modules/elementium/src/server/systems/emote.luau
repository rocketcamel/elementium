local Players = game:GetService "Players"

local ecs = require "../../../ReplicatedStorage/shared/ecs"

type Chat = {
	player: Player,
	message: string,
}

local emotes = {}

local function handle_emote(player: Player, name: string)
	if name == "groove" then
		local target = player.Character :: ecs.CharacterModel
		if not target then return end

		local animation = Instance.new "Animation"
		animation.AnimationId = "rbxassetid://14055464412"

		local track = target.Humanoid.Animator:LoadAnimation(animation)
		track.Looped = true
		track:Play()

		local sound = Instance.new "Sound"
		sound.Parent = target.HumanoidRootPart
		sound.SoundId = "rbxassetid://14055443115"
		sound.Volume = 1
		sound.TimePosition = 41.3

		sound:Play()

		emotes[target] = { track = track, sound = sound }
	end
end

local function emote()
	local chatted: { Chat } = {}
	local n = 0

	for _, player in Players:GetPlayers() do
		player.Chatted:Connect(function(message)
			table.insert(chatted, { player = player, message = message })
			n += 1
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(message)
			table.insert(chatted, { player = player, message = message })
			n += 1
		end)
	end)

	local function iter(): ...Chat
		if n == 0 then return end
		n -= 1

		return table.remove(chatted, 1) :: Chat
	end

	return function()
		for chat in iter do
			local command = string.split(chat.message, " ")
			if command[1] ~= "/e" then continue end

			handle_emote(chat.player, command[2])
		end

		for target, emote in emotes do
			if target.Humanoid.MoveDirection.Magnitude > 0.5 then
				emote.sound:Destroy()
				emote.track:Stop()

				emotes[target] = nil
			end
		end
	end
end

return {
	name = "emote",
	phase = "post_simulation",
	system = emote(),
}
