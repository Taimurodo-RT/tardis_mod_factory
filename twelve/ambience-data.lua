-- Sprites for the living interior: glass floor over the star and additive glows.
local P = '__tardis__/graphics/twelve/'
data:extend({
  -- 13 tiles across, centred under the console.
  { type = 'sprite', name = 'tardis-glass-floor', filename = P .. 'glass-floor.png', size = 1024, scale = 0.406 },
  -- Wall ring for the closed Eye hall (tools/make_rims.py), same size as tardis-circular-rim.
  { type = 'sprite', name = 'tardis-eye-rim', filename = P .. 'eye-rim.png', size = 1536, scale = 0.65 },
  -- Dark hull band laid just outside a wall ring to hide the stepped tile edge behind it. Its inner
  -- edge is 440 px from the centre: scale 1.09 puts it at 15 tiles, scale 2.15 at 29.6.
  { type = 'sprite', name = 'tardis-hull-ring', filename = P .. 'hull-ring.png', size = 1024 },
  -- The console-room version leaves the north, east and south corridors open.
  { type = 'sprite', name = 'tardis-hull-ring-console', filename = P .. 'hull-ring-console.png', size = 1024 },
  -- White radial glow, 8 tiles across at scale 1; tinted and pulsed at runtime. Additive, so it
  -- reads in the always-lit console room where draw_light would be invisible.
  { type = 'sprite', name = 'tardis-glow', filename = P .. 'glow.png', size = 256, blend_mode = 'additive' },
})
