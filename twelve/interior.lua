-- A persistent, buildable Factorio surface. Only the ship's original floor is
-- resurfaced on upgrade; machines, belts, inventories and player paving survive.
local Migration = require('twelve.interior-migration')
local Chunks = require('twelve.interior-chunks')
local I = { revision = 130003 }
I.on_cloned = Migration.on_cloned
I.tile_name = Chunks.name
local original_floor = { ['tardis-floor'] = true }
local room_original_floor = { ['tardis-floor'] = true, ['refined-hazard-concrete-left'] = true }
local function valid(e)
  return e and e.valid
end
local function protect(e)
  if valid(e) then
    e.destructible = false
    e.minable = false
  end
  return e
end
local function destroy_renders(list)
  for _, r in pairs(list or {}) do
    if r.valid then
      r.destroy()
    end
  end
end
local function entity(f, list, name, position)
  local e = protect(
    f.surface.create_entity({ name = name, position = position, force = f.force, create_build_effect_smoke = false })
  )
  if e then
    list[#list + 1] = e
  end
  return e
end
local function relay(f, list, position)
  if f.surface.count_entities_filtered({ name = 'tardis-room-relay', position = position, radius = 0.75 }) == 0 then
    return entity(f, list, 'tardis-room-relay', position)
  end
end
local function wall(f, list, x, y)
  -- A legacy factory may already occupy this part of the room. Decor never
  -- displaces it or draws a solid panel over it.
  local found = f.surface.find_entities_filtered({ area = { { x - 1.8, y - 0.5 }, { x + 1.8, y + 0.5 } } })
  for _, e in pairs(found) do
    if e.type ~= 'character' and e.type ~= 'corpse' and e.type ~= 'item-entity' and e.name ~= 'tardis-room-relay' then
      return
    end
  end
  entity(f, list, 'tardis-roundel-wall', { x, y })
end
local function lamp(f, list, x, y)
  if f.surface.can_place_entity({ name = 'small-lamp', position = { x, y }, force = f.force }) then
    local e = entity(f, list, 'small-lamp', { x, y })
    if e then
      e.always_on = true
    end
  end
end
local function center_floor(x, y)
  local dx, dy = x + 0.5, y + 0.5
  local r = math.sqrt(dx * dx + dy * dy)
  if x >= 21 then
    if x == 21 or x == 41 or y == -12 or y == 12 then
      return 'tardis-brass-floor'
    end
    if (x >= 29 and x <= 32) or y == 0 or y == -1 then
      return 'tardis-grate-floor'
    end
    return 'tardis-steel-floor'
  end
  if r >= 13.3 or (math.abs(dx) < 2 and y >= 13) then
    return 'tardis-brass-floor'
  end
  if (r >= 4.2 and r < 6.5) or (x >= 12 and math.abs(dy) < 2) then
    return 'tardis-grate-floor'
  end
  if r < 3.7 then
    return 'tardis-brass-floor'
  end
  return 'tardis-steel-floor'
end

local tree = {
  { x = -16, y = -40 },
  { x = 16, y = -40 },
  { x = -48, y = -76 },
  { x = -16, y = -76 },
  { x = 16, y = -76 },
  {
    x = 48,
    y = -76,
  },
}
local parents = { [3] = 1, [4] = 1, [5] = 2, [6] = 2 }
local function old_position(slot)
  return { x = 56 + 28 * ((slot - 1) % 3), y = slot <= 3 and -18 or 18 }
end
function I.position(slot, f)
  if f and f.room_layout_version == 1 then
    return f.rooms[slot] and f.rooms[slot].position or old_position(slot)
  end
  local p = tree[slot]
  return p and { x = p.x, y = p.y } or nil
end
local function chunk(s, x, y)
  Chunks.ensure(s, math.floor(x / 32), math.floor(y / 32))
end
local function route(f, slot, list)
  local s = f.surface
  local tiles = {}
  f.room_corridor_tiles = f.room_corridor_tiles or {}
  local function tile(x, y)
    local name = Chunks.name(s, x, y)
    if name == 'out-of-map' or name == 'tardis-floor' then
      chunk(s, x, y)
      tiles[#tiles + 1] = { name = 'tardis-grate-floor', position = { x, y } }
      f.room_corridor_tiles[x .. ':' .. y] = true
    end
  end
  local function vertical(x, from, to)
    for xx = x - 2, x + 1 do
      for y = math.min(from, to), math.max(from, to) do
        tile(xx, y)
      end
    end
  end
  local function horizontal(y, from, to)
    for x = math.min(from, to) - 2, math.max(from, to) + 1 do
      for yy = y - 2, y + 1 do
        tile(x, yy)
      end
    end
  end
  local p = tree[slot]
  local parent = parents[slot]
  local base = parent and tree[parent] or p
  vertical(0, -13, -23)
  horizontal(-22, 0, base.x)
  vertical(base.x, -22, -31)
  if parent then
    -- Migrated legacy leaves may exist before their new parent. A narrow owned
    -- corridor keeps them reachable without granting a free full-size room.
    vertical(base.x, -31, -58)
    horizontal(-58, base.x, p.x)
    vertical(p.x, -58, -67)
  end
  s.set_tiles(tiles, true)
  relay(f, list, { 0, -18 })
  relay(f, list, { base.x, -22 })
  relay(f, list, { base.x, -40 })
  if parent then
    relay(f, list, { base.x, -58 })
    if math.abs(p.x - base.x) > 20 then
      relay(f, list, { (p.x + base.x) / 2, -58 })
    end
    relay(f, list, { p.x, -58 })
  end
  relay(f, list, { p.x, p.y })
end
local function room_floor(p, kind, x, y)
  local dx, dy = x - p.x, y - p.y
  if dx == -12 or dx == 11 or dy == -10 or dy == 9 then
    return 'tardis-brass-floor'
  end
  if (dy >= -1 and dy <= 1) or (kind == 'workshop' and (dx == -7 or dx == 6)) then
    return 'tardis-grate-floor'
  end
  return 'tardis-steel-floor'
end

function I.room(f, slot, room, legacy)
  if room.architecture_revision == I.revision then
    return
  end
  local p = I.position(slot, f)
  local s = f.surface
  local tiles = {}
  local edits = {}
  local function tile(x, y, name, allow_void)
    local key = x .. ':' .. y
    if edits[key] then
      return
    end
    local existing = Chunks.name(s, x, y)
    if not legacy or room_original_floor[existing] or (allow_void and existing == 'out-of-map') then
      edits[key] = true
      tiles[#tiles + 1] = { name = name, position = { x, y } }
    end
  end
  Chunks.ensure_area(s, p.x - 13, p.y - 11, p.x + 13, p.y + 11)
  if f.room_layout_version == 1 then
    -- A blocked migration retains the entire usable original geometry.
    for x = 42, p.x + 1 do
      for y = -2, 1 do
        local current = Chunks.name(s, x, y)
        if current == 'out-of-map' or current == 'tardis-floor' then
          tile(x, y, 'tardis-grate-floor', true)
        end
      end
    end
    for x = p.x - 2, p.x + 1 do
      for y = math.min(0, p.y), math.max(0, p.y) do
        tile(x, y, 'tardis-grate-floor', true)
      end
    end
  end
  for x = p.x - 12, p.x + 11 do
    for y = p.y - 10, p.y + 9 do
      tile(x, y, room_floor(p, room.kind, x, y))
    end
  end
  s.set_tiles(tiles, true)
  destroy_renders(room.renders)
  room.renders = {}
  room.entities = room.entities or {}
  if not legacy then
    entity(f, room.entities, 'tardis-terminal', { p.x + 7, p.y + 5 })
    for _, xy in ipairs({ { p.x - 9, p.y - 7 }, { p.x + 8, p.y - 7 }, { p.x - 9, p.y + 6 }, { p.x + 8, p.y + 6 } }) do
      lamp(f, room.entities, xy[1], xy[2])
    end
  end
  if f.room_layout_version == 1 then
    for x = 43, p.x, 20 do
      relay(f, room.entities, { x + 0.5, -1.5 })
    end
    relay(f, room.entities, { p.x, p.y })
  else
    route(f, slot, room.entities)
  end
  -- Parent rooms have a clearly open north passage to their children.
  if slot <= 2 and f.room_layout_version ~= 1 then
    for _, e in
      ipairs(s.find_entities_filtered({ name = 'tardis-roundel-wall', position = { p.x, p.y - 8.75 }, radius = 1 }))
    do
      e.destroy()
    end
  end
  for _, x in ipairs({ -8, -4, 0, 4, 8 }) do
    if x ~= 0 or slot > 2 or f.room_layout_version == 1 then
      wall(f, room.entities, p.x + x, p.y - 8.75)
    end
  end
  room.architecture_revision = I.revision
  room.position = p
  f.force.chart(s, { { p.x - 13, p.y - 11 }, { p.x + 13, p.y + 11 } })
end

-- Layout errors are LocalisedStrings (tables), or plain strings from old saves
-- and Lua runtime errors; compare by value so a repeated failure stays quiet.
local function same_message(a, b)
  if type(a) ~= 'table' or type(b) ~= 'table' then
    return a == b
  end
  if #a ~= #b then
    return false
  end
  for i = 1, #a do
    if not same_message(a[i], b[i]) then
      return false
    end
  end
  return true
end
function I.apply(f)
  if not (f.surface and f.surface.valid) then
    return
  end
  -- The five-tile-wide console snaps from {0,0} to {.5,0} on creation. Keep
  -- its native footprint and sprite together at the circular floor's origin.
  -- A checked in-place teleport preserves inventory/unit identity and leaves
  -- neighbouring player equipment untouched if the half-tile move is blocked.
  if valid(f.console) and (math.abs(f.console.position.x) > 0.001 or math.abs(f.console.position.y) > 0.001) then
    f.console_center_pending = not f.console.teleport({ 0, 0 }, nil, false, false, defines.build_check_type.manual)
  else
    f.console_center_pending = nil
  end
  Chunks.clean(f, function(slot, ship)
    return ship.room_layout_version == 2 and I.position(slot) or old_position(slot)
  end)
  if f.room_layout_version ~= 2 then
    local previous_error = f.room_layout_error
    local ok, why = Migration.move(f, old_position, function(slot)
      return I.position(slot)
    end)
    if not ok then
      f.room_layout_version = 1
      if not same_message(previous_error, why) then
        f.force.print({ 'tardis-interior.relayout-postponed', why })
      end
      f.room_layout_error = why
    elseif next(f.rooms or {}) then
      f.force.print({ 'tardis-interior.relayout-done' })
    end
  end
  if f.interior_revision ~= I.revision then
    if valid(f.art) then
      f.art.destroy()
    end
    f.art = nil
    local tiles = {}
    for x = -20, 43 do
      for y = -20, 22 do
        if original_floor[Chunks.name(f.surface, x, y)] then
          tiles[#tiles + 1] = { name = center_floor(x, y), position = { x, y } }
        end
      end
    end
    f.surface.set_tiles(tiles, true)
    f.architecture_entities = f.architecture_entities or {}
    relay(f, f.architecture_entities, { 12.5, 0.5 })
    relay(f, f.architecture_entities, { 0.5, -0.5 })
    if f.room_layout_version == 2 then
      local vestibule = {}
      for x = -2, 1 do
        for y = -24, -13 do
          if Chunks.name(f.surface, x, y) == 'out-of-map' then
            vestibule[#vestibule + 1] = { name = 'tardis-grate-floor', position = { x, y } }
          end
        end
      end
      f.surface.set_tiles(vestibule, true)
      relay(f, f.architecture_entities, { 0, -18 })
    end
    -- The generated circular rim owns the main hall's wall now, including its
    -- north opening. Remove only the previous ship-created wall entities.
    for _, e in ipairs(f.architecture_entities) do
      if
        valid(e)
        and e.name == 'tardis-roundel-wall'
        and math.abs(e.position.x) < 15
        and math.abs(e.position.y) < 15
      then
        e.destroy()
      end
    end
    for _, xy in ipairs({ { -10, -7 }, { 10, -7 }, { -10, 7 }, { 10, 7 } }) do
      lamp(f, f.architecture_entities, xy[1], xy[2])
    end
    f.interior_revision = I.revision
  end
  for slot, room in pairs(f.rooms or {}) do
    if room.state == 'ready' then
      I.room(f, slot, room, true)
    end
  end
  Migration.cleanup_legacy_wing(f)
end
function I.chunk_generated(event)
  for _, f in pairs(storage.twelve and storage.twelve.ships or {}) do
    if f.surface == event.surface then
      Chunks.clean(f, function(slot, ship)
        return ship.room_layout_version == 2 and I.position(slot) or old_position(slot)
      end, event.position)
      return
    end
  end
end
return I
