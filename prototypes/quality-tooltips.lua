-- returns the default buff amount per quality level in vanilla
local function get_quality_buff(quality_level)
    return 1 + quality_level * 0.3
end

local function add_quality_factoriopedia_info(entity, factoriopedia_info)
    entity.custom_tooltip_fields = entity.custom_tooltip_fields or {}

    for _, factoriopedia_info in pairs(factoriopedia_info or {}) do
        local stat_to_buff, factoriopedia_function = unpack(factoriopedia_info)

        local quality_values = {}
        for _, quality in pairs(data.raw.quality) do
            local quality_level = quality.level
            if quality.hidden then goto continue end
            quality_values[quality.name] = tostring(factoriopedia_function(entity, quality_level))
            ::continue::
        end

        table.insert(
            entity.custom_tooltip_fields,
            {
                name = {"quality-description." .. stat_to_buff},
                quality_header = "quality-tooltip." .. stat_to_buff,
                value = tostring(factoriopedia_function(entity, 0)),
                quality_values = quality_values
            }
        )
    end
end

add_quality_factoriopedia_info(data.raw["storage-tank"]["tardis"], {
    {"interior-space", function(entity, quality_level) return "30×30" end},
})

