local administration = require "../ReplicatedStorage/shared/administration"
local ecs = require "../ReplicatedStorage/shared/ecs"
local net = require "../ReplicatedStorage/shared/net"
local services = require "./client/services"
local systems = require "./client/systems"

net.client.create()

ecs.create()
systems.register()
services.register()

administration.create()
