letters = {
	letter_cutter = {}
}

local MP = minetest.get_modpath(minetest.get_current_modname())
dofile(MP..'/api.lua')
dofile(MP..'/itemlist.lua')

if minetest.get_modpath("default") then
	dofile(MP..'/letter_cutter.lua')
end

dofile(MP..'/registrations.lua')
