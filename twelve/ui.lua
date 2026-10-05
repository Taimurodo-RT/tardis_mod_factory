local M=require('twelve.model')
local UI={}
local C=M.C
local V=M.Voyage or require('twelve.voyage')
local Core=M.EyeCore or require('twelve.eye-core')
local function root() return storage.twelve end
local function state(p) root().players[p.index]=root().players[p.index] or {};return root().players[p.index] end
local systems={
 {panel='navigation',title='Навигация',code='01'}, {panel='warehouse',title='Хранилище',code='02'},
 {panel='reactor',title='Энергия',code='03'}, {panel='ports',title='Шлюзы / Сеть',code='04'},
 {panel='rooms',title='Архитектура',code='05'}, {panel='restoration',title='Ремонт',heading='Хроника корабля',code='06'},
 {panel='eye',title='Око Гармонии',code='07'}
}
local function dimensions(p)
 local width=p.display_resolution.width/p.display_scale
 local height=p.display_resolution.height/p.display_scale
 local pane=math.min(820,math.max(640,width-220))
 return {rail=148,pane=pane,content=pane-24,width=pane+188,height=math.max(440,math.min(840,height-32))}
end
local function canvas(element)
 local p=game.get_player(element.player_index)
 return dimensions(p).content
end
local function scaled(element,width) return math.floor(width*canvas(element)/812) end
local function shell(element)
 while element and element.name~='t12' do element=element.parent end
 return element
end
local defaults={textfield='t12_field',['drop-down']='t12_dropdown',checkbox='t12_checkbox',['sprite-button']='t12_sprite_button',['choose-elem-button']='t12_slot'}
local function add(parent,t,name,caption,extra)
 local v={type=t,name=name,caption=caption,style=defaults[t]};for k,x in pairs(extra or {}) do v[k]=x end;return parent.add(v)
end
local function flow(p,name) return add(p,'flow',name,nil,{direction='horizontal'}) end
local function label(p,text) return add(p,'label',nil,text,{style='t12_text'}) end
local function button(p,name,text,tags) return add(p,'button',name,text,{tags=tags or {},style='t12_button'}) end
local function field(p,name,text,width) local e=add(p,'textfield',name,nil,{text=tostring(text)});e.style.width=scaled(p,width or 110);return e end
local help_text={
 ['Новые маршруты появляются после исследования планет. Отсчёт расстояния — от текущей посадки; 100 МДж на запуск и 1 кДж на километр.']='Следуйте открытым мирам. Расход: 100 МДж + 1 кДж/км.',
 ['Выберите предмет для точного фильтра по качеству. Щелчок: взять стак; Shift: взять всё доступное. Передача предметов доступна внутри Тардис.']='Щелчок — стак. Shift — всё. Фильтр учитывает качество.',
 ['Оборудование, качество, теги и порча сохраняются. Складские комнаты добавляют по 4096 ячеек — до 32 768. Ресурсы для строительства берутся отсюда.']='Содержимое стека сохраняется. Складской модуль: +4096 ячеек.',
 ['Общий резерв — 10 ГДж. Контур удержания открывает ремонт коллекторов: каждый даёт 20 МВт, преобразователь после обоих добавляет 10 МВт. Для полёта нужны все четыре исправные энергомашины.']='Один резерв на весь корабль. Отдача Ока: 0 → 20 → 40 → 50 МВт.',
 ['Подключите фабрику к энергетическому разъёму рядом с будкой. Выдача учитывает реальное потребление: подключение пустой сети не разряжает резерв. Разъём путешествует вместе с Тардис.']='Разъёмы передают энергию по фактической нагрузке.',
 ['При нагрузке выше выработки запас уменьшается. Если энергии не хватает на выбранный маршрут, ТАРДИС не взлетит. Отключите выдачу в сети или снизьте нагрузку завода и дождитесь заряда.']='Перерасход истощает резерв. Для полёта нужен заряд на весь маршрут.',
 ['Снаружи поставьте входной/выходной порт не дальше 8 клеток от будки; эти порты остаются на планете. Внутри порты работают во всех комнатах и во время полёта, снабжая мобильный завод из общего склада.']='Внешние шлюзы: до 8 клеток от будки. Внутренние: на обеих палубах.',
 ['Вход без фильтра принимает любые предметы. Выход без фильтра ничего не выдаёт. «Оставить» — неснижаемый запас выбранного предмета на складе. До 500 предметов за цикл, два цикла в секунду.']='Вход принимает всё. Выходу нужен фильтр. Остаток защищает запас.',
 ['Вход — логистический сундук запроса, выход — пассивное снабжение. Запросы роботов настраиваются в обычном окне сундука; манипуляторы работают как обычно.']='Роботы и манипуляторы обслуживают шлюзы как обычные сундуки.',
 ['Отдельные вход и выход находятся по бокам будки и в грузовом отсеке. Подайте команды на вход, читайте состояние со выхода; не объединяйте их одним проводом. Грузовые порты подключают предметы к общей фабрике, сигнальные терминалы управляют кораблём.']='Янтарный терминал принимает команды. Голубой передаёт состояние.',
 ['При крушении корабль инженера врезался в ТАРДИС. Ремонтируйте узлы по порядку, снабжая общий склад через грузовые порты или вручную. Используются материалы обычного качества.']='След аварии сохранился в памяти корабля. Восстановите повреждённые системы.',
 ['Сначала контур удержания, затем два коллектора в любом порядке, последним — преобразователь. Нужны исправная матрица и химическая наука. Частичная отдача заряжает резерв, но для полёта исправными должны быть все четыре машины.']='Удержание → два коллектора → преобразователь. Ремонт — возле машины.',
 ['Входные грузовые порты также снабжают строительство. Отменить можно формирование комнаты; готовые комнаты остаются частью корабля.']='Материалы поступают из общего склада. Готовые комнаты остаются с кораблём.'
}
local function note(parent,text)
 local brief=type(text)=='string' and help_text[text]
 local e=label(parent,brief or text);e.style='t12_muted';e.style.single_line=false;e.style.maximal_width=canvas(parent)
 if brief then e.tooltip=text end
 return e
end
local function access(p,f) return M.is_inside and M.is_inside(p,f) or p.physical_surface==f.surface or p.physical_surface==f.eye_surface end
local function valid(e) return e and e.valid end
local function near_hatch(p,f,lower)
 if M.Eye then
  local fn=lower and M.Eye.can_leave or M.Eye.can_enter
  if fn then return fn(p,f) end
 end
 local surface=lower and f.eye_surface or f.surface
 if not valid(surface) or p.physical_surface~=surface or not valid(p.character) then return false end
 local room=f.eye_room;local entity=room and (lower and room.ladder or room.hatch)
 if not valid(entity) then return false end
 local a,b=p.physical_position,entity.position
 return (a.x-b.x)^2+(a.y-b.y)^2<=16
end
local function near_entry(p,f)
 local e=valid(f.box) and f.box or f.anchor
 return valid(e) and p.physical_surface==e.surface and (p.physical_position.x-e.position.x)^2+(p.physical_position.y-e.position.y)^2<100
end
local function sprite(parent,path,size,name)
 local icon=add(parent,'sprite',name,nil,{sprite=path,resize_to_sprite=false})
 icon.style.size=size;icon.style.stretch_image_to_widget_size=true;return icon
end
local function wrapped(parent,name,text,width,style)
 local e=add(parent,'label',name,text,{style=style or 't12_text'});e.style.single_line=false;e.style.maximal_width=scaled(parent,width or 810);return e
end
local function planet_name(name) return name and prototypes.space_location[name] and prototypes.space_location[name].localised_name or '—' end
local function tell(p,text) state(p).message=text;p.print(text) end
local function close(p)
 local f=p.gui.screen.t12;if f then f.destroy() end
end
local function panel(f,n,title,p)
 local d=dimensions(p)
 local tab=f.add{type='tab',caption='',style='t12_tab_hidden'}
 local content=f.add{type='scroll-pane',name=n,horizontal_scroll_policy='never',vertical_scroll_policy='auto',style='t12_scroll'}
 content.style.width=d.pane;content.style.height=d.height-24
 f.add_tab(tab,content);tab.visible=false
 return content
