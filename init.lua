letters = {
	{"a", "al"},
	{"b", "bl"},
	{"c", "cl"},
	{"d", "dl"},
	{"e", "el"},
	{"f", "fl"},
	{"g", "gl"},
	{"h", "hl"},
	{"i", "il"},
	{"j", "jl"},
	{"k", "kl"},
	{"l", "ll"},
	{"m", "ml"},
	{"n", "nl"},
	{"o", "ol"},
	{"p", "pl"},
	{"q", "ql"},
	{"r", "rl"},
	{"s", "sl"},
	{"t", "tl"},
	{"u", "ul"},
	{"v", "vl"},
	{"w", "wl"},
	{"x", "xl"},
	{"y", "yl"},
	{"z", "zl"},
}

letter_cutter = {}
letter_cutter.known_nodes = {}

function letters.register_letters(modname, subname, from_node, description, tiles)
	for _, row in ipairs(letters) do
		local name = subname.. "_letter_" ..row[1]
		local desc = description.. " " ..row[1]
		local tiles = tiles.. "^letters_" ..row[2].. "_overlay.png^[makealpha:255,126,126"
		local groups = {not_in_creative_inventory=1, not_in_craft_guide=1, oddly_breakable_by_hand=1}
		minetest.register_node(":" ..modname..":"..name, {
			description = desc,
			drawtype = "signlike",
			tiles = {tiles},
			inventory_image = tiles,
			wield_image = tiles,
			paramtype = "light",
			paramtype2 = "wallmounted",
			sunlight_propagates = true,
			is_ground_content = false,
			walkable = false,
			selection_box = {
				type = "wallmounted",
				--wall_top = <default>
				--wall_bottom = <default>
				--wall_side = <default>
			},
			groups = groups,
			legacy_wallmounted = false,
		})
		minetest.register_craft({
			output = from_node,
			recipe = {
				{modname..":"..name, modname..":"..name, modname..":"..name},
				{modname..":"..name, modname..":"..name, modname..":"..name},
				{modname..":"..name, modname..":"..name, modname..":"..name},
			},
		})				
	end
	letter_cutter.known_nodes[from_node] = {modname, subname}
end

letters.register_letters("darkage", "marble", "darkage:marble", "Marble", "darkage_marble.png")

--[[How many microblocks does this shape at the output inventory cost:
letter_cutter.cost_in_microblocks = {
	1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1,
}]]
cost = 0.110

letter_cutter.names = {
	{"letter_a"},
	{"letter_b"},
	{"letter_c"},
	{"letter_d"},
	{"letter_e"},
	{"letter_f"},
	{"letter_g"},
	{"letter_h"},
	{"letter_i"},
	{"letter_j"},
	{"letter_k"},
	{"letter_l"},
	{"letter_m"},
	{"letter_n"},
	{"letter_o"},
	{"letter_p"},
	{"letter_q"},
	{"letter_r"},
	{"letter_s"},
	{"letter_t"},
	{"letter_u"},
	{"letter_v"},
	{"letter_w"},
	{"letter_x"},
	{"letter_y"},
	{"letter_z"},
}

--[[function letter_cutter:get_cost(inv, stackname)
	for i, item in pairs(inv:get_list("output")) do
		if item:get_name() == stackname then
			return letter_cutter.cost_in_microblocks[i]
		end
	end
end]]

function letter_cutter:get_output_inv(modname, subname, amount, max)

	local list = {}
	-- If there is nothing inside, display empty inventory:
	if amount < 1 then
		return list
	end

	for i, t in ipairs(letter_cutter.names) do
		table.insert(list, modname .. ":" .. subname .. "_" .. t[1]
			.. " " .. math.min(math.floor(amount/cost), max))
	end
	return list
end


-- Reset empty letter_cutter after last full block has been taken out
-- (or the letter_cutter has been placed the first time)
-- Note: max_offered is not reset:
function letter_cutter:reset(pos)
	local meta = minetest.get_meta(pos)
	local inv  = meta:get_inventory()

	inv:set_list("input",  {})
	inv:set_list("output", {})
	meta:set_int("anz", 0)

	meta:set_string("infotext",
			"Letter Cutter is empty (owned by "..
				meta:get_string("owner")..")")
end

