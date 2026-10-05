local Chunks=require('twelve.interior-chunks')
local Core=require('twelve.eye-core')
local E={revision=140001,radius=32,pit_radius=7.5,interaction_radius=4}
E.module_positions={containment={x=0,y=-17},collector_a={x=-17,y=0},collector_b={x=17,y=0},converter={x=0,y=17}}
local order={'containment','collector_a','collector_b','converter'}
local titles={containment='КОНТУР УДЕРЖАНИЯ',collector_a='СЪЁМНИК ЭНЕРГИИ · А',collector_b='СЪЁМНИК ЭНЕРГИИ · Б',converter='ПРЕОБРАЗОВАТЕЛЬ'}
local function valid(object) return object and object.valid end
local function protect(entity)
 if valid(entity) then entity.destructible=false;entity.minable=false end
 return entity
end
local function distance(a,b) return (a.x-b.x)^2+(a.y-b.y)^2 end
local function tracked(room,object)
 if object then room.renders[#room.renders+1]=object end
 return object
end
local function create(f,name,position,surface)
 return protect((surface or f.eye_surface).create_entity{name=name,position=position,force=f.force,create_build_effect_smoke=false})
end
local function floor_name(x,y)
 local dx,dy=x+.5,y+.5;local radius=math.sqrt(dx*dx+dy*dy)
 if radius>=31.6 or radius<E.pit_radius then return 'out-of-map' end
 if radius>29.4 or radius<9 then return 'tardis-brass-floor' end
 for _,p in pairs(E.module_positions) do if (dx-p.x)^2+(dy-p.y)^2<3.5^2 then return 'tardis-brass-floor' end end
 if math.abs(dx)<2 or math.abs(dy)<2 or (radius>=22 and radius<24) then return 'tardis-grate-floor' end
 return 'tardis-steel-floor'
end
local function make_surface(f)
 local name='tardis12-eye-'..f.id
 local s=game.get_surface(name)
 local created=not s
 if not s then
  s=game.create_surface(name,{width=1,height=1,autoplace_controls={},
   autoplace_settings={entity={treat_missing_as_default=false},tile={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
 end
 f.eye_surface=s
 s.freeze_daytime=true;s.always_day=false;s.daytime=.35;s.show_clouds=false
 s.set_property('solar-power',0);s.set_property('pressure',1000);s.set_property('gravity',10)
 if created then
  Chunks.ensure_area(s,-40,-40,40,40)
  local tiles={}
  for x=-40,40 do for y=-40,40 do tiles[#tiles+1]={name=floor_name(x,y),position={x,y}} end end
  s.set_tiles(tiles,false)
 end
 f.force.chart(s,{{-34,-34},{34,34}})
 return s
end
local function relay(f,room,x,y)
 if f.eye_surface.count_entities_filtered{name='tardis-room-relay',position={x,y},radius=.75}==0 then
  local e=create(f,'tardis-room-relay',{x,y});if e then room.entities[#room.entities+1]=e end
 end
end
local function ensure_hatch(f,room)
 if valid(room.hatch) then return end
 local surface=f.surface
 if not (surface and surface.valid) then return end
 local at=surface.find_non_colliding_position('tardis-eye-hatch',{6,7},12,.5)
 if not at then return end
 room.hatch=create(f,'tardis-eye-hatch',at,surface)
 if valid(room.hatch) then
  if valid(room.hatch_label) then room.hatch_label.destroy() end
  room.hatch_label=tracked(room,rendering.draw_text{surface=surface,target={entity=room.hatch,offset={0,1.65}},
   text='НИЖНЯЯ ПАЛУБА',color={.8,.84,.86},scale=.7,alignment='center'})
 end
end
function E.ensure(f)
 Core.ensure(f)
 f.eye_room=f.eye_room or {entities={},renders={},modules={},module_art={},module_labels={},module_lights={}}
 local room=f.eye_room
 room.entities=room.entities or {};room.renders=room.renders or {};room.modules=room.modules or {}
 room.module_art=room.module_art or {};room.module_labels=room.module_labels or {};room.module_lights=room.module_lights or {}
 room.energy_lines=room.energy_lines or {}
 f.eye_modules=room.modules
 -- The model first attempts a native stack transfer to cargo. A full hold must
 -- leave the old container (including item metadata) intact for a later retry.
 local retained=false
 if valid(f.eye_entity) then
  local inv=f.eye_entity.get_inventory(defines.inventory.chest)
  if inv and not inv.is_empty() then
   retained=true
   if not f.eye_legacy_notice then
    f.force.print('ТАРДИС XII: в старом отсеке Ока остались предметы. Освободите место в хранилище или заберите их из старого контейнера; после следующего входа на нижнюю палубу он будет убран.')
    f.eye_legacy_notice=true
   end
  else f.eye_entity.destroy() end
 end
 if not retained then
  f.eye_entity=nil;f.eye_legacy_notice=nil
  if valid(f.eye_label) then f.eye_label.destroy() end;f.eye_label=nil
 end
 if not (f.eye_surface and f.eye_surface.valid) then make_surface(f) end
 ensure_hatch(f,room)
 if not valid(room.ladder) then
  local at=f.eye_surface.find_non_colliding_position('tardis-eye-ladder',{0,27},4,.5)
  if at then room.ladder=create(f,'tardis-eye-ladder',at) end
 end
 if not valid(room.ladder_label) and valid(room.ladder) then
  room.ladder_label=tracked(room,rendering.draw_text{surface=f.eye_surface,target={entity=room.ladder,offset={0,1.65}},
   text='В ЦЕНТРАЛЬНЫЙ ЗАЛ',color={.8,.84,.86},scale=.8,alignment='center'})
 end
 if not valid(room.star) then room.star=create(f,'tardis-eye-star',{0,0}) end
 if not valid(room.halo) then
  room.halo=tracked(room,rendering.draw_sprite{sprite='tardis-eye-star-glow',surface=f.eye_surface,target=room.star,
   render_layer='higher-object-above',tint={1,.6,.25,.16},x_scale=1.03,y_scale=1.03})
 end
 if not valid(room.star_light) then
  room.star_light=tracked(room,rendering.draw_light{sprite='utility/light_medium',surface=f.eye_surface,target={0,0},
   color={1,.55,.2},scale=12,intensity=.7,minimum_darkness=0})
 end
 if not valid(room.rim) then
  room.rim=tracked(room,rendering.draw_sprite{sprite='tardis-circular-rim',surface=f.eye_surface,target={0,0},render_layer='floor',x_scale=2,y_scale=2})
 end
 for _,key in ipairs(order) do
  local p=E.module_positions[key]
  if not valid(room.modules[key]) then
   -- On later updates a user machine could occupy the expected position.
   -- A nearby free position is preferable to replacing anything they built.
   local at=f.eye_surface.find_non_colliding_position('tardis-eye-machine',p,5,.5)
   if at then room.modules[key]=create(f,'tardis-eye-machine',at) end
  end
  local machine=room.modules[key]
  if valid(machine) then
   if not valid(room.module_art[key]) then room.module_art[key]=tracked(room,rendering.draw_sprite{
    sprite='tardis-eye-machine-art',surface=f.eye_surface,target=machine,render_layer='object'}) end
   room.module_art[key].x_scale=key=='collector_b' and -1 or 1
   if not valid(room.energy_lines[key]) then
    local p0=machine.position;local r=math.sqrt(p0.x*p0.x+p0.y*p0.y);local ux,uy=p0.x/r,p0.y/r
    local from={ux*8,uy*8};local to={p0.x-ux*3.3,p0.y-uy*3.3}
    tracked(room,rendering.draw_line{surface=f.eye_surface,from=from,to=to,color={.1,.11,.12,.9},width=9,draw_on_ground=true})
    room.energy_lines[key]=tracked(room,rendering.draw_line{surface=f.eye_surface,from=from,to=to,
     color={.45,.1,.04,.4},width=3,draw_on_ground=true})
   end
   if not valid(room.module_labels[key]) then room.module_labels[key]=tracked(room,rendering.draw_text{
    surface=f.eye_surface,target={entity=machine,offset={0,3.1}},text=titles[key],color={.7,.75,.8},scale=.7,alignment='center'}) end
   if not valid(room.module_lights[key]) then room.module_lights[key]=tracked(room,rendering.draw_light{
    sprite='utility/light_small',surface=f.eye_surface,target={entity=machine,offset={0,1.4}},color={1,.2,.08},scale=2.5,intensity=.55,minimum_darkness=0}) end
  end
 end
 if not valid(f.eye_power) then
  f.eye_power=create(f,'tardis-power',{26,10})
  if valid(f.eye_power) then f.eye_power.electric_buffer_size=2e6;f.eye_power.energy=0 end
 end
 if not valid(f.eye_connector) then
  local at=f.eye_surface.find_non_colliding_position('tardis-connector',{26,10},6,.5)
  if at then f.eye_connector=create(f,'tardis-connector',at) end
 end
 for _,p in ipairs{{18,10},{0,18},{-18,10},{-18,-10},{0,-18},{18,-10}} do relay(f,room,p[1],p[2]) end
 if room.revision~=E.revision then
  for _,p in ipairs{{23,18},{-23,18},{23,-18},{-23,-18},{0,29},{0,-29},{29,0},{-29,0}} do
   if f.eye_surface.can_place_entity{name='small-lamp',position=p,force=f.force} then
    local e=create(f,'small-lamp',p);if e then e.always_on=true;room.entities[#room.entities+1]=e end
   end
  end
  -- The pit itself is void. This ring only stops movement through the painted
  -- outer wall, leaving the actual factory floor inside fully buildable.
  for x=-32,31 do for y=-32,31 do local r=(x+.5)^2+(y+.5)^2
   if r>=30.6^2 and r<=31.4^2 and f.eye_surface.can_place_entity{name='tardis-rim-collider',position={x+.5,y+.5},force=f.force} then
    local e=create(f,'tardis-rim-collider',{x+.5,y+.5});if e then room.entities[#room.entities+1]=e end
   end
  end end
  room.revision=E.revision
 end
 E.tick(f)
 return room
end
function E.is_inside(p,f) return p and valid(f.eye_surface) and p.physical_surface==f.eye_surface end
local function near(p,f,entity,surface)
 return p and p.valid and p.force==f.force and p.physical_surface==surface and valid(entity)
  and distance(p.physical_position,entity.position)<=E.interaction_radius^2
end
function E.can_enter(p,f)
 if not f or not near(p,f,f.eye_room and f.eye_room.hatch,f.surface) then return false,'Подойдите к люку в центральном зале.' end
 if not valid(f.eye_surface) or not valid(f.eye_room.ladder) then return false,'Нижняя площадка недоступна.' end
 return true
end
function E.can_leave(p,f)
 if not f or not near(p,f,f.eye_room and f.eye_room.ladder,f.eye_surface) then return false,'Подойдите к лестнице у южного края зала Ока.' end
 if not valid(f.surface) or not valid(f.eye_room.hatch) then return false,'Верхняя площадка недоступна.' end
 return true
end
function E.enter(p,f)
 local ok,reason=E.can_enter(p,f);if not ok then return false,reason end
 local ladder=f.eye_room.ladder.position
 local at=f.eye_surface.find_non_colliding_position('character',{ladder.x,ladder.y-2},6,.25)
 if not at then return false,'На нижней площадке нет свободного места.' end
 p.driving=false
 if not p.teleport(at,f.eye_surface) then return false,'Не удалось спуститься на нижнюю палубу.' end
 return true,'Нижняя палуба: Око Гармонии.'
end
function E.leave(p,f)
 local ok,reason=E.can_leave(p,f);if not ok then return false,reason end
 local p0=f.eye_room.hatch.position
 local at=f.surface.find_non_colliding_position('character',{p0.x,p0.y+2},6,.25)
 if not at then return false,'Рядом с верхним люком нет свободного места.' end
 p.driving=false
 if not p.teleport(at,f.surface) then return false,'Не удалось подняться в центральный зал.' end
 return true,'Центральный зал.'
end
function E.module_key(f,entity)
 for key,machine in pairs(f.eye_modules or {}) do if valid(machine) and machine==entity then return key end end
end
function E.tick(f)
 local room=f.eye_room
 if not room or not valid(f.eye_surface) then return end
 local core=Core.ensure(f);local returned=f.voyage and f.voyage.returned
 local repaired=0;for _,key in ipairs(order) do if core.modules[key] then repaired=repaired+1 end end
 local pulse=.5+.5*math.sin(game.tick/48)
 if valid(room.star) then room.star.color=returned and {.08,.1,.12,1} or (repaired==4 and {1,1,1,1} or {.78,.52,.4,1}) end
 if valid(room.halo) then
  room.halo.visible=not returned;room.halo.x_scale=1.015+.018*pulse;room.halo.y_scale=room.halo.x_scale
  room.halo.color={1,.56,.2,.11+.06*pulse}
 end
 if valid(room.star_light) then room.star_light.intensity=returned and 0 or (.48+.12*pulse+.025*repaired) end
 for _,key in ipairs(order) do
  local active=core.modules[key] and not returned
  local color=returned and {.3,.34,.38,1} or active and {.86,.97,1,1} or {.52,.31,.27,1}
  if valid(room.module_art[key]) then room.module_art[key].color=color end
  local line=room.energy_lines and room.energy_lines[key]
  if valid(line) then
   line.visible=not returned
   line.color=active and ((key=='collector_a' or key=='collector_b') and {.15,.8,1,.62+.2*pulse} or {1,.6,.15,.62+.2*pulse}) or {.45,.1,.04,.35}
   line.width=active and (3+1.4*pulse) or 2
  end
  if valid(room.module_labels[key]) then
   room.module_labels[key].text=titles[key]..'\n'..(returned and 'ОТКЛЮЧЁН' or active and 'В СТРОЮ' or 'ТРЕБУЕТ РЕМОНТА')
   room.module_labels[key].color=returned and {.45,.48,.5} or active and {.6,.85,.78} or {.88,.48,.35}
  end
  if valid(room.module_lights[key]) then
   room.module_lights[key].color=active and {.25,.8,1} or {1,.15,.05}
   room.module_lights[key].intensity=returned and .05 or active and .5 or (.28+.1*pulse)
  end
 end
end
function E.chunk_generated(event)
 for _,f in pairs(storage.twelve and storage.twelve.ships or {}) do if f.eye_surface==event.surface then
  local tiles={}
  local p=event.position
  for x=p.x*32,p.x*32+31 do for y=p.y*32,p.y*32+31 do
   if Chunks.name(event.surface,x,y)=='grass-1' then tiles[#tiles+1]={name='out-of-map',position={x,y}} end
  end end
  if #tiles>0 then event.surface.set_tiles(tiles,false) end
  return
 end end
end
function E.on_surface_deleted(f,index)
 if not valid(f.eye_surface) or f.eye_surface.index~=index then return false end
 local target=valid(f.eye_room and f.eye_room.hatch) and f.eye_room.hatch.position or {x=6,y=7}
 for _,p in pairs(game.players) do if p.physical_surface==f.eye_surface and valid(f.surface) then
  local at=f.surface.find_non_colliding_position('character',{target.x,target.y+2},32,.25)
  if at then p.driving=false;p.teleport(at,f.surface) end
 end end
 for _,r in pairs(f.eye_room and f.eye_room.renders or {}) do if valid(r) then r.destroy() end end
 if valid(f.eye_room and f.eye_room.hatch) then f.eye_room.hatch.destroy() end
 f.eye_surface=nil;f.eye_room=nil;f.eye_modules=nil;f.eye_power=nil;f.eye_connector=nil
 return true
end
return E
