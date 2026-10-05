local find_surrounding_tardis = remote_api.find_surrounding_tardis

tardis.on_event(tardis.events.on_init(), function()
    storage.tardis_valid_keys = storage.tardis_valid_keys or {}
end)

local function generate_guid()
    return game.tick .. "-" .. math.random(100000, 999999)
end

tardis.on_event(tardis.events.on_built(), function(event)
    local entity = event.entity
    if not entity.valid then return end

    if entity.name == "tardis-key-synchronizer" then
        if not remote_api.is_tardis_surface(entity.surface) then
            tardis.cancel_creation(entity, event.player_index, {"tardis-key-gui.wrong-surface"})
            return
        end

        local tardis_data = find_surrounding_tardis(entity.surface, entity.position)
        if not tardis_data then
            tardis.cancel_creation(entity, event.player_index, {"tardis-key-gui.wrong-surface"})
            return
        end
        return
    end

    if string.match(entity.name, '^tardis%-key%-') then
        local key_name = entity.name
        local player = game.get_player(event.player_index)
        if not player then
            entity.destroy()
            return
        end

        local tags = event.tags or (event.stack and event.stack.valid_for_read and event.stack.tags)
        entity.destroy()

        local function restore_key_to_cursor(tags)
            if player.cursor_stack then
                player.cursor_stack.set_stack {
                    name = key_name,
                    count = 1,
                    tags = tags
                }
            end
        end

        if not tags or not tags.tardis_id or not tags.key_guid then
            restore_key_to_cursor(tags or {})
            player.create_local_flying_text {text = {"tardis-key-gui.unbound-key"}, create_at_cursor = true}
            player.play_sound {path = "utility/cannot_build"}
            return
        end

        -- Validate GUID
        local valid_keys = storage.tardis_valid_keys[tags.tardis_id]
        if not valid_keys or not valid_keys[tags.key_guid] then
            restore_key_to_cursor(tags)
            player.create_local_flying_text {text = {"tardis-key-gui.invalid-key"}, create_at_cursor = true}
            player.play_sound {path = "utility/cannot_build"}
            return
        end

        -- Look up TARDIS data
        local tardis_data = storage.factories[tags.tardis_id]
        if not tardis_data then
            restore_key_to_cursor(tags)
            player.create_local_flying_text {text = {"tardis-key-gui.invalid-key"}, create_at_cursor = true}
            player.play_sound {path = "utility/cannot_build"}
            return
        end

        -- Attempt teleport (all checks are done inside)
        local target_position = {player.position.x + 4, player.position.y}
        local success = remote_api.attempt_teleport(player, tardis_data, target_position, player.surface)

        -- Always restore key to cursor
        restore_key_to_cursor(tags)
        return
    end
end)

-- KEY SYNCHRONIZER GUI --

local function destroy_key_gui(player)
    local frame = player.gui.relative["tardis-key-panel"]
    if frame then frame.destroy() end
end

local function create_key_gui(player, entity)
    destroy_key_gui(player)

    local anchor = {
        gui = defines.relative_gui_type.container_gui,
        position = defines.relative_gui_position.right,
        name = "tardis-key-synchronizer",
    }

    local frame = player.gui.relative.add {
        type = "frame",
        name = "tardis-key-panel",
        direction = "vertical",
        anchor = anchor,
    }

    frame.add {
        type = "label",
        caption = {"tardis-key-gui.title"},
        style = "frame_title",
    }

    local content = frame.add {
        type = "flow",
        name = "tardis-key-content",
        direction = "vertical",
        style = "inset_frame_container_vertical_flow",
    }

    local inner = content.add {
        type = "frame",
        name = "tardis-key-inner",
        style = "inside_shallow_frame_with_padding",
        direction = "vertical",
    }

    -- Color selection
    inner.add {
        type = "label",
        caption = {"tardis-key-gui.color-label"},
        style = "caption_label",
    }

    local colors = {"white", "red", "green", "blue", "yellow", "orange", "purple", "pink", "cyan", "black"}
    local color_items = {}
    for i, color_name in ipairs(colors) do
        color_items[i] = {"color." .. color_name}
    end

    inner.add {
        type = "drop-down",
        name = "tardis-key-color-dropdown",
        items = color_items,
        selected_index = 1,
    }

    -- Spacer
    local spacer = inner.add {type = "flow", direction = "vertical"}
    spacer.style.height = 8

    inner.add {
        type = "button",
        name = "tardis-key-bind",
        caption = {"tardis-key-gui.bind"},
        tooltip = {"tardis-key-gui.bind-tooltip"},
        style = "confirm_button",
    }