function letter_cutter:update_inventory(pos, amount)
	local meta          = minetest.get_meta(pos)
	local inv           = meta:get_inventory()

	amount = meta:get_int("anz") + amount

	-- The material is recycled automaticly.

	if amount < 1 then -- If the last block is taken out.
		self:reset(pos)
		return
	end
 
	local stack = inv:get_stack("input",  1)
	-- At least one "normal" block is necessary to see what kind of stairs are requested.
	if stack:is_empty() then
		-- Any microblocks not taken out yet are now lost.
		-- (covers material loss in the machine)
		self:reset(pos)
		return

	end
	local node_name = stack:get_name() or ""
	local name_parts = letter_cutter.known_nodes[node_name] or ""
	local modname  = name_parts[1] or ""
	local material = name_parts[2] or ""

	inv:set_list("input", { -- Display as many full blocks as possible:
		node_name.. " " .. math.floor(amount)
	})

	-- The stairnodes made of default nodes use moreblocks namespace, other mods keep own:
--	if modname == "default" then
	--	modname = "moreblocks"
	--end
	-- print("letter_cutter set to " .. modname .. " : "
	--	.. material .. " with " .. (amount) .. " microblocks.")

	-- Display:
	inv:set_list("output",
		self:get_output_inv(modname, material, amount,
				meta:get_int("max_offered")))
	-- Store how many microblocks are available:
	meta:set_int("anz", amount)

	meta:set_string("infotext",
			"Letter Cutter is working (owned by "..
				meta:get_string("owner")..")")
end


-- The amount of items offered per shape can be configured:
function letter_cutter.on_receive_fields(pos, formname, fields, sender)
	local meta = minetest.get_meta(pos)
	local max = tonumber(fields.max_offered)
	if max and max > 0 then
		meta:set_string("max_offered",  max)
		-- Update to show the correct number of items:
		letter_cutter:update_inventory(pos, 0)
	end
end


-- Moving the inventory of the letter_cutter around is not allowed because it
-- is a fictional inventory. Moving inventory around would be rather
-- impractical and make things more difficult to calculate:
function letter_cutter.allow_metadata_inventory_move(
		pos, from_list, from_index, to_list, to_index, count, player)
	return 0
end


-- Only input- and recycle-slot are intended as input slots:
function letter_cutter.allow_metadata_inventory_put(
		pos, listname, index, stack, player)
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
		for name, t in pairs(letter_cutter.known_nodes) do
			if name == stackname and inv:room_for_item("input", stack) then
				return count
			end
		end
		return 0
	end
end

-- Taking is allowed from all slots (even the internal microblock slot).
-- Putting something in is slightly more complicated than taking anything
-- because we have to make sure it is of a suitable material:
function letter_cutter.on_metadata_inventory_put(
		pos, listname, index, stack, player)
	-- We need to find out if the letter_cutter is already set to a
	-- specific material or not:
	local meta = minetest.get_meta(pos)
	local inv  = meta:get_inventory()
	local stackname = stack:get_name()
	local count = stack:get_count()

	-- Putting something into the input slot is only possible if that had
	-- been empty before or did contain something of the same material:
	if listname == "input" then
		-- Each new block is worth 8 microblocks:
		letter_cutter:update_inventory(pos, count)
	end
end

function letter_cutter.on_metadata_inventory_take(
		pos, listname, index, stack, player)
	-- If it is one of the offered stairs: find out how many
	-- microblocks have to be substracted:
	if listname == "output" then
		-- We do know how much each block at each position costs:
		letter_cutter:update_inventory(pos, 8 * -cost)
	elseif listname == "input" then
		-- Each normal (= full) block taken costs 8 microblocks:
		letter_cutter:update_inventory(pos, 8 * -stack:get_count())
	end
	-- The recycle field plays no role here since it is processed immediately.
end

gui_slots = "listcolors[#606060AA;#808080;#101010;#202020;#FFF]"

function letter_cutter.on_construct(pos)
	local meta = minetest.get_meta(pos)
	meta:set_string("formspec", "size[11,9]" ..gui_slots..
			"label[0,0;Input\nmaterial]" ..
			"list[current_name;input;1.5,0;1,1;]" ..
			"list[current_name;output;2.8,0;8,4;]" ..
			"list[current_player;main;1.5,5;8,4;]")

	meta:set_int("anz", 0) -- No microblocks inside yet.
	meta:set_string("max_offered", 9) -- How many items of this kind are offered by default?
	meta:set_string("infotext", "Letter Cutter is empty")

	local inv = meta:get_inventory()
	inv:set_size("input", 1)    -- Input slot for full blocks of material x.
	inv:set_size("output", 4*8) -- 4x8 versions of stair-parts of material x.

	letter_cutter:reset(pos)
