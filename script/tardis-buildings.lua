local get_tardis_by_building = remote_api.get_tardis_by_building

local has_layout = has_layout

-- INITIALIZATION --

tardis.on_event(tardis.events.on_init(), function()
    -- List of all factories
    storage.factories = storage.factories or {}
    -- Map: Id from item-with-tags -> tardis
    storage.saved_factories = storage.saved_factories or {}
    -- Map: Entity unit number -> tardis it is a part of
    storage.factories_by_entity = storage.factories_by_entity or {}
    -- Map: Surface index -> list of factories on it
    storage.surface_factories = storage.surface_factories or {}
end)

-- RECURSION TECHNOLOGY --

local function surface_localised_name(surface)
    if surface.localised_name then
        return surface.localised_name
    elseif surface.planet and surface.planet.prototype.localised_name then
        return {"", "[img=space-location.", surface.planet.name, "] ", surface.planet.prototype.localised_name}
    else
        return {"?", {"space-location-name." .. surface.name}, surface.name}
    end
end

--- @return string
local function which_surface_should_this_new_tardis_be_placed_on(layout, building)
    return layout.surface_override or "tardis-pocket-surface"
end

local function set_tardis_active_or_inactive(tardis)
    tardis.inactive = false
end

local function build_tardis_upgrade_light(tardis)
    if not tardis.inside_surface.valid then return end

    tardis.inside_surface.daytime = 1
    tardis.inside_surface.freeze_daytime = true
end

local function build_tardis_upgrades(tardis)
    build_tardis_upgrade_light(tardis)
end

local function activate_factories()
    for _, tardis in pairs(storage.factories) do
        set_tardis_active_or_inactive(tardis)
        build_tardis_upgrades(tardis)
    end
end
tardis.on_event(tardis.events.on_init(), activate_factories)

tardis.on_event({defines.events.on_research_finished, defines.events.on_research_reversed}, function(event)
    if not storage.factories then return end -- In case any mod or scenario script calls LuaForce.research_all_technologies() during its on_init
    for _, tardis in pairs(storage.factories) do build_tardis_upgrades(tardis) end
end)

-- Sanitize map_gen_settings on existing pocket surfaces when loading saves
-- (prevents noise expression errors when mods like "Everything on Nauvis" change autoplace controls)
tardis.on_event(tardis.events.on_init(), function()
    local surface = game.get_surface("tardis-pocket-surface")
    if surface then
        surface.map_gen_settings = {
            width = 2,
            height = 2,
            autoplace_controls = {},
            autoplace_settings = {
                decorative = { treat_missing_as_default = false },
                entity = { treat_missing_as_default = false },
                tile = { treat_missing_as_default = false }
            }
        }
    end
end)

-- tardis GENERATION --

tardis.on_event(defines.events.on_surface_created, function(event)
    local surface = game.get_surface(event.surface_index)
    if surface.name ~= "tardis-pocket-surface" then return end

    surface.map_gen_settings = {
        width = 2,
        height = 2,
        autoplace_controls = {},
        autoplace_settings = {
            decorative = { treat_missing_as_default = false },
            entity = { treat_missing_as_default = false },
            tile = { treat_missing_as_default = false }
        }
    }
end)

--- searches a tardis floor for "holes" where a new tardis could be created
--- else returns the next position
local function find_first_unused_position(surface)
    local used_indexes = {}
    for k in pairs(storage.surface_factories[surface.index] or {}) do
        table.insert(used_indexes, k)
    end
    table.sort(used_indexes)

    for i, index in pairs(used_indexes) do
        if i ~= index then -- found a gap
            return (used_indexes[i - 1] or 0) + 1
        end
    end

    return #used_indexes + 1
end

local function surface_sanity_checks(surface, building)
    surface.localised_name = surface_localised_name(surface)

    surface.daytime = 0.5
    surface.freeze_daytime = true

    -- Ensure nothing generates on the TARDIS interior surface.
    surface.map_gen_settings = {
        width = 2,
        height = 2,
        autoplace_controls = {},
        autoplace_settings = {
            decorative = { treat_missing_as_default = false },
            entity = { treat_missing_as_default = false },
            tile = { treat_missing_as_default = false }
        }
    }
