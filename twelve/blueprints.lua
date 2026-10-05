-- The console's blueprint archive: blueprints, books and planners kept inside the ship.
-- Items live in a script inventory, so their contents survive jumps and saves.
local B = { slots = 60 }

function B.ensure(f)
  if not (f.blueprints and f.blueprints.valid) then
    f.blueprints = game.create_inventory(B.slots, { 'tardis-ship.blueprint-archive-title' })
  end
  return f.blueprints
end

function B.allowed(stack)
  return stack
    and stack.valid_for_read
    and (stack.is_blueprint or stack.is_blueprint_book or stack.is_deconstruction_item or stack.is_upgrade_item)
end

function B.label(stack)
  local text = stack.is_blueprint and stack.label or nil
  if text and text ~= '' then
    return text
  end
  return stack.prototype.localised_name
end

-- Stores the item in the player's cursor; into `slot` when it is free, otherwise the first free slot.
function B.store(p, f, slot)
  local archive = B.ensure(f)
  local cursor = p.cursor_stack
  if not (cursor and cursor.valid_for_read) then
    if p.cursor_record then
      return false, { 'tardis-ship.blueprint-record' }
    end
    return false, { 'tardis-ship.blueprint-no-item' }
  end
  if not B.allowed(cursor) then
    return false, { 'tardis-ship.blueprint-not-allowed' }
  end
  local target = slot and archive[slot]
  if not (target and not target.valid_for_read) then
    target = archive.find_empty_stack()
  end
  if not target then
    return false, { 'tardis-ship.blueprint-full' }
  end
  local name = B.label(cursor)
  if not target.transfer_stack(cursor) then
    return false, { 'tardis-ship.blueprint-full' }
  end
  return true, { 'tardis-ship.blueprint-stored', name }
end

-- Puts a copy (or, with copy = false, the original) of an archived item into the empty cursor.
function B.take(p, f, slot, copy)
  local stack = B.ensure(f)[slot]
  if not (stack and stack.valid_for_read) then
    return false, { 'tardis-ship.blueprint-empty-slot' }
  end
  local cursor = p.cursor_stack
  if not cursor or cursor.valid_for_read or p.cursor_record then
    return false, { 'tardis-ship.blueprint-hands-full' }
  end
  local name = B.label(stack)
  if copy then
    if not cursor.set_stack(stack) then
      return false, { 'tardis-ship.blueprint-hands-full' }
    end
    return true, { 'tardis-ship.blueprint-copied', name }
  end
  if not cursor.transfer_stack(stack) then
    return false, { 'tardis-ship.blueprint-hands-full' }
  end
  return true, { 'tardis-ship.blueprint-taken', name }
end

function B.destroy(f)
  if f.blueprints and f.blueprints.valid then
    f.blueprints.destroy()
  end
end

return B
