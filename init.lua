letters = {
	letter_cutter = {}
}

local MP = core.get_modpath(core.get_current_modname())
dofile(MP..'/api.lua')
dofile(MP..'/itemlist.lua')

if core.get_modpath("default") then
	dofile(MP..'/letter_cutter.lua')
end

dofile(MP..'/registrations.lua')
