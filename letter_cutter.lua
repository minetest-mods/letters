local letter_cutter = letters.letter_cutter
local cost = 0.110

-- Collect items to display in letter cutter output inventory.
function letter_cutter.get_output_inv(modname, subname, amount, max, group)
	local list = {}
	if amount < 1 then
		return list
	end

	for _, name in ipairs(group) do
		table.insert(list, modname .. ":" .. subname .. "_" .. name
			.. " " .. math.min(math.floor(amount/cost), max))
	end
	return list
end

-- Reset letter cutter to its empty state.
function letter_cutter:reset(pos)
	local meta = minetest.get_meta(pos)
	local inv  = meta:get_inventory()

	inv:set_list("input",  {})
	inv:set_list("output", {})
	meta:set_int("anz", 0)

	local groupname = self.group_name(pos)
	meta:set_string("infotext",
			"Letter Cutter ("..groupname..") is empty (owned by "..
				meta:get_string("owner")..")")
end

-- Update letter cutter inventories with available material count.
function letter_cutter:update_inventory(pos, amount)
	local meta          = minetest.get_meta(pos)
	local inv           = meta:get_inventory()

	amount = meta:get_int("anz") + amount

	local groupname = self.group_name(pos)
	if amount < 1 then -- If the last block is taken out.
		self:reset(pos)
		return
	end

	local stack = inv:get_stack("input",  1)
	if stack:is_empty() then
		self:reset(pos)
		return

	end
	local node_name = stack:get_name() or ""
	local name_parts = letter_cutter.known_nodes[node_name] or ""
	local modname  = name_parts[1] or ""
	local material = name_parts[2] or ""

	inv:set_list("input", {
		node_name.. " " .. math.floor(amount)
	})

	local max_offered = meta:get_int("max_offered")
	local output = self.get_output_inv(modname, material, amount, max_offered, self.group(pos))
	-- Display:
	inv:set_list("output", output)
	-- Store how many microblocks are available:
	meta:set_int("anz", amount)

	meta:set_string("infotext",
			"Letter Cutter ("..groupname..") is working (owned by "..
				meta:get_string("owner")..")")
end

-- Implement allow_metadata_inventory_move.
-- https://minetest.gitlab.io/minetest/definition-tables/#node-definition
--
-- Moving is forbidden.
function letter_cutter.allow_metadata_inventory_move(_pos, _from_list, _from_index, _to_list, _to_index, _count, _player)
	return 0
end


-- Implement allow_metadata_inventory_put.
-- https://minetest.gitlab.io/minetest/definition-tables/#node-definition
--
-- Only input- and recycle-slot are intended as input slots:
function letter_cutter.allow_metadata_inventory_put(pos, listname, index, stack, _player)
	-- The player is not allowed to put something in there:
	if listname == "output" then
		return 0
	end

	local meta = minetest.get_meta(pos)
	local inv  = meta:get_inventory()
	local stackname = stack:get_name()
	local count = stack:get_count()

	-- Only accept certain blocks as input which are known to be craftable into stairs:
	if listname == "input" then
		if not inv:is_empty("input") and
				inv:get_stack("input", index):get_name() ~= stackname then
			return 0
		end
		for name, _ in pairs(letter_cutter.known_nodes) do
			if name == stackname and inv:room_for_item("input", stack) then
				return count
			end
		end
		return 0
	end
end

-- Implement on_metadata_inventory_put.
-- https://minetest.gitlab.io/minetest/definition-tables/#node-definition
--
-- Add craftable letters to the letter cutter inventory.
function letter_cutter.on_metadata_inventory_put(pos, listname, _index, stack, _player)
	local count = stack:get_count()

	if listname == "input" then
		letter_cutter:update_inventory(pos, count)
	end
end

-- Implement on_metadata_inventory_take.
-- https://minetest.gitlab.io/minetest/definition-tables/#node-definition
--
-- Taking is allowed from all slots (even the internal microblock slot).
function letter_cutter.on_metadata_inventory_take(pos, listname, _index, stack, _player)
	if listname == "output" then
		-- We do know how much each block at each position costs:
		letter_cutter:update_inventory(pos, 8 * -cost)
	elseif listname == "input" then
		-- Each normal (= full) block taken costs 8 microblocks:
		letter_cutter:update_inventory(pos, 8 * -stack:get_count())
	end
	-- The recycle field plays no role here since it is processed immediately.
end

