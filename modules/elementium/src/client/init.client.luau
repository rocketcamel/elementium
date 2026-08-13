local ecs = require "../ReplicatedStorage/shared/ecs"
local net = require "../ReplicatedStorage/shared/ecs/net"
local services = require "./client/services"
local systems = require "./client/systems"

net.client.create()

ecs.create()
systems.register()
services.register()