end
local function refresh(p,tab) UI.open(p,state(p).ship,tab) end
local function heading(parent,code,title)
 if parent.type=='scroll-pane' and parent.parent.name=='t12_tabs' and not parent['system-header'] then
  local row=flow(parent,'system-header');row.style.width=canvas(parent);row.style.vertical_align='center'
  sprite(row,'t12-gallifreyan-seal',36,'system-glyph')
  local brand=add(row,'flow','system-brand',nil,{direction='vertical'})
  local system=systems[tonumber(code)]
  label(brand,'TYPE 40  /  '..code..'  /  ТАРДИС XII').style='t12_muted'
  local name=wrapped(brand,'system-title',system and (system.heading or system.title) or title,660,'t12_title')
  local drag=add(row,'empty-widget','drag');drag.style.horizontally_stretchable=true;drag.style.height=46;drag.drag_target=shell(parent)
  local x=button(row,'t12-close','×');x.style.width=32;x.style.minimal_width=32;x.tooltip='Закрыть пульт'
  wrapped(parent,'status','',810,'t12_subtitle')
  local bar=add(parent,'progressbar','energy',nil,{style='t12_progress',value=0});bar.style.width=canvas(parent)
  return
 end
 local row=flow(parent,nil);label(row,code).style='t12_subtitle';wrapped(row,nil,'  /  '..title,750,'t12_subtitle')
end
local function metric(parent,name,title,value)
 local card=add(parent,'frame',name,nil,{direction='vertical',style='t12_card'});card.style.width=math.floor((canvas(parent)-16)/3)
 label(card,title).style='t12_muted';add(card,'label','t12_metric',value,{style='t12_subtitle'});return card
