local layout_generators = {
    ["tardis"] = {
        name = "tardis",
        tier = 1,
        inside_size = 30,
        inside_door_x = 0,
        inside_door_y = 16,
        outside_door_x = 0,
        outside_door_y = 4,
        overlay_x = 0,
        overlay_y = 3,
        rectangles = {
            {
                x1 = -16, x2 = 16, y1 = -16, y2 = 16, tile = "tardis-wall"
            },
            {
                x1 = -15, x2 = 15, y1 = -15, y2 = 15, tile = "hazard-concrete-left"
            },
            {
                x1 = -14, x2 = 14, y1 = -14, y2 = 14, tile = "tardis-floor"
            },
            {
                x1 = -4, x2 = 4, y1 = 15, y2 = 18, tile = "tardis-wall"
            },
            {
                x1 = -3, x2 = 3, y1 = 15, y2 = 18, tile = "hazard-concrete-left"
            },
            {
                x1 = -2, x2 = 2, y1 = 14, y2 = 18, tile = "tardis-entrance"
            },
        },
        mosaics = {
        },
    },
}

--[[
/c __tardis__ reload_layouts()
--]]

_G.reload_layouts = function()
    storage.layout_generators = storage.layout_generators or {}
    for name, layout in pairs(layout_generators) do
        storage.layout_generators[name] = layout
    end
end

tardis.on_event(tardis.events.on_init(), reload_layouts)