end

local function create_tardis_surface(surface_name)
    assert(_G.surface == nil)

    local surface = game.get_surface(surface_name)
    if surface then
        return surface
    end

    local planet = game.planets[surface_name]
    if planet then
        return planet.create_surface()
    end

    return game.create_surface(surface_name, {
        width = 2,
        height = 2,
        autoplace_controls = {},
        autoplace_settings = {
            decorative = { treat_missing_as_default = false },
            entity = { treat_missing_as_default = false },
            tile = { treat_missing_as_default = false }
        }
    })
end

local function create_tardis_position(layout, building)
    local surface_name = which_surface_should_this_new_tardis_be_placed_on(layout, building)
    local surface = game.get_surface(surface_name)

    if not surface then
        surface = create_tardis_surface(surface_name)
    end

    surface_sanity_checks(surface, building)

    local n = find_first_unused_position(surface) - 1
    local tardis_CHUNK_SPACING = 16
    local cx = tardis_CHUNK_SPACING * (n % 8)
    local cy = tardis_CHUNK_SPACING * math.floor(n / 8)
    -- To make void chnks show up on the map, you need to tell them they've finished generating.
    for xx = -2, 2 do
        for yy = -2, 2 do
            surface.set_chunk_generated_status({cx + xx, cy + yy}, defines.chunk_generated_status.entities)
        end
    end
    surface.destroy_decoratives {area = {{32 * (cx - 2), 32 * (cy - 2)}, {32 * (cx + 2), 32 * (cy + 2)}}}

    local tardis = {}
    tardis.inside_surface = surface
    tardis.inside_x = 32 * cx
    tardis.inside_y = 32 * cy
    tardis.outside_x = building.position.x
    tardis.outside_y = building.position.y
    tardis.outside_door_x = tardis.outside_x + layout.outside_door_x
    tardis.outside_door_y = tardis.outside_y + layout.outside_door_y
    tardis.outside_surface = building.surface

    storage.surface_factories[surface.index] = storage.surface_factories[surface.index] or {}
    storage.surface_factories[surface.index][n + 1] = tardis

    local highest_currently_used_id = 0
    for id in pairs(storage.factories) do
        if id > highest_currently_used_id then
            highest_currently_used_id = id
        end
    end
    tardis.id = highest_currently_used_id + 1
    storage.factories[tardis.id] = tardis

    return tardis
end

local function add_tile_rect(tiles, tile_name, xmin, ymin, xmax, ymax) -- tiles is rw
    local i = #tiles
    for x = xmin, xmax - 1 do
        for y = ymin, ymax - 1 do
            i = i + 1
            tiles[i] = {name = tile_name, position = {x, y}}
        end
    end
end

local function add_hidden_tile_rect(tardis)
    local surface = tardis.inside_surface
    local xmin = tardis.inside_x - 64
    local ymin = tardis.inside_y - 64
    local xmax = tardis.inside_x + 64
    local ymax = tardis.inside_y + 64

    local position = {0, 0}
    for x = xmin, xmax - 1 do
        for y = ymin, ymax - 1 do
            position[1] = x
            position[2] = y
            surface.set_hidden_tile(position, "water")
        end
    end
end

local function add_tile_mosaic(tiles, tile_name, xmin, ymin, xmax, ymax, pattern) -- tiles is rw
    local i = #tiles
    for x = 0, xmax - xmin - 1 do
        for y = 0, ymax - ymin - 1 do
            if (string.sub(pattern[y + 1], x + 1, x + 1) == "+") then
                i = i + 1
                tiles[i] = {name = tile_name, position = {x + xmin, y + ymin}}
            end
        end
    end
end