-- The name of the group of letters managed by this letter cutter.
function letter_cutter.group_name(pos)
	local node = minetest.get_node(pos)
	if node.name == "letters:letter_cutter_digit" then
		return "Digit"
	elseif node.name == "letters:letter_cutter_upper" then
		return "Upper"
	elseif node.name == "letters:letter_cutter_lower" then
		return "Lower"
	end
end

-- The group of letters managed by this letter cutter.
function letter_cutter.group(pos)
	local node = minetest.get_node(pos)
	if node.name == "letters:letter_cutter_digit" then
		return letter_cutter.names_digit
	elseif node.name == "letters:letter_cutter_upper" then
		return letter_cutter.names_upper
	elseif node.name == "letters:letter_cutter_lower" then
		return letter_cutter.names_lower
	end
end

-- Consume the input material and update inventories.
function letter_cutter.remove_from_input(pos, origname, count)
	local meta = minetest.get_meta(pos)

	local cutterinv = meta:get_inventory()

	local removed = cutterinv:remove_item("input", origname .. " " .. tostring(count))
	letter_cutter:update_inventory(pos, -removed:get_count())
end

local gui_slots = "listcolors[#606060AA;#808080;#101010;#202020;#FFF]"

-- Update formspec.
local function update_cutter_formspec(pos)
	local meta = minetest.get_meta(pos)
	meta:set_string("formspec", "size[11,9]" ..gui_slots..
			"label[0,0;Input\nmaterial]" ..
			"list[current_name;input;1.5,0;1,1;]" ..
			"list[current_name;output;2.8,0;8,4;]" ..
			"button[0,1;2.5,1;itemlist;Cuttable materials]" ..
			"list[current_player;main;1.5,5;8,4;]" ..
			"field[0.5,4.3;3,1;text;Enter text;${text}]" ..
			"button[3.5,4;2,1;make_text;Make text]" ..
			"label[5.5,4.2;" .. minetest.formspec_escape(meta:get_string("message")) .. "]")
end

-- Create letter nodes from player-supplied text string.
local function cut_from_text(pos, input_text, player)
	local playername = player:get_player_name()

	local meta = minetest.get_meta(pos)

	local cutterinv = meta:get_inventory()
	local cutterinput = cutterinv:get_list("input")
	local cuttercount = cutterinput[1]:get_count()

	if cuttercount < 1 then
		meta:set_string("message", "No materials.")
		update_cutter_formspec(pos)
		return
	end

	local origname = cutterinput[1]:get_name()

	local playerinv = player:get_inventory()

	meta:set_string("text", input_text)

	local totalcost = 0
	local throwawayinv = minetest.create_detached_inventory("letter_cutter:throwaway", {}, playername)

	throwawayinv:set_size("main", playerinv:get_size("main"))
	throwawayinv:set_list("main", playerinv:get_list("main"))

	for i = 1, #input_text do
		-- Determine letter group.
		local char = input_text:sub(i, i)
		local group
		if char:match("%d") then
			group = "d"
		elseif char:match("%u") then
			group = "u"
			char = char:lower()
		elseif char:match("%l") then
			group = "l"
		else
			goto continue -- unrecognized, skip it
		end

		local lettername = origname .. "_" .. "letter_" ..char:lower() ..group
		if cuttercount < totalcost + cost then
			meta:set_string("message", "Not enough materials.")
			update_cutter_formspec(pos)

			minetest.remove_detached_inventory("letter_cutter:throwaway")
			return
		end

		if lettername and not throwawayinv:room_for_item("main", lettername) then
			meta:set_string("message", "Not enough room.")
			update_cutter_formspec(pos)

			minetest.remove_detached_inventory("letter_cutter:throwaway")
			return
		end

		totalcost = totalcost + cost

		throwawayinv:add_item("main", lettername)
		::continue::
	end

	meta:set_string("message", "Successfully added letters to inventory.")
	update_cutter_formspec(pos)

	letter_cutter.remove_from_input(pos, origname, tostring(math.ceil(totalcost)))
	playerinv:set_list("main", throwawayinv:get_list("main"))

	minetest.remove_detached_inventory("letter_cutter:throwaway")
end

