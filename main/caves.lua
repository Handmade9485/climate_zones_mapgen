local M = {}
local config = climate_zones.config

local nobj_surface_caves = nil
local nobj_deep_caves = nil
function M.gen_caves(gen_data)
	local dims = {x=gen_data.sidelen, y=gen_data.sidelen, z=gen_data.sidelen}
	local nvals_surface_caves = {}
	local nvals_deep_caves = {}

	local np_surface = config.caves_surface_np
	nobj_surface_caves = nobj_surface_caves or core.get_value_noise_map(np_surface, dims)
	nobj_surface_caves:get_3d_map_flat(gen_data.minp, nvals_surface_caves)

	local np_depths = config.caves_depths_np
	nobj_deep_caves = nobj_deep_caves or core.get_value_noise_map(np_depths, dims)
	nobj_deep_caves:get_3d_map_flat(gen_data.minp, nvals_deep_caves)

	for y = 0, gen_data.sidelen-1 do
		local blend_factor = smoothstep(config.caves_max_growth_depth, config.terrain_size, y + gen_data.minp.y)
		for z = 0, gen_data.sidelen-1 do
		for x = 0, gen_data.sidelen-1 do
			local i = 1 + x + y * gen_data.sidelen + z * gen_data.sidelen^2
			local surface_caveness = nvals_surface_caves[i] * .5 + .5
			local deep_caveness = nvals_deep_caves[i] * .5 + .5

			local caveness = deep_caveness + (surface_caveness - deep_caveness) * blend_factor
			local cave_threshold = config.caves_depths_threshold + (config.caves_surface_threshold - config.caves_depths_threshold) * blend_factor

			gen_data.caves[i] = caveness > cave_threshold
		end
		end
	end
end

local nobj_worm_caves1 = nil
local nobj_worm_caves2 = nil
function M.gen_worm_caves(gen_data)
	local np1 = table.copy(config.caves_tunnel_np)
	local np2 = table.copy(config.caves_tunnel_np)
	np1.seed = 42
	np2.seed = 43
	local dims = {x=gen_data.sidelen, y=gen_data.sidelen, z=gen_data.sidelen}
	nobj_worm_caves1 = nobj_worm_caves1 or core.get_value_noise_map(np1, dims)
	nobj_worm_caves2 = nobj_worm_caves2 or core.get_value_noise_map(np2, dims)

	local nvals_ridge_1 = {}
	local nvals_ridge_2 = {}
	nobj_worm_caves1:get_3d_map_flat(gen_data.minp, nvals_ridge_1)
	nobj_worm_caves2:get_3d_map_flat(gen_data.minp, nvals_ridge_2)
	for i = 1, #nvals_ridge_1 do
		local r1 = 1 - math.abs(nvals_ridge_1[i])
		local r2 = 1 - math.abs(nvals_ridge_2[i])
		-- min gives thicker tunnels than multiplication
		gen_data.worm_caves[i] = math.min(r1, r2) > config.caves_tunnel_threshold
	end
end

return M
