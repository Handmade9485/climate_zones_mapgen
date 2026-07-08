WORLD_SCALE = 1

HEIGHT_SCALE = 50 * WORLD_SCALE
CLIMATE_SCALE = 97 * WORLD_SCALE
PLATEAU_SIZE = 401 * WORLD_SCALE

BLEND_FACTOR = 10
HEIGHT_OFFSET = .0

local np_terrain = {
	offset = 0,
	scale = 1,
	spread = {x = 4 * HEIGHT_SCALE, y = 4 * HEIGHT_SCALE, z = 4 * HEIGHT_SCALE},
	seed = 5900033,
	octaves = 7,
	persist = 0.5,
	lacunarity = 2.0,
	--flags = ""
}

local np_heat = {
	offset = 0,
	scale = 1,
	spread = {x=128, y=128, z=128},
	seed = 23,
	octaves = 1,
}

local np_humidity = {
	offset = 0,
	scale = 1,
	spread = {x=128, y=128, z=128},
	seed = 42,
	octaves = 1,
}

-- Initialize noise object to nil. It will be created once only during the
-- generation of the first mapchunk, to minimise memory use.
local nobj_terrain = nil

local nobj_voronoi = nil

-- Localise noise buffer table outside the loop, to be re-used for all
-- mapchunks, therefore minimising memory use.
local nvals_terrain1 = {}
local nvals_terrain2 = {}

-- Localise data buffer table outside the loop, to be re-used for all
-- mapchunks, therefore minimising memory use.
local data = {}

core.set_mapgen_setting("mg_name", "singlenode", true)
core.set_mapgen_setting("mg_flags", "nolight", true)

local c_stone, c_water, c_river
core.register_on_mods_loaded(function()
	c_stone = core.get_content_id("mapgen_stone")
	c_water = core.get_content_id("mapgen_water_source")
	c_river = core.get_content_id("mapgen_river_water_source")
end)

local function n22(x, y)
	ax = x * 534.709
	ay = y * 7123.5381
	az = x * 6783.52711
	ax = ax - math.floor(ax)
	ay = ay - math.floor(ay)
	az = az - math.floor(az)

	dot = ax * ax + ay * ay + az * az
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

local function get_climate_noise(x, y, nobj)
	x = x / CLIMATE_SCALE
	y = y / CLIMATE_SCALE

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

	return nobj:get_2d({x=min_x*CLIMATE_SCALE, y=min_y*CLIMATE_SCALE}) * .5 + .5
end

local function get_climate_noise_old(x, y, nobj)
	x = x / CLIMATE_SCALE
	y = y / CLIMATE_SCALE

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

		local weight = dist_sq ^ -50

		local noise = nobj:get_2d({x=cell_x*CLIMATE_SCALE, y=cell_y*CLIMATE_SCALE}) * .5 + .5
		sum = sum + noise * weight
		w_sum = w_sum + weight
	end
	end

	return sum / w_sum
end

local function get_plateau_noise(x, y)
	x = x / PLATEAU_SIZE
	y = y / PLATEAU_SIZE
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

local function get_rivers(sidelen, heightmap, humidmap, rivers)
	for z = 2, sidelen - 2 do
	for x = 2, sidelen - 2 do
		local i = x + z * sidelen
		local height = heightmap[i]
		local higher_neighbors = 0

		local river = {}

		local steepest_neighbor = i
		local max_steepness = -1
		local second_steepness = -1

		for n_z = z-1, z+1 do
		for n_x = x-1, x+1 do
		if n_x ~= x or n_z ~= z then
			local n_i = n_x + n_z * sidelen
			local new_steepness = heightmap[n_i] - height
			if new_steepness > 0 then
				higher_neighbors = higher_neighbors + 1
			end
			if new_steepness > max_steepness then
				second_steepness = max_steepness
				max_steepness = new_steepness
				steepest_neighbor = n_i
			end
		end
		end
		end

		if higher_neighbors == 8 then
		while i >= 1 and i <= #rivers do
			table.insert(river, i)

			local best_neighbor = nil
			local best_drop = -math.huge

			local ix = i % sidelen
			local iz = math.floor(i / sidelen)

			for o_z = -1, 1 do
			for o_x = -1, 1 do
			if o_x ~= 0 or o_z ~= 0 then
				local nx = ix + o_x
				local nz = iz + o_z

				if nx >= 2 and nx <= sidelen - 2 and nz >= 2 and nz <= sidelen - 2 then
					local n_i = nx + nz * sidelen

					-- Find where this neighbor would naturally flow.
					local lowest = n_i
					local biggest_drop = 0

					for p_z = -1, 1 do
					for p_x = -1, 1 do
						if p_x ~= 0 or p_z ~= 0 then
							local nn_i = n_i + p_x + p_z * sidelen
							local drop = heightmap[n_i] - heightmap[nn_i]

							if drop > biggest_drop then
								biggest_drop = drop
								lowest = nn_i
							end
						end
					end
					end

					-- Does this neighbor drain into us?
					if lowest == i then
						local drop = heightmap[n_i] - heightmap[i]
						if drop > best_drop then
							best_drop = drop
							best_neighbor = n_i
						end
					end
				end
			end
			end
			end

			if not best_neighbor then
				break
			end

			i = best_neighbor
		end
		end

		if #river >= 10 then
			local widened = {}
			for _, r_i in pairs(river) do
			if r_i >= 2 and r_i + 1 <= #rivers and heightmap[r_i-1] > heightmap[r_i+1] then
				table.insert(widened, r_i+1)
			elseif r_i >= 2 and r_i + 1 <= #rivers and heightmap[r_i-1] <= heightmap[r_i+1] then
				table.insert(widened, r_i+1)
			end
			if r_i - sidelen >= 1 and r_i + sidelen <= #rivers and heightmap[r_i-sidelen] > heightmap[r_i+sidelen] then
				table.insert(widened, r_i+sidelen)
			elseif r_i - sidelen >= 1 and r_i + sidelen <= #rivers and heightmap[r_i-sidelen] <= heightmap[r_i+sidelen] then
				table.insert(widened, r_i+sidelen)
			end
			end
			for _, w_i in pairs(widened) do
				table.insert(river, w_i)
			end

			for _, r_i in pairs(river) do
				rivers[r_i] = true
				for o_x = -2, 2 do
				for o_z = -2, 2 do
					local n_i = r_i + o_x + o_z * sidelen
					if n_i >= 1 and n_i <= #humidmap then
						humidmap[n_i] = 1 - (1 - humidmap[n_i]) * 0.95
					end
				end
				end
			end
		end
	end
	end
