local fluid = require "../../roblox_packages/fluid"
local pad = require "../components/pad"

local effect = fluid.effect
local read = fluid.read

type Can<T> = T | () -> T
type Child = Instance | { Child } | () -> Child

type FlexProperties = {
	direction: "column" | "row"?,
	sort: "order" | "name"?,
	justify: Can<
		"center" | "left" | "right" | "around" | "between" | "even" | "fill"
	>,
	align: Can<
		"center" | "top" | "bottom" | "around" | "between" | "even" | "fill"
	>,
	wrap: boolean?,
	pad: number?,
}

type SpecialProperties = {
	name: string?,

	w: Can<number>?,
	h: Can<number>?,

	ws: Can<number>?,
	hs: Can<number>?,
	auto: Can<Auto>?,

	x: Can<number>?,
	y: Can<number>?,

	xs: Can<number>?,
	ys: Can<number>?,
	rot: Can<number>?,

	flex: FlexProperties?,
	pad: pad.Pad?,
}

type function CombineTableAndSetIndexer(a: type, b: type, c: type)
	local t: any = {}

	for key, value in a:properties() do
		t[key] = value
	end

	if b.tag == "table" then
		for key, value in b:properties() do
			if t[key] then error(`overlapping properties {key:value()}`) end
			t[key] = value.read
		end
	end

	return types.newtable(
		t,
		{ index = types.number, readresult = c, writeresult = c }
	)
end

type Auto = "x" | "y" | "xy" | ""

local AUTO_MAP = {
	x = Enum.AutomaticSize.X,
	y = Enum.AutomaticSize.Y,
	xy = Enum.AutomaticSize.XY,
	[""] = Enum.AutomaticSize.None,
}

local function auto(auto: Can<Auto>): Enum.AutomaticSize
	if typeof(read(auto)) == "string" then
		return AUTO_MAP[read(auto)]
	else
		return Enum.AutomaticSize.None
	end
end

local function component<Object, Properties>(
	constructor: (
		Properties,
		never
	) -> unknown
): (
	CombineTableAndSetIndexer<SpecialProperties, Properties, any>
) -> unknown
	local parent_ref: Instance?

	local parent_selector = fluid.action(
		function(instance) parent_ref = instance end
	)

	return function(props: SpecialProperties)
		parent_ref = nil
		local instance = constructor(props, parent_selector :: any) :: Instance
		local parent = parent_ref or instance
		parent_ref = nil

		fluid.bind(instance, { unpack(props :: any) })

		if props.name then instance.Name = props.name end

		local flex = props.flex
		if flex then
			local layout = parent:FindFirstChildWhichIsA "UIListLayout"
				or Instance.new "UIListLayout"
			layout.FillDirection = (flex.direction or "column") == "column"
					and Enum.FillDirection.Vertical
				or Enum.FillDirection.Horizontal
			layout.SortOrder = (flex.sort or "order") == "order"
					and Enum.SortOrder.LayoutOrder
				or Enum.SortOrder.Name
			layout.Wraps = if flex.wrap ~= nil then flex.wrap else false
			print(layout)

			local padding = flex.pad
			if padding then
				effect(function() layout.Padding = UDim.new(0, padding) end)
			end

			local justify = flex.justify or "center"

			effect(function()
				local justify = read(justify)

				if justify == "center" then
					layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
				elseif justify == "left" then
					layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
				elseif justify == "right" then
					layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
				elseif justify == "around" then
					layout.HorizontalFlex = Enum.UIFlexAlignment.SpaceAround
				elseif justify == "between" then
					layout.HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween
				elseif justify == "even" then
					layout.HorizontalFlex = Enum.UIFlexAlignment.SpaceEvenly
				elseif justify == "fill" then
					layout.HorizontalFlex = Enum.UIFlexAlignment.Fill
				end
			end)

			local align = flex.align or "center"

			effect(function()
				local align = read(align)

				if align == "center" then
					layout.VerticalAlignment = Enum.VerticalAlignment.Center
				elseif align == "top" then
					layout.VerticalAlignment = Enum.VerticalAlignment.Top
				elseif align == "bottom" then
					layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
				elseif align == "around" then
					layout.VerticalFlex = Enum.UIFlexAlignment.SpaceAround
				elseif align == "between" then
					layout.VerticalFlex = Enum.UIFlexAlignment.SpaceBetween
				elseif align == "even" then
					layout.VerticalFlex = Enum.UIFlexAlignment.SpaceEvenly
				elseif align == "fill" then
					layout.VerticalFlex = Enum.UIFlexAlignment.Fill
				end
			end)

			layout.Parent = parent
		end

		if props.pad then pad(props.pad).Parent = parent end

		if props.rot then
			effect(
				function() (instance :: GuiObject).Rotation = read(props.rot) end
			)
		end

		local w, h = props.w, props.h
		local ws, hs = props.ws, props.hs

		local w_given, h_given = w or ws, h or hs

		if props.auto then
			effect(
				function()
					(instance :: GuiObject).AutomaticSize =
						auto(read(props.auto))
				end
			)
		end

		if w_given or h_given then
			w = w or 0
			h = h or 0

			ws = ws or 0
			hs = hs or 0

			effect(function()
				local x = read(w)
				local y = read(h)

				local xs = read(ws)
				local ys = read(hs)

				local size = UDim2.new(xs, x, ys, y);
				(instance :: GuiObject).Size = size
			end)
		end

		local x, y = props.x, props.y
		local xs, ys = props.xs, props.ys

		local x_given, y_given = x or xs, y or ys

		if x_given or y_given then
			x = x or 0
			y = y or 0

			xs = xs or 0
			ys = ys or 0

			effect(function()
				local x = read(x)
				local y = read(y)

				local xs = read(xs)
				local ys = read(ys)

				local position = UDim2.new(x, xs, y, ys);
				(instance :: GuiObject).Position = position
			end)
		end

		return instance
	end
end

local f = component(
	function(p: { name: Can<string>? }, _) return fluid.create "Frame" end
)

return component
