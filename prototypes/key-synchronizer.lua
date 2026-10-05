local T = "__tardis__"

local colors = {
    {name = "white", r = 1, g = 1, b = 1},
    {name = "red", r = 1, g = 0.2, b = 0.2},
    {name = "green", r = 0.2, g = 1, b = 0.2},
    {name = "blue", r = 0.2, g = 0.5, b = 1},
    {name = "yellow", r = 1, g = 1, b = 0.2},
    {name = "orange", r = 1, g = 0.6, b = 0.2},
    {name = "purple", r = 0.8, g = 0.2, b = 1},
    {name = "pink", r = 1, g = 0.4, b = 0.8},
    {name = "cyan", r = 0.2, g = 0.8, b = 1},
    {name = "black", r = 0.2, g = 0.2, b = 0.2},
}

for _, color in pairs(colors) do
    local key_name = "tardis-key-" .. color.name

    data:extend{{
        type = "simple-entity",
        name = key_name,
        localised_name = {"item-name.tardis-key"},
        localised_description = {"color." .. color.name},
        icons = {
            {icon = T .. "/graphics/items/key.png", icon_size = 64},
            {icon = T .. "/graphics/items/key-tint.png", icon_size = 64, tint = {r = color.r, g = color.g, b = color.b, a = 1}},
        },
        flags = {"not-on-map", "placeable-off-grid"},
        selectable_in_game = false,
        max_health = 1,
        collision_box = {{0, 0}, {0, 0}},
        selection_box = {{0, 0}, {0, 0}},
        collision_mask = {layers = {}},
        pictures = {{
            layers = {
                {
                    filename = T .. "/graphics/items/key.png",
                    width = 64,
                    height = 64,
                },
                {
                    filename = T .. "/graphics/items/key-tint.png",
                    width = 64,
                    height = 64,
                    tint = {r = color.r, g = color.g, b = color.b, a = 1},
                },
            }
        }},
        autoplace = {probability_expression = 0},
    }}

    data:extend{{
        type = "item-with-tags",
        name = key_name,
        localised_name = {"item-name.tardis-key"},
        localised_description = {"color." .. color.name},
        icons = {
            {icon = T .. "/graphics/items/key.png", icon_size = 64},
            {icon = T .. "/graphics/items/key-tint.png", icon_size = 64, tint = {r = color.r, g = color.g, b = color.b, a = 1}},
        },
        stack_size = 1,
        subgroup = "tardis",
        flags = {"not-stackable"},
        place_result = key_name,
    }}
end

data:extend {
    {
        type = "container",
        name = "tardis-key-synchronizer",
        icon = T .. "/graphics/buildings/key-synchronizer/icon.png",
        icon_size = 64,
        flags = {"player-creation", "placeable-player"},
        minable = {mining_time = 0.5, result = "tardis-key-synchronizer", count = 1},
        selectable_in_game = true,
        hidden = true,
        hidden_in_factoriopedia = true,
        max_health = 1000,
        collision_box = {{-0.95, -0.95}, {0.95, 0.95}},
        selection_box = {{-0.95, -0.95}, {0.95, 0.95}},
        collision_mask = {layers = {object = true, player = true, water_tile = true}},
        inventory_size = 1,
        quality_affects_inventory_size = false,
        picture = {
            layers = {
                {
                    filename = T .. "/graphics/buildings/key-synchronizer/shadow.png",
                    width = 314,
                    height = 157,
                    scale = 0.5,
                    shift = {1.25, 0},
                    draw_as_shadow = true,
                },
                {
                    filename = T .. "/graphics/buildings/key-synchronizer/base.png",
                    width = 314,
                    height = 157,
                    scale = 0.5,
                    shift = {1.25, 0},
                },
            }
        },
        render_layer = "object",
    },
    {
        type = "item",
        name = "tardis-key-synchronizer",
        icon = T .. "/graphics/buildings/key-synchronizer/icon.png",
        icon_size = 64,
        place_result = "tardis-key-synchronizer",
        stack_size = 1,
        subgroup = "tardis",
        order = "b",
    },
}
