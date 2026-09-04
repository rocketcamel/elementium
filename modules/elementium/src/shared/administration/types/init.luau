local conch = require "../../roblox_packages/conch"

local roles = conch.args.enum_from_array("roles", { "administration", "jabby" })

local character_info = conch.args.enum_from_array(
	"character info",
	{ "health", "max_health", "walk_speed", "jump_power" }
)

return {
	roles = roles,
	character_info = character_info,
}
