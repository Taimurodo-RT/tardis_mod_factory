local config = require("difficulty-config")

local difficulty = settings.startup["tardis-recipe-difficulty"].value
if difficulty == "space" and not mods["space-age"] then
    difficulty = "hard"
end
local recipe = config.recipe[difficulty]

data:extend {
    {
        type = "recipe",
        name = "tardis",
        enabled = false,
        energy_required = recipe.energy_required,
        ingredients = recipe.ingredients,
        results = {{type = "item", name = "tardis", amount = 1}},
        main_product = "tardis",
        localised_name = {"entity-name.tardis"},
        category = data.raw["recipe-category"]["metallurgy-or-assembling"] and "metallurgy-or-assembling" or nil
    },
    {
        type = "recipe",
        name = "tardis-key-synchronizer",
        enabled = false,
        energy_required = 30,
        ingredients = {
            {type = "item", name = "steel-plate", amount = 100},
            {type = "item", name = "processing-unit", amount = 100},
        },
        results = {{type = "item", name = "tardis-key-synchronizer", amount = 1}},
    },
    {
        type = "recipe",
        name = "tardis-key-white",
        enabled = false,
        energy_required = 10,
        ingredients = {
            {type = "item", name = "iron-plate", amount = 100},
            {type = "item", name = "electronic-circuit", amount = 50},
        },
        results = {{type = "item", name = "tardis-key-white", amount = 1}},
    },
}

-- small vanilla change to allow factories to be crafted at the start of the game
if data.raw["recipe-category"]["metallurgy-or-assembling"] then
    table.insert(data.raw["assembling-machine"]["assembling-machine-1"].crafting_categories or {}, "metallurgy-or-assembling")
end
