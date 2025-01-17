-- file generated automatically
local loadedFrame = CreateFrame("FRAME")
loadedFrame:RegisterEvent("ADDON_LOADED")
loadedFrame:SetScript("OnEvent", function(_, _, addonName)
  if addonName == "WeakAurasCompanion" then
    timestamp = GetTime()
    if WeakAuras then
      local WeakAurasData = WeakAurasCompanion.WeakAuras
      -- previous version compatibility
      WeakAurasCompanion.slugs = WeakAurasData.slugs
      WeakAurasCompanion.uids = WeakAurasData.uids
      WeakAurasCompanion.ids = WeakAurasData.ids
      WeakAurasCompanion.stash = WeakAurasData.stash
      local count = WeakAuras.CountWagoUpdates()
      if count and count > 0 then
        WeakAuras.prettyPrint(WeakAuras.L["There are %i updates to your auras ready to be installed!"]:format(count))
      end
      if WeakAuras.ImportHistory then
        for id, data in pairs(WeakAurasSaved.displays) do
          if data.uid and not WeakAurasSaved.history[data.uid] then
            local slug = WeakAurasData.uids[data.uid]
            if slug then
              local wagoData = WeakAurasData.slugs[slug]
              if wagoData and wagoData.encoded then
                WeakAuras.ImportHistory(wagoData.encoded)
              end
            end
          end
        end
      end
      if WeakAurasData.stash then
        local emptyStash = true
        for _ in pairs(WeakAurasData.stash) do
          emptyStash = false
        end
        if not emptyStash then
          WeakAuras.prettyPrint(WeakAuras.L["You have new auras ready to be installed!"])
        end
      end
    end
    if Plater and Plater.CheckWagoUpdates then
      Plater.CheckWagoUpdates()
    end
  end
end)