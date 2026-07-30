local ecs = require "../ReplicatedStorage/shared/ecs"
local services = require "./server/services"
local systems = require "./server/systems"

ecs.create()
systems.register()
services.register()
