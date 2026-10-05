local M = require('twelve.model')
local UI = require('twelve.ui')
_G.Twelve = M -- Named console/debug entry point; no serialized functions.
_G.TwelveUI = UI
script.on_init(M.init)
script.on_configuration_changed(function(e)
  M.init()
  for _, p in pairs(game.players) do
    if p.gui.screen.t12 then
      p.gui.screen.t12.destroy()
    end
  end
end)
script.on_event(defines.events.on_player_created, M.starter)
script.on_event({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
}, M.built)
script.on_event({ defines.events.on_player_mined_entity, defines.events.on_robot_mined_entity }, M.mined)
script.on_event({ defines.events.on_entity_died, defines.events.script_raised_destroy }, M.died)
script.on_event(defines.events.on_pre_surface_deleted, M.surface_deleted)
script.on_event(defines.events.on_chunk_generated, function(e)
  M.Interior.chunk_generated(e)
  M.Eye.chunk_generated(e)
end)
script.on_event(defines.events.on_player_changed_position, M.walk)
script.on_event(defines.events.on_entity_cloned, function(e)
  if M.Interior.on_cloned and M.Interior.on_cloned(e) then
    return
  end
  if e.destination.name:sub(1, 7) == 'tardis-' or e.destination.name == 'tardis' then
    e.destination.destroy()
  end
end)
script.on_nth_tick(6, function()
  M.tick()
  UI.tick()
end)
script.on_event(defines.events.on_gui_opened, UI.opened)
script.on_event(defines.events.on_gui_closed, UI.closed)
script.on_event(defines.events.on_gui_click, UI.click)
script.on_event(defines.events.on_gui_text_changed, UI.changed)
script.on_event(defines.events.on_gui_elem_changed, UI.changed)
script.on_event(defines.events.on_gui_selection_state_changed, UI.changed)
script.on_event(defines.events.on_gui_checked_state_changed, UI.changed)
script.on_event(defines.events.on_gui_confirmed, UI.confirmed)
script.on_event(defines.events.on_string_translated, UI.translated)
script.on_event('tardis-control', UI.shortcut)
script.on_event(defines.events.on_lua_shortcut, function(e)
  if e.prototype_name == 'tardis-control' then
    UI.shortcut(e)
  end
end)
commands.add_command('tardis', { 'tardis-ship.command-help' }, function(e)
  local p = e.player_index and game.get_player(e.player_index)
  if not p then
    return
  end
  if e.parameter == 'open' then
    UI.shortcut(e)
  elseif e.parameter == 'demo' then
    if p.admin then
      M.demo(p)
      UI.shortcut(e)
    end
  else
    M.starter({ player_index = p.index, manual = true })
  end
end)
remote.add_interface('tardis12', {
  status = M.status,
  jump = M.jump,
  create = M.create,
  enter = M.enter,
  leave = M.leave,
  transfer = M.move,
  configure_port = M.configure_port,
  upgrade = M.upgrade,
  build_room = M.build_room,
  cancel_room = M.cancel_room,
  repair = M.repair,
  repair_eye = M.repair_eye,
  store_blueprint = M.store_blueprint,
  take_blueprint = M.take_blueprint,
  descend = M.descend,
  ascend = M.ascend,
  return_doctor = M.return_doctor,
  quote = function(id, target)
    return M.Voyage.quote(M.get(id), target)
  end,
  open = function(i, id, tab)
    UI.open(game.get_player(i), id, tab)
  end,
})
