local M = {}
local config = climate_zones.config

local function get_plateau_noise(x, y)
	x = x / config.plateau_size
	y = y / config.plateau_size
	local id_x = math.floor(x)
	local id_y = math.floor(y)

	local fr_x = x - id_x
	local fr_y = y - id_y

	local sum = 0
	local w_sum = 0

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

		local weight = dist_sq ^ -5

		local noise, _ = n22(cell_x, cell_y)
		sum = sum + noise * weight
		w_sum = w_sum + weight
	end
	end

	return sum / w_sum
end

local nobj_terrain = nil
function M.gen_heightmap(gen_data)
	local p_offset = {x=gen_data.minp.x + config.terrain_size, y=gen_data.minp.z + config.terrain_size}
	local nvals_terrain1 = {}
	local nvals_terrain2 = {}
	local dims = {x = gen_data.sidelen, y = gen_data.sidelen, z = gen_data.sidelen}

	nobj_terrain = nobj_terrain or core.get_value_noise_map(config.np_terrain, dims)
	nobj_terrain:get_2d_map_flat({x=gen_data.minp.x, y=gen_data.minp.z}, nvals_terrain1)
	nobj_terrain:get_2d_map_flat(p_offset, nvals_terrain2)

	local ni = 1
	for z = gen_data.minp.z, gen_data.maxp.z do
	for x = gen_data.minp.x, gen_data.maxp.x do
		local h1 = nvals_terrain1[ni]
		local h2 = nvals_terrain2[ni]
		local mountain = math.min(h1*h1, h1*h2)
		local plateau = get_plateau_noise(x, z) * (1 - config.plateau_min_flatness) + config.plateau_min_flatness
		gen_data.heightmap[ni] = mountain * plateau

		ni = ni + 1
	end
	end
end

return M
