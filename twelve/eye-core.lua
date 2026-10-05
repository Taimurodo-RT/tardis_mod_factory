-- Persistent repair state for the four physical Eye of Harmony machines.
-- Repair authority is the player's actual character, surface and distance to a
-- registered module entity; opening the remote console never grants access.
local Core = { range = 6, order = { 'containment', 'collector_a', 'collector_b', 'converter' } }
Core.plans = {
  containment = {
    title = 'Контур удержания',
    icon = 'nuclear-reactor',
    bearing = 'Север',
    description = 'Стабилизирует звезду. Сам не вырабатывает энергию; открывает ремонт двух коллекторов.',
    cost = {
      { name = 'steel-plate', count = 80 },
      { name = 'advanced-circuit', count = 20 },
      { name = 'battery', count = 40 },
      { name = 'processing-unit', count = 5 },
    },
  },
  collector_a = {
    title = 'Коллектор A',
    icon = 'heat-exchanger',
    bearing = 'Запад',
    previous = { 'containment' },
    description = 'Собирает излучение удерживаемой звезды. Исправный коллектор добавляет 20 МВт.',
    cost = {
      { name = 'steel-plate', count = 40 },
      { name = 'advanced-circuit', count = 30 },
      { name = 'battery', count = 20 },
      { name = 'processing-unit', count = 5 },
    },
  },
  collector_b = {
    title = 'Коллектор B',
    icon = 'heat-exchanger',
    bearing = 'Восток',
    previous = { 'containment' },
    description = 'Второй независимый канал съёма энергии. Исправный коллектор добавляет ещё 20 МВт.',
    cost = {
      { name = 'steel-plate', count = 40 },
      { name = 'advanced-circuit', count = 30 },
      { name = 'battery', count = 20 },
      { name = 'processing-unit', count = 5 },
    },
  },
  converter = {
    title = 'Преобразователь',
    icon = 'substation',
    bearing = 'Юг',
    previous = { 'collector_a', 'collector_b' },
    description = 'Согласует два канала с общим резервом. Добавляет 10 МВт, доводит отдачу до 50 МВт и разрешает полёт.',
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
    return false, 'Выберите энергомашину.'
  end
  if not player or not player.valid or player.force ~= f.force then
    return false, 'Это энергомашина другой команды.'
  end
  if not valid(player.character) then
    return false, 'Для ремонта нужен персонаж возле энергомашины.'
  end
  if not valid(f.eye_surface) or player.physical_surface ~= f.eye_surface then
    return false, 'Спуститесь через люк консольного зала к Оку Гармонии.'
  end
  local entity = f.eye_modules and f.eye_modules[key]
  if not valid(entity) or entity.surface ~= f.eye_surface or entity.force ~= f.force then
    return false, 'Энергомашина недоступна. Обновите помещение корабля.'
  end
  local p, b = player.physical_position, entity.position
  if (p.x - b.x) ^ 2 + (p.y - b.y) ^ 2 > Core.range ^ 2 then
    return false,
      'Подойдите к выбранной энергомашине на расстояние не более 6 клеток.'
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
    return false, 'Выберите энергомашину.'
  end
  if player then
    local near, reason = Core.near(player, f, key)
    if not near then
      return false, reason
    end
  end
  if not f.voyage or not f.voyage.console then
    return false, 'Сначала восстановите матрицу управления.'
  end
  if f.voyage.returned then
    return false, 'Око уже отправлено Доктору.'
  end
  if f.flight then
    return false, 'Дождитесь окончания полёта перед ремонтом.'
  end
  if state.modules[key] then
    return false, 'Эта энергомашина уже восстановлена.'
  end
  local tech = f.force.technologies['chemical-science-pack']
  if not tech or not tech.researched then
    return false, 'Сначала исследуйте химическую науку.'
  end
  for _, previous in ipairs(plan.previous or {}) do
    if not state.modules[previous] then
      return false, 'Сначала восстановите узел: ' .. Core.plans[previous].title .. '.'
    end
  end
  if #Core.missing(f, key) > 0 then
    return false,
      'На общем складе недостаточно материалов обычного качества.'
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
  local message = Core.plans[key].title
    .. ' восстановлен. Отдача Ока: '
    .. math.floor(Core.recharge(f) / 1e6)
    .. ' МВт.'
  if f.voyage.eye then
    message = message
      .. ' Все четыре энергомашины исправны; полёты доступны.'
  end
  return true, message
end
return Core