local function create_tardis_interior(layout, building)
    local force = building.force

    local tardis = create_tardis_position(layout, building)
    tardis.building = building
    tardis.layout = layout
    tardis.force = force
    tardis.quality = building.quality
    tardis.inside_door_x = layout.inside_door_x + tardis.inside_x
    tardis.inside_door_y = layout.inside_door_y + tardis.inside_y

    local tile_name_mapping = {}

    local tiles = {}
    for _, rect in pairs(layout.rectangles) do
        local tile_name = tile_name_mapping[rect.tile] or rect.tile
        add_tile_rect(tiles, tile_name, rect.x1 + tardis.inside_x, rect.y1 + tardis.inside_y, rect.x2 + tardis.inside_x, rect.y2 + tardis.inside_y)
    end
    for _, mosaic in pairs(layout.mosaics) do
        local tile_name = tile_name_mapping[mosaic.tile] or mosaic.tile
        add_tile_mosaic(tiles, tile_name, mosaic.x1 + tardis.inside_x, mosaic.y1 + tardis.inside_y, mosaic.x2 + tardis.inside_x, mosaic.y2 + tardis.inside_y, mosaic.pattern)
    end
    tardis.inside_surface.set_tiles(tiles)
    add_hidden_tile_rect(tardis)

    local radar = tardis.inside_surface.create_entity {
        name = "tardis-hidden-radar",
        position = {tardis.inside_x, tardis.inside_y},
        force = force,
    }
    radar.destructible = false
    tardis.radar = radar
    tardis.inside_overlay_controllers = {}

    local console = tardis.inside_surface.create_entity {
        name = "tardis-console",
        position = {tardis.inside_x, tardis.inside_y},
        force = force,
    }
    console.destructible = false
    apply_console_filters(console)

    return tardis
end

local function create_tardis_exterior(tardis, building)
    local layout = tardis.layout
    local force = tardis.force
    tardis.outside_x = building.position.x
    tardis.outside_y = building.position.y
    tardis.outside_door_x = tardis.outside_x + layout.outside_door_x
    tardis.outside_door_y = tardis.outside_y + layout.outside_door_y
    tardis.outside_surface = building.surface

    tardis.outside_overlay_displays = {}
    tardis.outside_port_markers = {}

    storage.factories_by_entity[building.unit_number] = tardis
    tardis.building = building
    tardis.built = true

    build_tardis_upgrades(tardis)
    return tardis
end

-- tardis MINING AND DECONSTRUCTION --

local function cleanup_tardis_exterior(tardis, building)
    for _, render_id in pairs(tardis.outside_overlay_displays) do
        local object = rendering.get_object_by_id(render_id)
        if object then object.destroy() end
    end
    tardis.outside_overlay_displays = {}
    for _, render_id in pairs(tardis.outside_port_markers) do
        local object = rendering.get_object_by_id(render_id)
        if object then object.destroy() end
    end
    tardis.outside_port_markers = {}
    tardis.building = nil
    tardis.built = false
end

local function is_completely_empty(tardis)
    local x, y = tardis.inside_x, tardis.inside_y
    local D = (tardis.layout.inside_size + 8) / 2
    local area = {{x - D, y - D}, {x + D, y + D}}

    local interior_entities = tardis.inside_surface.find_entities_filtered {area = area}
    for _, entity in pairs(interior_entities) do
        if entity.name == "tardis-console" then
            -- Check if console has items
            local inventory = entity.get_inventory(defines.inventory.chest)
            if inventory and not inventory.is_empty() then
                return false
            end
            goto continue
        end
        local collision_mask = entity.prototype.collision_mask.layers
        local is_hidden_entity = (not collision_mask) or table_size(collision_mask) == 0
        if not is_hidden_entity then return false end
        ::continue::
    end
    return true
end

