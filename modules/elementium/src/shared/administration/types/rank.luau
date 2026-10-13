return function(registry: any)
	registry:RegisterType(
		"rank",
		registry.Cmdr.Util.MakeEnumType("Rank", { "owner", "admin" })
	)

	registry:RegisterType(
		"characterInfo",
		registry.Cmdr.Util.MakeEnumType(
			"field",
			{ "health", "max_health", "walk_speed", "jump_power" }
		)
	)
end
