-- Story and navigation rules shared by the console, circuit input and remote API.
-- All prices use the installed game's space-connection graph, never surface indices.
local Core=require('twelve.eye-core')
local V={base_cost=100e6,joules_per_km=1000,return_cost=1e9,final_location='shattered-planet',EyeCore=Core}
V.order={'console','eye','stabilizer'}
V.plans={
 console={title='Матрица управления',icon='electronic-circuit',
  description='Починить повреждённую кораблём инженера консоль и восстановить сообщение Доктора.',
  cost={{name='iron-plate',count=100},{name='copper-plate',count=50},{name='electronic-circuit',count=20},{name='repair-pack',count=20}}},
 eye={title='Око Гармонии',icon='nuclear-reactor',previous='console',technology='chemical-science-pack',
  description='Спуститесь через люк и восстановите четыре энергомашины у звезды. Выработка растёт по мере ремонта: 0 → 20 → 40 → 50 МВт.',
  cost={{name='steel-plate',count=200},{name='advanced-circuit',count=100},{name='battery',count=100},{name='processing-unit',count=20}}},
 stabilizer={title='Пространственный стабилизатор',icon='quantum-processor',previous='eye',technology='promethium-science-pack',
  description='Вернуть полную целостность кораблю. Открывает последний перелёт к Разрушенной планете и возвращение Доктору.',
  cost={{name='tungsten-plate',count=100},{name='holmium-plate',count=100},{name='carbon-fiber',count=100},{name='lithium-plate',count=50},{name='quantum-processor',count=25}}}
}
V.doctor_message='Если вы слышите это, вы уже познакомились с моей ТАРДИС. Судя по повреждениям, знакомство было громким. Почините Око Гармонии и пространственный стабилизатор. Затем отыщите Разрушенную планету за границей этой солнечной системы: там ещё держится след моей временной линии. Отправьте её по этому следу. И, пожалуйста, выйдите перед отправкой. — Доктор'
local function valid(e) return e and e.valid end
local unlock_technologies
local function energy(f)
 local n=f.energy or 0
 for _,key in ipairs{'power','inner_power','eye_power'} do if valid(f[key]) then n=n+f[key].energy end end
 return n
end
function V.ensure(f,legacy)
 if not f.voyage then
  f.voyage={console=legacy==true,eye=legacy==true,stabilizer=false,message=legacy==true,returned=false,revision=1}
  -- Existing ships keep their working generator and reserve. A new wreck has no free reactor.
  if not legacy then f.energy=math.min(f.energy or 0,100e6) end
 end
 Core.ensure(f)
 return f.voyage
end
function V.can_fly(f)
 local q=V.ensure(f,false)
 if q.returned then return false,'ТАРДИС уже возвращена Доктору.' end
 if not q.console then return false,'Сначала восстановите матрицу управления во вкладке «Восстановление».' end
 if not q.eye then return false,'Для полёта восстановите все четыре энергомашины нижнего зала Ока Гармонии.' end
 if f.flight then return false,'ТАРДИС уже в полёте.' end
 return true
end
function V.recharge(f)
 V.ensure(f,false)
 return Core.recharge(f)
end
function V.origin(f)
 local surface=valid(f.box) and f.box.surface or (f.last_location and game.get_surface(f.last_location.surface))
 return surface and surface.planet and surface.planet.name or nil
end
function V.location(target)
 if type(target)=='string' and prototypes.space_location[target] then return target end
 if type(target)=='number' or type(target)=='string' then target=game.get_surface(target) end
 return target and target.valid and target.planet and target.planet.name or nil
