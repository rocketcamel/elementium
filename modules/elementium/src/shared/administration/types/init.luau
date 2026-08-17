local conch = require "../../roblox_packages/conch"

local roles = conch.args.enum_from_array("roles", { "administration", "jabby" })

return {
	roles = roles,
}
