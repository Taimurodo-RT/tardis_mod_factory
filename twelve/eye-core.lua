-- Persistent repair state for the four physical Eye of Harmony machines.
-- Repair authority is the player's actual character, surface and distance to a
-- registered module entity; opening the remote console never grants access.
local Core = { range = 6, order = { 'containment', 'collector_a', 'collector_b', 'converter' } }
Core.plans = {
  containment = {
    title = { 'tardis-eye.containment-title' },
    icon = 'nuclear-reactor',
    bearing = { 'tardis-eye.bearing-north' },
    description = { 'tardis-eye.containment-description' },
    cost = {
      { name = 'steel-plate', count = 80 },
      { name = 'advanced-circuit', count = 20 },
      { name = 'battery', count = 40 },
      { name = 'processing-unit', count = 5 },
    },
  },
  collector_a = {
    title = { 'tardis-eye.collector-a-title' },
    icon = 'heat-exchanger',
    bearing = { 'tardis-eye.bearing-west' },
    previous = { 'containment' },
    description = { 'tardis-eye.collector-a-description' },
    cost = {
      { name = 'steel-plate', count = 40 },
      { name = 'advanced-circuit', count = 30 },
      { name = 'battery', count = 20 },
      { name = 'processing-unit', count = 5 },
    },
  },
  collector_b = {
    title = { 'tardis-eye.collector-b-title' },
    icon = 'heat-exchanger',
    bearing = { 'tardis-eye.bearing-east' },
    previous = { 'containment' },
    description = { 'tardis-eye.collector-b-description' },
    cost = {
      { name = 'steel-plate', count = 40 },
      { name = 'advanced-circuit', count = 30 },
      { name = 'battery', count = 20 },
      { name = 'processing-unit', count = 5 },
    },
  },
  converter = {
    title = { 'tardis-eye.converter-title' },
    icon = 'substation',
    bearing = { 'tardis-eye.bearing-south' },
    previous = { 'collector_a', 'collector_b' },
    description = { 'tardis-eye.converter-description' },
    cost = {
      { name = 'steel-plate', count = 40 },
      { name = 'advanced-circuit', count = 20 },
      { name = 'battery', count = 20 },
      { name = 'processing-unit', count = 5 },
    },
  },
}
local function valid(e)
  return e and e.valid
end
function Core.ensure(f)
  if not f.eye_core then
    local legacy = f.voyage and f.voyage.eye == true
    f.eye_core = { modules = {}, revision = 1 }
    for _, key in ipairs(Core.order) do
      f.eye_core.modules[key] = legacy
    end
  end
  local state = f.eye_core
  state.modules = state.modules or {}
  state.revision = state.revision or 1
  local complete = true
  for _, key in ipairs(Core.order) do
    state.modules[key] = state.modules[key] == true
    complete = complete and state.modules[key]
  end
  if f.voyage then
    f.voyage.eye = complete
  end
  return state
end
function Core.count(f)
  local state = Core.ensure(f)
  local n = 0
  for _, key in ipairs(Core.order) do
    if state.modules[key] then
      n = n + 1
    end
  end
  return n
end
function Core.complete(f)
  return Core.count(f) == #Core.order
end
function Core.recharge(f)
  local m = Core.ensure(f).modules
  if (f.voyage and f.voyage.returned) or not m.containment then
    return 0
  end
  local watts = (m.collector_a and 20e6 or 0) + (m.collector_b and 20e6 or 0)
  if m.collector_a and m.collector_b and m.converter then
    watts = watts + 10e6
  end
  return watts
end
function Core.near(player, f, key)
  if not Core.plans[key] then
    return false, { 'tardis-eye.select-machine' }
  end
  if not player or not player.valid or player.force ~= f.force then
    return false, { 'tardis-eye.other-team-machine' }
  end
  if not valid(player.character) then
    return false, { 'tardis-eye.need-character' }
  end
  if not valid(f.eye_surface) or player.physical_surface ~= f.eye_surface then
    return false, { 'tardis-eye.go-down-hatch' }
  end
  local entity = f.eye_modules and f.eye_modules[key]
  if not valid(entity) or entity.surface ~= f.eye_surface or entity.force ~= f.force then
    return false, { 'tardis-eye.machine-unavailable' }
  end
  local p, b = player.physical_position, entity.position
  if (p.x - b.x) ^ 2 + (p.y - b.y) ^ 2 > Core.range ^ 2 then
    return false, { 'tardis-eye.move-closer' }
  end
  return true
end
function Core.missing(f, key)
  local plan = Core.plans[key]
  if not plan then
    return nil
  end
  local missing = {}
  for _, item in ipairs(plan.cost) do
    local count = f.cargo.get_item_count({ name = item.name, quality = 'normal' })
    if count < item.count then
      missing[#missing + 1] = { name = item.name, count = item.count - count }
    end
  end
  return missing
end
function Core.repair_ready(f, key, player)
  local state = Core.ensure(f)
  local plan = Core.plans[key]
  if not plan then
    return false, { 'tardis-eye.select-machine' }
  end
  if player then
    local near, reason = Core.near(player, f, key)
    if not near then
      return false, reason
    end
  end
  if not f.voyage or not f.voyage.console then
    return false, { 'tardis-eye.need-console' }
  end
  if f.voyage.returned then
    return false, { 'tardis-eye.eye-returned' }
  end
  if f.flight then
    return false, { 'tardis-eye.wait-flight' }
  end
  if state.modules[key] then
    return false, { 'tardis-eye.already-restored' }
  end
  local tech = f.force.technologies['chemical-science-pack']
  if not tech or not tech.researched then
    return false, { 'tardis-eye.need-chemical-science' }
  end
  for _, previous in ipairs(plan.previous or {}) do
    if not state.modules[previous] then
      return false, { 'tardis-eye.need-previous', Core.plans[previous].title }
    end
  end
  if #Core.missing(f, key) > 0 then
    return false, { 'tardis-eye.not-enough-materials' }
  end
  return true
end
function Core.repair(player, f, key)
  local near, reason = Core.near(player, f, key)
  if not near then
    return false, reason
  end
  local ready, why = Core.repair_ready(f, key, player)
  if not ready then
    return false, why
  end
  -- All normal-quality counts are checked before this atomic event removes any.
  for _, item in ipairs(Core.plans[key].cost) do
    local removed = f.cargo.remove({ name = item.name, count = item.count, quality = 'normal' })
    assert(removed == item.count, 'Eye repair payment changed during an atomic event')
  end
  local state = f.eye_core
  state.modules[key] = true
  state.revision = state.revision + 1
  Core.ensure(f)
  f.voyage.revision = (f.voyage.revision or 0) + 1
  local message = {
    f.voyage.eye and 'tardis-eye.repaired-all' or 'tardis-eye.repaired',
    Core.plans[key].title,
    tostring(math.floor(Core.recharge(f) / 1e6)),
  }
  return true, message
end
return Core
