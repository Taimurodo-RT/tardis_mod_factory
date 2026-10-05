local has_space_age = mods["space-age"] ~= nil

local config = {}

config.technology = {
    easy = {
        count = 300,
        time = 30,
        prerequisites = {"logistic-science-pack"},
        ingredients = {
            {"automation-science-pack", 1},
            {"logistic-science-pack", 1},
        },
    },
    medium = {
        count = 750,
        time = 30,
        prerequisites = {"chemical-science-pack"},
        ingredients = {
            {"automation-science-pack", 1},
            {"logistic-science-pack", 1},
            {"chemical-science-pack", 1},
        },
    },
    hard = {
        count = 1500,
        time = 60,
        prerequisites = {"utility-science-pack"},
        ingredients = {
            {"automation-science-pack", 1},
            {"logistic-science-pack", 1},
            {"chemical-science-pack", 1},
            {"production-science-pack", 1},
            {"utility-science-pack", 1},
        },
    },
    space = {
        count = 2000,
        time = 60,
        prerequisites = {"electromagnetic-science-pack"},
        ingredients = {
            {"automation-science-pack", 1},
            {"logistic-science-pack", 1},
            {"chemical-science-pack", 1},
            {"production-science-pack", 1},
            {"utility-science-pack", 1},
            {"space-science-pack", 1},
            {"agricultural-science-pack", 1},
            {"electromagnetic-science-pack", 1},
        },
    },
}

config.recipe = {
    easy = {
        energy_required = 30,
        ingredients = {
            {type = "item", name = "steel-plate",       amount = 200},
            {type = "item", name = "stone-brick",       amount = 500},
            {type = "item", name = "electronic-circuit", amount = 100},
        },
    },
    medium = {
        energy_required = 60,
        ingredients = {
            {type = "item", name = "steel-plate",      amount = 500},
            {type = "item", name = "refined-concrete",  amount = 500},
            {type = "item", name = "processing-unit",   amount = 100},
        },
    },
    hard = {
        energy_required = 120,
        ingredients = {
            {type = "item", name = "steel-plate",           amount = 1000},
            {type = "item", name = "refined-concrete",      amount = 1000},
            {type = "item", name = "processing-unit",       amount = 300},
            {type = "item", name = "low-density-structure", amount = 200},
        },
    },
    space = {
        energy_required = 180,
        ingredients = {
            {type = "item", name = "steel-plate",           amount = 1500},
            {type = "item", name = "refined-concrete",      amount = 1500},
            {type = "item", name = "low-density-structure", amount = 300},
            {type = "item", name = "quantum-processor",     amount = 100},
            {type = "item", name = "bioflux",               amount = 200},
            {type = "item", name = "holmium-plate",         amount = 200},
            {type = "item", name = "superconductor",        amount = 100},
        },
    },
}

--- Build a localised string for one difficulty level (keeps under 20 param limit).
local function build_level_description(setting_name, level_key, category, data)
    local parts = {""}
    parts[#parts + 1] = {"", "[color=yellow]", {"string-mod-setting." .. setting_name .. "-" .. level_key}, "[/color]\n"}

    if category == "recipe" then
        for j, ing in ipairs(data.ingredients) do
            if j > 1 then parts[#parts + 1] = "  " end
            parts[#parts + 1] = "[img=item/" .. ing.name .. "] " .. ing.amount
        end
    else
        parts[#parts + 1] = data.count .. "x "
        for j, ing in ipairs(data.ingredients) do
            if j > 1 then parts[#parts + 1] = " " end
            parts[#parts + 1] = "[img=item/" .. ing[1] .. "]"
        end
    end

    return parts
end

--- Build a localised description listing all difficulty levels.
--- @param category string "recipe" or "technology"
--- @param setting_name string the setting name for locale key lookup
function config.build_description(category, setting_name)
    local desc = {"",
        build_level_description(setting_name, "easy", category, config[category].easy),
        "\n\n",
        build_level_description(setting_name, "medium", category, config[category].medium),
        "\n\n",
        build_level_description(setting_name, "hard", category, config[category].hard),
    }

    if has_space_age then
        desc[#desc + 1] = "\n\n"
        desc[#desc + 1] = build_level_description(setting_name, "space", category, config[category].space)
    end

    return desc
end

return config
