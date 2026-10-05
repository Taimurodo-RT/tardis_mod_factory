-- Sprites for the living interior: glass floor over the star and additive glows.
local P = '__tardis__/graphics/twelve/'
data:extend({
  -- 13 tiles across, centred under the console.
  { type = 'sprite', name = 'tardis-glass-floor', filename = P .. 'glass-floor.png', size = 1024, scale = 0.406 },
  -- White radial glow, 8 tiles across at scale 1; tinted and pulsed at runtime. Additive, so it
  -- reads in the always-lit console room where draw_light would be invisible.
  { type = 'sprite', name = 'tardis-glow', filename = P .. 'glow.png', size = 256, blend_mode = 'additive' },
})