local function cleanup_tardis_interior(tardis)
    local x, y = tardis.inside_x, tardis.inside_y
    local D = (tardis.layout.inside_size + 8) / 2
    local area = {{x - D, y - D}, {x + D, y + D}}

    for _, e in pairs(tardis.inside_surface.find_entities_filtered {area = area}) do
        e.destroy()
    end

    local out_of_map_tiles = {}
    for xx = math.floor(x - D), math.ceil(x + D) do
        for yy = math.floor(y - D), math.ceil(y + D) do
            out_of_map_tiles[#out_of_map_tiles + 1] = {position = {xx, yy}, name = "out-of-map"}
        end
    end
    tardis.inside_surface.set_tiles(out_of_map_tiles)

    local tardis_lists = {storage.factories, storage.saved_factories, storage.factories_by_entity}
    for _, tardis_list in pairs(storage.surface_factories) do
        tardis_lists[#tardis_lists + 1] = tardis_list
    end

    for _, tardis_list in pairs(tardis_lists) do
        for k, f in pairs(tardis_list) do
            if f == tardis then
                tardis_list[k] = nil
            end
        end
    end

    for _, force in pairs(game.forces) do
        force.rechart(tardis.inside_surface)
    end

    -- https://github.com/notnotmelon/tardis-2-notnotmelon/issues/211
    storage.was_deleted = storage.was_deleted or {}
    storage.was_deleted[tardis.id] = true

    -- Invalidate all keys bound to this TARDIS
    if storage.tardis_valid_keys then
        storage.tardis_valid_keys[tardis.id] = nil
    end

    for k in pairs(tardis) do tardis[k] = nil end
end

-- How players pick up factories
-- Working tardis buildings don't return items, so we have to manually give the player an item
tardis.on_event({
    defines.events.on_player_mined_entity,
    defines.events.on_robot_mined_entity,
    defines.events.on_space_platform_mined_entity
}, function(event)
    local entity = event.entity
    if not has_layout(entity.name) then return end

    local tardis = get_tardis_by_building(entity)
    if not tardis then return end

    -- Save console inventory before cleanup
    local console = tardis.inside_surface.find_entity("tardis-console", {tardis.inside_x, tardis.inside_y})
    if console and console.valid then
        local inventory = console.get_inventory(defines.inventory.chest)
        if inventory and not inventory.is_empty() then
            tardis.saved_console_inventory = {}
            for i = 1, #inventory do
                local slot = inventory[i]
                if slot.valid_for_read then
                    tardis.saved_console_inventory[i] = {
                        name = slot.name,
                        count = slot.count,
                        quality = slot.quality.name,
                        health = slot.health,
                    }
                end
            end
        end
    end

    cleanup_tardis_exterior(tardis, entity)

    if is_completely_empty(tardis) then
        local buffer = event.buffer
        buffer.clear()
        buffer.insert {
            name = tardis.layout.name,
            count = 1,
            quality = entity.quality,
            health = entity.health / entity.max_health
        }
        cleanup_tardis_interior(tardis)
        return
    end

    storage.saved_factories[tardis.id] = tardis
    local buffer = event.buffer
    buffer.clear()
    buffer.insert {
        name = tardis.layout.name .. "-instantiated",
        count = 1,
        tags = {id = tardis.id},
        quality = entity.quality,
        health = entity.health / entity.max_health
    }
    local item_stack = buffer[1]
    assert(item_stack.valid_for_read and item_stack.is_item_with_tags)
    local item = item_stack.item
    assert(item and item.valid)
    tardis.item = item
end)

local function prevent_tardis_mining(entity)
    local tardis = get_tardis_by_building(entity)
    if not tardis then return end
    storage.factories_by_entity[entity.unit_number] = nil
    local entity = entity.surface.create_entity {
        name = entity.name,
        position = entity.position,
        force = entity.force,
        raise_built = false,
        create_build_effect_smoke = false,
        player = entity.last_user
    }
    storage.factories_by_entity[entity.unit_number] = tardis
    tardis.building = entity
    if #tardis.outside_port_markers ~= 0 then
        tardis.outside_port_markers = {}
        tardis.toggle_port_markers(tardis)
    end
    tardis.create_flying_text {position = entity.position, text = {"tardis-cant-be-mined"}}
end

local fake_robots = {["repair-block-robot"] = true} -- Modded construction robots with heavy control scripting
tardis.on_event(defines.events.on_robot_pre_mined, function(event)
    local entity = event.entity
    if has_layout(entity.name) and fake_robots[event.robot.name] then
        prevent_tardis_mining(entity)
        entity.destroy()
    elseif entity.type == "item-entity" and entity.stack.valid_for_read and has_layout(entity.stack.name) then
        event.robot.destructible = false
    end
end)

-- How biters pick up factories
-- Too bad they don't have hands
tardis.on_event(defines.events.on_entity_died, function(event)
    local entity = event.entity
    if not has_layout(entity.name) then return end
    local tardis = get_tardis_by_building(entity)
    if not tardis then return end

    storage.saved_factories[tardis.id] = tardis
    cleanup_tardis_exterior(tardis, entity)

    local items = entity.surface.spill_item_stack {
        position = entity.position,
        stack = {
            name = tardis.layout.name .. "-instantiated",
            tags = {id = tardis.id},
            quality = entity.quality.name,
            count = 1
        },
        enable_looted = false,
        force = nil,
        allow_belts = false,
        max_radius = 0,
        use_start_position_on_failure = true
    }
    assert(table_size(items) == 1, "Failed to generate tardis item. Are you using the quantum-fabricator mod? See https://github.com/notnotmelon/tardis-2-notnotmelon/issues/203")
    local item = items[1].stack.item
    assert(item and item.valid)
    tardis.item = item
    entity.force.print {"tardis-killed-by-biters", items[1].gps_tag}
end)

tardis.on_event(defines.events.on_post_entity_died, function(event)
    if not has_layout(event.prototype.name) or not event.ghost then return end
    local tardis = storage.factories_by_entity[event.unit_number]
    if not tardis then return end
    event.ghost.tags = {id = tardis.id}
end)

-- Just rebuild the tardis in this case
tardis.on_event(defines.events.script_raised_destroy, function(event)
    local entity = event.entity
    if has_layout(entity.name) then
        prevent_tardis_mining(entity)
    end
end)

local function on_delete_surface(surface)
    storage.surface_factories[surface.index] = nil

    local childen_surfaces_to_delete = {}
    for _, tardis in pairs(storage.factories) do
        local inside_surface = tardis.inside_surface
        local outside_surface = tardis.outside_surface
        if inside_surface.valid and outside_surface.valid and tardis.outside_surface == surface then
            childen_surfaces_to_delete[inside_surface.index] = inside_surface
        end
    end

    for _, tardis_list in pairs {storage.factories, storage.saved_factories, storage.factories_by_entity} do
        for k, tardis in pairs(tardis_list) do
            local inside_surface = tardis.inside_surface
            if not inside_surface.valid or childen_surfaces_to_delete[inside_surface.index] then
                tardis_list[k] = nil
            end
        end
    end

    for _, child_surface in pairs(childen_surfaces_to_delete) do
        on_delete_surface(child_surface)
        game.delete_surface(child_surface)
    end
end

-- Delete all children surfaces in this case.
tardis.on_event(defines.events.on_pre_surface_cleared, function(event)
    on_delete_surface(game.get_surface(event.surface_index))
end)

-- tardis PLACEMENT AND INITALIZATION --

local function create_fresh_tardis(entity)
    local layout = remote_api.create_layout(entity.name, entity.quality)
    local tardis = create_tardis_interior(layout, entity)
    create_tardis_exterior(tardis, entity)
    set_tardis_active_or_inactive(tardis)
    return tardis
end

-- It's possible that the item used to build this tardis is not the same as the one that was saved.
-- In this case, clear tags and description of the saved item such that there is only 1 copy of the tardis item.
-- https://github.com/notnotmelon/tardis-2-notnotmelon/issues/155
local function handle_tardis_control_xed(tardis)
    local item = tardis.item
    if not item or not item.valid then return end
    tardis.item.tags = {}
    tardis.item.custom_description = tardis.item.prototype.localised_description

    -- We should also attempt to swapped the packed tardis item with an unpacked.
    -- If this fails, whatever. It's just to avoid confusion. A packed tardis with no tags is equal to an unpacked tardis.
    local item_stack = item.item_stack
    if not item_stack or not item_stack.valid_for_read then return end

    item_stack.set_stack {
        name = item.name:gsub("%-instantiated$", ""),
        count = item_stack.count,
        quality = item_stack.quality,
        health = item_stack.health,
    }
end

local function handle_tardis_placed(entity, tags)
    if not tags or not tags.id then
        create_fresh_tardis(entity)
        return
    end

    local tardis = storage.saved_factories[tags.id]
    storage.saved_factories[tags.id] = nil
    if tardis and tardis.inside_surface and tardis.inside_surface.valid then
        -- This is a saved tardis, we need to unpack it
        tardis.quality = entity.quality
        create_tardis_exterior(tardis, entity)
        set_tardis_active_or_inactive(tardis)
        handle_tardis_control_xed(tardis)

        -- Restore console inventory
        if tardis.saved_console_inventory then
            local console = tardis.inside_surface.find_entity("tardis-console", {tardis.inside_x, tardis.inside_y})
            if console and console.valid then
                local inventory = console.get_inventory(defines.inventory.chest)
                if inventory then
                    for slot_index, item_data in pairs(tardis.saved_console_inventory) do
                        inventory[slot_index].set_stack {
                            name = item_data.name,
                            count = item_data.count,
                            quality = item_data.quality,
                            health = item_data.health,
                        }
                    end
                end
            end
            tardis.saved_console_inventory = nil
        end

        return
    end

    if not tardis and storage.factories[tags.id] then
        -- This tardis was copied from somewhere else. Clone all contained entities
        local tardis = create_fresh_tardis(entity)
        tardis.copy_entity_ghosts(storage.factories[tags.id], tardis)
        return
    end

    -- https://github.com/notnotmelon/tardis-2-notnotmelon/issues/211
    if storage.was_deleted and storage.was_deleted[tags.id] then
        create_fresh_tardis(entity)
        return
    end

    tardis.create_flying_text {position = entity.position, text = {"tardis-connection-text.invalid-tardis-data"}}
    entity.destroy()
end

tardis.on_event(tardis.events.on_built(), function(event)
    local entity = event.entity
    if not entity.valid then return end
    local entity_name = entity.name

    if has_layout(entity_name) then
        local inventory = event.consumed_items
        local tags = event.tags or (inventory and not inventory.is_empty() and inventory[1].valid_for_read and inventory[1].is_item_with_tags and inventory[1].tags) or nil
        handle_tardis_placed(entity, tags)
        return
    end

end)

-- How to clone your tardis
-- This implementation will not actually clone tardis buildings, but move them to where they were cloned.
local clone_forbidden_prefixes = {
    "tardis-",
    "tardis-port-marker",
    "tardis-linked-",
    "tardis-requester-chest-",
    "tardis-eject-chest-",
    "tardis-hidden-radar-",
    "tardis-console",
    "tardis-key-synchronizer",
}

local function is_entity_clone_forbidden(name)
    for _, prefix in pairs(clone_forbidden_prefixes) do
        if name:sub(1, #prefix) == prefix then
            return true
        end
    end
    return false
end

tardis.on_event(defines.events.on_entity_cloned, function(event)
    local src_entity = event.source
    local dst_entity = event.destination
    if is_entity_clone_forbidden(dst_entity.name) then
        dst_entity.destroy()
    elseif has_layout(src_entity.name) then
        local tardis = get_tardis_by_building(src_entity)
        cleanup_tardis_exterior(tardis, src_entity)
        if src_entity.valid then src_entity.destroy() end
        create_tardis_exterior(tardis, dst_entity)
        set_tardis_active_or_inactive(tardis)
    end
end)

-- MISC --

commands.add_command("give-lost-tardis-buildings", {"command-help-message.give-lost-tardis-buildings"}, function(event)
    local player = game.get_player(event.player_index)
    if not (player and player.connected and player.admin) then return end
    local inventory = player.get_main_inventory()
    if not inventory then return end
    for id, tardis in pairs(storage.saved_factories) do
        for i = 1, #inventory do
            local stack = inventory[i]
            if stack.valid_for_read and stack.name == tardis.layout.name and stack.type == "item-with-tags" and stack.tags.id == id then goto found end
        end
        player.insert {name = tardis.layout.name .. "-instantiated", count = 1, tags = {id = id}}
        ::found::
    end
end)

tardis.on_event(defines.events.on_forces_merging, function(event)
    for _, tardis in pairs(storage.factories) do
        if not tardis.force.valid then
            tardis.force = game.forces["player"]
        end
        if tardis.force.name == event.source.name then
            tardis.force = event.destination
        end
    end
end)
