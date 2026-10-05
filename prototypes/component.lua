data:extend {
    {
        type = "radar",
        name = "tardis-hidden-radar",
        selectable_in_game = false,
        flags = {"not-on-map", "hide-alt-info"},
        hidden = true,
        collision_mask = {layers = {}},
        energy_per_nearby_scan = "250J",
        energy_per_sector = "1kW",
        energy_source = {type = "void"},
        energy_usage = "250W",
        max_distance_of_sector_revealed = 0,
        max_distance_of_nearby_sector_revealed = 1,
        localised_name = "",
        max_health = 1,
        connects_to_other_radars = false,
    }
}
