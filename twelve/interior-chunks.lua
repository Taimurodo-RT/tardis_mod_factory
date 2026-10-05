-- Marking a Factorio chunk generated does not initialise its terrain: with an
-- empty autoplace list the native fallback is grass-1. Explicitly start every
-- newly allocated interior chunk as void before carving rooms into it.
local C={}
function C.name(surface,x,y)
 local tile=surface.get_tile(x,y)
 return tile.valid and tile.name or 'out-of-map'
end
function C.ensure(surface,cx,cy)
 if surface.is_chunk_generated({cx,cy}) then return end
 local tiles={}
 for x=cx*32,cx*32+31 do for y=cy*32,cy*32+31 do
  local name=C.name(surface,x,y)
  -- Preserve any already scripted/custom paving in a partly generated chunk.
  tiles[#tiles+1]={name=(name=='grass-1' or name=='out-of-map') and 'out-of-map' or name,position={x,y}}
 end end
 surface.set_chunk_generated_status({cx,cy},defines.chunk_generated_status.entities)
 surface.set_tiles(tiles,false)
end
function C.ensure_area(surface,left,top,right,bottom)
 for cx=math.floor(left/32),math.floor(right/32) do for cy=math.floor(top/32),math.floor(bottom/32) do C.ensure(surface,cx,cy) end end
end
function C.clean(f,position,only_chunk)
 local s=f.surface;local tiles={}
 local function owned(x,y)
  if x>=-20 and x<=43 and y>=-20 and y<=22 then return true end
  for slot,room in pairs(f.rooms or {}) do if room.state=='ready' then
   local p=room.position or position(slot,f)
   if x>=p.x-12 and x<p.x+12 and y>=p.y-10 and y<p.y+10 then return true end
  end end
  return false
 end
 local function clean_chunk(cx,cy)
  local area={{cx*32,cy*32},{cx*32+32,cy*32+32}}
  local grass=s.find_tiles_filtered{area=area,name='grass-1'}
  if #grass==0 then return end
  -- If a player has used leaked natural floor, retain that whole patch. This
  -- avoids deleting a walkable factory yard around a machine or dropped items.
  for _,e in ipairs(s.find_entities_filtered{area=area}) do
   local box=e.bounding_box
   for x=math.floor(box.left_top.x),math.floor(box.right_bottom.x) do for y=math.floor(box.left_top.y),math.floor(box.right_bottom.y) do
    if not owned(x,y) and C.name(s,x,y)=='grass-1' then return end
   end end
  end
  for _,tile in ipairs(grass) do
   local p=tile.position
   if not owned(p.x,p.y) then tiles[#tiles+1]={name='out-of-map',position=p} end
  end
 end
 if only_chunk then clean_chunk(only_chunk.x,only_chunk.y)
 else for chunk in s.get_chunks() do clean_chunk(chunk.x,chunk.y) end end
 if #tiles>0 then s.set_tiles(tiles,false);f.room_revision=(f.room_revision or 0)+1 end
 return #tiles
end
return C
