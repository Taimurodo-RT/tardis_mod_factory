-- Light and motion in the console room: glass floor lit by the star below, and a time rotor
-- whose glow follows the ship's mood (calm, flight, low power, returned to the Doctor).
local A = {}

local function valid(o)
  return o and o.valid
end

-- One shared heartbeat with the Eye, so the glass glow and the star pulse together.
function A.pulse(speed)
  return 0.5 + 0.5 * math.sin(game.tick / (speed or 48))
end

local function glow(color, k)
  return { color[1] * k, color[2] * k, color[3] * k, k }
end

function A.ensure(f)
  if not valid(f.surface) then
    return
  end
  f.ambience = f.ambience or {}
  local a = f.ambience
  if not valid(a.glass) then
    a.glass = rendering.draw_sprite({
      sprite = 'tardis-glass-floor',
      surface = f.surface,
      target = { 0, 0 },
      render_layer = 'floor',
    })
  end
  -- The separate hull band of 1.9 is part of the console wall render now.
  if a.hull then
    if valid(a.hull) then
      a.hull.destroy()
    end
    a.hull = nil
  end
  if not valid(a.under) then
    a.under = rendering.draw_sprite({
      sprite = 'tardis-glow',
      surface = f.surface,
      target = { 0, 0 },
      render_layer = 'lower-object',
      x_scale = 2.2,
      y_scale = 2.2,
      tint = { 0, 0, 0, 0 },
    })
  end
  if valid(f.console) and not valid(a.rotor) then
    a.rotor = rendering.draw_sprite({
      sprite = 'tardis-glow',
      surface = f.surface,
      target = { entity = f.console, offset = { 0, -4.2 } },
      render_layer = 'higher-object-above',
      x_scale = 0.42,
      y_scale = 0.75,
      tint = { 0, 0, 0, 0 },
    })
  end
end

-- low: repaired but without enough charge for a jump.
function A.tick(f, low)
  local a = f.ambience
  if not a then
    return
  end
  local story = f.voyage or {}
  local returned = story.returned
  local star = A.pulse()
  if valid(a.under) then
    -- The star below shines brighter as the Eye is restored.
    local eye = story.eye and 1 or 0.45
    a.under.color = returned and { 0, 0, 0, 0 } or glow({ 1, 0.48, 0.14 }, (0.4 + 0.25 * star) * eye)
  end
  if valid(a.rotor) then
    local color, k
    if returned then
      color, k = { 0.4, 0.45, 0.5 }, 0.08
    elseif f.flight then
      color, k = { 0.85, 0.95, 1 }, 0.55 + 0.35 * A.pulse(6)
    elseif low then
      color, k = { 1, 0.45, 0.15 }, 0.5 + 0.3 * A.pulse(20)
    else
      color, k = { 0.35, 0.85, 1 }, 0.6 + 0.25 * A.pulse(30)
    end
    a.rotor.color = glow(color, k)
  end
end

function A.destroy(f)
  for _, r in pairs(f.ambience or {}) do
    if valid(r) then
      r.destroy()
    end
  end
  f.ambience = nil
end

return A
