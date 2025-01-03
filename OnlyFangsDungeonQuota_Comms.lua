local addonName, addon = ...

-- Register addon message prefix
C_ChatInfo.RegisterAddonMessagePrefix("OFDQ_MOB_KILL")

-- Handle incoming messages
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    if prefix == "OFDQ_MOB_KILL" then
        addon:Debug(string.format("Received kill data from %s: %s", sender, message))
        local data = addon:DeserializeKillData(message)
        addon:StoreMobKill(data)
    end
end)

function addon:SerializeKillData(data)
    return string.format("%s:%s:%s",
        data.name,
        data.mob,
        data.date
    )
end

function addon:DeserializeKillData(message)
    local name, mob, date = strsplit(":", message)
    return {
        name = name,
        mob = mob,
        date = date
    }
end
