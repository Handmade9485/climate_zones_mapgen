local M = {}
local config = climate_zones.config

local function trace_rivulet(start_x, start_z, sidelen, cache, gen_data)
	local river = {}
	local cur_x = start_x
	local cur_z = start_z

	while true do
		local i = cur_x + cur_z * sidelen
		if cache[i] and #cache[i] == 0 then
			return {} -- invalid rivulet
		elseif cache[i] and #cache[i] > 0 then
			table.move(cache[i], 1, #cache[i], #river + 1, river)
			return river
		end

		table.insert(river, i)

		local best_neighbor_x = nil
		local best_neighbor_z = nil
		local lowest_height = 999

		for z = cur_z-1, cur_z+1 do
		for x = cur_x-1, cur_x+1 do
			-- touches chunk boundary = discard
			if x <= 1 or x >= sidelen or z <= 1 or z >= sidelen then
				return {}
			end

			local n_i = x + z * sidelen
			local new_height = gen_data.heightmap[n_i]

			if new_height < lowest_height then
				lowest_height = new_height
				best_neighbor_x = x
				best_neighbor_z = z
			end
		end
		end

		if best_neighbor_x == cur_x and best_neighbor_z == cur_z or lowest_height <= 0 then
			return river
		end

		cur_x = best_neighbor_x
		cur_z = best_neighbor_z
	end
end

function M.gen_rivulets(gen_data)
	local longest_river = {}
	local cache = {}
	for x = 1, gen_data.sidelen do
	for z = 1, gen_data.sidelen do
		local i = x + z * gen_data.sidelen
		local river = trace_rivulet(x, z, gen_data.sidelen, cache, gen_data)
		cache[i] = river;
		if river and #river > #longest_river then
			longest_river = river
		end
	end
	end

	local height_diff = 0
	if #longest_river >= 2 then
		local source = longest_river[1]
		local sink = longest_river[#longest_river]
		height_diff = gen_data.heightmap[source] - gen_data.heightmap[sink]
	end

	if height_diff > (1 / #longest_river) then
		local river_banks = {}
		for _, r_i in pairs(longest_river) do
			local main_height = gen_data.heightmap[r_i]
			if r_i >= 2 and r_i + 1 <= gen_data.sidelen2 and gen_data.heightmap[r_i-1] > gen_data.heightmap[r_i+1] then
				table.insert(river_banks, r_i+1)
			elseif r_i >= 2 and r_i + 1 <= gen_data.sidelen2 and gen_data.heightmap[r_i-1] <= gen_data.heightmap[r_i+1] then
				table.insert(river_banks, r_i-1)
			end
			if r_i - gen_data.sidelen >= 1 and r_i + gen_data.sidelen <= gen_data.sidelen2 and gen_data.heightmap[r_i-gen_data.sidelen] > gen_data.heightmap[r_i+gen_data.sidelen] then
				table.insert(river_banks, r_i + gen_data.sidelen)
			elseif r_i - gen_data.sidelen >= 1 and r_i + gen_data.sidelen <= gen_data.sidelen2 and gen_data.heightmap[r_i-gen_data.sidelen] <= gen_data.heightmap[r_i+gen_data.sidelen] then
				table.insert(river_banks, r_i - gen_data.sidelen)
			end
		end
		table.move(river_banks, 1, #river_banks, #longest_river + 1, longest_river)

		for _, r_i in pairs(longest_river) do
			gen_data.rivers_depths[r_i] = 1
			for o_x = -config.rivulet_humidity_radius, config.rivulet_humidity_radius do
			for o_z = -config.rivulet_humidity_radius, config.rivulet_humidity_radius do
				local n_i = r_i + o_x + o_z * gen_data.sidelen
				if n_i >= 1 and n_i <= #gen_data.humidmap then
					gen_data.humidmap[n_i] = 1 - (1 - gen_data.humidmap[n_i]) * config.rivulet_humidity_factor
				end
			end
			end
		end
	end
end

return M
