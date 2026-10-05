-- Native area cloning is staged before any original entity is removed. If an
-- occupied destination, unsupported entity or verification failure is found, the
-- complete old layout is retained. The clone callback is synchronous only.
local T = {}
local Chunks = require('twelve.interior-chunks')
local context
local function valid(e)
  return e and e.valid
end
local function bounds(p)
  return { { p.x - 12, p.y - 10 }, { p.x + 12, p.y + 10 } }
end
local function contains(p, xy)
  return xy.x >= p.x - 12 and xy.x < p.x + 12 and xy.y >= p.y - 10 and xy.y < p.y + 10
end
local function key(e)
  return e.unit_number and ('u' .. e.unit_number) or (e.name .. ':' .. e.position.x .. ':' .. e.position.y)
end
local function contents(inventory)
  local a = inventory.get_contents()
  table.sort(a, function(x, y)
    return x.name == y.name and x.quality < y.quality or x.name < y.name
  end)
  return helpers.table_to_json(a)
end
local inventory_ids = {}
for _, id in pairs(defines.inventory) do
  inventory_ids[id] = true
end
local belt_types = {
  ['transport-belt'] = true,
  ['underground-belt'] = true,
  splitter = true,
  loader = true,
  ['loader-1x1'] = true,
  ['linked-belt'] = true,
}
local function snapshot(e)
  local result = {
    name = e.name,
    quality = e.quality.name,
    force = e.force.index,
    health = e.health,
    inventories = {},
    belts = {},
    fluids = e.get_fluid_contents(),
  }
  for id in pairs(inventory_ids) do
    local inv = e.get_inventory(id)
    if inv then
      result.inventories[id] = contents(inv)
    end
  end
  if belt_types[e.type] then
    for i = 1, e.get_max_transport_line_index() do
      result.belts[i] = contents(e.get_transport_line(i))
    end
  end
  return result
