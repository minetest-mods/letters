local lettersmod = minetest.get_current_modname()
local letterspath = minetest.get_modpath(lettersmod)
local letter_cutter = letters.letter_cutter

letter_cutter.known_nodes = {}

-- Use files in the textures folder to populate letter group tables.
letter_cutter.names_upper = {}
letter_cutter.names_lower = {}
letter_cutter.names_digit = {}
for _, tile in ipairs(minetest.get_dir_list(letterspath .. "/textures", false)) do
	local char, group = tile:match("_([%d%u%l])(%l)_overlay")
	if char and group then
		if group == "d" then
			table.insert(letter_cutter.names_digit, "letter_" ..char..group)
		elseif group == "u" then
			table.insert(letter_cutter.names_upper, "letter_" ..char..group)
		elseif group == "l" then
			table.insert(letter_cutter.names_lower, "letter_" ..char..group)
		end
	end
end

--- Register a node for use as a material in letter cutters.
-- @param modname is the mod that the node belongs to.
-- @param subname is the actual name of the node.
-- @param from_node is the node that the letters will be crafted from (Usually modname:subname).
-- @param description is the description of the node.
-- @param tiles defines the image that will be used with the node.
-- @param basedef (optional) may contain additional node definition parameters. Some might be overwritten to make the letters look and work as intended.
function letters.register_letters(modname, subname, from_node, description, tiles, basedef)
	basedef = basedef and table.copy(basedef) or {}

	--default node
	basedef.drawtype = "signlike"
	basedef.paramtype = "light"
	basedef.paramtype2 = basedef.paramtype2 or "wallmounted"
	basedef.sunlight_propagates = true
	basedef.is_ground_content = false
	basedef.walkable = false
	basedef.selection_box = {
		type = "wallmounted"
		--wall_top = <default>
		--wall_bottom = <default>
		--wall_side = <default>
	}
	basedef.groups = basedef.groups or {
		not_in_creative_inventory = 1,
		not_in_craft_guide = 1,
		oddly_breakable_by_hand = 1,
		attached_node = 1
	}
	basedef.legacy_wallmounted = false

	-- Register a new node for each letter using the provided from_node as the material.
	for _, tile in ipairs(minetest.get_dir_list(letterspath .. "/textures", false)) do
		local char, group = tile:match("_([%d%u%l])(%l)_overlay")
		if char and group then
			local def = table.copy(basedef)

			if group == "d" then
				def.description = description.. " " ..char
			elseif group == "u" then
				def.description = description.. " " ..char:upper()
			elseif group == "l" then
				def.description = description.. " " ..char
			end
			def.inventory_image = tiles.. "^" ..tile.. "^[makealpha:255,126,126"
			def.wield_image = def.inventory_image
			def.tiles = {def.inventory_image}

			minetest.register_node(":" ..modname..":"..subname.. "_letter_" ..char..group,def)
		end
	end
	letter_cutter.known_nodes[from_node] = {modname, subname}
end