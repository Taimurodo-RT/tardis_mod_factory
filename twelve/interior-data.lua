-- The material art belongs to this mod. Borders and their collision/sound rules
-- are inherited from Factorio rather than copied into the release archive.
local P = '__tardis__/graphics/twelve/'
local materials = {
  { name = 'steel', layer = 60, color = { 49, 54, 59 } },
  { name = 'grate', layer = 61, color = { 30, 34, 37 } },
  { name = 'brass', layer = 62, color = { 87, 71, 44 } },
}
for _, material in ipairs(materials) do
  local tile = table.deepcopy(data.raw.tile['refined-concrete'])
  tile.name = 'tardis-' .. material.name .. '-floor'
  tile.localised_name = { 'tile-name.' .. tile.name }
  tile.order = 'z[tardis]-' .. material.name
  tile.minable = nil
  tile.placeable_by = nil
  tile.next_direction = nil
  tile.layer = material.layer
  tile.walking_speed_modifier = 1.15
  tile.map_color = material.color
  tile.variants.material_background = { picture = P .. 'floor-' .. material.name .. '.png', count = 1, scale = 0.5 }
  tile.variants.material_texture_width_in_tiles = 4
  tile.variants.material_texture_height_in_tiles = 4
  -- Keep transition masks in the base package. No baked whole-room overlay is used.
  data:extend({ tile })
end

data:extend({
  {
    type = 'simple-entity-with-owner',
    name = 'tardis-roundel-wall',
    icon = P .. 'console-icon.png',
    icon_size = 64,
    localised_name = { 'entity-name.tardis-roundel-wall' },
    flags = { 'not-on-map', 'not-blueprintable', 'not-deconstructable' },
    max_health = 1000,
    selectable_in_game = false,
    collision_mask = { layers = {} },
    collision_box = { { 0, 0 }, { 0, 0 } },
    selection_box = { { -2, -1 }, { 2, 0.25 } },
    picture = { filename = P .. 'roundel-wall.png', width = 256, height = 256, scale = 0.5, shift = { 0, -1.25 } },
    render_layer = 'object',
  },
})

-- Native chests are working archive cabinets, not a photograph of shelving.
local cabinet = table.deepcopy(data.raw.container['steel-chest'])
cabinet.name = 'tardis-archive-cabinet'
cabinet.localised_name = { 'entity-name.tardis-archive-cabinet' }
cabinet.minable = nil
cabinet.inventory_size = 48
cabinet.flags = { 'placeable-player', 'player-creation', 'not-blueprintable', 'not-deconstructable' }
cabinet.next_upgrade = nil
cabinet.fast_replaceable_group = nil
data:extend({ cabinet })