-- Implement on_construct.
-- https://minetest.gitlab.io/minetest/definition-tables/#node-definition
--
-- Initialize a new letter cutter.
function letter_cutter.on_construct(pos)
	local meta = minetest.get_meta(pos)
	local groupname = letter_cutter.group_name(pos)
	update_cutter_formspec(pos)

	meta:set_int("anz", 0) -- No microblocks inside yet.
	meta:set_string("max_offered", 9) -- How many items of this kind are offered by default?
	meta:set_string("infotext", "Letter Cutter ("..groupname..") is empty")

	meta:set_string("text", "")
	meta:set_string("message", "")

	local inv = meta:get_inventory()
	inv:set_size("input", 1)    -- Input slot for full blocks of material x.
	inv:set_size("output", 4*8) -- 4x8 versions of stair-parts of material x.

	letter_cutter:reset(pos)
end

-- Implement can_dig.
-- https://minetest.gitlab.io/minetest/definition-tables/#node-definition
--
-- Allow digging if the letter cutter is empty.
function letter_cutter.can_dig(pos, _player)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	if not inv:is_empty("input") then
		return false
	end
	return true
end

-- Implement on_receive_fields.
-- https://minetest.gitlab.io/minetest/definition-tables/#node-definition
--
-- Handle formspec update.
function letter_cutter.on_receive_fields(pos, _formname, fields, sender)
	if fields.itemlist then
		local list = {}
		for name, _ in pairs(letter_cutter.known_nodes) do
			list[#list+1] = name
		end
		letters.show_item_list(sender, 'Cuttable materials', list, pos)
		return
	end

	if fields.make_text and fields.text then
		cut_from_text(pos, fields.text, sender)
		return
	end
end

minetest.register_node("letters:letter_cutter_lower",  {
	description = "Lower Case Leter Cutter",
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.4375, -0.5, -0.4375, -0.3125, 0.125, -0.3125},
			{-0.4375, -0.5, 0.3125, -0.3125, 0.125, 0.4375},
			{0.3125, -0.5, 0.3125, 0.4375, 0.125, 0.4375},
			{0.3125, -0.5, -0.4375, 0.4375, 0.125, -0.3125},
			{-0.5, 0.0625, -0.5, 0.5, 0.25, 0.5},
			{-0.125, 0.25, 0.125, 0.125, 0.3125, 0.1875},
			{0.125, 0.25, 0.0625, 0.1875, 0.3125, 0.125},
			{0.1875, 0.25, -0.1875, 0.25, 0.3125, 0.1875},
			{-0.1875, 0.25, 0.0625, -0.125, 0.3125, 0.125},
			{-0.25, 0.25, -0.1875, -0.1875, 0.3125, 0.0625},
			{-0.1875, 0.25, -0.25, -0.125, 0.3125, -0.1875},
			{-0.125, 0.25, -0.3125, 0.125, 0.3125, -0.25},
			{0.125, 0.25, -0.25, 0.375, 0.3125, -0.1875},
			{0.3125, 0.25, -0.1875, 0.375, 0.3125, -0.125},
		},
	},
	tiles = {"letters_letter_cutter_lower_top.png",
		"default_tree.png",
		"letters_letter_cutter_side.png"},
	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "facedir",
	groups = {choppy = 2,oddly_breakable_by_hand = 2},
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
	on_construct = letter_cutter.on_construct,
	can_dig = letter_cutter.can_dig,
	-- Set the cutter type and owner.
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		local owner = placer and placer:get_player_name() or ""
		meta:set_string("owner",  owner)
		meta:set_string("infotext",
				"Letter Cutter (Lower) is empty (owned by "
					..meta:get_string("owner")..")")
	end,
	allow_metadata_inventory_move = letter_cutter.allow_metadata_inventory_move,
	allow_metadata_inventory_put = letter_cutter.allow_metadata_inventory_put,
	on_metadata_inventory_put = letter_cutter.on_metadata_inventory_put,
	on_metadata_inventory_take = letter_cutter.on_metadata_inventory_take,
	on_receive_fields = letter_cutter.on_receive_fields,
})

minetest.register_craft({
	output = "letters:letter_cutter_lower",
	recipe = {
		{"default:tree", "default:tree", "default:tree"},
		{"default:wood", "default:steel_ingot", "default:wood"},
		{"default:tree", "", "default:tree"},
	},
})

