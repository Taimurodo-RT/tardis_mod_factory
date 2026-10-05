local P = '__tardis__/graphics/twelve/'

data:extend({
  {
    type = 'container',
    name = 'tardis-console',
    icon = P .. 'console-icon.png',
    icon_size = 64,
    flags = {
      'not-on-map',
      'hide-alt-info',
      'not-deconstructable',
      'not-blueprintable',
      'not-flammable',
      'not-upgradable',
    },
    selectable_in_game = true,
    hidden = true,
    hidden_in_factoriopedia = true,
    max_health = 1000,
    collision_box = { { -2.4, -1.8 }, { 2.4, 1.8 } },
    selection_box = { { -2.9, -5 }, { 2.9, 2 } },
    collision_mask = { layers = { object = true, player = true, water_tile = true } },
    inventory_size = 1,
    inventory_type = 'with_filters_and_bar',
    quality_affects_inventory_size = false,
    picture = { filename = P .. 'console.png', width = 512, height = 512, scale = 0.6, shift = { 0, -1.2 } },
    render_layer = 'object',
  },
  {
    type = 'sound',
    name = 'tardis-teleportation',
    filename = '__tardis__/sound/tardis.ogg',
    volume = 0.8,
  },
  {
    type = 'sound',
    name = 'tardis-teleport-complete',
    filename = '__tardis__/sound/scifi.ogg',
    volume = 0.8,
  },
})
