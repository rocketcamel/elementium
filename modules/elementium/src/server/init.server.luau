local administration = require "../ReplicatedStorage/shared/administration"
local ecs = require "../ReplicatedStorage/shared/ecs"
local net = require "../ReplicatedStorage/shared/ecs/net"
local services = require "./server/services"
local systems = require "./server/systems"

ecs.create()
systems.register()
services.register()

net.server.create()
administration.create()
