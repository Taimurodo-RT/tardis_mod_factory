local find_surrounding_tardis = remote_api.find_surrounding_tardis
local execute_later = tardis.execute_later

local function get_fuel_item() return settings.startup["tardis-fuel-type"].value end
local function get_fuel_cost() return settings.startup["tardis-fuel-amount"].value end
local TELEPORT_TICKS = 690
local SOUND_LOOP_TICKS = 230

-- SURFACE VALIDATION --

local function is_surface_blocked(surface)
    if remote_api.is_tardis_surface(surface) then return true end
    if settings.startup["tardis-block-space-platforms"].value and surface.platform ~= nil then return true end
    return false
end

-- TELEPORT EFFECTS --

local SPARK_CHANCE = 0.15

local function update_teleport_effects()
    if not storage.active_teleport_effects then return end

    local to_remove = {}
    local tick = game.tick

    for i, effect in pairs(storage.active_teleport_effects) do
        if not effect.surface.valid or tick >= effect.end_tick then
            to_remove[#to_remove + 1] = i
            goto next_effect
        end

        -- Replay sound when previous one ends
        if tick >= effect.next_sound_tick then
            effect.surface.play_sound {path = "tardis-teleportation", position = effect.console_position}
            if effect.building_surface and effect.building_surface.valid then
                effect.building_surface.play_sound {path = "tardis-teleportation", position = effect.building_position}
            end
            effect.next_sound_tick = tick + SOUND_LOOP_TICKS
        end

        -- Sparks on the lower half of the console
        if math.random() < SPARK_CHANCE then
            local x = effect.center_x + (math.random() * 4 - 2)
            local y = effect.center_y + (math.random() * 1.2)
            effect.surface.create_entity {
                name = "explosion",
                position = {x, y},
            }
        end

        ::next_effect::
    end

    for i = #to_remove, 1, -1 do
        table.remove(storage.active_teleport_effects, to_remove[i])
    end
end

-- INVENTORY FILTERING --

function apply_console_filters(entity)
    local inventory = entity.get_inventory(defines.inventory.chest)
    for i = 1, #inventory do
        inventory.set_filter(i, get_fuel_item())
    end
end

tardis.on_event(tardis.events.on_init(), function()
    storage.console_cooldowns = storage.console_cooldowns or {}
    local surface = game.get_surface("tardis-pocket-surface")
    if not surface then return end
    for _, entity in pairs(surface.find_entities_filtered {name = "tardis-console"}) do
        apply_console_filters(entity)
    end
end)

-- COOLDOWN --

local function is_console_on_cooldown(entity)
    local cooldown_until = (storage.console_cooldowns or {})[entity.unit_number]
    return cooldown_until and game.tick < cooldown_until
end

local function get_cooldown_progress(entity)
    local cooldown_until = (storage.console_cooldowns or {})[entity.unit_number]
    if not cooldown_until then return 0 end
    local remaining = cooldown_until - game.tick
    if remaining <= 0 then return 0 end
    return 1 - (remaining / TELEPORT_TICKS)
end

-- CONSOLE GUI --

local function destroy_console_gui(player)
    local frame = player.gui.relative["tardis-console-panel"]
    if frame then frame.destroy() end
end

local function create_console_gui(player, entity)
    destroy_console_gui(player)

    local anchor = {
        gui = defines.relative_gui_type.container_gui,
        position = defines.relative_gui_position.right,
        name = "tardis-console",
    }

    local frame = player.gui.relative.add {
        type = "frame",
        name = "tardis-console-panel",
        direction = "vertical",
        anchor = anchor,
    }

    frame.add {
        type = "label",
        caption = {"tardis-console-gui.title"},
        style = "frame_title",
    }

    local content = frame.add {
        type = "flow",
        name = "tardis-console-content",
        direction = "vertical",
        style = "inset_frame_container_vertical_flow",
    }

    local inner = content.add {
        type = "frame",
        name = "tardis-console-inner",
        style = "inside_shallow_frame_with_padding",
        direction = "vertical",
    }

    local on_cooldown = is_console_on_cooldown(entity)

    if settings.startup["tardis-map-teleport"].value then
        local button = inner.add {
            type = "button",
            name = "tardis-console-teleport",
            caption = {"tardis-console-gui.teleport"},
            tooltip = {"tardis-console-gui.teleport-tooltip", get_fuel_cost(), "[item=" .. get_fuel_item() .. "]"},
            style = "confirm_button",
        }
        button.enabled = not on_cooldown
    end

    local alert_button = inner.add {
        type = "button",
        name = "tardis-console-teleport-to-alert",
        caption = {"tardis-console-gui.teleport-to-alert"},
        tooltip = {"tardis-console-gui.teleport-to-alert-tooltip", get_fuel_cost(), "[item=" .. get_fuel_item() .. "]"},
        style = "red_confirm_button",
    }
    alert_button.enabled = not on_cooldown
    alert_button.style.top_margin = 4

    local bar = inner.add {
        type = "progressbar",
        name = "tardis-console-progressbar",
        style = "production_progressbar",
    }
    bar.style.horizontally_stretchable = true
    bar.style.top_margin = 4

    if on_cooldown then
        bar.value = get_cooldown_progress(entity)
        bar.visible = true
    else
        bar.visible = false
    end
end

tardis.on_event(defines.events.on_gui_opened, function(event)
    local entity = event.entity
    if not entity or not entity.valid then return end
    if entity.name ~= "tardis-console" then return end

    create_console_gui(game.get_player(event.player_index), entity)
end)

tardis.on_event(defines.events.on_gui_closed, function(event)
    local entity = event.entity
    if not entity or not entity.valid then return end
    if entity.name ~= "tardis-console" then return end

    destroy_console_gui(game.get_player(event.player_index))
end)

-- PROGRESS BAR UPDATE --

tardis.on_nth_tick(6, function()
    update_teleport_effects()

    if not storage.console_cooldowns then return end
    if table_size(storage.console_cooldowns) == 0 then return end

    for _, player in pairs(game.connected_players) do
        local opened = player.opened
        if not opened or not opened.valid or opened.name ~= "tardis-console" then goto continue end

        local panel = player.gui.relative["tardis-console-panel"]
        if not panel then goto continue end

        local bar = panel["tardis-console-content"]["tardis-console-inner"]["tardis-console-progressbar"]
        if not bar then goto continue end

        if is_console_on_cooldown(opened) then
            bar.value = get_cooldown_progress(opened)
            bar.visible = true
        else
            bar.visible = false
        end

        ::continue::
    end
end)

-- TELEPORT LOGIC --

local function set_teleport_button_enabled(player, enabled)
    local panel = player.gui.relative["tardis-console-panel"]
    if not panel then return end
    local inner = panel["tardis-console-content"]["tardis-console-inner"]
    if not inner then return end

    local button = inner["tardis-console-teleport"]
    if button then button.enabled = enabled end

    local alert_button = inner["tardis-console-teleport-to-alert"]
    if alert_button then alert_button.enabled = enabled end
end

local function set_progressbar_visible(player, visible)
    local panel = player.gui.relative["tardis-console-panel"]
    if not panel then return end
    local bar = panel["tardis-console-content"]["tardis-console-inner"]["tardis-console-progressbar"]
    if not bar then return end
    bar.visible = visible
    if not visible then bar.value = 0 end
end

tardis.register_delayed_function("tardis_console_teleport_complete", function(console_unit_number, building_unit_number, target_x, target_y, target_surface_index)
    storage.console_cooldowns[console_unit_number] = nil

    -- Teleport the external building
    local tardis_data = storage.factories_by_entity[building_unit_number]
    if tardis_data and tardis_data.building and tardis_data.building.valid then
        local building = tardis_data.building
        local target_surface = game.get_surface(target_surface_index)
        if target_surface and not is_surface_blocked(target_surface) then
            local safe_position = target_surface.find_non_colliding_position(building.name, {target_x, target_y}, 40, 0.5)

            if safe_position then
                if target_surface ~= building.surface then
                    -- Cross-surface teleport: destroy and recreate
                    local new_building = target_surface.create_entity {
                        name = building.name,
                        position = safe_position,
                        force = building.force,
                        quality = building.quality,
                    }
                    storage.factories_by_entity[building.unit_number] = nil
                    building.destroy()
                    storage.factories_by_entity[new_building.unit_number] = tardis_data
                    tardis_data.building = new_building
                    tardis_data.outside_surface = target_surface
                    tardis_data.outside_x = new_building.position.x
                    tardis_data.outside_y = new_building.position.y
                else
                    building.teleport(safe_position)
                    tardis_data.outside_x = building.position.x
                    tardis_data.outside_y = building.position.y
                end
                tardis_data.outside_door_x = tardis_data.outside_x + tardis_data.layout.outside_door_x
                tardis_data.outside_door_y = tardis_data.outside_y + tardis_data.layout.outside_door_y

                -- Play completion sound inside near the console
                tardis_data.inside_surface.play_sound {
                    path = "tardis-teleport-complete",
                    position = {tardis_data.inside_x, tardis_data.inside_y},
                }
            else
                -- No safe location found
                tardis_data.inside_surface.play_sound {
                    path = "utility/cannot_build",
                    position = {tardis_data.inside_x, tardis_data.inside_y},
                }
                for _, player in pairs(game.connected_players) do
                    local opened = player.opened
                    if opened and opened.valid and opened.name == "tardis-console" and opened.unit_number == console_unit_number then
                        player.create_local_flying_text {text = {"tardis-console-gui.no-safe-location"}, create_at_cursor = true}
                    end
                end
            end
        end
    end

    -- Re-enable button for all players who have this console open
    for _, player in pairs(game.connected_players) do
        local opened = player.opened
        if opened and opened.valid and opened.name == "tardis-console" and opened.unit_number == console_unit_number then
            set_teleport_button_enabled(player, true)
            set_progressbar_visible(player, false)
            player.create_local_flying_text {text = {"tardis-console-gui.teleported"}, create_at_cursor = true}
        end
    end
end)

-- SHARED VALIDATION --

local function validate_console(player)
    local opened = player.opened
    if not opened or not opened.valid or opened.name ~= "tardis-console" then return nil end
    if is_console_on_cooldown(opened) then return nil end

    local tardis_data = find_surrounding_tardis(opened.surface, opened.position)
    if not tardis_data then
        player.create_local_flying_text {text = {"tardis-console-gui.no-tardis"}, create_at_cursor = true}
        player.play_sound {path = "utility/cannot_build"}
        return nil
    end

    if not tardis_data.building or not tardis_data.building.valid then
        player.create_local_flying_text {text = {"tardis-console-gui.not-placed"}, create_at_cursor = true}
        player.play_sound {path = "utility/cannot_build"}
        return nil
    end

    local inventory = opened.get_inventory(defines.inventory.chest)
    local available = 0
    for i = 1, #inventory do
        local slot = inventory[i]
        if slot.valid_for_read and slot.name == get_fuel_item() then
            available = available + slot.count
        end
    end

    if available < get_fuel_cost() then
        player.create_local_flying_text {text = {"tardis-console-gui.no-fuel", get_fuel_cost(), "[item=" .. get_fuel_item() .. "]"}, create_at_cursor = true}
        player.play_sound {path = "utility/cannot_build"}
        return nil
    end

    return opened, tardis_data
end

-- LOCATION SELECTION --

local function start_teleport(player, console, tardis_data, target_position, target_surface)
    if is_surface_blocked(target_surface) then
        player.create_local_flying_text {text = {"tardis-console-gui.invalid-surface"}, create_at_cursor = true}
        player.play_sound {path = "utility/cannot_build"}
        return
    end

    local inventory = console.get_inventory(defines.inventory.chest)

    -- Consume fuel
    local remaining = get_fuel_cost()
    for i = 1, #inventory do
        if remaining <= 0 then break end
        local slot = inventory[i]
        if slot.valid_for_read and slot.name == get_fuel_item() then
            local take = math.min(slot.count, remaining)
            slot.count = slot.count - take
            remaining = remaining - take
        end
    end

    -- Set cooldown on the console entity itself
    storage.console_cooldowns[console.unit_number] = game.tick + TELEPORT_TICKS

    -- Disable button and show progress bar for ALL players who have this console open
    for _, p in pairs(game.connected_players) do
        local p_opened = p.opened
        if p_opened and p_opened.valid and p_opened.name == "tardis-console" and p_opened.unit_number == console.unit_number then
            set_teleport_button_enabled(p, false)
            set_progressbar_visible(p, true)
        end
    end

    -- Start all teleport effects
    local building = tardis_data.building

    -- Animation plays for the full duration, ping-pongs automatically
    rendering.draw_animation {
        animation = "tardis-console-animated",
        target = console.position,
        surface = console.surface,
        time_to_live = TELEPORT_TICKS,
        animation_speed = 0.2,
        render_layer = "object",
    }

    -- Sound plays once now, then replays via update_teleport_effects
    console.surface.play_sound {path = "tardis-teleportation", position = console.position}
    building.surface.play_sound {path = "tardis-teleportation", position = building.position}

     rendering.draw_animation {
         animation = "tardis-animated",
         target = building.position,
         surface = building.surface,
         time_to_live = TELEPORT_TICKS,
         animation_speed = 0.2,
         render_layer = "object",
     }

    storage.active_teleport_effects = storage.active_teleport_effects or {}
    storage.active_teleport_effects[#storage.active_teleport_effects + 1] = {
        surface = console.surface,
        console_position = console.position,
        center_x = tardis_data.inside_x,
        center_y = tardis_data.inside_y,
        building_surface = building.surface,
        building_position = building.position,
        end_tick = game.tick + TELEPORT_TICKS,
        next_sound_tick = game.tick + SOUND_LOOP_TICKS,
    }

    local tx = target_position.x or target_position[1]
    local ty = target_position.y or target_position[2]
    execute_later("tardis_console_teleport_complete", TELEPORT_TICKS, console.unit_number, building.unit_number, tx, ty, target_surface.index)
end

-- UNIVERSAL TELEPORT WITH ALL CHECKS --

local function attempt_teleport(player, tardis_data, target_position, target_surface)
    -- Find console
    local console = tardis_data.inside_surface.find_entity("tardis-console", {tardis_data.inside_x, tardis_data.inside_y})
    if not console or not console.valid then
        player.create_local_flying_text {text = {"tardis-console-gui.no-tardis"}, create_at_cursor = true}
        player.play_sound {path = "utility/cannot_build"}
        return false
    end

    -- Check cooldown
    storage.console_cooldowns = storage.console_cooldowns or {}
    local cooldown_until = storage.console_cooldowns[console.unit_number]
    if cooldown_until and game.tick < cooldown_until then
        player.create_local_flying_text {text = {"tardis-console-gui.on-cooldown"}, create_at_cursor = true}
        player.play_sound {path = "utility/cannot_build"}
        return false
    end

    -- Check building exists
    if not tardis_data.building or not tardis_data.building.valid then
        player.create_local_flying_text {text = {"tardis-console-gui.not-placed"}, create_at_cursor = true}
        player.play_sound {path = "utility/cannot_build"}
        return false
    end

    -- Check fuel
    local inventory = console.get_inventory(defines.inventory.chest)
    local available = 0
    for i = 1, #inventory do
        local slot = inventory[i]
        if slot.valid_for_read and slot.name == get_fuel_item() then
            available = available + slot.count
        end
    end

    if available < get_fuel_cost() then
        player.create_local_flying_text {text = {"tardis-console-gui.no-fuel", get_fuel_cost(), "[item=" .. get_fuel_item() .. "]"}, create_at_cursor = true}
        player.play_sound {path = "utility/cannot_build"}
        return false
    end

    -- Check surface not blocked
    if is_surface_blocked(target_surface) then
        player.create_local_flying_text {text = {"tardis-console-gui.invalid-surface"}, create_at_cursor = true}
        player.play_sound {path = "utility/cannot_build"}
        return false
    end

    -- Check safe location
    local building = tardis_data.building
    if not target_surface.find_non_colliding_position(building.name, target_position, 40, 0.5) then
        player.create_local_flying_text {text = {"tardis-console-gui.no-safe-location"}, create_at_cursor = true}
        player.play_sound {path = "utility/cannot_build"}
        return false
    end

    -- All checks passed — start teleport!
    start_teleport(player, console, tardis_data, target_position, target_surface)
    player.create_local_flying_text {text = {"tardis-console-gui.teleported"}, create_at_cursor = true}
    return true
end

-- MAP TELEPORT BUTTON --

gui_events[defines.events.on_gui_click]["^tardis%-console%-teleport$"] = function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local console, tardis_data = validate_console(player)
    if not console then return end

    -- Give selection tool to cursor for location picking
    player.clear_cursor()
    player.cursor_stack.set_stack {name = "tardis-teleport-selector", count = 1}

    storage.pending_teleports = storage.pending_teleports or {}
    storage.pending_teleports[event.player_index] = {
        console_unit_number = console.unit_number,
        console = console,
        tardis_data = tardis_data,
    }

    player.create_local_flying_text {text = {"tardis-console-gui.select-location"}, create_at_cursor = true}
end

-- ALERT TELEPORT BUTTON --

gui_events[defines.events.on_gui_click]["^tardis%-console%-teleport%-to%-alert$"] = function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local console, tardis_data = validate_console(player)
    if not console then return end

    local building = tardis_data.building

    -- Collect all alerts, sorted: planet first, then space
    local all_alerts = player.get_alerts({})
    local planet_alerts = {}
    local space_alerts = {}

    for surface_index, alert_types in pairs(all_alerts) do
        local surface = game.get_surface(surface_index)
        if surface and surface.valid then
            local is_space = surface.platform ~= nil
            for _, alerts in pairs(alert_types) do
                for _, alert in pairs(alerts) do
                    if alert.position then
                        local alert_data = {
                            surface = surface,
                            position = alert.position,
                        }
                        if is_space then
                            space_alerts[#space_alerts + 1] = alert_data
                        else
                            planet_alerts[#planet_alerts + 1] = alert_data
                        end
                    end
                end
            end
        end
    end

    -- Chain through alerts: pre-check surface block and safe location
    local has_blocked_surface = false
    local has_no_safe_location = false

    local function try_alerts(alerts)
        for _, alert in ipairs(alerts) do
            if is_surface_blocked(alert.surface) then
                has_blocked_surface = true
            elseif not alert.surface.find_non_colliding_position(building.name, alert.position, 40, 0.5) then
                has_no_safe_location = true
            else
                return alert
            end
        end
        return nil
    end

    local target_alert = try_alerts(planet_alerts) or try_alerts(space_alerts)

    if target_alert then
        start_teleport(player, console, tardis_data, target_alert.position, target_alert.surface)
        return
    end

    -- No valid alert found — show appropriate error messages
    player.play_sound {path = "utility/cannot_build"}

    if #planet_alerts == 0 and #space_alerts == 0 then
        player.create_local_flying_text {text = {"tardis-console-gui.no-alerts"}, create_at_cursor = true}
        return
    end

    if has_no_safe_location then
        player.create_local_flying_text {text = {"tardis-console-gui.no-safe-location"}, create_at_cursor = true}
    end
    if has_blocked_surface then
        player.create_local_flying_text {text = {"tardis-console-gui.invalid-surface"}, create_at_cursor = true}
    end
end

-- MAP SELECTION HANDLERS --

tardis.on_event(defines.events.on_player_selected_area, function(event)
    if event.item ~= "tardis-teleport-selector" then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    storage.pending_teleports = storage.pending_teleports or {}
    local pending = storage.pending_teleports[event.player_index]
    if not pending then return end
    storage.pending_teleports[event.player_index] = nil
    player.clear_cursor()

    -- Validate console is still valid
    local console = pending.console
    if not console or not console.valid then return end

    if is_surface_blocked(event.surface) then
        player.create_local_flying_text {text = {"tardis-console-gui.invalid-surface"}, create_at_cursor = true}
        player.play_sound {path = "utility/cannot_build"}
        return
    end

    -- Calculate center of selected area
    local target = {
        (event.area.left_top.x + event.area.right_bottom.x) / 2,
        (event.area.left_top.y + event.area.right_bottom.y) / 2,
    }

    start_teleport(player, console, pending.tardis_data, target, event.surface)
end)

tardis.on_event(defines.events.on_player_alt_selected_area, function(event)
    if event.item ~= "tardis-teleport-selector" then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    storage.pending_teleports = storage.pending_teleports or {}
    local pending = storage.pending_teleports[event.player_index]
    if not pending then return end
    storage.pending_teleports[event.player_index] = nil
    player.clear_cursor()

    local console = pending.console
    if not console or not console.valid then return end

    if is_surface_blocked(event.surface) then
        player.create_local_flying_text {text = {"tardis-console-gui.invalid-surface"}, create_at_cursor = true}
        player.play_sound {path = "utility/cannot_build"}
        return
    end

    local target = {
        (event.area.left_top.x + event.area.right_bottom.x) / 2,
        (event.area.left_top.y + event.area.right_bottom.y) / 2,
    }

    start_teleport(player, console, pending.tardis_data, target, event.surface)
end)

-- Clean up pending teleport if player changes cursor
tardis.on_event(defines.events.on_player_cursor_stack_changed, function(event)
    if not storage.pending_teleports then return end
    local pending = storage.pending_teleports[event.player_index]
    if not pending then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    local cursor = player.cursor_stack
    if not cursor or not cursor.valid_for_read or cursor.name ~= "tardis-teleport-selector" then
        storage.pending_teleports[event.player_index] = nil
    end
end)

-- KEY TELEPORT (capsule handler) --

local KEY_CAPSULE_PREFIX = "tardis-key-active"

local function recreate_key_capsule(player, capsule_name)
    if player.cursor_stack then
        player.cursor_stack.set_stack {name = capsule_name, count = 1}
    end
end

tardis.on_event(defines.events.on_player_used_capsule, function(event)
    if event.item.name:sub(1, #KEY_CAPSULE_PREFIX) ~= KEY_CAPSULE_PREFIX then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    local capsule_name = event.item.name
    local active = (storage.active_key or {})[event.player_index]
    if not active then
        recreate_key_capsule(player, capsule_name)
        return
    end

    -- Validate GUID
    local valid_keys = (storage.tardis_valid_keys or {})[active.tardis_id]
    if not valid_keys or not valid_keys[active.key_guid] then
        player.create_local_flying_text {text = {"tardis-key-gui.invalid-key"}, create_at_cursor = true}
        player.play_sound {path = "utility/cannot_build"}
        recreate_key_capsule(player, capsule_name)
        return
    end

    -- Look up TARDIS data
    local tardis_data = storage.factories[active.tardis_id]
    if not tardis_data then
        player.create_local_flying_text {text = {"tardis-key-gui.invalid-key"}, create_at_cursor = true}
        player.play_sound {path = "utility/cannot_build"}
        recreate_key_capsule(player, capsule_name)
        return
    end

    if not tardis_data.building or not tardis_data.building.valid then
        player.create_local_flying_text {text = {"tardis-console-gui.not-placed"}, create_at_cursor = true}
        player.play_sound {path = "utility/cannot_build"}
        recreate_key_capsule(player, capsule_name)
        return
    end

    -- Check surface not blocked
    if is_surface_blocked(player.surface) then
        player.create_local_flying_text {text = {"tardis-console-gui.invalid-surface"}, create_at_cursor = true}
        player.play_sound {path = "utility/cannot_build"}
        recreate_key_capsule(player, capsule_name)
        return
    end

    -- Pre-check safe location (offset from player so TARDIS doesn't land on top)
    local building = tardis_data.building
    local target_position = {player.position.x + 4, player.position.y}
    if not player.surface.find_non_colliding_position(building.name, target_position, 40, 0.5) then
        player.create_local_flying_text {text = {"tardis-console-gui.no-safe-location"}, create_at_cursor = true}
        player.play_sound {path = "utility/cannot_build"}
        recreate_key_capsule(player, capsule_name)
        return
    end

    -- Find console and check fuel
    local console = tardis_data.inside_surface.find_entity("tardis-console", {tardis_data.inside_x, tardis_data.inside_y})
    if not console or not console.valid then
        player.create_local_flying_text {text = {"tardis-console-gui.no-tardis"}, create_at_cursor = true}
        player.play_sound {path = "utility/cannot_build"}
        recreate_key_capsule(player, capsule_name)
        return
    end

    if is_console_on_cooldown(console) then
        recreate_key_capsule(player, capsule_name)
        return
    end

    local inventory = console.get_inventory(defines.inventory.chest)
    local available = 0
    for i = 1, #inventory do
        local slot = inventory[i]
        if slot.valid_for_read and slot.name == get_fuel_item() then
            available = available + slot.count
        end
    end

    if available < get_fuel_cost() then
        player.create_local_flying_text {text = {"tardis-console-gui.no-fuel", get_fuel_cost(), "[item=" .. get_fuel_item() .. "]"}, create_at_cursor = true}
        player.play_sound {path = "utility/cannot_build"}
        recreate_key_capsule(player, capsule_name)
        return
    end

    -- All checks passed — teleport TARDIS near player
    start_teleport(player, console, tardis_data, target_position, player.surface)
    player.create_local_flying_text {text = {"tardis-console-gui.teleported"}, create_at_cursor = true}
    recreate_key_capsule(player, capsule_name)
end)

-- Export for key activation
remote_api.attempt_teleport = attempt_teleport
