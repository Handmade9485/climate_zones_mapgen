local M = {}
local config = climate_zones.config

local function get_climate_noise(x, y, nobj)
	x = x / config.climate_size
	y = y / config.climate_size

	local id_x = math.floor(x)
	local id_y = math.floor(y)

	local fr_x = x - id_x
	local fr_y = y - id_y

	local min_x = 999
	local min_y = 999
	local min_dist = 999

	for o_y = -1, 1 do
	for o_x = -1, 1 do
		local cell_x = id_x + o_x
		local cell_y = id_y + o_y

		-- randomly shift the origin around in the cell, so the voronoi isnt just squares
		local d_x, d_y = n22(cell_x, cell_y)
		local p_x = d_x + o_x
		local p_y = d_y + o_y

		local dist_x = p_x - fr_x
		local dist_y = p_y - fr_y
		local dist_sq = dist_x * dist_x + dist_y * dist_y

		if dist_sq < min_dist then
			min_dist = dist_sq
			min_x = cell_x
			min_y = cell_y
		end
	end
	end

	return nobj:get_2d({x=min_x * config.climate_size, y=min_y * config.climate_size}) * .5 + .5
end

local nobj_heat = nil
local nobj_humidity = nil
function M.gen_climatemap(gen_data)
	local dims = {x = gen_data.sidelen, y = gen_data.sidelen, z = gen_data.sidelen}
	nobj_heat = nobj_heat or core.get_value_noise(config.np_heat, dims)
	nobj_humidity = nobj_humidity or core.get_value_noise(config.np_humidity, dims)

	local ni = 1
	for z = gen_data.minp.z, gen_data.maxp.z do
	for x = gen_data.minp.x, gen_data.maxp.x do
		local o_x, o_z = n22(x, z)
		gen_data.heatmap[ni] = get_climate_noise(x + o_x*config.blend_factor, z + o_z*config.blend_factor, nobj_heat) * 100 * (1-gen_data.heightmap[ni]^3)
		gen_data.humidmap[ni] = get_climate_noise(x + o_x*config.blend_factor, z + o_z*config.blend_factor, nobj_humidity) * 100

		ni = ni + 1
	end
	end
end

return M
