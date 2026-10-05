local C = require('twelve.config')
local Rooms = require('twelve.rooms')
local Voyage = require('twelve.voyage')
local Circuit = require('twelve.circuit')
local Interior = require('twelve.interior')
local Eye = require('twelve.eye')
local EyeCore = require('twelve.eye-core')
local M =
  { C = C, Rooms = Rooms, Voyage = Voyage, Circuit = Circuit, Interior = Interior, Eye = Eye, EyeCore = EyeCore }
local function root()
  return storage.twelve
end
local function valid(e)
  return e and e.valid
end
local function msg(p, text)
  if p then
    p.print(text)
  end
end
local function protect(e)
  if e then
    e.destructible = false
    e.minable = false
  end
  return e
end
local function inside(p, f)
  return p.physical_surface == f.surface or Eye.is_inside(p, f)
end
M.is_inside = inside
function M.surface_name(s)
  return s.localised_name or (s.planet and s.planet.prototype.localised_name) or s.name
end
function M.get(id)
  return root().ships[tonumber(id)]
end
function M.init()
  storage.twelve = storage.twelve
    or { ships = {}, next_id = 1, ports = {}, players = {}, starters = {}, last_walk = {} }
  for _, f in pairs(storage.twelve.ships) do
    Rooms.init(f)
    Voyage.ensure(f, true)
    Interior.apply(f)
    M.ensure_eye(f)
    M.ensure_decor(f)
    Circuit.create(f)
    f.door_progress = f.door_progress or 0
  end
  for _, p in pairs(game.players) do
    M.starter({ player_index = p.index })
  end
end
function M.starter(e)
  local p = game.get_player(e.player_index)
  if not p then
    return
  end
  if not e.manual and (root().starters[p.index] or not settings.global['tardis-starter'].value) then
    return
  end
  root().starters[p.index] = true
  for _, f in pairs(root().ships) do
    if f.force == p.force then
      return
    end
  end
  root().crashes = root().crashes or {}
  root().crashes[p.force.index] = { tick = game.tick + 300, player = p.index }
end
function M.crash_tick()
  for force_id, record in pairs(root().crashes or {}) do
    if game.tick >= record.tick then
      local p = game.get_player(record.player)
      if p then
        local exists = false
        for _, f in pairs(root().ships) do
          if f.force == p.force then
            exists = true
          end
        end
        if not exists then
          local s = game.surfaces.nauvis
          local origin = p.force.get_spawn_position(s)
          local wreck = s.find_entities_filtered({ name = 'crash-site-spaceship', position = origin, radius = 150 })[1]
          local pos = wreck and wreck.position or origin
          s.request_to_generate_chunks(pos, 1)
          s.force_generate_chunk_requests()
          local at = s.find_non_colliding_position('tardis', { pos.x + 7, pos.y + 4 }, 32, 0.5)
          if at then
            local box = s.create_entity({ name = 'tardis', position = at, force = p.force })
            box.health = box.max_health * 0.32
            local id = M.create(box)
            local f = M.get(id)
            f.voyage.crash_tick = game.tick
            for _, xy in ipairs({ { -2, -1 }, { 2, 2 }, { -3, 2 } }) do
              s.create_entity({
                name = 'crash-site-spaceship-wreck-small-1',
                position = { at.x + xy[1], at.y + xy[2] },
                force = 'neutral',
              })
            end
            s.create_entity({ name = 'big-explosion', position = at })
            p.force.chart(s, { { at.x - 24, at.y - 24 }, { at.x + 24, at.y + 24 } })
            p.force.print({
              '',
              { 'tardis-ship.crash-log' },
              ' [gps=',
              at.x,
              ',',
              at.y,
              ',nauvis]',
            })
            p.insert({ name = 'tardis-input', count = 2 })
            p.insert({ name = 'tardis-output', count = 2 })
          else
            record.tick = game.tick + 300
            return
          end
        end
        root().crashes[force_id] = nil
      end
    end
  end
end
function M.find(p)
  local state = root().players[p.index]
  for _, f in pairs(root().ships) do
    if f.force == p.force and inside(p, f) then
      return f
    end
  end
  if p.selected and p.selected.name == 'tardis-anchor' then
    for _, f in pairs(root().ships) do
      if f.anchor == p.selected and f.force == p.force then
        return f
      end
    end
  end
  if p.selected and p.selected.name == 'tardis' then
    for _, f in pairs(root().ships) do
      if f.box == p.selected and f.force == p.force then
        return f
      end
    end
  end
  if state and M.get(state.ship) and M.get(state.ship).force == p.force then
    return M.get(state.ship)
  end
  for _, f in pairs(root().ships) do
    if f.force == p.force then
      return f
    end
  end
