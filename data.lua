local util = require('util')
local P = '__tardis__/graphics/twelve/'
data:extend({ { type = 'item-subgroup', name = 'tardis', group = 'logistics', order = 'z-tardis' } })
require('prototypes.tardis')
require('prototypes.console')
local console = data.raw.container['tardis-console']
local function port(name, base, tint)
  local p = table.deepcopy(data.raw['logistic-container'][base])
  p.name = name
  p.minable = { mining_time = 0.2, result = name }
  p.inventory_size = 96
  p.icons = { { icon = p.icon, icon_size = p.icon_size or 64, tint = tint } }
  p.icon = nil
  p.localised_name = { 'entity-name.' .. name }
  p.next_upgrade = nil
  p.fast_replaceable_group = nil
  data:extend({
    p,
    { type = 'item', name = name, icons = p.icons, subgroup = 'tardis', stack_size = 50, place_result = name },
    {
      type = 'recipe',
      name = name,
      enabled = true,
      ingredients = {
        { type = 'item', name = 'steel-plate', amount = 4 },
        {
          type = 'item',
          name = 'electronic-circuit',
          amount = 2,
        },
      },
      results = { { type = 'item', name = name, amount = 1 } },
    },
  })
end
port('tardis-input', 'requester-chest', { 0.3, 0.8, 1 })
port('tardis-output', 'passive-provider-chest', { 1, 0.7, 0.25 })
local terminal = table.deepcopy(data.raw.container['steel-chest'])
terminal.name = 'tardis-terminal'
terminal.icon = P .. 'console-icon.png'
terminal.inventory_size = 1
terminal.minable = nil
terminal.flags = { 'placeable-player', 'player-creation', 'not-blueprintable', 'not-deconstructable' }
local power = {
  type = 'electric-energy-interface',
  name = 'tardis-power',
  icon = P .. 'console-icon.png',
  icon_size = 64,
  flags = { 'not-on-map', 'hide-alt-info', 'not-blueprintable', 'not-deconstructable' },
  hidden = true,
  selectable_in_game = false,
  collision_mask = { layers = {} },
  collision_box = { { 0, 0 }, { 0, 0 } },
  energy_source = {
    type = 'electric',
    buffer_capacity = '20MJ',
    usage_priority = 'primary-output',
    input_flow_limit = '0W',
    output_flow_limit = '200MW',
  },
  energy_production = '0W',
  energy_usage = '0W',
  picture = util.empty_sprite(),
}
local pole = table.deepcopy(data.raw['electric-pole']['medium-electric-pole'])
pole.name = 'tardis-connector'
pole.minable = nil
pole.maximum_wire_distance = 24
pole.supply_area_distance = 18
pole.flags = { 'not-blueprintable', 'not-deconstructable', 'placeable-player', 'player-creation' }
local relay = table.deepcopy(pole)
relay.name = 'tardis-room-relay'
relay.pictures = util.empty_sprite()
relay.pictures.direction_count = 1
relay.connection_points = { relay.connection_points[1] }
relay.draw_copper_wires = false
relay.draw_circuit_wires = false
relay.collision_box = { { 0, 0 }, { 0, 0 } }
relay.collision_mask = { layers = {} }
relay.selection_box = { { -0.4, -0.4 }, { 0.4, 0.4 } }
relay.selectable_in_game = false
local floor = table.deepcopy(data.raw.tile['refined-concrete'])
floor.name = 'tardis-floor'
floor.minable = nil
floor.walking_speed_modifier = 1.15
floor.map_color = { 0.12, 0.17, 0.23 }
data:extend({
  terminal,
  power,
  pole,
  relay,
  floor,
  {
    type = 'sprite',
    name = 'tardis-exterior-open',
    filename = P .. 'exterior-open.png',
    width = 256,
    height = 384,
    scale = 0.34,
    shift = { 0, -1.05 },
  },
  {
    type = 'sprite',
    name = 'tardis-library-room',
    filename = P .. 'library-room.png',
    width = 1536,
    height = 1280,
    scale = 0.5,
  },
  { type = 'sprite', name = 'tardis-room', filename = P .. 'room.png', width = 1536, height = 1536, scale = 0.75 },
  { type = 'custom-input', name = 'tardis-control', key_sequence = 'CONTROL + T', consuming = 'none' },
  {
    type = 'shortcut',
    name = 'tardis-control',
    action = 'lua',
    icon = P .. 'console-icon.png',
    icon_size = 64,
    small_icon = P .. 'console-icon.png',
    small_icon_size = 64,
  },
})
require('twelve.styles')
require('twelve.voyage-data')
require('twelve.circuit-data')
require('twelve.interior-data')
require('twelve.eye-data')
local anchor = table.deepcopy(terminal)
anchor.name = 'tardis-anchor'
anchor.localised_name = { 'entity-name.tardis-anchor' }
data:extend({ anchor })
local eye = table.deepcopy(console)
eye.name = 'tardis-eye'
eye.localised_name = { 'entity-name.tardis-eye' }
eye.minable = nil
eye.picture = { filename = P .. 'eye.png', width = 512, height = 512, scale = 0.36, shift = { 0, -1 } }
eye.collision_box = { { -1.8, -1.4 }, { 1.8, 1.4 } }
eye.selection_box = { { -2.4, -3.6 }, { 2.4, 1.8 } }
data:extend({ eye })
local exit = table.deepcopy(terminal)
exit.name = 'tardis-exit'
exit.localised_name = { 'entity-name.tardis-exit' }
exit.picture = { filename = P .. 'exterior-open.png', width = 256, height = 384, scale = 0.46, shift = { 0, -1.55 } }
exit.collision_box = { { 0, 0 }, { 0, 0 } }
exit.collision_mask = { layers = {} }
exit.selection_box = { { -1.7, -3.5 }, { 1.7, 1 } }
data:extend({
  exit,
  {
    type = 'sprite',
    name = 'tardis-circular-rim',
    filename = P .. 'circular-rim.png',
    width = 1536,
    height = 1536,
    scale = 0.65,
  },
})
data:extend({
  {
    type = 'simple-entity-with-owner',
    name = 'tardis-rim-collider',
    icon = P .. 'console-icon.png',
    icon_size = 64,
    flags = { 'not-on-map', 'not-blueprintable', 'not-deconstructable' },
    hidden = true,
    selectable_in_game = false,
    collision_box = { { -0.48, -0.48 }, { 0.48, 0.48 } },
    collision_mask = { layers = { object = true, player = true } },
    picture = util.empty_sprite(),
    max_health = 1000,
  },
})
-- A recovered Type 40 is found at the crash site; it has no recipe and cannot be mass produced.
