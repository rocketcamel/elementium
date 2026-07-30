local ecs = require "../ReplicatedStorage/shared/ecs"
local net = require "../ReplicatedStorage/shared/ecs/net"
local systems = require "./client/systems"

ecs.create()
systems.register()

net.client.create()
