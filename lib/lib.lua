_G.tardis = tardis or {}

require "table"
require "string"
require "defines"
require "color"

if data and data.raw and not data.raw.item["iron-plate"] then
    tardis.stage = "settings"
elseif data and data.raw then
    tardis.stage = "data"
    require "data-stage"
elseif script then
    tardis.stage = "control"
    require "control-stage"
else
    error("Could not determine load order stage.")
end