end

core.register_on_generated(function(minp, maxp, seed)
	local minp_offset = {x=minp.x + HEIGHT_SCALE, y=minp.y + HEIGHT_SCALE, z=minp.z + HEIGHT_SCALE}

	local sidelen = maxp.x - minp.x + 1
	local permapdims2d = {x = sidelen, y = sidelen}
	nobj_terrain = nobj_terrain or core.get_value_noise_map(np_terrain, permapdims2d)
	nobj_terrain:get_2d_map_flat({x=minp.x, y=minp.z}, nvals_terrain1)
	nobj_terrain:get_2d_map_flat({x=minp_offset.x, y=minp_offset.z}, nvals_terrain2)

	nobj_heat = nobj_heat or core.get_value_noise(np_heat)
	nobj_humidity = nobj_humidity or core.get_value_noise(np_humidity)

	local vm, emin, emax = core.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}
	vm:get_data(data)

	heatmap = {}
	humidmap = {}
	heightmap = {}
	rivers = {}

	local ni = 1
	for z = minp.z, maxp.z do
	for x = minp.x, maxp.x do
		local h1 = nvals_terrain1[ni]
		local h2 = nvals_terrain2[ni]
		local mountain = math.min(h1*h1, h1*h2) + HEIGHT_OFFSET
		local plateau = get_plateau_noise(x, z) * .75 + .25
		heightmap[ni] = mountain * plateau

		local o_x, o_z = n22(x, z)
		heatmap[ni] = get_climate_noise(x + o_x*BLEND_FACTOR, z + o_z*BLEND_FACTOR, nobj_heat) * 100 * (1-heightmap[ni]^3)
		humidmap[ni] = get_climate_noise(x + o_x*BLEND_FACTOR, z + o_z*BLEND_FACTOR, nobj_humidity) * 100

		rivers[ni] = false

		ni = ni + 1
	end
	end

	get_rivers(sidelen, heightmap, humidmap, rivers)

	ni = 1
	for z = minp.z, maxp.z do
	for x = minp.x, maxp.x do
		local node_height = math.floor(heightmap[ni] * HEIGHT_SCALE)
		-- sink rivers into the ground
		if rivers[ni] and node_height > 1 then
			node_height = node_height - 1
		end

		for y = minp.y, maxp.y do
			local vi = area:index(x, y, z)

			if y <= 0 and y > node_height then
				data[vi] = c_water
			elseif y == node_height and y > 0 and rivers[ni] then
				data[vi] = c_river
			elseif y <= node_height then
				data[vi] = c_stone
			end
		end

		ni = ni + 1
	end
	end

	biomegen.generate_biomes(data, area, minp, maxp, heatmap, humidmap)
	vm:set_data(data)
	core.generate_ores(vm, minp, maxp)
	biomegen.place_all_decos(data, area, vm, minp, maxp, seed)
	vm:get_data(data)
	biomegen.dust_top_nodes(data, area, vm, minp, maxp)


	-- Calculate lighting for what has been created.
	vm:calc_lighting()
	-- Write what has been created to the world.
	vm:write_to_map()
	-- Liquid nodes were placed so set them flowing.
	vm:update_liquids()
end)