end

tardis.on_event(defines.events.on_gui_opened, function(event)
    local entity = event.entity
    if not entity or not entity.valid then return end
    if entity.name ~= "tardis-key-synchronizer" then return end

    create_key_gui(game.get_player(event.player_index), entity)
end)

tardis.on_event(defines.events.on_gui_closed, function(event)
    local entity = event.entity
    if not entity or not entity.valid then return end
    if entity.name ~= "tardis-key-synchronizer" then return end

    destroy_key_gui(game.get_player(event.player_index))
end)

gui_events[defines.events.on_gui_click]["^tardis%-key%-bind$"] = function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local opened = player.opened
    if not opened or not opened.valid or opened.name ~= "tardis-key-synchronizer" then return end

    -- Find surrounding TARDIS
    local tardis_data = find_surrounding_tardis(opened.surface, opened.position)
    if not tardis_data then
        player.create_local_flying_text {text = {"tardis-key-gui.wrong-surface"}, create_at_cursor = true}
        player.play_sound {path = "utility/cannot_build"}
        return
    end

    -- Check container has any tardis-key variant
    local inventory = opened.get_inventory(defines.inventory.chest)
    local key_slot = nil
    for i = 1, #inventory do
        local slot = inventory[i]
        if slot.valid_for_read and string.match(slot.name, '^tardis%-key%-') then
            key_slot = slot
            break
        end
    end

    if not key_slot then
        player.create_local_flying_text {text = {"tardis-key-gui.no-key"}, create_at_cursor = true}
        player.play_sound {path = "utility/cannot_build"}
        return
    end

    -- Invalidate old GUID if any
    local old_tags = key_slot.tags
    if old_tags and old_tags.tardis_id and old_tags.key_guid then
        local old_keys = storage.tardis_valid_keys[old_tags.tardis_id]
        if old_keys then
            old_keys[old_tags.key_guid] = nil
        end
    end

    -- Generate and register new GUID
    local guid = generate_guid()
    local tardis_id = tardis_data.id

    storage.tardis_valid_keys[tardis_id] = storage.tardis_valid_keys[tardis_id] or {}
    storage.tardis_valid_keys[tardis_id][guid] = true

    -- Get selected color from dropdown
    local gui = player.gui.relative["tardis-key-panel"]
    local dropdown = gui and gui["tardis-key-content"]["tardis-key-inner"]["tardis-key-color-dropdown"]
    local colors = {"white", "red", "green", "blue", "yellow", "orange", "purple", "pink", "cyan", "black"}
    local selected_key_name = dropdown and dropdown.selected_index > 0 and ("tardis-key-" .. colors[dropdown.selected_index])

    -- Replace key with selected color if different, preserving new tags
    local new_tags = {tardis_id = tardis_id, key_guid = guid}
    if selected_key_name and selected_key_name ~= key_slot.name then
        key_slot.set_stack{name = selected_key_name, count = 1, tags = new_tags}
    else
        key_slot.tags = new_tags
    end

    player.create_local_flying_text {text = {"tardis-key-gui.bound"}, create_at_cursor = true}
    player.play_sound { path = "utility/confirm" }
end

gui_events[defines.events.on_gui_selection_state_changed]["^tardis%-key%-color%-dropdown$"] = function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local opened = player.opened
    if not opened or not opened.valid or opened.name ~= "tardis-key-synchronizer" then return end

    local dropdown = event.element
    if not dropdown or dropdown.selected_index == 0 then return end

    -- Map index to key name
    local colors = {"white", "red", "green", "blue", "yellow", "orange", "purple", "pink", "cyan", "black"}
    local new_key_name = "tardis-key-" .. colors[dropdown.selected_index]

    -- Find key in container
    local inventory = opened.get_inventory(defines.inventory.chest)
    local key_slot_index = nil
    for i = 1, #inventory do
        local slot = inventory[i]
        if slot.valid_for_read and string.match(slot.name, "^tardis%-key%-") then
            key_slot_index = i
            break
        end
    end

    if not key_slot_index then return end

    -- Replace with new colored key, preserving tags
    local old_tags = inventory[key_slot_index].tags
    inventory[key_slot_index].set_stack{name = new_key_name, count = 1, tags = old_tags}
end