end
function T.on_cloned(event)
  if not context then
    return false
  end
  local source, destination = event.source, event.destination
  if source.surface ~= context.surface or destination.surface ~= context.surface then
    return false
  end
  context.created[#context.created + 1] = destination
  context.clones[key(source)] = destination
  return true
end
local function same_snapshot(a, b)
  if a.name ~= b.name or a.quality ~= b.quality or a.force ~= b.force or a.health ~= b.health then
    return false
  end
  for id, value in pairs(a.inventories) do
    if b.inventories[id] ~= value then
      return false
    end
  end
  for id, value in pairs(a.belts) do
    if b.belts[id] ~= value then
      return false
    end
  end
  for name, amount in pairs(a.fluids) do
    if math.abs((b.fluids[name] or 0) - amount) > 0.0001 then
      return false
    end
  end
  return true
end

function T.move(f, old_position, new_position)
  if f.room_layout_version == 2 then
    return true
  end
  local s = f.surface
  local entries = {}
  local originals = {}
  local ownership = {}
  local snapshots = {}
  local wires = {}
  local actors = {}
  local transaction = { surface = s, created = {}, clones = {} }
  local function fail(reason)
    context = nil
    for _, e in ipairs(transaction.created) do
      if valid(e) then
        e.destroy()
      end
    end
    local tiles = {}
    for _, entry in ipairs(entries) do
      for x = entry.to.x - 12, entry.to.x + 11 do
        for y = entry.to.y - 10, entry.to.y + 9 do
          tiles[#tiles + 1] = { name = 'out-of-map', position = { x, y } }
        end
      end
    end
    if #tiles > 0 then
      s.set_tiles(tiles, true)
    end
    f.room_layout_version = 1
    -- Messages are LocalisedStrings (tables); Lua runtime errors are strings.
    local message = type(reason) == 'table' and reason or tostring(reason)
    f.room_layout_error = message
    return false, message
  end
  -- Preflight all destinations before a single tile is written.
  for slot, room in pairs(f.rooms or {}) do
    if room.state == 'ready' then
      local from = room.position or old_position(slot)
      local to = new_position(slot)
      local entry = { slot = slot, room = room, from = from, to = to, entities = {} }
      for x = to.x - 12, to.x + 11 do
        for y = to.y - 10, to.y + 9 do
          if Chunks.name(s, x, y) ~= 'out-of-map' then
            return false, { 'tardis-interior.migration-slot-tiles', slot }
          end
        end
      end
      if s.count_entities_filtered({ area = bounds(to) }) > 0 then
        return false, { 'tardis-interior.migration-slot-entities', slot }
      end
      for _, e in ipairs(s.find_entities_filtered({ area = bounds(from) })) do
        local box = e.bounding_box
        if
          e.type ~= 'character'
          and (
            box.left_top.x < from.x - 12
            or box.left_top.y < from.y - 10
            or box.right_bottom.x > from.x + 12
            or box.right_bottom.y > from.y + 10
          )
        then
          return false, { 'tardis-interior.migration-entity-crosses-border', e.name, slot }
        end
        if contains(from, e.position) then
          if e.type == 'character' then
            actors[#actors + 1] = {
              entity = e,
              player = e.player,
              from = e.position,
              to = {
                e.position.x + to.x - from.x,
                e.position.y + to.y - from.y,
              },
            }
          else
            if
              e.type == 'locomotive'
              or e.type == 'cargo-wagon'
              or e.type == 'fluid-wagon'
              or e.type == 'artillery-wagon'
            then
              return false, { 'tardis-interior.migration-train', slot }
            end
            if (e.type == 'car' or e.type == 'spider-vehicle') and (e.get_driver() or e.get_passenger()) then
              return false, { 'tardis-interior.migration-vehicle-passenger', slot }
            end
            local k = key(e)
            if originals[k] then
              return false, { 'tardis-interior.migration-entity-multiple' }
            end
            originals[k] = e
            ownership[k] = slot
            entry.entities[#entry.entities + 1] = e
          end
        end
      end
      entries[#entries + 1] = entry
    end
  end
  table.sort(entries, function(a, b)
    return a.slot < b.slot
  end)
  -- Geometry changes cannot preserve a belt, pipe or heat connection through an
  -- old doorway. Refuse the migration rather than silently disconnect a factory.
  local function crossing(source, target)
    return valid(target) and ownership[key(target)] ~= ownership[key(source)]
  end
  for _, e in pairs(originals) do
    if belt_types[e.type] then
      local neighbours = e.belt_neighbours
      for _, list in pairs(neighbours) do
        for _, other in pairs(list) do
          if crossing(e, other) then
            return false, { 'tardis-interior.migration-disconnect-belts' }
          end
        end
      end
      if e.type == 'underground-belt' and crossing(e, e.neighbours) then
        return false, { 'tardis-interior.migration-disconnect-underground' }
      end
    end
    for i = 1, #e.fluidbox do
      for _, connection in ipairs(e.fluidbox.get_pipe_connections(i)) do
        if connection.target and crossing(e, connection.target.owner) then
          return false, { 'tardis-interior.migration-disconnect-pipes' }
        end
      end
    end
    if e.type == 'heat-pipe' or e.type == 'reactor' then
      for _, other in pairs(e.neighbours or {}) do
        if crossing(e, other) then
          return false, { 'tardis-interior.migration-disconnect-heat' }
        end
      end
    end
  end
  -- Offline, god and editor controllers may have a physical position without a
  -- character entity in find_entities_filtered. They must follow the room too.
  local actor_players = {}
  for _, actor in ipairs(actors) do
    if actor.player then
      actor_players[actor.player.index] = true
    end
  end
  for _, player in pairs(game.players) do
    if player.physical_surface == s and not actor_players[player.index] then
      for _, entry in ipairs(entries) do
        if contains(entry.from, player.physical_position) then
          local pos = player.physical_position
          actors[#actors + 1] = {
            player = player,
            entity = player.character,
            from = pos,
            to = { pos.x + entry.to.x - entry.from.x, pos.y + entry.to.y - entry.from.y },
          }
          actor_players[player.index] = true
          break
        end
      end
    end
  end
  local ok, reason = pcall(function()
    for k, e in pairs(originals) do
      snapshots[k] = snapshot(e)
      for id, connector in pairs(e.get_wire_connectors(false)) do
        for _, wire in ipairs(connector.connections) do
          wires[#wires + 1] = {
            source = k,
            id = id,
            target = wire.target.owner,
            target_id = wire.target.wire_connector_id,
            origin = wire.origin,
          }
        end
      end
    end
    context = transaction
    for _, entry in ipairs(entries) do
      Chunks.ensure_area(s, entry.to.x - 13, entry.to.y - 11, entry.to.x + 13, entry.to.y + 11)
      s.clone_area({
        source_area = bounds(entry.from),
        destination_area = bounds(entry.to),
        destination_surface = s,
        clone_tiles = true,
        clone_entities = false,
        clone_decoratives = false,
        clear_destination_entities = false,
        clear_destination_decoratives = false,
        expand_map = false,
      })
      s.clone_entities({
        entities = entry.entities,
        destination_offset = { entry.to.x - entry.from.x, entry.to.y - entry.from.y },
        destination_surface = s,
        snap_to_grid = false,
        create_build_effect_smoke = false,
      })
    end
    context = nil
    for k, e in pairs(originals) do
      local clone = transaction.clones[k]
      -- assert() only accepts string messages; raise LocalisedStrings with error().
      if not valid(clone) then
        error({ 'tardis-interior.migration-clone-missing', e.name }, 0)
      end
      if not same_snapshot(snapshots[k], snapshot(clone)) then
        error({ 'tardis-interior.migration-clone-mismatch', e.name }, 0)
      end
    end
    -- Internal and external red/green/copper links are preserved. Rearranging a
    -- spatial room may stretch a pre-existing wire beyond ordinary building reach.
    for _, wire in ipairs(wires) do
      local source = transaction.clones[wire.source]
      local target = transaction.clones[key(wire.target)] or wire.target
      if valid(source) and valid(target) then
        local a = source.get_wire_connector(wire.id, true)
        local b = target.get_wire_connector(wire.target_id, true)
        if not (a and b) then
          error({ 'tardis-interior.migration-wire-connector-lost' }, 0)
        end
        if not a.is_connected_to(b, wire.origin) then
          if not a.connect_to(b, false, wire.origin) then
            error({ 'tardis-interior.migration-wire-not-restored' }, 0)
          end
        end
      end
    end
    -- Real characters are moved; they are never cloned, so player and armour
    -- ownership remains with the same native character entity.
    for _, actor in ipairs(actors) do
      if actor.player then
        actor.player.driving = false
      end
      local who = actor.player or actor.entity
      if not who.teleport(actor.to, s) then
        error({ 'tardis-interior.migration-character-not-moved' }, 0)
      end
    end
  end)
  context = nil
  if not ok then
    for _, actor in ipairs(actors) do
      if valid(actor.player or actor.entity) then
        (actor.player or actor.entity).teleport(actor.from, s)
      end
    end
    return fail(reason)
  end
  -- From this point every clone exists and was checked. Save references are
  -- replaced before originals disappear; escrow inventories are not involved.
  for _, entry in ipairs(entries) do
    local list = {}
    for _, e in ipairs(entry.room.entities or {}) do
      if valid(e) then
        list[#list + 1] = transaction.clones[key(e)] or e
      end
    end
    entry.room.entities = list
    for _, r in pairs(entry.room.renders or {}) do
      if valid(r) then
        r.destroy()
      end
    end
    entry.room.renders = {}
    entry.room.position = entry.to
    entry.room.architecture_revision = nil
  end
  local ports = storage.twelve and storage.twelve.ports
  if ports then
    local updates = {}
    for unit, port in pairs(ports) do
      local clone = transaction.clones['u' .. unit]
      if valid(clone) then
        port.entity = clone
        updates[#updates + 1] = { old = unit, new = clone.unit_number, port = port }
      end
    end
    for _, v in ipairs(updates) do
      ports[v.old] = nil
      ports[v.new] = v.port
    end
  end
  for _, e in pairs(originals) do
    if valid(e) then
      e.destroy()
    end
  end
  local tiles = {}
  for _, entry in ipairs(entries) do
    for x = entry.from.x - 12, entry.from.x + 11 do
      for y = entry.from.y - 10, entry.from.y + 9 do
        tiles[#tiles + 1] = { name = 'out-of-map', position = { x, y } }
      end
    end
  end
  if #tiles > 0 then
    s.set_tiles(tiles, true)
  end
  f.room_layout_version = 2
  f.room_layout_error = nil
  f.room_revision = (f.room_revision or 0) + 1
  return true
end
function T.cleanup_legacy_wing(f)
  if f.room_layout_version ~= 2 or f.legacy_corridor_cleaned then
    return
  end
  local area = { { 42, -30 }, { 128, 30 } }
  local s = f.surface
  local entities = s.find_entities_filtered({ area = area })
  for _, e in ipairs(entities) do
    if e.name ~= 'tardis-room-relay' then
      return
    end
    for _, id in ipairs({ defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green }) do
      local connector = e.get_wire_connector(id, false)
      if connector and connector.connection_count > 0 then
        return
      end
    end
  end
  local tiles = {}
  for x = 42, 127 do
    for y = -30, 29 do
      local corridor = x <= 113 and y >= -2 and y <= 1
      for _, cx in ipairs({ 56, 84, 112 }) do
        if x >= cx - 2 and x <= cx + 1 and y >= -18 and y <= 18 then
          corridor = true
        end
      end
      if corridor then
        local name = Chunks.name(s, x, y)
        if name == 'tardis-floor' or name == 'tardis-grate-floor' or name == 'refined-hazard-concrete-left' then
          tiles[#tiles + 1] = { name = 'out-of-map', position = { x, y } }
        end
      end
    end
  end
  for _, e in ipairs(entities) do
    e.destroy()
  end
  if #tiles > 0 then
    s.set_tiles(tiles, false)
  end
  f.legacy_corridor_cleaned = true
end
return T
