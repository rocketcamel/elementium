local ecs = require "../ReplicatedStorage/shared/ecs"
local systems = require "./client/systems"

ecs.create()
systems.register()