end
function M.total_energy(f)
  local e = f.energy
  for _, k in ipairs({ 'power', 'inner_power', 'eye_power' }) do
    if valid(f[k]) then
      e = e + f[k].energy
    end
  end
  return math.min(C.capacity, e)
end
local function reclaim(f)
  for _, k in ipairs({ 'power', 'inner_power', 'eye_power' }) do
    if valid(f[k]) then
      f.energy = f.energy + f[k].energy
      f[k].energy = 0
    end
  end
  f.energy = math.min(C.capacity, f.energy)
end
local function destroy_outside(f)
  reclaim(f)
  Circuit.destroy(f, true)
  if f.door_visual and f.door_visual.valid then
    f.door_visual.destroy()
  end
  f.door_visual = nil
  f.door_progress = 0
  f.door_hold_until = 0
  for _, k in ipairs({ 'power', 'connector' }) do
    if valid(f[k]) then
      f[k].destroy()
    end
    f[k] = nil
  end
end
local function exterior(f)
  if not valid(f.box) then
    return
  end
  local s = f.box.surface
  local p = f.box.position
  f.power = protect(s.create_entity({ name = 'tardis-power', position = p, force = f.force }))
  local at = s.find_non_colliding_position('tardis-connector', { p.x + 3, p.y - 2 }, 6, 0.5)
  if at then
    f.connector = protect(s.create_entity({ name = 'tardis-connector', position = at, force = f.force }))
  end
  f.door_progress = 0
  Circuit.create(f)
end
function M.door_tick(f)
  if not valid(f.box) then
    return
  end
  local open = not f.flight and (f.door_hold_until or 0) > game.tick
  local b = f.box.position
  if not f.flight then
    for _, p in pairs(game.connected_players) do
      if p.character and p.force == f.force and p.physical_surface == f.box.surface then
        local xy = p.physical_position
        local dx = xy.x - b.x
        local dy = xy.y - b.y
        if math.abs(dx) < 2.5 and dy > 0.3 and dy < 4 then
          open = true
          f.door_hold_until = game.tick + 36
          break
        end
      end
    end
  end
  local before = f.door_progress or 0
  f.door_progress = math.max(0, math.min(1, before + (open and 0.25 or -0.25)))
  if f.door_progress > 0 then
    if not (f.door_visual and f.door_visual.valid) then
      f.door_visual = rendering.draw_sprite({
        sprite = 'tardis-exterior-open',
        surface = f.box.surface,
        target = f.box,
        render_layer = 'higher-object-above',
      })
    end
    f.door_visual.color = { 1, 1, 1, f.door_progress }
    f.door_visual.visible = true
  elseif f.door_visual and f.door_visual.valid then
    f.door_visual.visible = false
  end