end
function V.is_unlocked(force,name)
 if not force.is_space_location_unlocked(name) then return false end
 if not unlock_technologies then
  unlock_technologies={}
  for tech_name,prototype in pairs(prototypes.technology) do
   for _,effect in pairs(prototype.effects) do
    if effect.type=='unlock-space-location' then
     local list=unlock_technologies[effect.space_location] or {}
     list[#list+1]=tech_name;unlock_technologies[effect.space_location]=list
    end
   end
  end
 end
 -- Version 1.2 could set the force unlock flag through its free-navigation mode.
 -- Research remains authoritative even when that old flag survives migration.
 local choices=unlock_technologies[name]
 if not choices then return true end
 for _,tech_name in ipairs(choices) do
  local tech=force.technologies[tech_name]
  if tech and tech.researched then return true end
 end
 return false
end
function V.distance(origin,target)
 if not origin or not target then return nil end
 if origin==target then return 0,{origin} end
 local graph={}
 for _,edge in pairs(prototypes.space_connection) do
  local a,b=edge.from.name,edge.to.name
  graph[a]=graph[a] or {};graph[b]=graph[b] or {}
  local n=edge.length
  graph[a][b]=math.min(graph[a][b] or math.huge,n)
  graph[b][a]=math.min(graph[b][a] or math.huge,n)
 end
 local distances={[origin]=0};local visited={};local previous={}
 while true do
  local current,best=nil,math.huge
  for name,n in pairs(distances) do
   if not visited[name] and (n<best or (n==best and (not current or name<current))) then current,best=name,n end
  end
  if not current then return nil end
  if current==target then
   local path={target};local at=target
   while previous[at] do at=previous[at];table.insert(path,1,at) end
   return best,path
  end
  visited[current]=true
  for name,length in pairs(graph[current] or {}) do
   local n=best+length
   if n<(distances[name] or math.huge) then distances[name]=n;previous[name]=current end
  end
 end
end
function V.quote(f,target)
 local destination=V.location(target);local origin=V.origin(f)
 local q={ok=false,origin=origin,target=destination,cost=0,distance=0,path={}}
 if not destination or not game.planets[destination] then q.error='Выберите поверхность планеты.';return q end
 if not origin then q.error='Не удалось определить планету последней посадки.';return q end
 local distance,path=V.distance(origin,destination)
 if not distance then q.error='Между планетами нет известного космического маршрута.';return q end
 q.distance=distance;q.path=path;q.cost=math.ceil(V.base_cost+distance*V.joules_per_km)
 if not V.is_unlocked(f.force,destination) then q.error='Планета ещё не открыта исследованиями вашей команды.';return q end
 local fly,reason=V.can_fly(f)
 if not fly then q.error=reason;return q end
 if destination==V.final_location and not f.voyage.stabilizer then q.error='Для полёта к Разрушенной планете восстановите пространственный стабилизатор.';return q end
 if energy(f)<q.cost then q.error=string.format('Недостаточно энергии: нужно %.1f МДж. Отключите отдачу в сеть и дождитесь зарядки.',q.cost/1e6);return q end
 q.ok=true;return q
end
function V.missing(f,key)
 local plan=V.plans[key];if not plan then return nil end
 local missing={}
 for _,item in ipairs(plan.cost) do
  local have=f.cargo.get_item_count{name=item.name,quality='normal'}
  if have<item.count then missing[#missing+1]={name=item.name,count=item.count-have} end
 end
 return missing
end
function V.repair_ready(f,key)
 local state=V.ensure(f,false);local plan=V.plans[key]
 if not plan then return false,'Неизвестный узел корабля.' end
 if state.returned then return false,'ТАРДИС уже возвращена Доктору.' end
 if f.flight then return false,'Завершите перелёт перед ремонтом.' end
 if state[key] then return false,'Этот узел уже восстановлен.' end
 if key=='eye' then return false,'Спуститесь через люк к Оку и ремонтируйте каждую энергомашину рядом с ней. Сводная починка с консоли недоступна.' end
 if plan.previous and not state[plan.previous] then return false,'Сначала восстановите предыдущий узел корабля.' end
 if plan.technology then
  local tech=f.force.technologies[plan.technology]
  if not tech or not tech.researched then return false,plan.technology=='promethium-science-pack' and 'Сначала исследуйте прометиевую науку и границу солнечной системы.' or 'Сначала исследуйте химическую науку.' end
 end
 if #V.missing(f,key)>0 then return false,'На складе недостаточно материалов обычного качества.' end
 return true
end
function V.repair(player,f,key)
 if not player or not player.valid or player.force~=f.force or (player.physical_surface~=f.surface and player.physical_surface~=f.eye_surface) then return false,'Восстановление доступно только изнутри своей ТАРДИС.' end
 local ok,reason=V.repair_ready(f,key);if not ok then return false,reason end
 -- The event executes atomically after all normal-quality counts have been checked.
 for _,item in ipairs(V.plans[key].cost) do
  local removed=f.cargo.remove{name=item.name,count=item.count,quality='normal'}
  assert(removed==item.count,'TARDIS repair payment changed during an atomic event')
 end
 f.voyage[key]=true;f.voyage.revision=f.voyage.revision+1
 if key=='console' then
  f.voyage.message=true;f.force.print('[color=120,205,230]Восстановленная запись Доктора[/color]\n'..V.doctor_message)
  return true,'Матрица восстановлена. Сообщение Доктора расшифровано; теперь восстановите Око Гармонии.'
 end
 return true,'Корабль полностью восстановлен. Последняя цель — Разрушенная планета за границей солнечной системы.'
end
function V.return_ready(f)
 local state=V.ensure(f,false)
 if state.returned then return false,'ТАРДИС уже возвращена Доктору.' end
 if not state.console or not state.eye or not state.stabilizer then return false,'Перед отправкой полностью восстановите ТАРДИС.' end
 if f.flight then return false,'Дождитесь посадки.' end
 if V.origin(f)~=V.final_location or not valid(f.box) then return false,'Отправка Доктору возможна только после посадки на Разрушенной планете.' end
 if not V.is_unlocked(f.force,V.final_location) then return false,'Сначала исследуйте прометиевую науку.' end
 if energy(f)<V.return_cost then return false,'Для возвращения по временной линии нужен резерв 1 ГДж.' end
 return true
end
function V.mark_returned(f)
 -- Root model must evacuate players and retain cargo/interior before marking the story complete.
 local ok,reason=V.return_ready(f);if not ok then return false,reason end
 f.voyage.returned=true;f.voyage.returned_tick=game.tick;f.voyage.revision=f.voyage.revision+1
 f.force.print('[color=120,205,230]Сообщение Доктора[/color]\nВот она. Моя невозможная девочка, снова дома. Спасибо, инженер. Берегите свою планету. И на этот раз смотрите, куда приземляетесь.\nИстория «Возвращение ТАРДИС» завершена.')
 return true,'ТАРДИС возвращена Доктору. История завершена.'
end
function V.info(f)
 local q=V.ensure(f,false);local next_repair
 for _,key in ipairs(V.order) do if not q[key] then next_repair=key;break end end
 local stage=q.returned and 'Возвращена Доктору' or q.stabilizer and 'Курс на Разрушенную планету' or q.eye and 'Восстановить стабилизатор' or q.console and 'Восстановить Око Гармонии' or 'Повреждена при крушении'
 return {stage=stage,next_repair=next_repair,console=q.console,eye=q.eye,stabilizer=q.stabilizer,returned=q.returned,
  message=q.message and V.doctor_message or 'Сигнал повреждён. Восстановите матрицу управления, чтобы прочитать сообщение.',
  recharge=V.recharge(f),eye_modules=Core.count(f),origin=V.origin(f),final_location=V.final_location,return_cost=V.return_cost,revision=q.revision}
end
return V