minetest.register_node("letters:letter_cutter_upper",  {
	description = "Upper Case Leter Cutter",
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.4375, -0.5, -0.4375, -0.3125, 0.125, -0.3125},
			{-0.4375, -0.5, 0.3125, -0.3125, 0.125, 0.4375},
			{0.3125, -0.5, 0.3125, 0.4375, 0.125, 0.4375},
			{0.3125, -0.5, -0.4375, 0.4375, 0.125, -0.3125},
			{-0.5, 0.0625, -0.5, 0.5, 0.25, 0.5},
			{0.1875, 0.25, -0.125, 0.125, 0.3125, -0.3125},
			{0.125, 0.25, 0.125, 0.0625, 0.3125, -0.125},
			{0.0625, 0.25, 0.3125, -0.0625, 0.3125, 0.0625},
			{-0.0625, 0.25, 0.125, -0.125, 0.3125, -0.125},
			{-0.125, 0.25, -0.125, -0.1875, 0.3125, -0.3125},
			{0.125, 0.25, -0.125, -0.125, 0.3125, -0.1875},
		},
	},
	tiles = {"letters_letter_cutter_upper_top.png",
		"default_tree.png",
		"letters_letter_cutter_side.png"},
	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "facedir",
	groups = {choppy = 2,oddly_breakable_by_hand = 2},
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
	on_construct = letter_cutter.on_construct,
	can_dig = letter_cutter.can_dig,
	-- Set the cutter type and owner.
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		local owner = placer and placer:get_player_name() or ""
		meta:set_string("owner",  owner)
		meta:set_string("infotext",
				"Letter Cutter (Upper) is empty (owned by "
					..meta:get_string("owner")..")")
	end,
	allow_metadata_inventory_move = letter_cutter.allow_metadata_inventory_move,
	allow_metadata_inventory_put = letter_cutter.allow_metadata_inventory_put,
	on_metadata_inventory_put = letter_cutter.on_metadata_inventory_put,
	on_metadata_inventory_take = letter_cutter.on_metadata_inventory_take,
	on_receive_fields = letter_cutter.on_receive_fields,
})

minetest.register_craft({
	output = "letters:letter_cutter_upper",
	recipe = {
		{"default:tree", "default:tree", "default:tree"},
		{"default:wood", "default:steel_ingot", "default:wood"},
		{"default:tree", "default:steel_ingot", "default:tree"},
	},
})

minetest.register_node("letters:letter_cutter_digit",  {
	description = "Digit Cutter",
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.4375, -0.5, -0.4375, -0.3125, 0.125, -0.3125},
			{-0.4375, -0.5, 0.3125, -0.3125, 0.125, 0.4375},
			{0.3125, -0.5, 0.3125, 0.4375, 0.125, 0.4375},
			{0.3125, -0.5, -0.4375, 0.4375, 0.125, -0.3125},
			{-0.5, 0.0625, -0.5, 0.5, 0.25, 0.5},
			{-0.0625, 0.25, 0.3125, 0, 0.3125, 0.1875},
			{0.125, 0.25, 0.3125, 0.1875, 0.3125, 0.1875},
			{-0.25, 0.25, 0.125, 0.25, 0.3125, 0.1875},
			{-0.125, 0.25, -0.0625, -0.0625, 0.3125, 0.125},
			{0.0625, 0.25, -0.0625, 0.125, 0.3125, 0.125},
			{-0.25, 0.25, -0.0625, 0.25, 0.3125, -0.125},
			{-0.1875, 0.25, -0.125, -0.125, 0.3125, -0.25},
			{0, 0.25, -0.125, 0.0625, 0.3125, -0.25},
		},
	},
	tiles = {"letters_letter_cutter_digit_top.png",
		"default_tree.png",
		"letters_letter_cutter_side.png"},
	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "facedir",
	groups = {choppy = 2,oddly_breakable_by_hand = 2},
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
	on_construct = letter_cutter.on_construct,
	can_dig = letter_cutter.can_dig,
	-- Set the cutter type and owner.
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		local owner = placer and placer:get_player_name() or ""
		meta:set_string("owner",  owner)
		meta:set_string("infotext",
				"Letter Cutter (Digit) is empty (owned by "
					..meta:get_string("owner")..")")
	end,
	allow_metadata_inventory_move = letter_cutter.allow_metadata_inventory_move,
	allow_metadata_inventory_put = letter_cutter.allow_metadata_inventory_put,
	on_metadata_inventory_put = letter_cutter.on_metadata_inventory_put,
	on_metadata_inventory_take = letter_cutter.on_metadata_inventory_take,
	on_receive_fields = letter_cutter.on_receive_fields,
})

minetest.register_craft({
	output = "letters:letter_cutter_digit",
	recipe = {
		{"default:tree", "default:tree", "default:tree"},
		{"default:wood", "default:copper_ingot", "default:wood"},
		{"default:tree", "", "default:tree"},
	},
})
