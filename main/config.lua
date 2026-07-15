local settings = core.settings
local function get_num(name, default)
	return tonumber(settings:get(name)) or default
end

local function cap_octaves(np)
	local min_spread = math.min(np.spread.x, np.spread.y, np.spread.z)
	local octaves = math.max(
		1,
		math.floor(math.log(min_spread / 4) / math.log(np.lacunarity or 2)) + 1
	)
	return math.min(np.octaves, octaves)
end


local config = {
	world_scale = get_num("climate_zones_world_scale", 1),

	terrain_size = get_num("climate_zones_terrain_size", 100),
	plateau_size = get_num("climate_zones_tectonic_size", 400),
	plateau_min_flatness = get_num("climate_zones_tectonic_min_flatness", .1),
	np_terrain = {
		offset = 0,
		scale = 1,
		spread = {},
		seed = 2,
		octaves = 16,
		persist = 0.5,
		lacunarity = 2.0,
	},

	climate_size = get_num("climate_zones_climate_size", 100),
	climate_spread = get_num("climate_zones_climate_spread", 256),
	blend_factor = get_num("climate_zones_climate_transition_size", 10),
	np_heat = {
		offset = 0,
		scale = 1,
		spread = {},
		seed = 3,
		octaves = 1,
	},
	np_humidity = {
		offset = 0,
		scale = 1,
		spread = {},
		seed = 5,
		octaves = 1,
	},

	crust_thickness = get_num("climate_zones_crust_thickness", 50),
	caves_max_growth_depth = get_num("climate_zones_caves_max_growth_depth", -8000),
	caves_surface_threshold = get_num("climate_zones_caves_surface_threshold", .85),
	caves_depths_threshold = get_num("climate_zones_caves_depths_threshold", .75),
	caves_surface_np = settings:get_np_group("climate_zones_caves_surface_noise") or {
		offset = 0,
		scale = 1,
		spread = {x = 50, y = 50, z = 50},
		seed = 7,
		octaves = 5,
		persist = 0.5,
		lacunarity = 2.0,
	},
	caves_depths_np = settings:get_np_group("climate_zones_caves_depths_noise") or {
		offset = 0,
		scale = 1,
		spread = {x = 4096, y = 1024, z = 4096},
		seed = 11,
		octaves = 9,
		persist = 0.5,
		lacunarity = 2.0,
	},
	caves_tunnel_np = settings:get_np_group("climate_zones_caves_tunnel_noise") or {
		offset = 0,
		scale = 1,
		spread = {x = 100, y = 100, z = 100},
		seed = 7,
		octaves = 5,
		persist = 0.5,
		lacunarity = 2.0,
	},
	caves_tunnel_threshold = get_num("climate_zones_caves_tunnel_threshold", 0.95),

	rivulet_enabled = settings:get_bool("climate_zones_gen_rivulets", true),
	rivulet_humidity_radius = get_num("climate_zones_rivulet_humidity_radius", 2),
	rivulet_humidity_factor = 1 - get_num("climate_zones_rivulet_humidity", 0.05),
}

config.terrain_size = config.terrain_size * config.world_scale
config.plateau_size = config.plateau_size * config.world_scale
config.climate_size = config.climate_size * config.world_scale
config.climate_spread = config.climate_spread * config.world_scale
config.caves_max_growth_depth = config.caves_max_growth_depth * config.world_scale

config.caves_surface_np.spread.x = config.caves_surface_np.spread.x * config.world_scale
config.caves_surface_np.spread.y = config.caves_surface_np.spread.y * config.world_scale
config.caves_surface_np.spread.z = config.caves_surface_np.spread.z * config.world_scale
config.caves_surface_np.octaves = cap_octaves(config.caves_surface_np)
config.caves_depths_np.spread.x = config.caves_depths_np.spread.x * config.world_scale
config.caves_depths_np.spread.y = config.caves_depths_np.spread.y * config.world_scale
config.caves_depths_np.spread.z = config.caves_depths_np.spread.z * config.world_scale
config.caves_depths_np.octaves = cap_octaves(config.caves_depths_np)
config.caves_tunnel_np.spread.x = config.caves_tunnel_np.spread.x * config.world_scale
config.caves_tunnel_np.spread.y = config.caves_tunnel_np.spread.y * config.world_scale
config.caves_tunnel_np.spread.z = config.caves_tunnel_np.spread.z * config.world_scale
config.caves_tunnel_np.octaves = cap_octaves(config.caves_tunnel_np)

-- 4 is just a good multiplier to make mountains appear natural
config.np_terrain.spread.x = 4 * config.terrain_size
config.np_terrain.spread.y = 4 * config.terrain_size
config.np_terrain.spread.z = 4 * config.terrain_size
config.np_terrain.octaves = cap_octaves(config.np_terrain)

config.np_heat.spread.x = config.climate_spread
config.np_heat.spread.y = config.climate_spread
config.np_heat.spread.z = config.climate_spread
config.np_heat.octaves = cap_octaves(config.np_heat)
config.np_humidity.spread.x = config.climate_spread
config.np_humidity.spread.y = config.climate_spread
config.np_humidity.spread.z = config.climate_spread
config.np_humidity.octaves = cap_octaves(config.np_humidity)

return config
