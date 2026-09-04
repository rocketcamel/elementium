local ecs = require "../shared/ecs"

local animation_tracks: { [ecs.CharacterModel]: { { animation: Animation, track: AnimationTrack } } } =
	{}

local track_slot = 0

export type TrackExtra = {
	loop: boolean?,
}

local function or_default<T>(value: T?, default: T): T return value or default end

local function animate(
	id: string,
	target: ecs.CharacterModel,
	track_extra: TrackExtra?
): number
	track_slot += 1

	local animation = Instance.new "Animation"
	animation.AnimationId = id

	local track = target.Humanoid.Animator:LoadAnimation(animation)
	track:Play()

	if track_extra then track.Looped = or_default(track_extra.loop, false) end

	if not animation_tracks[target] then animation_tracks[target] = {} end

	animation_tracks[target][track_slot] =
		{ animation = animation, track = track }

	return track_slot
end

local function stop_track(slot: number, target: ecs.CharacterModel)
	local tracks = animation_tracks[target]

	if tracks then
		local node = tracks[slot]

		if node then
			node.track:Stop()
			tracks[slot] = nil
		end
	end
end

return {
	animate = animate,
	stop_track = stop_track,
}
