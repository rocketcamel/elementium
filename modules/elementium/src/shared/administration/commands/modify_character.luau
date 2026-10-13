return {
	Name = "modify_character",
	Group = "Owner",
	Description = "modify a field on a specified character",
	Args = {
		{
			Type = "players",
			Name = "player(s)",
			Description = "the player(s) to modify",
		},
		{
			Type = "characterInfo",
			Name = "field",
			Description = "the field to modify",
		},
		{
			Type = "json", -- for some reason this is effectively an any type
			Name = "value",
			Description = "the value to set",
		},
	},
}
