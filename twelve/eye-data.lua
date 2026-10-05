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
-- Spiral stair down a shaft lit by the star (Blender render, tools/blender/stair.py).
hatch.picture = { filename = P .. 'stair-down.png', size = 384, scale = 0.33 }
hatch.collision_box = { { -0.6, -0.45 }, { 0.6, 0.45 } }
hatch.selection_box = { { -1.9, -1.7 }, { 1.9, 1.7 } }
local ladder = table.deepcopy(hatch)
ladder.name = 'tardis-eye-ladder'
ladder.localised_name = { 'entity-name.tardis-eye-ladder' }
ladder.localised_description = { 'entity-description.tardis-eye-ladder' }
-- The same stair seen from below, climbing towards the console room's light.
ladder.picture = { filename = P .. 'stair-up.png', size = 384, scale = 0.42, shift = { 0, -0.9 } }
ladder.selection_box = { { -2, -2.6 }, { 2, 1.6 } }

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
    -- Drawn by the 'tardis-eye-core' animation; the entity only anchors it.
    picture = util.empty_sprite(),
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
    -- Blender loop (tools/blender/eye_star.py): star and three gyroscope rings, 96 frames.
    -- 512 px frames of 6.2 units; scale 1.16 makes the star's disc 6 tiles across, centred over the
    -- pit. Drawn as glow: the render carries its own lighting, so the dark hall must not dim it.
    type = 'animation',
    name = 'tardis-eye-core',
    width = 512,
    height = 512,
    frame_count = 96,
    scale = 1.16,
    draw_as_glow = true,
    stripes = {
      { filename = P .. 'eye-core-1.png', width_in_frames = 8, height_in_frames = 8 },
      { filename = P .. 'eye-core-2.png', width_in_frames = 8, height_in_frames = 4 },
    },
  },
})
