local Voyage=require('twelve.voyage')
local Circuit={}
-- Stable wire protocol: adding another mod must never renumber an existing route.
Circuit.planets={[1]='nauvis',[2]='vulcanus',[3]='fulgora',[4]='gleba',[5]='aquilo',[6]='shattered-planet'}
Circuit.codes={};for code,name in pairs(Circuit.planets) do Circuit.codes[name]=code end
local keys={'inner_input','inner_output','outer_input','outer_output'}
local function valid(e) return e and e.valid end
local function clamp(v) return math.max(-2147483648,math.min(2147483647,math.floor(v or 0))) end
local function state(f)
 f.circuit=f.circuit or {edges={},last_result=0}
 f.circuit.edges=f.circuit.edges or {}
 return f.circuit
end
local function create_terminal(f,key,surface,position,kind)
 local c=state(f)
 if valid(c[key]) then return end
 if not (surface and surface.valid) then return end
 local name='tardis-circuit-'..kind
 local at=surface.find_non_colliding_position(name,position,4,.5)
 if not at then return end
 local e=surface.create_entity{name=name,position=at,force=f.force,direction=defines.direction.south,create_build_effect_smoke=false}
 if not e then return end
 e.destructible=false;e.minable=false;e.operable=false
 e.get_or_create_control_behavior().enabled=kind=='output'
 c[key]=e
end
function Circuit.create(f)
 create_terminal(f,'inner_input',f.surface,{24.5,1.5},'input')
 create_terminal(f,'inner_output',f.surface,{27.5,1.5},'output')
 if valid(f.box) then
  local b=f.box.position
  create_terminal(f,'outer_input',f.box.surface,{b.x-2.5,b.y},'input')
  create_terminal(f,'outer_output',f.box.surface,{b.x+2.5,b.y},'output')
 end
end
function Circuit.destroy(f,outside_only)
 local c=f.circuit;if not c then return end
 for _,key in ipairs(keys) do
  if not outside_only or key:sub(1,5)=='outer' then
   if valid(c[key]) then c[key].destroy() end;c[key]=nil
  end
 end
 -- Do not reset an outside high latch at landing. A continuously high command
 -- must not turn into a new edge just because the box has materialised elsewhere.
 if not outside_only then f.circuit=nil end
end
local function read(entity)
 if not valid(entity) then return {} end
 -- Players can connect red and green wires but cannot configure this silent input.
 entity.get_or_create_control_behavior().enabled=false
 local signals=entity.get_signals(defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green) or {}
 local values={}
 for _,s in ipairs(signals) do
  if s.signal.type=='virtual' and s.signal.name:sub(1,14)=='tardis-signal-' then
   values[s.signal.name:sub(15)]=s.count
  end
 end
 return values
end
local function resolve_destination(f,code)
 local name=Circuit.planets[code]
 if not name then return nil,'Неизвестный код планеты: '..tostring(code)..'.' end
 local planet=game.planets[name]
 if not planet then return nil,'Планета недоступна в этой партии.' end
 if not Voyage.is_unlocked(f.force,name) then return nil,'Планета ещё не исследована.' end
 return planet.surface or planet.create_surface()
end
local function command(f,M,values)
 local c=f.circuit
 if c.inhibit then c.last_result=-4;c.last_error='Прыжки заблокированы логической сетью.';return end
 if f.flight then c.last_result=-3;c.last_error='ТАРДИС уже в полёте.';return end
 local destination,err=resolve_destination(f,values.destination or 0)
 if not destination then c.last_result=-2;c.last_error=err;return end
 local ok,message=M.jump(f.id,destination.index,values.x or 0,values.y or 0)
 c.last_result=ok and 1 or -1;c.last_error=ok and nil or message
 c.last_command_tick=game.tick
end
local function filter(kind,name,count,quality)
 return {value={type=kind,name=name,quality=quality or 'normal',comparator='='},min=clamp(count)}
end
local function write_output(entity,filters)
 if not valid(entity) then return end
 local behavior=entity.get_or_create_control_behavior();behavior.enabled=true
 -- 100 slots per section keeps the native section UI and modded inventories bounded.
 local needed=math.max(1,math.ceil(#filters/100))
 for i=1,needed do
  local section=behavior.get_section(i) or behavior.add_section()
  if section then
   local subset={}
   for j=(i-1)*100+1,math.min(i*100,#filters) do subset[#subset+1]=filters[j] end
   section.group='';section.active=true;section.multiplier=1;section.filters=subset
  end
 end
 for i=behavior.sections_count,needed+1,-1 do behavior.remove_section(i) end
end
function Circuit.origin(f)
 local surface=valid(f.box) and f.box.surface or (f.last_location and game.get_surface(f.last_location.surface))
 return surface and Circuit.codes[surface.planet and surface.planet.name or surface.name] or 0
end
function Circuit.status(f,M)
 local c=state(f);local contents=f.cargo.valid and f.cargo.get_contents() or {}
 table.sort(contents,function(a,b) return a.name==b.name and a.quality<b.quality or a.name<b.name end)
 local total=0;for _,v in ipairs(contents) do total=total+v.count end
 local energy=M.total_energy(f)
 local ready=valid(f.box) and not f.flight and not c.inhibit
 if ready then
  if M.jump_ready then ready=M.jump_ready(f)
  else ready=Voyage.can_fly(f) and energy>=Voyage.base_cost end
 end
 local values={energy=math.floor(energy/1e6),charge=math.floor(100*energy/M.C.capacity),
  busy=f.flight and 1 or 0,ready=ready and 1 or 0,origin=Circuit.origin(f),items=total,
  ['free-slots']=f.cargo.valid and f.cargo.count_empty_stacks(true) or 0,result=c.last_result or 0}
 local output={}
 for _,key in ipairs{'energy','charge','busy','ready','origin','items','free-slots','result'} do
  output[#output+1]=filter('virtual','tardis-signal-'..key,values[key])
 end
 for _,v in ipairs(contents) do output[#output+1]=filter('item',v.name,v.count,v.quality) end
 return output,values
end
function Circuit.tick(f,M)
 if game.tick%30~=0 then return end
 Circuit.create(f)
 local c=state(f);local a,b=read(c.inner_input),read(c.outer_input)
 c.inhibit=(a.inhibit or 0)>0 or (b.inhibit or 0)>0
 -- A connected nonzero command owns export while held; zero returns control to UI.
 -- Interior input wins if both terminals send conflicting export commands.
 local export=(a.export or 0)~=0 and a.export or b.export or 0
 if export~=0 then f.export=export>0 end
 local acted=false
 for i,values in ipairs{a,b} do
  local high=(values.jump or 0)>0
  if high and not c.edges[i] then
   if not acted then command(f,M,values);acted=true end
  end
  c.edges[i]=high
 end
 local output=Circuit.status(f,M)
 write_output(c.inner_output,output);write_output(c.outer_output,output)
end
return Circuit