end
local function interior(f)
  local s = game.create_surface('tardis12-' .. f.id, {
    width = 1,
    height = 1,
    autoplace_controls = {},
    autoplace_settings = {
      entity = { treat_missing_as_default = false },
      tile = { treat_missing_as_default = false },
      decorative = { treat_missing_as_default = false },
    },
  })
  f.surface = s
  s.freeze_daytime = true
  s.daytime = 0
  s.always_day = true
  s.show_clouds = false
  s.set_property('solar-power', 100)
  s.set_property('pressure', 1000)
  s.set_property('gravity', 10)
  for x = -1, 1 do
    for y = -1, 0 do
      s.set_chunk_generated_status({ x, y }, defines.chunk_generated_status.entities)
    end
  end
  local tiles = {}
  for x = -20, 43 do
    for y = -20, 22 do
      local walk = (x + 0.5) ^ 2 + (y + 0.5) ^ 2 < 14.7 ^ 2
        or (math.abs(x + 0.5) < 1.8 and y >= 12 and y <= 20)
        or (x >= 12 and x <= 23 and math.abs(y + 0.5) < 2)
        or (x >= 21 and x <= 41 and y >= -12 and y <= 12)
      tiles[#tiles + 1] = { name = walk and 'tardis-floor' or 'out-of-map', position = { x, y } }
    end
  end
  s.set_tiles(tiles, true)
  f.art = rendering.draw_sprite({ sprite = 'tardis-room', surface = s, target = { 1.2, 1.65 }, render_layer = 'floor' })
  f.console = protect(s.create_entity({ name = 'tardis-console', position = { 0, 0 }, force = f.force }))
  f.terminal = protect(s.create_entity({ name = 'tardis-terminal', position = { 24, -3 }, force = f.force }))
  f.inner_power = protect(s.create_entity({ name = 'tardis-power', position = { 31, 5 }, force = f.force }))
  f.inner_power.electric_buffer_size = 2e6
  f.inner_connector = protect(s.create_entity({ name = 'tardis-connector', position = { 31, 5 }, force = f.force }))
  f.renders = {
    rendering.draw_text({
      text = { 'tardis-ship.cargo-bay-label' },
      surface = s,
      target = { 30, -10 },
      color = { 0.55, 0.8, 1 },
      scale = 1.1,
      alignment = 'center',
    }),
    rendering.draw_text({
      text = { 'tardis-ship.warehouse-terminal-label' },
      surface = s,
      target = { 24, -5 },
      color = { 1, 0.8, 0.4 },
      scale = 0.8,
      alignment = 'center',
    }),
  }
  for _, xy in ipairs({ { 23, 10 }, { 39, 10 }, { 23, -10 }, { 39, -10 } }) do
    local lamp = s.create_entity({ name = 'small-lamp', position = xy, force = f.force })
    if lamp then
      lamp.always_on = true
    end
  end
  f.force.chart(s, { { -20, -20 }, { 44, 22 } })
end
function M.create(box)
  if not valid(box) or box.name ~= 'tardis' then
    return nil
  end
  for _, f in pairs(root().ships) do
    if f.box == box then
      return f.id
    end
  end
  local id = root().next_id
  root().next_id = id + 1
  local f = {
    id = id,
    force = box.force,
    box = box,
    energy = C.capacity,
    export = true,
    interior_power = true,
    cargo = game.create_inventory(C.base_slots, { 'tardis-ship.cargo-title', id }),
    bookmarks = {},
    jumps = 0,
  }
  root().ships[id] = f
  Voyage.ensure(f, false)
  interior(f)
  exterior(f)
  Rooms.init(f)
  Interior.apply(f)
  M.ensure_eye(f)
  M.ensure_decor(f)
  f.bookmarks[1] =
    { name = { 'tardis-ship.home-bookmark' }, surface = box.surface.index, x = box.position.x, y = box.position.y }
  return id
end
function M.built(e)
  local entity = e.entity
  if not valid(entity) then
    return
  end
  if entity.name == 'tardis-input' or entity.name == 'tardis-output' then
    root().ports[entity.unit_number] = { entity = entity, keep = 0, enabled = true }
    return
  end
  if entity.name ~= 'tardis' then
    return
  end
  local tags = e.tags
  if
    not tags
    and e.consumed_items
    and #e.consumed_items > 0
    and e.consumed_items[1].valid_for_read
    and e.consumed_items[1].is_item_with_tags
  then
    tags = e.consumed_items[1].tags
  end
  local f = tags and M.get(tags.twelve_id)
  if f and f.voyage and f.voyage.returned then
    entity.destroy()
    return -- An old packed token must never recall the Doctor's ship.
  elseif f and f.force == entity.force and not valid(f.box) then
    f.box = entity
    exterior(f)
  else
    M.create(entity)
  end
end
local function pack(entity, buffer, drop)
  for _, f in pairs(root().ships) do
    if f.box == entity then
      if f.flight then
        f.energy = math.min(C.capacity, f.energy + (f.flight.cost or C.jump_cost))
        f.flight = nil
      end
      destroy_outside(f)
      f.last_location = { surface = entity.surface.index, x = entity.position.x, y = entity.position.y }
      local item =
        { name = 'tardis-instantiated', count = 1, quality = entity.quality.name, tags = { twelve_id = f.id } }
      if buffer then
        buffer.clear()
        buffer.insert(item)
      elseif drop then
        entity.surface.spill_item_stack({
          position = entity.position,
          stack = item,
          enable_looted = false,
          allow_belts = false,
        })
      end
      f.box = nil
      return
    end
  end
end
function M.mined(e)
  if e.entity.name == 'tardis' then
    pack(e.entity, e.buffer, false)
  end
  root().ports[e.entity.unit_number or 0] = nil
end
function M.died(e)
  if e.entity.name == 'tardis' then
    pack(e.entity, nil, true)
  end
  root().ports[e.entity.unit_number or 0] = nil
end
function M.surface_deleted(e)
  for _, f in pairs(root().ships) do
    if f.surface.index == e.surface_index then
      for _, p in pairs(game.players) do
        if inside(p, f) then
          local dest = valid(f.box) and f.box.surface or game.surfaces.nauvis
          local origin = valid(f.box) and f.box.position or f.force.get_spawn_position(dest)
          local at = dest.find_non_colliding_position('character', { origin.x, origin.y + 3 }, 64, 0.5)
          if at then
            p.driving = false
            p.teleport(at, dest)
          end
        end
      end
      Rooms.destroy(f)
      Circuit.destroy(f)
      if f.cargo.valid then
        f.cargo.destroy()
      end
      destroy_outside(f)
      if valid(f.box) then
        f.box.destroy()
      end
      root().ships[f.id] = nil
      if valid(f.eye_surface) then
        game.delete_surface(f.eye_surface)
      end
    elseif valid(f.eye_surface) and f.eye_surface.index == e.surface_index then
      Eye.on_surface_deleted(f, e.surface_index)
    elseif valid(f.box) and f.box.surface.index == e.surface_index then
      destroy_outside(f)
      f.box = nil
      f.flight = nil
      f.force.print({ 'tardis-ship.planet-deleted' })
    end
  end
end
function M.enter(index, id)
  local p = game.get_player(index)
  local f = M.get(id)
  if not p or not f or p.force ~= f.force or not p.character or f.flight then
    return false
  end
  local at = f.surface.find_non_colliding_position('character', { 0, 17 }, 3, 0.25)
  if not at then
    return false
  end
  p.driving = false
  local ok = p.teleport(at, f.surface)
  f.door_hold_until = game.tick + 90
  root().last_walk[p.index] = game.tick
  root().players[p.index] = root().players[p.index] or {}
  root().players[p.index].ship = id
  return ok
end
function M.leave(index, id)
  local p = game.get_player(index)
  local f = M.get(id)
  if not p or not f or p.force ~= f.force then
    return false
  end
  if Eye.is_inside(p, f) then
    return M.ascend(index, id)
  end
  if f.flight then
    msg(p, { 'tardis-ship.in-flight-wait' })
    return false
  end
  if not valid(f.box) then
    local loc = f.last_location or { surface = game.surfaces.nauvis.index, x = 0, y = 0 }
    local s = game.get_surface(loc.surface) or game.surfaces.nauvis
    local at = s.find_non_colliding_position('character', { loc.x, loc.y + 2 }, 64, 0.5)
    if not at then
      return false
    end
    root().last_walk[p.index] = game.tick
    return p.teleport(at, s)
  end
  local at =
    f.box.surface.find_non_colliding_position('character', { f.box.position.x, f.box.position.y + 2 }, 12, 0.25)
  if not at then
    return false
  end
  local ok = p.teleport(at, f.box.surface)
  root().last_walk[p.index] = game.tick
  return ok
end
function M.walk(e)
  local p = game.get_player(e.player_index)
  if not p or not p.character or p.driving or game.tick - (root().last_walk[p.index] or -100) < 40 then
    return
  end
  for _, f in pairs(root().ships) do
    if f.force == p.force then
      local xy = p.physical_position
      if Eye.is_inside(p, f) then
        return
      elseif p.physical_surface == f.surface then
        if xy.y > 18.7 and math.abs(xy.x) < 2 then
          M.leave(p.index, f.id)
        end
        return
      elseif valid(f.box) and p.physical_surface == f.box.surface then
        local b = f.box.position
        if
          not f.flight
          and (f.door_progress or 0) >= 0.75
          and math.abs(xy.x - b.x) < 1.05
          and xy.y - b.y > 0.85
          and xy.y - b.y < 1.65
          and p.walking_state.direction == defines.direction.north
        then
          M.enter(p.index, f.id)
          return
        end
      end
    end
  end
end
local function safe_landing(s, pos)
  s.request_to_generate_chunks(pos, 2)
  s.force_generate_chunk_requests()
  local at = s.find_non_colliding_position('tardis', pos, 64, 1)
  if not at then
    return nil
  end
  if not s.find_non_colliding_position('character', { at.x, at.y + 2 }, 6, 0.5) then
    return nil
  end
  return at
end
function M.jump(id, surface_id, x, y)
  local f = M.get(id)
  local s = game.get_surface(surface_id)
  if not f or not s then
    return false, { 'tardis-ship.no-destination' }
  end
  if s.name:sub(1, 9) == 'tardis12-' or s.platform then
    return false, { 'tardis-ship.pick-planet' }
  end
  if f.flight then
    return false, { 'tardis-ship.already-in-flight' }
  end
  if not valid(f.box) then
    return false, { 'tardis-ship.place-box-first' }
  end
  if f.circuit and f.circuit.inhibit then
    return false, { 'tardis-ship.jumps-inhibited' }
  end
  local quote = Voyage.quote(f, s)
  if not quote.ok then
    return false, quote.error
  end
  x = tonumber(x) or 0
  y = tonumber(y) or 0
  if math.abs(x) > 100000 or math.abs(y) > 100000 then
    return false, { 'tardis-ship.coords-out-of-range' }
  end
  local at = safe_landing(s, { x, y })
  if not at then
    return false, { 'tardis-ship.no-safe-landing' }
  end
  reclaim(f)
  f.energy = f.energy - quote.cost
  f.flight = {
    until_tick = game.tick + C.flight_ticks,
    surface = s.index,
    x = at.x,
    y = at.y,
    cost = quote.cost,
    distance = quote.distance,
  }
  f.box.minable = false
  f.surface.play_sound({ path = 'tardis-teleportation', position = { 0, 0 }, volume_modifier = 0.45 })
  f.box.surface.play_sound({ path = 'tardis-teleportation', position = f.box.position, volume_modifier = 0.45 })
  rendering.draw_circle({
    color = { 0.3, 0.65, 1, 0.65 },
    radius = 2.4,
    width = 4,
    filled = false,
    surface = f.box.surface,
    target = f.box,
    time_to_live = C.flight_ticks,
  })
  return true, { 'tardis-ship.dematerialising' }
end
local function finish(f)
  local t = f.flight
  local s = game.get_surface(t.surface)
  local at = s and s.find_non_colliding_position('tardis', { t.x, t.y }, 64, 1)
  if not at or not valid(f.box) then
    reclaim(f)
    f.energy = math.min(C.capacity, f.energy + (f.flight.cost or C.jump_cost))
    f.flight = nil
    if valid(f.box) then
      f.box.minable = true
    end
    f.force.print({ 'tardis-ship.landing-cancelled' })
    return
  end
  local old = f.box
  local new = s.create_entity({
    name = 'tardis',
    position = at,
    force = f.force,
    quality = old.quality,
    create_build_effect_smoke = false,
  })
  if not new then
    f.flight.until_tick = game.tick + 60
    return
  end
  new.health = old.health
  f.previous = { surface = old.surface.index, x = old.position.x, y = old.position.y }
  destroy_outside(f)
  old.destroy()
  f.box = new
  exterior(f)
  f.flight = nil
  f.jumps = f.jumps + 1
  f.force.chart(s, { { at.x - 32, at.y - 32 }, { at.x + 32, at.y + 32 } })
  s.play_sound({ path = 'tardis-teleport-complete', position = at, volume_modifier = 0.5 })
  f.force.print({
    '',
    { 'tardis-ship.materialised', M.surface_name(s) },
    ' [gps=',
    at.x,
    ',',
    at.y,
    ',',
    s.name,
    ']',
  })
end
function M.recall(p, f)
  if p.force ~= f.force or inside(p, f) then
    return false, { 'tardis-ship.recall-outside-only' }
  end
  if valid(f.box) then
    return M.jump(f.id, p.physical_surface.index, p.physical_position.x + 4, p.physical_position.y)
  end
  if f.flight then
    return false, { 'tardis-ship.in-flight' }
  end
  if f.voyage.returned then
    return false, { 'tardis-ship.returned-to-doctor' }
  end
  local quote = Voyage.quote(f, p.physical_surface)
  if not quote.ok then
    return false, quote.error
  end
  if f.circuit and f.circuit.inhibit then
    return false, { 'tardis-ship.jumps-inhibited' }
  end
  local at = safe_landing(p.physical_surface, { p.physical_position.x + 4, p.physical_position.y })
  if not at then
    return false, { 'tardis-ship.no-safe-pad' }
  end
  reclaim(f)
  f.energy = f.energy - quote.cost
  f.box = p.physical_surface.create_entity({ name = 'tardis', position = at, force = f.force })
  exterior(f)
  return true, { 'tardis-ship.recalled' }
end
-- Native stack-to-stack transfers preserve tags, armor grids, durability and spoilage.
-- No item is removed until Factorio has accepted it into the destination.
function M.move(source, dest, filter, limit)
  if not source or not source.valid or not dest or not dest.valid or source == dest then
    return 0
  end
  limit = limit or 1e9
  local moved = 0
  for i = 1, #source do
    local a = source[i]
    if
      a.valid_for_read
      and (not filter or (a.name == filter.name and (not filter.quality or a.quality.name == filter.quality)))
    then
      for pass = 1, 2 do
        for j = 1, #dest do
          if not a.valid_for_read or moved >= limit then
            break
          end
          local b = dest[j]
          if
            (
              pass == 1
              and b.valid_for_read
              and b.name == a.name
              and b.quality == a.quality
              and b.count < b.prototype.stack_size
            ) or (pass == 2 and not b.valid_for_read)
          then
            local before = a.count
            b.transfer_stack(a, math.min(before, limit - moved))
            moved = moved + before - (a.valid_for_read and a.count or 0)
          end
        end
      end
    end
    if moved >= limit then
      break
    end
  end
  return moved
end
function M.upgrade(id)
  local f = M.get(id)
  if not f then
    return false
  end
  if #f.cargo >= C.max_slots then
    return false
  end
  f.cargo.resize(math.min(C.max_slots, #f.cargo * 2))
  return true
end
function M.build_room(index, id, slot, kind)
  local f = M.get(id)
  if not f then
    return false, { 'tardis-ship.ship-not-found' }
  end
  return Rooms.request(game.get_player(index), f, slot, kind, M.move)
end
function M.cancel_room(index, id, slot)
  local f = M.get(id)
  if not f then
    return false, { 'tardis-ship.ship-not-found' }
  end
  return Rooms.cancel(game.get_player(index), f, tonumber(slot), M.move)
end
function M.configure_port(unit, filter, keep, enabled)
  local p = root().ports[unit]
  if not p or not valid(p.entity) then
    return false
  end
  if filter and not prototypes.item[filter.name] then
    return false
  end
  p.filter = filter
  p.keep = math.max(0, math.floor(tonumber(keep) or 0))
  p.enabled = enabled ~= false
  return true
end
function M.port_ship(port)
  if not valid(port.entity) then
    return nil
  end
  -- Interior docks feed the mobile factory from the same dimensional inventory,
  -- even while the exterior is dematerialised. No proximity limit inside a ship.
  for _, f in pairs(root().ships) do
    if f.force == port.entity.force and (f.surface == port.entity.surface or f.eye_surface == port.entity.surface) then
      return f
    end
  end
  local best, dist = nil, C.port_radius ^ 2
  for _, f in pairs(root().ships) do
    if not f.flight and valid(f.box) and f.force == port.entity.force and f.box.surface == port.entity.surface then
      local a = f.box.position
      local b = port.entity.position
      local d = (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2
      if d < dist or (d == dist and (not best or f.id < best.id)) then
        best = f
        dist = d
      end
    end
  end
  return best
end
function M.ports_tick()
  for id, p in pairs(root().ports) do
    if not valid(p.entity) then
      root().ports[id] = nil
    elseif p.enabled then
      local f = M.port_ship(p)
      p.ship = f and f.id or nil
      if f then
        local inv = p.entity.get_inventory(defines.inventory.chest)
        if p.entity.name == 'tardis-input' then
          M.move(inv, f.cargo, p.filter, C.port_rate)
        elseif p.filter then
          local available = f.cargo.get_item_count(p.filter) - p.keep
          if available > 0 then
            M.move(f.cargo, inv, p.filter, math.min(C.port_rate, available))
          end
        end
      end
    end
  end
end
function M.tick()
  M.crash_tick()
  for _, f in pairs(root().ships) do
    M.door_tick(f)
  end
  -- The position event alone can miss a doorway before character collision stops motion.
  for _, p in pairs(game.connected_players) do
    M.walk({ player_index = p.index })
  end
  for _, f in pairs(root().ships) do
    local before = M.total_energy(f)
    -- Both decks share one 20 MW allowance. Measure actual native consumption
    -- before reclaiming buffers, then bias the next grant toward the busy deck.
    local main_used = valid(f.inner_power) and math.max(10000, (f.inner_allocated or 0) - f.inner_power.energy) or 0
    local eye_used = valid(f.eye_power) and math.max(10000, (f.eye_allocated or 0) - f.eye_power.energy) or 0
    reclaim(f)
    f.energy = math.min(C.capacity, f.energy + Voyage.recharge(f) * C.step / 60)
    if f.flight and game.tick >= f.flight.until_tick then
      finish(f)
    end
    if valid(f.power) and f.export and not f.flight then
      local n = math.min(f.energy, C.buffer)
      f.power.energy = n
      f.energy = f.energy - n
    end
    f.inner_allocated = 0
    f.eye_allocated = 0
    if f.interior_power then
      local budget = math.min(f.energy, 2e6)
      local total = main_used + eye_used
      if total > 0 then
        local main = budget * main_used / total
        local lower = budget - main
        if valid(f.inner_power) then
          f.inner_power.energy = main
          f.inner_allocated = main
        end
        if valid(f.eye_power) then
          f.eye_power.energy = lower
          f.eye_allocated = lower
        end
        f.energy = f.energy - budget
      end
    end
    Eye.tick(f)
    f.net_mw = (M.total_energy(f) - (f.last_energy or before)) / (C.step / 60) / 1e6
    f.last_energy = M.total_energy(f)
    if game.tick % 30 == 0 then
      Rooms.tick(f, M.move)
      Circuit.tick(f, M)
    end
  end
  if game.tick % 30 == 0 then
    M.ports_tick()
  end
end
function M.status(id)
  local f = M.get(id)
  if not f then
    return nil
  end
  return {
    id = f.id,
    energy = M.total_energy(f),
    capacity = C.capacity,
    slots = #f.cargo,
    contents = f.cargo.get_contents(),
    surface = valid(f.box) and f.box.surface.name or 'packed',
    interior = f.surface.name,
    jumps = f.jumps,
    flight = f.flight ~= nil,
    export = f.export,
    position = valid(f.box) and f.box.position or nil,
    rooms = Rooms.count(f),
    door_open = (f.door_progress or 0) >= 0.75,
    voyage = Voyage.info(f),
    eye_interior = valid(f.eye_surface) and f.eye_surface.name,
    eye_modules = EyeCore.ensure(f).modules,
    circuit_error = f.circuit and f.circuit.last_error,
  }
end
function M.demo(p)
  local at = p.physical_surface.find_non_colliding_position(
    'tardis',
    { p.physical_position.x + 5, p.physical_position.y },
    20,
    0.5
  )
  if not at then
    return
  end
  local box = p.physical_surface.create_entity({ name = 'tardis', position = at, force = p.force })
  local id = M.create(box)
  local f = M.get(id)
  f.voyage.console = true
  f.voyage.eye = true
  f.voyage.message = true
  f.energy = C.capacity
  for _, key in ipairs(EyeCore.order) do
    EyeCore.ensure(f).modules[key] = true
  end
  f.cargo.insert({ name = 'iron-plate', count = 20000 })
  f.cargo.insert({ name = 'copper-plate', count = 10000 })
  f.cargo.insert({ name = 'processing-unit', count = 1000, quality = 'legendary' })
  f.cargo.insert({ name = 'steel-plate', count = 5000 })
  f.cargo.insert({ name = 'construction-robot', count = 50 })
  for _, name in ipairs({ 'vulcanus', 'fulgora', 'gleba', 'aquilo' }) do
    local tech = p.force.technologies['planet-discovery-' .. name]
    if tech then
      tech.researched = true
    end
    p.force.unlock_space_location(name)
  end
  for i, name in ipairs({ 'tardis-input', 'tardis-output' }) do
    local e = p.physical_surface.create_entity({
      name = name,
      position = { at.x + (i == 1 and -3 or 3), at.y + 1 },
      force = p.force,
    })
    M.built({ entity = e })
    if i == 2 then
      M.configure_port(e.unit_number, { name = 'iron-plate', quality = 'normal' }, 1000, true)
    end
  end
  p.insert({ name = 'steel-chest', count = 30 })
  p.insert({ name = 'assembling-machine-2', count = 10 })
  p.insert({ name = 'small-lamp', count = 30 })
  M.enter(p.index, id)
end
function M.ensure_decor(f)
  if not (f.rim and f.rim.valid) then
    f.rim = rendering.draw_sprite({
      sprite = 'tardis-circular-rim',
      surface = f.surface,
      target = { 0, 0 },
      render_layer = 'floor',
    })
  end
  for _, e in
    pairs(f.surface.find_entities_filtered({ name = 'tardis-roundel-wall', area = { { -15, -15 }, { 15, 15 } } }))
  do
    e.destroy()
  end
  if not f.rim_colliders then
    f.rim_colliders = {}
    for x = -15, 14 do
      for y = -15, 14 do
        local xx, yy = x + 0.5, y + 0.5
        local r = math.sqrt(xx * xx + yy * yy)
        local gate = math.abs(xx) < 2.1 or math.abs(yy) < 2.1
        if
          r > 13.3
          and r < 14.4
          and not gate
          and f.surface.can_place_entity({ name = 'tardis-rim-collider', position = { xx, yy }, force = f.force })
        then
          f.rim_colliders[#f.rim_colliders + 1] =
            protect(f.surface.create_entity({ name = 'tardis-rim-collider', position = { xx, yy }, force = f.force }))
        end
      end
    end
  end
  if not valid(f.exit_entity) then
    f.exit_entity = protect(f.surface.create_entity({ name = 'tardis-exit', position = { 0, 20 }, force = f.force }))
    f.exit_label = rendering.draw_text({
      text = { 'tardis-ship.exit-label' },
      surface = f.surface,
      target = { 0, 15.5 },
      color = { 1, 0.83, 0.43 },
      scale = 1.15,
      alignment = 'center',
    })
  end
end
function M.relayout(index, id)
  local p = game.get_player(index)
  local f = M.get(id)
  if not p or not f or p.force ~= f.force or not inside(p, f) then
    return false, { 'tardis-ship.relayout-console-only' }
  end
  if f.flight then
    return false, { 'tardis-ship.wait-flight-end' }
  end
  Interior.apply(f)
  M.ensure_decor(f)
  return f.room_layout_version == 2,
    f.room_layout_version == 2 and { 'tardis-ship.rooms-connected' } or f.room_layout_error
end
function M.ensure_eye(f)
  -- The legacy decorative container might have been fed by an inserter. M.move
  -- preserves quality, tags and equipment; a full cargo hold leaves it intact.
  if valid(f.eye_entity) then
    local inv = f.eye_entity.get_inventory(defines.inventory.chest)
    if inv and inv.valid then
      M.move(inv, f.cargo, nil, 1e9)
    end
  end
  return Eye.ensure(f)
end
local function near_hatch(p, entity)
  if not valid(p and p.character) or not valid(entity) or p.physical_surface ~= entity.surface then
    return false
  end
  local a, b = p.physical_position, entity.position
  return (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 <= 16
end
function M.descend(index, id)
  local p = game.get_player(index)
  local f = M.get(id)
  if not p or not f or p.force ~= f.force then
    return false, { 'tardis-ship.ship-not-found' }
  end
  M.ensure_eye(f)
  if not near_hatch(p, f.eye_room and f.eye_room.hatch) then
    return false, { 'tardis-ship.approach-hatch' }
  end
  local ok, why = Eye.enter(p, f)
  if ok then
    root().last_walk[p.index] = game.tick
    root().players[p.index] = root().players[p.index] or {}
    root().players[p.index].ship = id
  end
  return ok, why
end
function M.ascend(index, id)
  local p = game.get_player(index)
  local f = M.get(id)
  if not p or not f or p.force ~= f.force then
    return false, { 'tardis-ship.ship-not-found' }
  end
  if not near_hatch(p, f.eye_room and f.eye_room.ladder) then
    return false, { 'tardis-ship.approach-ladder' }
  end
  local ok, why = Eye.leave(p, f)
  if ok then
    root().last_walk[p.index] = game.tick
  end
  return ok, why
end
function M.repair_eye(index, id, key)
  local f = M.get(id)
  if not f then
    return false, { 'tardis-ship.ship-not-found' }
  end
  local ok, why = EyeCore.repair(game.get_player(index), f, key)
  if ok then
    if valid(f.box) then
      f.box.health = f.box.max_health * (f.voyage.stabilizer and 1 or f.voyage.eye and 0.85 or 0.55)
    end
    Eye.tick(f)
  end
  return ok, why
end
function M.jump_ready(f)
  return Voyage.can_fly(f) and M.total_energy(f) >= Voyage.base_cost
end
function M.repair(index, id, key)
  local f = M.get(id)
  if not f then
    return false, { 'tardis-ship.ship-not-found' }
  end
  local ok, why = Voyage.repair(game.get_player(index), f, key)
  if ok and valid(f.box) then
    f.box.health = f.box.max_health * (f.voyage.stabilizer and 1 or f.voyage.eye and 0.85 or 0.55)
  end
  return ok, why
end
function M.return_doctor(index, id)
  local p = game.get_player(index)
  local f = M.get(id)
  if not p or not f or p.force ~= f.force then
    return false, { 'tardis-ship.ship-not-found' }
  end
  if not inside(p, f) then
    return false, { 'tardis-ship.return-inside-only' }
  end
  local ok, why = Voyage.return_ready(f)
  if not ok then
    return false, why
  end
  -- The dimensional factory stays accessible after the story. No inventory/entity
  -- is serialized or destroyed, including offline players and machines mid-craft.
  local nauvis = game.surfaces.nauvis
  local home = f.force.get_spawn_position(nauvis)
  nauvis.request_to_generate_chunks(home, 1)
  nauvis.force_generate_chunk_requests()
  local at = nauvis.find_non_colliding_position('tardis-anchor', { home.x + 5, home.y }, 32, 0.5)
  if not at then
    return false, { 'tardis-ship.anchor-no-room' }
  end
  local anchor = protect(nauvis.create_entity({ name = 'tardis-anchor', position = at, force = f.force }))
  if not anchor then
    return false, { 'tardis-ship.anchor-failed' }
  end
  local old = f.box
  local dest = old.surface
  local b = old.position
  local passengers = {}
  for _, crew in pairs(game.players) do
    local xy = crew.physical_position
    local near = crew.physical_surface == dest and (xy.x - b.x) ^ 2 + (xy.y - b.y) ^ 2 < 32 ^ 2
    if crew.force == f.force and (inside(crew, f) or near) then
      passengers[#passengers + 1] = { player = crew, surface = crew.physical_surface, position = xy }
    end
  end
  for i, record in ipairs(passengers) do
    local safe =
      nauvis.find_non_colliding_position('character', { at.x + (i % 4) * 2, at.y + 3 + math.floor(i / 4) * 2 }, 32, 0.5)
    if not safe or not record.player.teleport(safe, nauvis) then
      for _, previous in ipairs(passengers) do
        previous.player.teleport(previous.position, previous.surface)
      end
      anchor.destroy()
      return false, { 'tardis-ship.evacuation-failed' }
    end
  end
  ok, why = Voyage.mark_returned(f)
  if not ok then
    anchor.destroy()
    return ok, why
  end
  reclaim(f)
  f.energy = math.max(0, f.energy - Voyage.return_cost)
  f.export = false
  destroy_outside(f)
  old.destroy()
  f.box = nil
  f.anchor = anchor
  f.last_location = { surface = nauvis.index, x = at.x, y = at.y }
  M.ensure_eye(f)
  f.force.chart(nauvis, { { at.x - 24, at.y - 24 }, { at.x + 24, at.y + 24 } })
  f.force.print({
    '',
    { 'tardis-ship.anchor-left' },
    ' [gps=',
    at.x,
    ',',
    at.y,
    ',nauvis]',
  })
  return true, why
end
return M
