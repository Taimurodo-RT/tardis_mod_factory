-- Headless scenario driven during --benchmark: no players, only the remote API.
local log_lines = {}
local function note(label, ...)
  log_lines[#log_lines + 1] = label .. ' ' .. serpent.line({...}, {comment = false, sortkeys = true})
end
local function snapshot(tag)
  local st = remote.call('tardis12', 'status', storage.id)
  if st then st.position = nil end
  helpers.write_file('smoke-' .. tag .. '.txt', serpent.block(st, {comment = false, sortkeys = true}) .. '\n')
end
script.on_event(defines.events.on_tick, function(e)
  local t = e.tick
  if t == 10 then
    local s = game.surfaces.nauvis
    s.request_to_generate_chunks({0, 0}, 3); s.force_generate_chunk_requests()
    for _, ent in pairs(s.find_entities_filtered{area = {{-30, -30}, {30, 30}}, type = {'tree', 'simple-entity', 'cliff', 'unit-spawner', 'turret', 'unit'}}) do ent.destroy() end
    local tiles = {}
    for x = -20, 20 do for y = -20, 20 do tiles[#tiles + 1] = {name = 'refined-concrete', position = {x, y}} end end
    s.set_tiles(tiles)
    local force = game.forces.player
    for _, name in ipairs{'vulcanus', 'fulgora', 'gleba', 'aquilo'} do
      local tech = force.technologies['planet-discovery-' .. name]
      if tech then tech.researched = true end
      force.unlock_space_location(name)
    end
    force.technologies['chemical-science-pack'].researched = true
    local box = s.create_entity{name = 'tardis', position = {0, 0}, force = 'player'}
    storage.id = remote.call('tardis12', 'create', box)
    for i, name in ipairs{'tardis-input', 'tardis-output'} do
      local p = s.create_entity{name = name, position = {i == 1 and -4 or 4, 2}, force = 'player'}
      script.raise_script_built{entity = p}
      if i == 1 then p.insert{name = 'iron-plate', count = 500} end
      if i == 2 then remote.call('tardis12', 'configure_port', p.unit_number, {name = 'iron-plate', quality = 'normal'}, 100, true) end
    end
    note('created', storage.id)
  elseif t == 20 then
    snapshot('a-created')
    note('quote-vulcanus', remote.call('tardis12', 'quote', storage.id, 'vulcanus'))
    note('jump-before-repair', remote.call('tardis12', 'jump', storage.id, 'nauvis', 10, 10))
    note('upgrade', remote.call('tardis12', 'upgrade', storage.id))
    remote.call('tardis-smoke-hook', 'repair_all', storage.id)
    note('quote-repaired', remote.call('tardis12', 'quote', storage.id, 'vulcanus'))
  elseif t == 300 then
    snapshot('b-ports')
    if not game.planets.vulcanus.surface then game.planets.vulcanus.create_surface() end
    note('jump-vulcanus', remote.call('tardis12', 'jump', storage.id, game.planets.vulcanus.surface.index, 0, 0))
  elseif t == 600 then
    snapshot('c-after-jump')
    note('jump-home', remote.call('tardis12', 'jump', storage.id, 'nauvis', 6, 6))
  elseif t == 900 then
    snapshot('c2-home')
  elseif t == 1100 then
    snapshot('d-final')
    helpers.write_file('smoke-log.txt', table.concat(log_lines, '\n') .. '\n')
  end
end)
