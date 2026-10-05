-- Use Factorio's own connector positions and industrial combinator model.
-- The amber command socket never emits signals; the cyan telemetry socket does.
local function tint_sprites(node, tint)
  if type(node) ~= 'table' then
    return
  end
  if node.filename and not node.draw_as_shadow then
    node.tint = tint
  end
  for _, v in pairs(node) do
    if type(v) == 'table' then
      tint_sprites(v, tint)
    end
  end
end
for _, entry in ipairs({ { 'input', { 1, 0.72, 0.38 } }, { 'output', { 0.38, 0.83, 1 } } }) do
  local p = table.deepcopy(data.raw['constant-combinator']['constant-combinator'])
  p.name = 'tardis-circuit-' .. entry[1]
  p.localised_name = { 'entity-name.' .. p.name }
  p.localised_description = { 'entity-description.' .. p.name }
  p.minable = nil
  p.next_upgrade = nil
  p.fast_replaceable_group = nil
  p.placeable_by = nil
  p.flags = { 'placeable-player', 'player-creation', 'not-blueprintable', 'not-deconstructable', 'not-rotatable' }
  p.max_health = 1000
  p.circuit_wire_max_distance = 20
  p.icons = { { icon = p.icon, icon_size = p.icon_size or 64, tint = entry[2] } }
  p.icon = nil
  tint_sprites(p.sprites, entry[2])
  data:extend({ p })
end
data:extend({ { type = 'item-subgroup', name = 'tardis-circuit-signals', group = 'signals', order = 'z-tardis' } })
local signals = {
  { 'jump', 'J', true },
  { 'destination', 'P', true },
  { 'x', 'X', true },
  { 'y', 'Y', true },
  { 'inhibit', 'H', true },
  { 'export', 'G', true },
  { 'energy', 'E' },
  { 'charge', 'Q' },
  { 'busy', 'B' },
  { 'ready', 'R' },
  { 'origin', 'O' },
  { 'items', 'I' },
  { 'free-slots', 'F' },
  { 'result', 'C' },
}
for i, s in ipairs(signals) do
  local p = table.deepcopy(data.raw['virtual-signal']['signal-' .. s[2]])
  p.name = 'tardis-signal-' .. s[1]
  p.localised_name = { 'virtual-signal-name.' .. p.name }
  p.localised_description = { 'virtual-signal-description.' .. p.name }
  p.subgroup = 'tardis-circuit-signals'
  p.order = string.format('%02d', i)
  p.icons = { { icon = p.icon, icon_size = p.icon_size or 64, tint = s[3] and { 1, 0.72, 0.38 } or { 0.38, 0.83, 1 } } }
  p.icon = nil
  data:extend({ p })
end
