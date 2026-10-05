local Interior = require('twelve.interior')
local R = { build_ticks = 600, max_rooms = 6, parents = { [3] = 1, [4] = 1, [5] = 2, [6] = 2 } }
R.order = { 'workshop', 'vault', 'library' }
R.plans = {
  workshop = {
    title = { 'tardis-interior.room-workshop-title' },
    icon = 'assembling-machine-2',
    subtitle = { 'tardis-interior.room-workshop-subtitle' },
    description = { 'tardis-interior.room-workshop-description' },
    cost = {
      { name = 'iron-plate', count = 400 },
      { name = 'steel-plate', count = 200 },
      { name = 'copper-plate', count = 200 },
      { name = 'electronic-circuit', count = 50 },
    },
  },
  vault = {
    title = { 'tardis-interior.room-vault-title' },
    icon = 'steel-chest',
    subtitle = { 'tardis-interior.room-vault-subtitle' },
    description = { 'tardis-interior.room-vault-description' },
    slots = 4096,
    cost = {
      { name = 'iron-plate', count = 250 },
      { name = 'steel-plate', count = 150 },
      {
        name = 'electronic-circuit',
        count = 100,
      },
    },
  },
  library = {
    title = { 'tardis-interior.room-library-title' },
    icon = 'wood',
    subtitle = { 'tardis-interior.room-library-subtitle' },
    description = { 'tardis-interior.room-library-description' },
    cost = {
      { name = 'wood', count = 150 },
      { name = 'steel-plate', count = 50 },
      { name = 'copper-plate', count = 100 },
      { name = 'electronic-circuit', count = 25 },
    },
  },
}
function R.init(f)
  f.rooms = f.rooms or {}
  f.room_renders = f.room_renders or {}
  f.room_revision = f.room_revision or 0
  if not f.room_layout_version and not next(f.rooms) then
    f.room_layout_version = 2
  end
end
function R.position(slot, f)
  return Interior.position(slot, f)
end
function R.parent(slot)
  return R.parents[tonumber(slot)]
end
function R.count(f)
  local n = 0
  for _, v in pairs(f.rooms or {}) do
    if v.state == 'ready' then
      n = n + 1
    end
  end
  return n
end
function R.missing(f, kind)
  local plan = R.plans[kind]
  if not plan then
    return nil
  end
  local missing = {}
  for _, v in ipairs(plan.cost) do
    local have = f.cargo.get_item_count({ name = v.name, quality = 'normal' })
    if have < v.count then
      missing[#missing + 1] = { name = v.name, count = v.count - have }
    end
  end
  return missing
end
local function floor_available(f, slot)
  local p = R.position(slot, f)
  for x = p.x - 12, p.x + 11 do
    for y = p.y - 10, p.y + 9 do
      local name = Interior.tile_name(f.surface, x, y)
      if
        name ~= 'out-of-map'
        and not (f.room_corridor_tiles and f.room_corridor_tiles[x .. ':' .. y] and name == 'tardis-grate-floor')
      then
        return false
      end
    end
  end
  return true
end
function R.available(f, slot)
  slot = tonumber(slot)
  if not f or not slot or slot % 1 ~= 0 or slot < 1 or slot > R.max_rooms then
    return false, { 'tardis-interior.choose-compartment' }
  end
  if f.rooms and f.rooms[slot] then
    return false, { 'tardis-interior.compartment-occupied' }
  end
  local parent = R.parents[slot]
  if f.room_layout_version ~= 1 and parent and not (f.rooms[parent] and f.rooms[parent].state == 'ready') then
    return false, { 'tardis-interior.build-parent-first', parent }
  end
  if not floor_available(f, slot) then
    return false, { 'tardis-interior.room-site-blocked' }
  end
  return true
end
function R.request(p, f, slot, kind, move)
  R.init(f)
  slot = tonumber(slot)
  if not p or p.force ~= f.force or (p.physical_surface ~= f.surface and p.physical_surface ~= f.eye_surface) then
    return false, { 'tardis-interior.build-from-inside' }
  end
  if not slot or slot % 1 ~= 0 or slot < 1 or slot > R.max_rooms or not R.plans[kind] then
    return false, { 'tardis-interior.choose-free-compartment' }
  end
  local available, why = R.available(f, slot)
  if not available then
    return false, why
  end
  local plan = R.plans[kind]
  if #R.missing(f, kind) > 0 then
    return false, { 'tardis-interior.not-enough-materials' }
  end
  local reserved = 0
  for _, v in pairs(f.rooms) do
    if v.state == 'building' then
      reserved = reserved + (R.plans[v.kind].slots or 0)
    end
  end
  if plan.slots and #f.cargo + reserved >= 32768 then
    return false, { 'tardis-interior.warehouse-full' }
  end
  -- Move only ordinary construction materials to persistent escrow. The event is atomic.
  local slots = 0
  for _, cost in ipairs(plan.cost) do
    slots = slots + math.ceil(cost.count / prototypes.item[cost.name].stack_size)
  end
  local escrow = game.create_inventory(slots)
  for _, cost in ipairs(plan.cost) do
    assert(
      move(f.cargo, escrow, { name = cost.name, quality = 'normal' }, cost.count) == cost.count,
      'Room material reservation failed'
    )
  end
  f.rooms[slot] =
    { kind = kind, state = 'building', started = game.tick, finish = game.tick + R.build_ticks, escrow = escrow }
  f.room_revision = f.room_revision + 1
  return true, { 'tardis-interior.room-forming' }
end
function R.cancel(p, f, slot, move)
  local room = f.rooms and f.rooms[slot]
  if
    not p
    or p.force ~= f.force
    or (p.physical_surface ~= f.surface and p.physical_surface ~= f.eye_surface)
    or not room
    or room.state ~= 'building'
  then
    return false, { 'tardis-interior.cancel-only-building' }
  end
  move(room.escrow, f.cargo)
  if not room.escrow.is_empty() then
    room.state = 'refund'
    room.finish = nil
    f.room_revision = f.room_revision + 1
    return true, { 'tardis-interior.cancel-refund-pending' }
  end
  room.escrow.destroy()
  f.rooms[slot] = nil
  f.room_revision = f.room_revision + 1
  return true, { 'tardis-interior.cancel-refunded' }
end
local function construct(f, slot, room)
  local p = R.position(slot, f)
  local s = f.surface
  Interior.room(f, slot, room, false)
  if R.plans[room.kind].slots then
    local before = #f.cargo
    f.cargo.resize(math.min(32768, before + R.plans[room.kind].slots))
    room.added_slots = #f.cargo - before
  end
  room.escrow.destroy()
  room.escrow = nil
  room.state = 'ready'
  room.finish = nil
  f.force.chart(s, { { p.x - 13, p.y - 11 }, { p.x + 13, p.y + 11 } })
  f.room_revision = f.room_revision + 1
  f.force.print({ 'tardis-interior.room-ready', slot, R.plans[room.kind].title })
end
function R.tick(f, move)
  R.init(f)
  for slot, room in pairs(f.rooms) do
    if room.state == 'building' and game.tick >= room.finish then
      construct(f, slot, room)
    elseif room.state == 'refund' then
      move(room.escrow, f.cargo)
      if room.escrow.is_empty() then
        room.escrow.destroy()
        f.rooms[slot] = nil
        f.room_revision = f.room_revision + 1
      end
    end
  end
end
function R.destroy(f)
  for _, v in pairs(f.rooms or {}) do
    if v.escrow and v.escrow.valid then
      v.escrow.destroy()
    end
  end
end
return R
