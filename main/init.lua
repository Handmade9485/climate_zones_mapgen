climate_zones = {}

local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)

local config = dofile(modpath .. "/config.lua")
climate_zones.config = config

local terrain = dofile(modpath .. "/terrain.lua")
local climate = dofile(modpath .. "/climate.lua")
local caves = dofile(modpath .. "/caves.lua")
local rivers = dofile(modpath .. "/rivers.lua")

function clamp(x, min_, max_)
	return math.max(min_, math.min(max_, x))
end

function smoothstep(edge0, edge1, x)
	local t = clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t^2 * (3 - 2 * t)
end

function sign(v)
	if v < 0 then
		return -1
	elseif v > 0 then
		return 1
	else
		return 0
	end
end

core.set_mapgen_setting("mg_name", "singlenode", true)
core.set_mapgen_setting("mg_flags", "nolight", true)

local c_stone, c_water, c_river
core.register_on_mods_loaded(function()
	c_stone = core.get_content_id("mapgen_stone")
	c_water = core.get_content_id("mapgen_water_source")
	c_river = core.get_content_id("mapgen_river_water_source")
end)

function n22(x, y)
	local ax = x * 534.709
	local ay = y * 7123.5381
	local az = x * 6783.52711
	ax = ax - math.floor(ax)
	ay = ay - math.floor(ay)
	az = az - math.floor(az)

	local dot = ax * ax + ay * ay + az * az
	dot = dot * 350.648391

	ax = ax + dot
	ay = ay + dot
	az = az + dot

	x = ax * ay
	y = ay * az
	x = x - math.floor(x)
	y = y - math.floor(y)
	return x, y
end

local function make_chunk(minp, maxp, seed)
	local vm, emin, emax = core.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}
	local data = {}
	vm:get_data(data)

	local intersects_surface = maxp.y >= -config.terrain_size - config.crust_thickness
	local sidelen = maxp.x - minp.x + 1

	local gen_data = {
		size = sidelen^2,
		sidelen = sidelen,
		minp = minp,
		maxp = maxp,
		heatmap = {},
		humidmap = {},
		heightmap = {},
		-- this is in nodes
		rivers_depths = {},
		-- these are booleans
		caves = {},
		worm_caves = {}
	}

	if intersects_surface then
		terrain.gen_heightmap(gen_data)
		climate.gen_climatemap(gen_data)
	-- 	gen_rivers(sidelen)
		if config.rivulet_enabled then
			rivers.gen_rivulets(gen_data)
		end
	end
	caves.gen_caves(gen_data)
	caves.gen_worm_caves(gen_data)

	local ni = 1
	local surface_node_height = nil
	for z = minp.z, maxp.z do
	for x = minp.x, maxp.x do
		if intersects_surface then
			surface_node_height = math.floor(gen_data.heightmap[ni] * config.terrain_size)
		end

		for y = minp.y, maxp.y do
			local vi = area:index(x, y, z)
			local ni_3d = 1 + (x-minp.x) + (y-minp.y) * sidelen + (z-minp.z) * sidelen^2

			local is_cave = gen_data.caves[ni_3d] or false
			local is_worm_cave = gen_data.worm_caves[ni_3d] or false

			if intersects_surface then
				if y <= 0 and y > surface_node_height then
					data[vi] = c_water
				elseif is_worm_cave then
					-- leave air
				elseif gen_data.rivers_depths[ni] and y >= 0 and y <= surface_node_height and y > surface_node_height - gen_data.rivers_depths[ni] then
					data[vi] = c_river
				elseif y <= surface_node_height and (y > surface_node_height - config.crust_thickness or not is_cave) then
					data[vi] = c_stone
				end
			elseif not intersects_surface and not (is_cave or is_worm_cave) then
					data[vi] = c_stone
			end
		end

		ni = ni + 1
	end
	end

	if intersects_surface then
		biomegen.generate_biomes(data, area, minp, maxp, gen_data.heatmap, gen_data.humidmap)
		vm:set_data(data)
	else
		biomegen.generate_biomes(data, area, minp, maxp)
		vm:set_data(data)
	end
	core.generate_ores(vm, minp, maxp)
	if config.terrain_size > 25 then
		biomegen.place_all_decos(data, area, vm, minp, maxp, seed)
	end
	vm:get_data(data)
	biomegen.dust_top_nodes(data, area, vm, minp, maxp)

	-- Calculate lighting for what has been created.
	vm:calc_lighting()
	-- Write what has been created to the world.
	vm:write_to_map()
	-- Liquid nodes were placed so set them flowing.
	vm:update_liquids()
end

-- Insert mapgen loop first, so that if other mods use core.register_on_generated, they will operate on an already generated terrain. This improves mod compatibility.
table.insert(core.registered_on_generateds, 1, make_chunk)
