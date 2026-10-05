-- Fix common migration issues.

tardis.on_event(tardis.events.on_init(), function()
    for _, tardis in pairs(storage.factories) do
        -- Fix issues when forces are deleted.
        if not tardis.force or not tardis.force.valid then
            tardis.force = game.forces.player
        end

        -- Fix issues when quality prototypes are removed.
        if not tardis.quality or not tardis.quality.valid then
            if tardis.building and tardis.building.valid then
                tardis.quality = tardis.building.quality
            else
                tardis.quality = prototypes.quality.normal
            end
        end

        -- Clean deprecated data.
        tardis.original_planet = nil
    end
end)
