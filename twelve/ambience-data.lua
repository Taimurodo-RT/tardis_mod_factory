-- Sprites for the living interior: glass floor over the star and additive glows.
local P = '__tardis__/graphics/twelve/'
data:extend({
  -- 13 tiles across, centred under the console.
  { type = 'sprite', name = 'tardis-glass-floor', filename = P .. 'glass-floor.png', size = 1024, scale = 0.406 },
  -- Round rooms rendered in Blender (tools/blender/rooms.py): 2048 px over 68 tiles for the Eye
  -- hall, 1024 px over 36 tiles for the console room; centred on the room, hull included.
  { type = 'sprite', name = 'tardis-eye-floor', filename = P .. 'eye-floor.png', size = 2048, scale = 1.0625 },
  { type = 'sprite', name = 'tardis-eye-wall', filename = P .. 'eye-wall.png', size = 2048, scale = 1.0625 },
  { type = 'sprite', name = 'tardis-console-wall', filename = P .. 'console-wall.png', size = 1024, scale = 1.125 },
  -- White radial glow, 8 tiles across at scale 1; tinted and pulsed at runtime. Additive, so it
  -- reads in the always-lit console room where draw_light would be invisible.
  { type = 'sprite', name = 'tardis-glow', filename = P .. 'glow.png', size = 256, blend_mode = 'additive' },
})