end


function letter_cutter.can_dig(pos,player)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	if not inv:is_empty("input") then
		return false
	end
	-- Can be dug by anyone when empty, not only by the owner:
	return true
end

minetest.register_node("letters:letter_cutter",  {
	description = "Leter Cutter", 
	drawtype = "nodebox", 
	node_box = {
		type = "fixed", 
		fixed = {
			{-0.4375, -0.5, -0.4375, -0.3125, 0.125, -0.3125}, -- NodeBox1
			{-0.4375, -0.5, 0.3125, -0.3125, 0.125, 0.4375}, -- NodeBox2
			{0.3125, -0.5, 0.3125, 0.4375, 0.125, 0.4375}, -- NodeBox3
			{0.3125, -0.5, -0.4375, 0.4375, 0.125, -0.3125}, -- NodeBox4
			{-0.5, 0.0625, -0.5, 0.5, 0.25, 0.5}, -- NodeBox5
			{0.125, 0.25, -0.1875, 0.3125, 0.3125, -0.125}, -- NodeBox6
			{-0.125, 0.25, -0.125, 0.125, 0.3125, -0.0625}, -- NodeBox7
			{-0.3125, 0.25, -0.0625, -0.0625, 0.3125, 0.0625}, -- NodeBox8
			{-0.125, 0.25, 0.0625, 0.125, 0.3125, 0.125}, -- NodeBox9
			{0.125, 0.25, 0.125, 0.3125, 0.3125, 0.1875}, -- NodeBox10
			{0.125, 0.25, -0.125, 0.1875, 0.3125, 0.125}, -- NodeBox11
		},
	},
	tiles = {"letters_letter_cutter_top.png",
		"default_tree.png",
		"letters_letter_cutter_side.png"},
	paramtype = "light", 
	sunlight_propagates = true,
	paramtype2 = "facedir", 
	groups = {choppy = 2,oddly_breakable_by_hand = 2},
	sounds = default.node_sound_wood_defaults(),
	on_construct = letter_cutter.on_construct,
	can_dig = letter_cutter.can_dig,
	-- Set the owner of this circular saw.
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		local owner = placer and placer:get_player_name() or ""
		meta:set_string("owner",  owner)
		meta:set_string("infotext",
				"Letter Cutter is empty (owned by "
					..meta:get_string("owner")..")")
	end,

	-- The amount of items offered per shape can be configured:
	on_receive_fields = letter_cutter.on_receive_fields,
	allow_metadata_inventory_move = letter_cutter.allow_metadata_inventory_move,
	-- Only input- and recycle-slot are intended as input slots:
	allow_metadata_inventory_put = letter_cutter.allow_metadata_inventory_put,
	-- Taking is allowed from all slots (even the internal microblock slot). Moving is forbidden.
	-- Putting something in is slightly more complicated than taking anything because we have to make sure it is of a suitable material:
	on_metadata_inventory_put = letter_cutter.on_metadata_inventory_put,
	on_metadata_inventory_take = letter_cutter.on_metadata_inventory_take,
})



local default_nodes = {
	{"stone", "stone"},
	{"cobble", "cobble",},
	{"mossycobble", "mossycobble"},
	{"brick", "brick"},
	{"sandstone", "sandstone" },
	{"steelblock", "steel_block"},
	{"goldblock", "gold_block"},
	{"copperblock", "copper_block"},
	{"bronzeblock", "bronze_block"},
	{"diamondblock", "diamond_block"},
	{"desert_stone", "desert_stone"},
	{"desert_cobble", "desert_cobble"},
	{"tree", "tree"},
	{"wood", "wood"},
	{"jungletree", "jungletree"},
	{"junglewood", "junglewood"},
	{"obsidian", "obsidian"},
	{"stonebrick", "stone_brick"},
	{"desert_stonebrick", "desert_stone_brick"},
	{"sandstonebrick", "sandstone_brick"},
	{"obsidianbrick", "obsidian_brick"},
	{"pinetree", "pinetree"},
	{"pinewood", "pinewood"},
}

for _, row in pairs(default_nodes) do
	local nodename = "default:" ..row[1]
	local ndef = minetest.registered_nodes[nodename]
	local texture = "default_" ..row[2].. ".png"
	letters.register_letters("default", row[1], nodename, ndef.description, texture) 
end

