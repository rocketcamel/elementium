return {
	Name = "give_rank",
	Description = "gives a player the specified rank",
	Group = "Owner",
	Args = {
		{
			Type = "players",
			Name = "player(s)",
			Description = "the player(s) to give the rank",
		},
		{
			Type = "rank",
			Name = "rank",
			Description = "one or more ranks to give the player",
		},
	},
}
