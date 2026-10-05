-- Space Age's canonical destination already has its icon, route and research.
-- Make that same location landable instead of introducing a second "ruined" planet.
local shattered = data.raw['space-location']['shattered-planet']
if shattered and not data.raw.planet['shattered-planet'] then
  local ground = table.deepcopy(data.raw.tile['nuclear-ground'])
  ground.name = 'tardis-shattered-ground'
  ground.localised_name = { 'tile-name.tardis-shattered-ground' }
  ground.order = 'z[tardis]-z[shattered-ground]'
  ground.autoplace = { probability_expression = '1' }
  ground.minable = nil
  local planet = table.deepcopy(shattered)
  planet.type = 'planet'
  planet.localised_description = { 'space-location-description.tardis-shattered-planet' }
  -- Keep fly_condition and the 4,000,000 km route unchanged for ordinary platforms.
  -- The TARDIS can materialise on a surviving fragment using its spatial stabiliser.
  planet.surface_properties =
    { ['day-night-cycle'] = 60 * 60 * 10, ['solar-power'] = 1, pressure = 1000, gravity = 10, ['magnetic-field'] = 0 }
  planet.map_gen_settings = {
    autoplace_controls = {},
    property_expression_names = { elevation = '100', temperature = '0', moisture = '0', aux = '0' },
    autoplace_settings = {
      tile = { treat_missing_as_default = false, settings = { ['tardis-shattered-ground'] = {} } },
      entity = { treat_missing_as_default = false, settings = {} },
      decorative = { treat_missing_as_default = false, settings = {} },
    },
  }
  data.raw['space-location']['shattered-planet'] = nil
  data:extend({ ground, planet })
end
