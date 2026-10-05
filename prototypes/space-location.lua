-- generate a surface prototype for the personal roboport travel surface. see travel.lua for more information
data:extend {{
    type = "planet",
    name = "tardis-travel-surface",
    localised_name = "",
    hidden = true,
    icon = "__base__/graphics/icons/space-science-pack.png",
    icon_size = 64,
    gravity_pull = 0,
    distance = 0,
    orientation = 0,
    map_gen_settings = {
        height = 1,
        width = 1,
        property_expression_names = {},
        autoplace_settings = {
            ["decorative"] = {treat_missing_as_default = false, settings = {}},
            ["entity"] = {treat_missing_as_default = false, settings = {}},
            ["tile"] = {treat_missing_as_default = false, settings = {}},
        }
    },
    surface_properties = mods["space-age"] and {
        gravity = -1,
        pressure = 10000,
        ["solar-power"] = 0,
    },
}}

-- single unified surface for all tardis interiors
data:extend {{
    type = "planet",
    name = "tardis-pocket-surface",
    localised_name = {"space-location-name.tardis-pocket-surface"},
    localised_description = {"space-location-description.tardis-pocket-surface"},
    hidden = true,
    hidden_in_factoriopedia = true,
    icon = "__tardis__/graphics/icon/surface.png",
    icon_size = 256,
    gravity_pull = 0,
    distance = 0,
    orientation = 0,
    draw_orbit = false,
    auto_save_on_first_trip = false,
    order = "z-[tardis-pocket-surface]",
    map_gen_settings = {
        height = 2,
        width = 2,
        property_expression_names = {},
        autoplace_settings = {
            ["decorative"] = {treat_missing_as_default = false, settings = {}},
            ["entity"] = {treat_missing_as_default = false, settings = {}},
            ["tile"] = {treat_missing_as_default = false, settings = {}},
        }
    },
    surface_properties = {
        ["solar-power"] = 200,
        ["day-night-cycle"] = 0,
        ["ceiling"] = 0,
    },
    surface_render_parameters = feature_flags.expansion_shaders and {
        fog = {
            shape_noise_texture = {
                filename = "__core__/graphics/clouds-noise.png",
                size = 2048
            },
            detail_noise_texture = {
                filename = "__core__/graphics/clouds-detail-noise.png",
                size = 2048
            },
            color1 = {0.3, 0.3, 0.3},
            color2 = {0.3, 0.3, 0.3},
            fog_type = "vulcanus",
        },
        draw_sprite_clouds = false,
    } or nil,
}}