end
local function select_system(p,frame,index)
 index=math.max(1,math.min(#systems,index or 1));frame.t12_tabs.selected_tab_index=index;state(p).tab=index
 local buttons=frame.t12_rail.systems
 for i,v in ipairs(systems) do
  local b=buttons['t12-system-'..i];b.style=i==index and 't12_rail_active' or 't12_rail_button'
  b.style.width=dimensions(p).rail-16;b.style.height=38
 end
end
local function update_planets(p,f,parent)
 local st=state(p);local planets,items={},{}
 for name,planet in pairs(game.planets) do
  if not planet.prototype.hidden and V.is_unlocked(p.force,name) then planets[#planets+1]=name end
 end
 table.sort(planets,function(a,b)
  local aa=M.Circuit.codes[a] or 99;local bb=M.Circuit.codes[b] or 99
  return aa==bb and a<b or aa<bb
 end)
 for _,name in ipairs(planets) do items[#items+1]=planet_name(name) end
 local key=table.concat(planets,'|')..':'..(st.planet or '')
 if st.planet_key==key and parent['planet-cards'].children[1] then return end
 st.planets=planets
 local idx=0;for i,name in ipairs(planets) do if st.planet==name then idx=i end end
 if idx==0 then idx=#planets>0 and 1 or 0;st.planet=planets[idx] end
 local dd=parent.destination['t12-planet'];dd.items=items;dd.selected_index=idx
 local cards=parent['planet-cards'];cards.clear()
 for _,name in ipairs(planets) do
  local card=add(cards,'frame','planet-'..name,nil,{direction='vertical',style=name==st.planet and 't12_amber_card' or 't12_card'});card.style.width=math.floor((canvas(parent)-30)/6)
  local b=add(card,'sprite-button','t12-planet-card-'..name,nil,{sprite='space-location/'..name,tags={planet=name},style='t12_slot',tooltip=planet_name(name)})
  b.style.size=48
  wrapped(card,nil,planet_name(name),108,'t12_muted')
 end
 st.planet_key=table.concat(planets,'|')..':'..(st.planet or '')
end
local function update_preview(p,parent)
 local st=state(p);local holder=parent['flight-view']['landing-preview']
 local planet=st.planet and game.planets[st.planet];local surface=planet and planet.surface
 local x,y=st.x or 0,st.y or 0;local charted=surface~=nil and math.abs(x)<=100000 and math.abs(y)<=100000
 if charted then
  -- The entire camera frame must be charted. Do not reveal neighbouring black chunks.
  for cx=math.floor((x-32)/32),math.floor((x+32)/32) do for cy=math.floor((y-32)/32),math.floor((y+32)/32) do
   if not p.force.is_chunk_charted(surface,{cx,cy}) then charted=false end
  end end
 end
 local key=(st.planet or '')..':'..x..':'..y..':'..tostring(charted)
 if holder.tags.preview_key==key then return end
 holder.tags={preview_key=key};holder.clear()
 label(holder,'РАЙОН ПОСАДКИ').style='t12_muted'
 if charted then
  local cam=add(holder,'camera','landing-camera',nil,{position={x,y},surface_index=surface.index,zoom=.4})
  cam.style.width=scaled(parent,360);cam.style.height=170
 else
  sprite(holder,planet and 'space-location/'..st.planet or 'item/tardis',96)
  wrapped(holder,nil,'Область ещё не разведана.',350,'t12_muted')
 end
end
local function update_navigation(p,f,parent)
 local st=state(p);update_planets(p,f,parent)
 local q=V.quote(f,st.planet);local left=parent['flight-view']['route-card']
 left['route-origin'].caption={'','ОТКУДА  ',planet_name(q.origin)}
 left['route-target'].caption={'','КУДА  ',planet_name(st.planet)}
 left['route-distance'].caption=string.format('ДИСТАНЦИЯ   %s км',q.distance or 0)
 left['route-cost'].caption=string.format('СТОИМОСТЬ   %.1f МДж',q.cost/1e6)
 local route={''};for i,name in ipairs(q.path or {}) do if i>1 then route[#route+1]=' → ' end;route[#route+1]=planet_name(name) end
 left['route-path'].caption=route
 local blocked=f.circuit and f.circuit.inhibit
 parent['flight-reason'].caption=blocked and 'Логическая сеть блокирует прыжки: сигнал запрета активен.' or q.error or 'Маршрут согласован. Координаты готовы к материализации.'
 parent.destination['t12-jump'].enabled=q.ok and not blocked and valid(f.box)
 parent.destination['t12-jump'].tooltip=q.error or string.format('Расход %.1f МДж. Время в вихре — 3 секунды.',q.cost/1e6)
 if parent['t12-return'] then
  local prev=f.previous and game.get_surface(f.previous.surface)
  parent['t12-return'].enabled=prev~=nil and V.quote(f,prev).ok and not blocked
 end
 parent.actions['t12-enter'].enabled=not access(p,f) and near_entry(p,f) and not f.flight
 local below=p.physical_surface==f.eye_surface
 local leave=parent.actions['t12-leave'];leave.caption=below and 'Подняться к консоли' or 'Выйти'
 local nearby,why=near_hatch(p,f,true)
 leave.enabled=access(p,f) and not f.flight and (not below or nearby)
 leave.tooltip=below and (why or 'Подняться по лестнице у южного входа в зал Ока.') or 'Выйти к месту посадки ТАРДИС.'
 parent.actions['t12-recall'].enabled=not access(p,f) and not f.voyage.returned and not f.flight
 for i,v in ipairs(f.bookmarks) do
  local row=parent.bookmarks['bm'..i];local surface=game.get_surface(v.surface)
  if row then row['t12-bookmark-go-'..i].enabled=surface~=nil and V.quote(f,surface).ok and not blocked end
 end
 update_preview(p,parent)
end
local function navigation(p,f,parent)
 heading(parent,'01','НАВИГАЦИЯ / ИЗУЧЕННЫЕ МИРЫ')
 note(parent,'Новые маршруты появляются после исследования планет. Отсчёт расстояния — от текущей посадки; 100 МДж на запуск и 1 кДж на километр.')
 local cards=add(parent,'table','planet-cards',nil,{column_count=6});cards.style.horizontal_spacing=6
 local view=flow(parent,'flight-view')
 local route=add(view,'frame','route-card',nil,{direction='vertical',style='t12_card'});route.style.width=scaled(parent,410);route.style.minimal_height=220
 wrapped(route,'route-origin','',386,'t12_muted');wrapped(route,'route-target','',386,'t12_subtitle')
 wrapped(route,'route-distance','',386);wrapped(route,'route-cost','',386,'t12_subtitle');wrapped(route,'route-path','',386,'t12_muted')
 local dial=add(route,'sprite','route-dial',nil,{sprite='t12-route-dial',resize_to_sprite=false});dial.style.width=scaled(parent,240);dial.style.height=scaled(parent,120);dial.style.stretch_image_to_widget_size=true;dial.tooltip='Временной контур маршрута'
 local preview=add(view,'frame','landing-preview',nil,{direction='vertical',style='t12_card'});preview.style.width=scaled(parent,390);preview.style.minimal_height=220
 local row=flow(parent,'destination')
 local dd=add(row,'drop-down','t12-planet',nil,{items={},selected_index=0});dd.style.width=scaled(parent,210)
 label(row,'X');field(row,'t12-x',state(p).x or 0,90);label(row,'Y');field(row,'t12-y',state(p).y or 0,90)
 local jump=button(row,'t12-jump','ПРЫЖОК');jump.style='t12_primary';jump.style.width=scaled(parent,225)
 wrapped(parent,'flight-reason','',810,'t12_muted')
 if f.previous then button(parent,'t12-return','← Предыдущее место посадки') end
 local b=flow(parent,'bookmark');field(b,'t12-bookmark-name',state(p).bookmark_name or 'Моя база',260)
 button(b,'t12-save-bookmark','Запомнить текущую посадку')
 local scroll=add(parent,'scroll-pane','bookmarks');scroll.style.maximal_height=165
 for i,v in ipairs(f.bookmarks) do
  local r=flow(scroll,'bm'..i);local s=game.get_surface(v.surface)
  local l=label(r,{'',v.name,' — ',s and M.surface_name(s) or 'удалена',' (',math.floor(v.x),', ',math.floor(v.y),')'});l.style.width=scaled(parent,530)
  button(r,'t12-bookmark-go-'..i,'Полететь',{bookmark=i})
  button(r,'t12-bookmark-delete-'..i,'×',{bookmark=i})
 end
 local r=flow(parent,'actions')
 button(r,'t12-enter','Войти').enabled=not access(p,f) and near_entry(p,f)
 button(r,'t12-leave','Выйти').enabled=access(p,f)
 button(r,'t12-recall','Призвать к себе').enabled=not access(p,f)
 note(parent,f.room_layout_version==1 and 'На юге круглого зала — большая синяя дверь выхода. Сохранено прежнее восточное крыло: комнаты за грузовым отсеком. Люк возле консоли ведёт вниз, в зал звезды Ока Гармонии.' or 'На юге круглого зала — большая синяя дверь выхода. Северный проход ведёт к ветвям комнат; восточный — к грузовому отсеку. Люк возле консоли ведёт на нижний уровень Ока Гармонии.')
 update_navigation(p,f,parent)
end
local function warehouse(p,f,parent)
 heading(parent,'02','ПРОСТРАНСТВЕННЫЙ БУФЕР')
 local st=state(p);st.page=st.page or 1
 local r=flow(parent,'cargo-tools');field(r,'t12-search',st.search or '',220).tooltip='Поиск по русскому названию или внутреннему имени. Enter — найти.'
 add(r,'choose-elem-button','t12-filter',nil,{elem_type='item-with-quality',['item-with-quality']=st.filter})
 button(r,'t12-refresh','Обновить');button(r,'t12-deposit','Положить всё').enabled=access(p,f)
 button(r,'t12-upgrade','Расширить склад').enabled=#f.cargo<C.max_slots
 note(parent,'Выберите предмет для точного фильтра по качеству. Щелчок: взять стак; Shift: взять всё доступное. Передача предметов доступна внутри Тардис.')
 local counts=f.cargo.get_contents();local list={};st.translations=st.translations or {};st.pending=st.pending or {}
 for _,v in pairs(counts) do
  local quality=type(v.quality)=='string' and v.quality or v.quality.name
  local key=v.name..'/'..quality
  if not st.translations[v.name] then local id=p.request_translation(prototypes.item[v.name].localised_name);if id then st.pending[id]=v.name end end
  local search=string.lower(st.search or '')
  local text=string.lower(v.name..' '..(st.translations[v.name] or ''))
  if (search=='' or text:find(search,1,true)) and (not st.filter or (v.name==st.filter.name and quality==(st.filter.quality or 'normal'))) then
   list[#list+1]={name=v.name,quality=quality,count=v.count,key=key}
  end
 end
 table.sort(list,function(a,b) return a.key<b.key end)
 local pages=math.max(1,math.ceil(#list/24));st.page=math.min(st.page,pages)
 local grid=add(parent,'table','cargo-grid',nil,{column_count=4});grid.style.horizontal_spacing=8
 for i=(st.page-1)*24+1,math.min(st.page*24,#list) do
  local v=list[i];local cell=flow(grid,'item-'..i)
  local icon=add(cell,'sprite-button','t12-item-'..i,nil,{sprite='item/'..v.name,number=v.count,
    tags={item=v.name,quality=v.quality},tooltip={'',prototypes.item[v.name].localised_name,' / ',prototypes.quality[v.quality].localised_name,'\n',v.count,' шт.\nЛКМ: стак, Shift: всё'},style='t12_slot'})
  icon.enabled=access(p,f)
  local l=label(cell,{'',prototypes.item[v.name].localised_name,'\n',prototypes.quality[v.quality].localised_name})
  l.style.width=scaled(parent,140);l.style.single_line=false
 end
 local paging=flow(parent,'paging');button(paging,'t12-prev','←').enabled=st.page>1
 label(paging,st.page..' / '..pages);button(paging,'t12-next','→').enabled=st.page<pages
 label(paging,'  Занято '..(#f.cargo-f.cargo.count_empty_stacks())..' / '..#f.cargo..' ячеек')
 note(parent,'Оборудование, качество, теги и порча сохраняются. Складские комнаты добавляют по 4096 ячеек — до 32 768. Ресурсы для строительства берутся отсюда.')
end
local function energy(p,f,parent)
 heading(parent,'03','ОКО ГАРМОНИИ / ЭНЕРГЕТИЧЕСКИЕ КОНТУРЫ')
 local gauges=flow(parent,'reactor-gauges')
 metric(gauges,'source','ВЫРАБОТКА ОКА','')
 metric(gauges,'export-limit','ВНЕШНИЙ ЭНЕРГОКОНТУР','200 МВт')
 metric(gauges,'interior-limit','ИНТЕРЬЕР И ВСЕ КОМНАТЫ','20 МВт')
 wrapped(parent,'reactor-condition','',810,'t12_subtitle')
 note(parent,'Общий резерв — 10 ГДж. Контур удержания открывает ремонт коллекторов: каждый даёт 20 МВт, преобразователь после обоих добавляет 10 МВт. Для полёта нужны все четыре исправные энергомашины.')
 add(parent,'checkbox','t12-export','Питать внешнюю сеть — до 200 МВт',{state=f.export})
 add(parent,'checkbox','t12-inner-power','Питать интерьер и мобильный завод — до 20 МВт',{state=f.interior_power})
 note(parent,'Подключите фабрику к энергетическому разъёму рядом с будкой. Выдача учитывает реальное потребление: подключение пустой сети не разряжает резерв. Разъём путешествует вместе с Тардис.')
 note(parent,'При нагрузке выше выработки запас уменьшается. Если энергии не хватает на выбранный маршрут, ТАРДИС не взлетит. Отключите выдачу в сети или снизьте нагрузку завода и дождитесь заряда.')
 button(parent,'t12-charge','Сосредоточить энергию на заряде')
 button(parent,'t12-go-eye','Открыть схему энергомашин')
 wrapped(parent,'reactor-charge-time','',810,'t12_muted')
end
local function ports(p,f,parent)
 heading(parent,'04','МАТЕРИАЛЬНЫЕ ШЛЮЗЫ')
 note(parent,'Снаружи поставьте входной/выходной порт не дальше 8 клеток от будки; эти порты остаются на планете. Внутри порты работают во всех комнатах и во время полёта, снабжая мобильный завод из общего склада.')
 local scroll=add(parent,'scroll-pane','port-scroll');scroll.style.maximal_height=270
 local found=0
 for id,v in pairs(root().ports) do
  if v.entity.valid and M.port_ship(v)==f then
   found=found+1;local r=flow(scroll,'port'..id)
   local input=v.entity.name=='tardis-input'
   label(r,(input and 'ВХОД' or 'ВЫХОД')..' #'..id).style.width=125
   add(r,'choose-elem-button','t12-port-filter-'..id,nil,{elem_type='item-with-quality',['item-with-quality']=v.filter,tags={port=id}})
   label(r,input and 'Принимать на склад' or 'Оставить на складе:')
   if not input then field(r,'t12-port-keep-'..id,v.keep,105).tags={port=id} end
   add(r,'checkbox','t12-port-enabled-'..id,'Включён',{state=v.enabled,tags={port=id}})
  end
 end
 if found==0 then note(parent,'Подключённых портов нет. Постройте их у будки или внутри завода. При перелёте отключаются только внешние порты.') end
 note(parent,'Вход без фильтра принимает любые предметы. Выход без фильтра ничего не выдаёт. «Оставить» — неснижаемый запас выбранного предмета на складе. До 500 предметов за цикл, два цикла в секунду.')
 button(parent,'t12-refresh-ports','Обновить порты')
 note(parent,'Вход — логистический сундук запроса, выход — пассивное снабжение. Запросы роботов настраиваются в обычном окне сундука; манипуляторы работают как обычно.')
 heading(parent,'I/O','ЛОГИЧЕСКАЯ СЕТЬ / КРАСНЫЙ И ЗЕЛЁНЫЙ ПРОВОД')
 note(parent,'Отдельные вход и выход находятся по бокам будки и в грузовом отсеке. Подайте команды на вход, читайте состояние со выхода; не объединяйте их одним проводом. Грузовые порты подключают предметы к общей фабрике, сигнальные терминалы управляют кораблём.')
 wrapped(parent,'circuit-condition','',810,'t12_subtitle')
 local protocol=add(parent,'table','circuit-protocol',nil,{column_count=2});protocol.style.horizontal_spacing=20;protocol.style.vertical_spacing=6
 local incoming=add(protocol,'frame','wire-input-help',nil,{direction='vertical',style='t12_card'});incoming.style.width=math.floor((canvas(parent)-20)/2)
 local outgoing=add(protocol,'frame','wire-output-help',nil,{direction='vertical',style='t12_card'});outgoing.style.width=math.floor((canvas(parent)-20)/2)
 label(incoming,'ВХОД / КОМАНДЫ').style='t12_subtitle';label(outgoing,'ВЫХОД / ТЕЛЕМЕТРИЯ').style='t12_subtitle'
 local function signal(parent,key,text)
  local row=flow(parent,nil);sprite(row,'virtual-signal/tardis-signal-'..key,24)
  wrapped(row,nil,text,338)
 end
 signal(incoming,'destination','Код планеты назначения')
 signal(incoming,'x','X точки посадки');signal(incoming,'y','Y точки посадки')
 signal(incoming,'jump','Прыжок: импульс 0 → положительное значение')
 signal(incoming,'inhibit','Запрет прыжков: значение > 0')
 signal(incoming,'export','Внешнее питание: > 0 вкл., < 0 выкл., 0 — управление с консоли')
 signal(outgoing,'energy','Запас энергии, МДж');signal(outgoing,'charge','Заряд резерва, %')
 signal(outgoing,'busy','В полёте: 1');signal(outgoing,'ready','Готова к запуску: 1 (цена цели проверяется при команде)')
 signal(outgoing,'origin','Код текущей планеты');signal(outgoing,'items','Количество предметов на складе')
 signal(outgoing,'free-slots','Свободные ячейки');signal(outgoing,'result','Результат: 1 успешно, отрицательное — отказ')
 note(parent,'Коды: 1 Наувис · 2 Вулкан · 3 Фульгора · 4 Глеба · 5 Аквило · 6 Разрушенная планета. Координаты — в клетках. Доступность исследований, ремонт, заряд и безопасная посадка проверяются при каждом прыжке.')
 note(parent,'Выход также передаёт все предметы склада с их количеством и качеством. Постоянный высокий сигнал прыжка не вызывает повторных полётов; для новой команды опустите его до нуля. Внутренний вход имеет приоритет при одновременных командах.')
end
local function rooms(p,f,parent)
 local R=M.Rooms;R.init(f);local st=state(p);st.room_slot=st.room_slot or 1
 local legacy=f.room_layout_version==1
 heading(parent,'05','АРХИТЕКТУРНАЯ СИСТЕМА')
 note(parent,legacy and 'Сохранено прежнее восточное крыло: перенос комнат не выполнен, чтобы сохранить существующие постройки. Вход через грузовой отсек. Материалы обычного качества берутся из общего склада; формирование — 10 секунд.' or 'Комнаты растут к северу от круглого консольного зала. Сначала постройте отсек первого уровня, затем его ответвления. Материалы обычного качества берутся из общего склада; формирование — 10 секунд.')
 local layout=add(parent,'frame','layout',nil,{direction='vertical',style='t12_card'});layout.style.width=canvas(parent)
 label(layout,legacy and 'ВОСТОЧНОЕ КРЫЛО / СОХРАНЁННАЯ ПЛАНИРОВКА' or '↑ СЕВЕР / ВТОРОЙ УРОВЕНЬ').style='t12_muted'
 local function parent_slot(slot) if legacy then return nil end;return R.parent and R.parent(slot) or (R.parents and R.parents[slot]) end
 local function room_button(holder,slot,width)
  local room=f.rooms[slot];local text=room and R.plans[room.kind].title or 'Свободный отсек'
  local parent_id=parent_slot(slot);local ready=not parent_id or (f.rooms[parent_id] and f.rooms[parent_id].state=='ready')
  local detail=room and (room.state=='ready' and 'ГОТОВ' or room.state=='refund' and 'ВОЗВРАТ РЕСУРСОВ' or 'ФОРМИРУЕТСЯ') or ready and 'Выбрать проект' or string.format('Сначала отсек %02d',parent_id)
  local b=button(holder,'t12-room-slot-'..slot,string.format('%02d  %s',slot,room and R.plans[room.kind].title or 'Пустой отсек'),{slot=slot})
  local xy=R.position(slot,f);b.tooltip=string.format('%02d / %s\n%s\nКоординаты: %d, %d',slot,text,detail,xy.x,xy.y)
  if slot==st.room_slot then b.style='t12_primary' end;b.style.width=scaled(holder,width);b.style.height=52
 end
 if legacy then
 local old=add(layout,'table','legacy-slots',nil,{column_count=3});old.style.horizontal_spacing=6;old.style.vertical_spacing=6
 for slot=1,R.max_rooms do room_button(old,slot,258) end
 else
 local leaves=flow(layout,'tree-leaves');leaves.style.horizontal_spacing=6
 for _,slot in ipairs{3,4,5,6} do room_button(leaves,slot,192) end
 local stems=flow(layout,'tree-stems');stems.style.horizontal_spacing=0
 for i=1,4 do
  local spacer=add(stems,'empty-widget',nil);spacer.style.width=scaled(parent,i==1 and 95 or 197)
  local line=add(stems,'line',nil,nil,{direction='vertical'});line.style.height=12
 end
 local connections=flow(layout,'tree-connections');connections.style.horizontal_spacing=0
 local spacer=add(connections,'empty-widget',nil);spacer.style.width=scaled(parent,95)
 add(connections,'line',nil,nil,{direction='horizontal'}).style.width=scaled(parent,198)
 spacer=add(connections,'empty-widget',nil);spacer.style.width=scaled(parent,198)
 add(connections,'line',nil,nil,{direction='horizontal'}).style.width=scaled(parent,198)
 local branches=flow(layout,'tree-branches');branches.style.horizontal_spacing=6
 room_button(branches,1,390);room_button(branches,2,390)
 local branch_names=flow(layout,'tree-branch-names');branch_names.style.horizontal_spacing=6
 wrapped(branch_names,nil,'Отсек 01 → ответвления 03 и 04',390,'t12_muted').style.width=scaled(parent,390)
 wrapped(branch_names,nil,'Отсек 02 → ответвления 05 и 06',390,'t12_muted').style.width=scaled(parent,390)
 local trunk=add(layout,'frame','tree-console-hall',nil,{direction='vertical',style='t12_amber_card'});trunk.style.width=scaled(parent,786)
 label(trunk,'КРУГЛЫЙ КОНСОЛЬНЫЙ ЗАЛ / СЕВЕРНЫЙ ПРОХОД').style='t12_subtitle'
 wrapped(trunk,nil,'Люк у консоли: вниз к Оку     ·     Восток: грузовой отсек     ·     Юг: дверь наружу',760,'t12_muted')
 end
 local room=f.rooms[st.room_slot]
 if room then
  heading(parent,string.format('%02d',st.room_slot),R.plans[room.kind].title)
  if room.state=='building' then
   add(parent,'label','room-countdown','Перестройка внутреннего пространства: '..math.max(0,math.ceil((room.finish-game.tick)/60))..' сек.',{style='t12_subtitle'})
   add(parent,'progressbar','build-progress',nil,{style='t12_progress',value=math.min(1,(game.tick-room.started)/R.build_ticks)}).style.width=canvas(parent)
   button(parent,'t12-cancel-room','Отменить и вернуть материалы',{slot=st.room_slot}).enabled=access(p,f)
  elseif room.state=='refund' then note(parent,'Освободите место в общем складе. Материалы сохранены и автоматически вернутся; отсек снова станет свободным.')
  else
   local xy=R.position(st.room_slot,f)
   note(parent,R.plans[room.kind].description)
   local parent_id=parent_slot(st.room_slot)
   note(parent,(legacy and ('Через восточный грузовой отсек пройдите по коридору '..(xy.y<0 and 'на север' or 'на юг')) or ('Из круглого зала пройдите на север, затем '..(parent_id and ('через отсек '..string.format('%02d',parent_id)..' к его ответвлению') or (xy.x<0 and 'по левой ветви' or 'по правой ветви'))))..'. Координаты комнаты: '..xy.x..', '..xy.y..'.')
   if room.added_slots then note(parent,'Этот модуль добавил '..room.added_slots..' ячеек в общий склад.') end
  end
 else
  local available,reason=R.available(f,st.room_slot)
  if not available then note(parent,reason) end
  local plans=add(parent,'table','projects',nil,{column_count=3});plans.style.horizontal_spacing=8
  for _,kind in ipairs(R.order) do
   local plan=R.plans[kind];local card=add(plans,'frame','project-'..kind,nil,{direction='vertical',style='t12_card'});card.style.width=math.floor((canvas(parent)-16)/3)
   local row=flow(card,nil);row.style.minimal_height=38;row.style.vertical_align='center'
   local icon=add(row,'sprite',nil,nil,{sprite='item/'..plan.icon});icon.resize_to_sprite=false
   icon.style.size=32;icon.style.stretch_image_to_widget_size=true
   label(row,plan.title).style='t12_subtitle'
   local desc=note(card,plan.description);desc.style.maximal_width=scaled(parent,235);desc.style.minimal_height=54
   for _,v in ipairs(plan.cost) do
    local have=f.cargo.get_item_count{name=v.name,quality='normal'}
    local color=have>=v.count and '139,211,208' or '241,171,97'
    local l=add(card,'label','cost-'..v.name,{'','[item=',v.name,']  [color=',color,']',math.min(have,v.count),' / ',v.count,'[/color]  ',prototypes.item[v.name].localised_name},{style='t12_text'});l.style.maximal_width=scaled(parent,235);l.style.single_line=false
   end
   local b=button(card,'t12-build-room-'..kind,'СФОРМИРОВАТЬ',{slot=st.room_slot,kind=kind});b.style='t12_primary';b.style.width=scaled(parent,235)
   b.enabled=access(p,f) and available and #R.missing(f,kind)==0 and not (plan.slots and #f.cargo>=C.max_slots)
   b.tooltip=reason or 'Ресурсы спишутся из общего склада. Готовая комната останется с Тардис при перелётах и упаковке.'
  end
 end
 local row=flow(parent,'room-actions');button(row,'t12-deposit-for-rooms','Внести материалы').enabled=access(p,f)
 button(row,'t12-refresh-rooms','Проверить ресурсы')
 if legacy then
  note(parent,f.room_layout_error or 'Освободите северные площадки и проверьте стыки труб и конвейеров старых комнат.')
  button(parent,'t12-migrate-rooms','Повторить перенос на север').enabled=access(p,f) and not f.flight
 end
 note(parent,'Входные грузовые порты также снабжают строительство. Отменить можно формирование комнаты; готовые комнаты остаются частью корабля.')
end
local function update_restoration(p,f,parent)
 local story=V.info(f);local st=state(p)
 parent['story-stage'].caption=story.stage
 parent['doctor-record']['doctor-message'].caption=story.message
 for _,key in ipairs(V.order) do
  local plan=V.plans[key];local card=parent['repair-projects']['repair-'..key]
  local repaired=f.voyage[key];local ready,reason=V.repair_ready(f,key)
  card['repair-state'].caption=repaired and '[color=140,205,140]ВОССТАНОВЛЕНО[/color]' or key=='eye' and ('ЭНЕРГОМАШИНЫ '..Core.count(f)..' / 4') or '[color=236,176,87]ТРЕБУЕТСЯ РЕМОНТ[/color]'
  card['repair-condition'].caption=key=='eye' and string.format('Отдача %.0f МВт. Ремонт выполняется у каждой машины в нижнем зале.',Core.recharge(f)/1e6) or repaired and 'Узел исправен.' or reason or 'Материалы готовы. Можно начать восстановление.'
  for _,item in ipairs(plan.cost) do
   local have=f.cargo.get_item_count{name=item.name,quality='normal'}
   local needed=item.count
   if key=='eye' then
    needed=0
    for _,module in ipairs(Core.order) do if not f.eye_core.modules[module] then
     for _,cost in ipairs(Core.plans[module].cost) do if cost.name==item.name then needed=needed+cost.count end end
    end end
   end
   local color=have>=needed and '139,211,150' or '241,171,97'
   card['cost-'..item.name].caption={'','[item=',item.name,']  [color=',color,']',math.min(have,needed),' / ',needed,'[/color]  ',prototypes.item[item.name].localised_name}
  end
  local b=card['t12-repair-'..key]
  if key=='eye' then b.enabled=true;b.caption='СХЕМА ЭНЕРГОМАШИН';b.tooltip='Посмотреть узлы Ока. Для ремонта спуститесь через люк и подойдите к нужной машине.'
  else b.enabled=access(p,f) and ready;b.caption=repaired and 'ВОССТАНОВЛЕНО' or 'ВОССТАНОВИТЬ';b.tooltip=reason or 'Материалы обычного качества спишутся из общего склада.' end
 end
 local holder=parent['return-protocol'];local ready,reason=V.return_ready(f)
 holder['return-condition'].caption=story.returned and 'ТАРДИС у Доктора. Завод и склад доступны через пространственный якорь на Наувисе.' or reason or 'Корабль восстановлен и достиг Разрушенной планеты. След временной линии найден.'
 holder['t12-return-doctor-review'].visible=not story.returned and not st.return_confirm
 holder['t12-return-doctor-review'].enabled=ready and access(p,f)
 holder['return-confirmation'].visible=not story.returned and st.return_confirm==true
 holder['return-confirmation']['return-confirm-actions']['t12-return-doctor-confirm'].enabled=ready and access(p,f)
end
local function restoration(p,f,parent)
 heading(parent,'06','ВОССТАНОВЛЕНИЕ / ВОЗВРАЩЕНИЕ ДОКТОРУ')
 wrapped(parent,'story-stage','',810,'t12_subtitle')
 note(parent,'При крушении корабль инженера врезался в ТАРДИС. Ремонтируйте узлы по порядку, снабжая общий склад через грузовые порты или вручную. Используются материалы обычного качества.')
 local projects=add(parent,'table','repair-projects',nil,{column_count=3});projects.style.horizontal_spacing=8
 for i,key in ipairs(V.order) do
  local plan=V.plans[key];local card=add(projects,'frame','repair-'..key,nil,{direction='vertical',style='t12_card'});card.style.width=math.floor((canvas(parent)-16)/3)
  local top=flow(card,nil);sprite(top,'item/'..plan.icon,32);wrapped(top,nil,string.format('%02d / ',i)..plan.title,200,'t12_subtitle')
  wrapped(card,'repair-state','',245,'t12_muted')
  wrapped(card,nil,plan.description,245).style.minimal_height=105
  for _,item in ipairs(plan.cost) do wrapped(card,'cost-'..item.name,'',245) end
  if plan.technology then
   wrapped(card,nil,{'','Исследование: ',prototypes.technology[plan.technology].localised_name},245,'t12_muted')
  else wrapped(card,nil,'Доступно с начала игры.',245,'t12_muted') end
  wrapped(card,'repair-condition','',245,'t12_muted').style.minimal_height=60
  local b=button(card,'t12-repair-'..key,key=='eye' and 'СХЕМА ЭНЕРГОМАШИН' or 'ВОССТАНОВИТЬ',key=='eye' and {eye_overview=true} or {repair=key});b.style='t12_primary';b.style.width=scaled(parent,235)
 end
 local actions=flow(parent,'repair-actions');button(actions,'t12-deposit-for-repairs','Внести материалы').enabled=access(p,f)
 button(actions,'t12-refresh-repairs','Проверить материалы')
 local record=add(parent,'frame','doctor-record',nil,{direction='vertical',style='t12_card'});record.style.width=canvas(parent)
 label(record,'АРХИВ / СООБЩЕНИЕ ДОКТОРА').style='t12_subtitle';wrapped(record,'doctor-message','',790)
 local finale=add(parent,'frame','return-protocol',nil,{direction='vertical',style='t12_amber_card'});finale.style.width=canvas(parent)
 label(finale,'ПОСЛЕДНИЙ МАРШРУТ / РАЗРУШЕННАЯ ПЛАНЕТА').style='t12_subtitle'
 wrapped(finale,'return-condition','',790)
 wrapped(finale,nil,'Это Разрушенная планета Space Age за границей солнечной системы. Её маршрут открывается исследованием прометиевой науки. После посадки полностью исправную ТАРДИС можно отправить по следу Доктора.',790,'t12_muted')
 button(finale,'t12-return-doctor-review','Подготовить возвращение Доктору')
 local confirmation=add(finale,'flow','return-confirmation',nil,{direction='vertical'})
 wrapped(confirmation,nil,'ТАРДИС и Око Гармонии отправятся Доктору. Будет потрачено 1 ГДж. Экипаж вернётся на Наувис; комнаты, все машины и груз останутся доступны через постоянный пространственный якорь рядом с местом старта. Завод станет стационарным, полёты и генерация Ока прекратятся. Для дальнейшей работы завода понадобится собственный источник энергии.',790)
 wrapped(confirmation,nil,'Это завершит историю этого корабля. Готовы отправить его?',790,'t12_subtitle')
 local row=flow(confirmation,'return-confirm-actions');local b=button(row,'t12-return-doctor-confirm','ВЕРНУТЬ ДОКТОРУ');b.style='t12_primary'
 button(row,'t12-return-doctor-cancel','Пока остаться')
 update_restoration(p,f,parent)
end
local function update_eye(p,f,parent)
 local state_core=Core.ensure(f);local st=state(p)
 if not Core.plans[st.eye_key] then st.eye_key=Core.order[1] end
 local key=st.eye_key;local plan=Core.plans[key]
 local watts=Core.recharge(f);local count=Core.count(f)
 parent['eye-condition'].caption=f.voyage.returned and 'Око отправлено Доктору. Энергомашины отключены.' or string.format('ВОССТАНОВЛЕНО %d / 4     ·     ВЫРАБОТКА %.0f МВт',count,watts/1e6)
 local map=parent['eye-map']
 for _,id in ipairs(Core.order) do
  local b=map['t12-eye-select-'..id];local repaired=state_core.modules[id]
  local short=id=='containment' and 'Удержание' or Core.plans[id].title
  b.caption=short..(repaired and '  [color=139,211,150]✓[/color]' or '  [color=241,171,97]×[/color]')
  b.tooltip=Core.plans[id].bearing..' / '..Core.plans[id].title..': '..(repaired and 'исправен' or 'повреждён')
  b.style=id==key and 't12_primary' or 't12_button';b.style.width=scaled(parent,250);b.style.height=54
 end
 map['eye-star-card']['eye-star-output'].caption=string.format('ЗВЕЗДА / %.0f МВт',watts/1e6)
 local details=parent['eye-selected']
 details['eye-module-title'].caption=plan.title..' / '..plan.bearing
 details['eye-module-description'].caption=plan.description
 for _,item in ipairs(plan.cost) do
  local have=f.cargo.get_item_count{name=item.name,quality='normal'}
  local color=have>=item.count and '139,211,150' or '241,171,97'
  details['eye-module-costs']['eye-cost-'..item.name].caption={'','[item=',item.name,']  [color=',color,']',math.min(have,item.count),' / ',item.count,'[/color]  ',prototypes.item[item.name].localised_name}
 end
 local ready,reason=Core.repair_ready(f,key,p)
 details['eye-repair-condition'].caption=state_core.modules[key] and 'Эта энергомашина уже восстановлена.' or reason or 'Вы рядом с машиной. Материалы готовы к ремонту.'
 local b=details['eye-repair-actions']['t12-eye-repair'];b.enabled=ready;b.tags={eye_repair=key};b.caption=state_core.modules[key] and 'ВОССТАНОВЛЕНО' or 'ВОССТАНОВИТЬ УЗЕЛ'
 b.tooltip=reason or 'Списать материалы обычного качества из общего склада и починить эту физическую машину.'
 local hatch=parent['eye-travel'];hatch['t12-eye-descend'].enabled=near_hatch(p,f,false);hatch['t12-eye-ascend'].enabled=near_hatch(p,f,true)
 hatch['t12-eye-descend'].visible=p.physical_surface~=f.eye_surface;hatch['t12-eye-ascend'].visible=p.physical_surface==f.eye_surface
 local at=valid(f.eye_room and f.eye_room.hatch) and f.eye_room.hatch.position or {x=6,y=7}
 parent['eye-hatch-guide'].caption=p.physical_surface==f.eye_surface and 'Назад в консольный зал — лестница у южного входа. Для ремонта подойдите к выбранной машине не дальше 6 клеток.' or string.format('Люк в полу круглого консольного зала: X %.1f, Y %.1f. Подойдите к нему и щёлкните. Эта схема доступна удалённо; ремонт — только возле машин внизу.',at.x,at.y)
end
local function eye(p,f,parent)
 local st=state(p);Core.ensure(f)
 if not Core.plans[st.eye_key] then
  st.eye_key=Core.order[1];for _,key in ipairs(Core.order) do if not f.eye_core.modules[key] then st.eye_key=key;break end end
 end
 heading(parent,'07','ОКО ГАРМОНИИ / НИЖНИЙ УРОВЕНЬ')
 wrapped(parent,'eye-condition','',810,'t12_subtitle')
 note(parent,'Сначала контур удержания, затем два коллектора в любом порядке, последним — преобразователь. Нужны исправная матрица и химическая наука. Частичная отдача заряжает резерв, но для полёта исправными должны быть все четыре машины.')
 local map=add(parent,'table','eye-map',nil,{column_count=3});map.style.horizontal_spacing=16;map.style.vertical_spacing=6
 local function blank() local e=add(map,'empty-widget',nil);e.style.width=scaled(parent,250);e.style.height=54 end
 local function node(key) local b=button(map,'t12-eye-select-'..key,'',{eye_select=key});b.style.width=scaled(parent,250);b.style.height=54 end
 blank();node('containment');blank();node('collector_a')
 local star=add(map,'frame','eye-star-card',nil,{direction='vertical',style='t12_amber_card'});star.style.width=scaled(parent,250)
 label(star,'ОКО ГАРМОНИИ').style='t12_subtitle';add(star,'label','eye-star-output','',{style='t12_muted'})
 node('collector_b');blank();node('converter');blank()
 local details=add(parent,'frame','eye-selected',nil,{direction='vertical',style='t12_card'});details.style.width=canvas(parent)
 wrapped(details,'eye-module-title','',788,'t12_subtitle');wrapped(details,'eye-module-description','',788)
 local costs=add(details,'table','eye-module-costs',nil,{column_count=2});costs.style.horizontal_spacing=20
 for _,item in ipairs(Core.plans.containment.cost) do wrapped(costs,'eye-cost-'..item.name,'',376) end
 wrapped(details,'eye-repair-condition','',788,'t12_muted')
 local row=flow(details,'eye-repair-actions');local b=button(row,'t12-eye-repair','ВОССТАНОВИТЬ УЗЕЛ');b.style='t12_primary'
 button(row,'t12-eye-deposit','Внести материалы').enabled=access(p,f)
 wrapped(parent,'eye-hatch-guide','',810,'t12_muted')
 local travel=flow(parent,'eye-travel');button(travel,'t12-eye-descend','Спуститься через люк');button(travel,'t12-eye-ascend','Подняться к консоли')
 update_eye(p,f,parent)
end
function UI.open(p,id,tab)
 local f=M.get(id);if not p or not f or p.force~=f.force then return end
 local st=state(p);st.ship=id
 local old=p.gui.screen.t12
 local selected=tab or (old and old.t12_tabs.selected_tab_index) or st.tab or 1
 close(p)
 local d=dimensions(p)
 local frame=add(p.gui.screen,'frame','t12',nil,{direction='horizontal',style='t12_shell'});frame.style.width=d.width;frame.style.height=d.height
 frame.tags={pane_width=d.pane,content_width=d.content,rail_width=d.rail}
 local rail=add(frame,'frame','t12_rail',nil,{direction='vertical',style='t12_rail'});rail.style.width=d.rail;rail.style.vertically_stretchable=true
 local crest=add(rail,'flow','crest',nil,{direction='vertical'});crest.style.horizontal_align='center';crest.style.width=d.rail-16
 crest.style.vertical_spacing=0;sprite(crest,'t12-gallifreyan-seal',64,'seal');label(crest,'TYPE 40').style='t12_title';label(crest,'TARDIS / XII').style='t12_muted'
 local selector=add(rail,'flow','systems',nil,{direction='vertical'});selector.style.vertical_spacing=3
 for i,v in ipairs(systems) do
  local b=button(selector,'t12-system-'..i,v.code..'  '..v.title,{system=i});b.style='t12_rail_button';b.style.width=d.rail-16;b.style.height=38;b.tooltip='Открыть систему: '..v.title
 end
 local gauges=add(rail,'flow','telemetry',nil,{direction='vertical'});gauges.style.vertical_spacing=4
 for _,m in ipairs{{'reserve','РЕЗЕРВ'},{'buffer','ХРАНИЛИЩЕ'},{'architecture','КОМНАТЫ'}} do
  local card=add(gauges,'flow',m[1],nil,{direction='vertical'});card.style.vertical_spacing=0;card.style.width=d.rail-16
  label(card,m[2]).style='t12_muted';add(card,'label','t12_metric','',{style='t12_subtitle'})
 end
 wrapped(rail,'ship-signature','T / '..string.format('%04d',id),130,'t12_muted')
 local tabs=add(frame,'tabbed-pane','t12_tabs',nil,{style='t12_tabs'});tabs.style.width=d.pane;tabs.style.height=d.height-24
 navigation(p,f,panel(tabs,'navigation','Навигация',p))
 warehouse(p,f,panel(tabs,'warehouse','Склад',p))
 energy(p,f,panel(tabs,'reactor','Реактор',p))
 ports(p,f,panel(tabs,'ports','Порты / Сеть',p))
 rooms(p,f,panel(tabs,'rooms','Комнаты',p))
 restoration(p,f,panel(tabs,'restoration','Восстановление',p))
 eye(p,f,panel(tabs,'eye','Око',p))
 select_system(p,frame,selected);st.room_revision=f.room_revision
 frame.auto_center=true;p.opened=frame
 UI.status(p,f)
end
function UI.status(p,f)
 local frame=p.gui.screen.t12;if not frame then return end
 local e=M.total_energy(f);local story=V.info(f);local location=valid(f.box) and M.surface_name(f.box.surface) or valid(f.anchor) and 'ЯКОРЬ / НАУВИС' or 'УПАКОВАНА'
 local mode=story.returned and 'ИСТОРИЯ ЗАВЕРШЕНА' or f.flight and 'В ПОЛЁТЕ' or not story.console and 'КОНСОЛЬ ПОВРЕЖДЕНА' or not story.eye and ('ЭНЕРГОМАШИНЫ '..Core.count(f)..'/4') or e<V.base_cost and 'ТРЕБУЕТСЯ ЗАРЯД' or 'СИСТЕМЫ ГОТОВЫ'
 for _,system in ipairs(systems) do
  local panel=frame.t12_tabs[system.panel]
  panel.status.caption={'',mode,'  ·  ',location};panel.energy.value=e/C.capacity
 end
 select_system(p,frame,frame.t12_tabs.selected_tab_index)
 local gauges=frame.t12_rail.telemetry
 gauges.reserve.t12_metric.caption=string.format('%.2f / 10 ГДж',e/1e9)
 gauges.buffer.t12_metric.caption=(#f.cargo-f.cargo.count_empty_stacks())..' / '..#f.cargo
 gauges.architecture.t12_metric.caption=M.Rooms.count(f)..' / '..M.Rooms.max_rooms
 update_navigation(p,f,frame.t12_tabs.navigation)
 local reactor=frame.t12_tabs.reactor
 reactor['reactor-gauges'].source.t12_metric.caption=string.format('%.0f МВт',story.recharge/1e6)
 reactor['reactor-condition'].caption=story.returned and 'Око вернулось к Доктору. Заводу нужен собственный источник энергии.' or not story.eye and string.format('Исправны %d из 4 энергомашин. Выработка %.0f МВт; для полёта завершите ремонт у звезды на нижнем уровне.',Core.count(f),story.recharge/1e6) or 'Око стабильно. Общий резерв питает полёты, внешний контур и мобильный завод.'
 reactor['t12-export'].enabled=story.recharge>0 and not story.returned;reactor['t12-export'].state=f.export==true
 reactor['t12-inner-power'].state=f.interior_power==true
 reactor['reactor-charge-time'].caption=story.recharge>0 and string.format('Полная зарядка с нуля без нагрузки: %.0f секунд. При нагрузке время увеличивается.',C.capacity/story.recharge) or 'Око начнёт зарядку после восстановления контура и хотя бы одного коллектора.'
 local circuit=f.circuit or {};frame.t12_tabs.ports['circuit-condition'].caption=circuit.inhibit and 'БЛОКИРОВКА ПРЫЖКОВ АКТИВНА' or circuit.last_error or (circuit.last_result==1 and 'Последняя команда выполнена.' or 'Терминалы готовы. Ожидается команда.')
 update_restoration(p,f,frame.t12_tabs.restoration)
 update_eye(p,f,frame.t12_tabs.eye)
end
function UI.shortcut(e)
 local p=game.get_player(e.player_index);if not p then return end
 local f=M.find(p);if f then UI.open(p,f.id) else tell(p,'Сначала поставьте Тардис. Получить стартовую будку: /tardis') end
end
function UI.opened(e)
 local entity=e.entity
 if not entity or not entity.valid then return end
 local eye_entity=entity.name=='tardis-eye-machine' or entity.name=='tardis-eye-star' or entity.name=='tardis-eye-hatch' or entity.name=='tardis-eye-ladder'
 if not eye_entity and entity.name~='tardis-console' and entity.name~='tardis-terminal' and entity.name~='tardis' and entity.name~='tardis-anchor' and entity.name~='tardis-eye' and entity.name~='tardis-exit' then return end
 local p=game.get_player(e.player_index);if not p then return end
 local f=M.find(p)
 if eye_entity then
  for _,candidate in pairs(root().ships) do
   if candidate.force==p.force and (entity.surface==candidate.surface or entity.surface==candidate.eye_surface) then f=candidate;break end
  end
  if not f or p.force~=f.force or entity.force~=f.force then return end
  p.opened=nil
  if entity.name=='tardis-eye-hatch' then local _,why=M.descend(p.index,f.id);if why then tell(p,why) end;return end
  if entity.name=='tardis-eye-ladder' then local _,why=M.ascend(p.index,f.id);if why then tell(p,why) end;return end
  local key=M.Eye and M.Eye.module_key(f,entity)
  if key then state(p).eye_key=key end
  UI.open(p,f.id,7);return
 end
 if entity.name=='tardis-exit' then
  if f and p.force==f.force and p.physical_surface==f.surface and entity.surface==f.surface then p.opened=nil;close(p);M.leave(p.index,f.id) end
  return
 end
 if entity.name=='tardis' or entity.name=='tardis-anchor' then for _,v in pairs(root().ships) do if v.box==entity or v.anchor==entity then f=v;break end end end
 if f then
  local tab=entity.name=='tardis-terminal' and 2 or entity.name=='tardis-eye' and 7 or 1
  p.opened=nil;UI.open(p,f.id,tab)
 end
end
function UI.closed(e)
 local p=game.get_player(e.player_index)
 if p and e.element and e.element.valid and e.element.name=='t12' then state(p).tab=e.element.t12_tabs.selected_tab_index;state(p).return_confirm=false;close(p) end
end
local function destination(p,f)
 local st=state(p);local dd=p.gui.screen.t12.t12_tabs.navigation.destination['t12-planet']
 local name=st.planets[dd.selected_index];if not name then return nil end
 local quote=V.quote(f,name);if not quote.ok then return nil,quote.error end
 local planet=game.planets[name];return planet.surface or planet.create_surface()
end
function UI.click(e)
 if not e.element or not e.element.valid then return end
 local n=e.element.name;if n:sub(1,4)~='t12-' then return end
 local p=game.get_player(e.player_index);local st=state(p);local f=M.get(st.ship)
 if n=='t12-close' then st.return_confirm=false;close(p);return end
 if not f or p.force~=f.force then return end
 local tags=e.element.tags;local _,why
 if tags.system then select_system(p,p.gui.screen.t12,tags.system)
 elseif n=='t12-jump' then local s,reason=destination(p,f);if s then _,why=M.jump(f.id,s.index,st.x,st.y) else why=reason end
 elseif tags.planet then st.planet=tags.planet;refresh(p,1)
 elseif n=='t12-return' and f.previous then local v=f.previous;_,why=M.jump(f.id,v.surface,v.x,v.y)
 elseif n=='t12-save-bookmark' then
  if f.box and f.box.valid and #f.bookmarks<40 then f.bookmarks[#f.bookmarks+1]={name=(st.bookmark_name or 'Моя база'):sub(1,80),surface=f.box.surface.index,x=f.box.position.x,y=f.box.position.y};refresh(p,1) end
 elseif n:find('t12-bookmark-go-',1,true) then local v=f.bookmarks[tags.bookmark];if v then _,why=M.jump(f.id,v.surface,v.x,v.y) end
 elseif n:find('t12-bookmark-delete-',1,true) then table.remove(f.bookmarks,tags.bookmark);refresh(p,1)
 elseif n=='t12-enter' then
  if near_entry(p,f) then close(p);M.enter(p.index,f.id) end
 elseif n=='t12-leave' then local ok,why=M.leave(p.index,f.id);if ok then close(p) else p.print(why or 'Не удалось покинуть помещение.');UI.status(p,f) end
 elseif n=='t12-recall' then _,why=M.recall(p,f)
 elseif n=='t12-deposit' and access(p,f) then
  local filter=st.filter;local count=M.move(p.get_main_inventory(),f.cargo,filter)
  tell(p,'На склад передано: '..count..' предметов.');refresh(p,2)
 elseif tags.item and access(p,f) then
  local count=M.move(f.cargo,p.get_main_inventory(),{name=tags.item,quality=tags.quality},e.shift and 1e9 or prototypes.item[tags.item].stack_size)
  if count==0 then tell(p,'В инвентаре нет места.') end;refresh(p,2)
 elseif n=='t12-upgrade' then refresh(p,5)
 elseif n=='t12-prev' then st.page=math.max(1,(st.page or 1)-1);refresh(p,2)
 elseif n=='t12-next' then st.page=(st.page or 1)+1;refresh(p,2)
 elseif n=='t12-refresh' then refresh(p,2)
 elseif n=='t12-refresh-ports' then refresh(p,4)
 elseif n=='t12-charge' then f.export=false;f.interior_power=false;refresh(p,3)
 elseif n=='t12-go-repairs' then refresh(p,6)
 elseif n=='t12-go-eye' or tags.eye_overview then refresh(p,7)
 elseif tags.eye_select and Core.plans[tags.eye_select] then
  st.eye_key=tags.eye_select;update_eye(p,f,p.gui.screen.t12.t12_tabs.eye)
 elseif n=='t12-eye-repair' and Core.plans[tags.eye_repair] then _,why=M.repair_eye(p.index,f.id,tags.eye_repair)
 elseif n=='t12-eye-deposit' and access(p,f) then M.move(p.get_main_inventory(),f.cargo);update_eye(p,f,p.gui.screen.t12.t12_tabs.eye)
 elseif n=='t12-eye-descend' then
  local ok;ok,why=M.descend(p.index,f.id);if ok then close(p) end
 elseif n=='t12-eye-ascend' then
  local ok;ok,why=M.ascend(p.index,f.id);if ok then close(p) end
 elseif tags.repair then _,why=M.repair(p.index,f.id,tags.repair);refresh(p,6)
 elseif n=='t12-deposit-for-repairs' and access(p,f) then M.move(p.get_main_inventory(),f.cargo);refresh(p,6)
 elseif n=='t12-refresh-repairs' then refresh(p,6)
 elseif n=='t12-return-doctor-review' then
  local ready,reason=V.return_ready(f)
  if ready and access(p,f) then st.return_confirm=true;update_restoration(p,f,p.gui.screen.t12.t12_tabs.restoration) else why=reason or 'Откройте протокол изнутри ТАРДИС.' end
 elseif n=='t12-return-doctor-cancel' then st.return_confirm=false;update_restoration(p,f,p.gui.screen.t12.t12_tabs.restoration)
 elseif n=='t12-return-doctor-confirm' and st.return_confirm and access(p,f) then
  _,why=M.return_doctor(p.index,f.id);st.return_confirm=false;refresh(p,6)
 elseif n=='t12-deposit-for-rooms' and access(p,f) then M.move(p.get_main_inventory(),f.cargo);refresh(p,5)
 elseif n=='t12-refresh-rooms' then refresh(p,5)
 elseif n=='t12-migrate-rooms' then _,why=M.relayout(p.index,f.id);refresh(p,5)
 elseif n:find('t12-room-slot-',1,true) then st.room_slot=tags.slot;refresh(p,5)
 elseif n:find('t12-build-room-',1,true) then _,why=M.build_room(p.index,f.id,tags.slot,tags.kind);refresh(p,5)
 elseif n=='t12-cancel-room' then _,why=M.cancel_room(p.index,f.id,tags.slot);refresh(p,5)
 end
 if why then tell(p,why) end
 if p.gui.screen.t12 then UI.status(p,f) end
end
function UI.changed(e)
 local el=e.element;if not el or not el.valid then return end
 local p=game.get_player(e.player_index);local st=state(p);local f=M.get(st.ship)
 if not f or p.force~=f.force then return end
 local n=el.name
 if n=='t12-search' then st.search=el.text;st.page=1 -- Refresh explicitly preserves typing focus.
 elseif n=='t12-filter' then st.filter=el.elem_value;st.page=1;refresh(p,2)
 elseif n=='t12-planet' then st.planet=st.planets[el.selected_index];update_navigation(p,f,p.gui.screen.t12.t12_tabs.navigation)
 elseif n=='t12-x' then st.x=tonumber(el.text) or 0;update_preview(p,p.gui.screen.t12.t12_tabs.navigation)
 elseif n=='t12-y' then st.y=tonumber(el.text) or 0;update_preview(p,p.gui.screen.t12.t12_tabs.navigation)
 elseif n=='t12-bookmark-name' then st.bookmark_name=el.text
 elseif n=='t12-export' then f.export=el.state and V.recharge(f)>0 and not f.voyage.returned or false;el.state=f.export
 elseif n=='t12-inner-power' then f.interior_power=el.state
 elseif el.tags.port then
  local v=root().ports[el.tags.port]
  if v and M.port_ship(v)==f then
   if n:find('filter',1,true) then v.filter=el.elem_value
   elseif n:find('keep',1,true) then v.keep=math.max(0,math.floor(tonumber(el.text) or 0))
   elseif n:find('enabled',1,true) then v.enabled=el.state end
  end
 end
end
function UI.translated(e)
 local p=game.get_player(e.player_index);if not p then return end
 local st=state(p);local name=st.pending and st.pending[e.id]
 if name then if e.translated then st.translations[name]=e.result end;st.pending[e.id]=nil end
end
function UI.confirmed(e)
 if e.element and e.element.valid and e.element.name=='t12-search' then
  local p=game.get_player(e.player_index);state(p).search=e.element.text;state(p).page=1;refresh(p,2)
 end
end
function UI.tick()
 if game.tick%30~=0 then return end
 for _,p in pairs(game.connected_players) do local st=state(p);local f=M.get(st.ship);if f then
  UI.status(p,f)
  local frame=p.gui.screen.t12
  if frame and frame.t12_tabs.selected_tab_index==5 then
   if st.room_revision~=f.room_revision then refresh(p,5)
   else
    local view=frame.t12_tabs.rooms;local room=f.rooms[st.room_slot or 1]
    if room and room.state=='building' and view['build-progress'] then
     view['build-progress'].value=math.min(1,(game.tick-room.started)/M.Rooms.build_ticks)
     view['room-countdown'].caption='Перестройка внутреннего пространства: '..math.max(0,math.ceil((room.finish-game.tick)/60))..' сек.'
    elseif view.projects then
     for _,kind in ipairs(M.Rooms.order) do local plan=M.Rooms.plans[kind];local card=view.projects['project-'..kind]
      for _,v in ipairs(plan.cost) do local have=f.cargo.get_item_count{name=v.name,quality='normal'};local color=have>=v.count and '139,211,208' or '241,171,97'
       card['cost-'..v.name].caption={'','[item=',v.name,']  [color=',color,']',math.min(have,v.count),' / ',v.count,'[/color]  ',prototypes.item[v.name].localised_name}
      end
      card['t12-build-room-'..kind].enabled=access(p,f) and M.Rooms.available(f,st.room_slot or 1) and #M.Rooms.missing(f,kind)==0 and not (plan.slots and #f.cargo>=C.max_slots)
     end
    end
   end
  end
 end end
end
return UI

