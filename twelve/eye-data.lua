local util = require('util')
local P = '__tardis__/graphics/twelve/'
local flags = { 'placeable-player', 'player-creation', 'not-blueprintable', 'not-deconstructable' }
local machine = table.deepcopy(data.raw.container['steel-chest'])
machine.name = 'tardis-eye-machine'
machine.localised_name = { 'entity-name.tardis-eye-machine' }
machine.localised_description = { 'entity-description.tardis-eye-machine' }
machine.icon = P .. 'extractor-icon.png'
machine.icon_size = 64
machine.minable = nil
machine.next_upgrade = nil
machine.fast_replaceable_group = nil
machine.flags = table.deepcopy(flags)
machine.max_health = 10000
machine.inventory_size = 1
-- The native entity provides collision, selection and GUI events. Its separate
-- object-layer sprite can be dimmed per module without replacing the entity.
machine.picture = util.empty_sprite()
machine.collision_box = { { -1.65, -1.25 }, { 1.65, 1.25 } }
machine.selection_box = { { -2.8, -4 }, { 2.8, 2.2 } }

local hatch = table.deepcopy(data.raw.container['steel-chest'])
hatch.name = 'tardis-eye-hatch'
hatch.localised_name = { 'entity-name.tardis-eye-hatch' }
hatch.localised_description = { 'entity-description.tardis-eye-hatch' }
hatch.minable = nil
hatch.next_upgrade = nil
hatch.fast_replaceable_group = nil
hatch.flags = table.deepcopy(flags)
hatch.max_health = 10000
hatch.inventory_size = 1
hatch.icon = P .. 'hatch-icon.png'
hatch.icon_size = 64
hatch.picture = { filename = P .. 'hatch.png', width = 256, height = 256, scale = 0.30, shift = { 0, -0.2 } }
hatch.collision_box = { { -0.6, -0.45 }, { 0.6, 0.45 } }
hatch.selection_box = { { -1.25, -1.35 }, { 1.25, 1.25 } }
local ladder = table.deepcopy(hatch)
ladder.name = 'tardis-eye-ladder'
ladder.localised_name = { 'entity-name.tardis-eye-ladder' }
ladder.localised_description = { 'entity-description.tardis-eye-ladder' }

data:extend({
  machine,
  hatch,
  ladder,
  {
    type = 'simple-entity-with-owner',
    name = 'tardis-eye-star',
    icon = P .. 'star-icon.png',
    icon_size = 64,
    localised_name = { 'entity-name.tardis-eye-star' },
    flags = { 'not-on-map', 'not-blueprintable', 'not-deconstructable' },
    max_health = 10000,
    selectable_in_game = false,
    collision_mask = { layers = {} },
    collision_box = { { 0, 0 }, { 0, 0 } },
    picture = { filename = P .. 'star.png', width = 768, height = 768, scale = 0.59, apply_runtime_tint = true },
    render_layer = 'object',
  },
  {
    type = 'sprite',
    name = 'tardis-eye-machine-art',
    filename = P .. 'extractor.png',
    width = 512,
    height = 512,
    scale = 0.38,
    shift = { 0, -1 },
  },
  {
    type = 'sprite',
    name = 'tardis-eye-star-glow',
    filename = P .. 'star.png',
    width = 768,
    height = 768,
    scale = 0.59,
  },
})
