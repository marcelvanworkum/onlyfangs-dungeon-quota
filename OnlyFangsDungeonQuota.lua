local addonName, addon = ...
_G["OnlyFangsDungeonQuota"] = addon

-- Add at the top with other constants
local ANNOUNCE_PREFERENCE_KEY = "OFDQ_AnnounceKills"

-- Add tracked mobs constant at the top
local TRACKED_MOBS = {
    "Mottled Boar",
    "Hare",
    "Adder"
}

SLASH_OFDQ1 = '/ofdq'
SlashCmdList["OFDQ"] = function(msg)
    if msg == "clear" then
        OFDQ_KillData = {
            players = {}
        }
        addon:Debug("Kill data cleared")
    elseif msg == "dump" then
        addon:Debug("Current kill data:")
        addon:Debug(OFDQ_KillData.players[UnitName("player")] or "No data")
    end
end

function addon:Debug(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00OFDQ Debug:|r " .. tostring(msg))
end

function addon:OnLoad()
    -- Initialize with announce preference
    if not OFDQ_KillData then
        OFDQ_KillData = {
            players = {},
            [ANNOUNCE_PREFERENCE_KEY] = false
        }
    end
    -- Ensure the key exists in existing data
    if OFDQ_KillData[ANNOUNCE_PREFERENCE_KEY] == nil then
        OFDQ_KillData[ANNOUNCE_PREFERENCE_KEY] = false
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:SetScript("OnEvent", function(self, event)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            addon:OnCombatLogEvent(CombatLogGetCurrentEventInfo())
        end
    end)
end

-- Helper function to check if mob should be tracked
function addon:IsTrackedMob(mobName)
    for _, trackedMob in ipairs(TRACKED_MOBS) do
        if mobName == trackedMob then
            return true
        end
    end
    return false
end

function addon:OnCombatLogEvent(...)
    local timestamp, eventType, _, sourceGUID, sourceName, sourceFlags, _,
    destGUID, destName, _, _, spellId, spellName = ...

    if eventType == "UNIT_DIED" then
        local targetName = UnitName("target")
        local inCombat = UnitAffectingCombat("player")

        -- Only proceed if it's a tracked mob
        if inCombat and destName == targetName and self:IsTrackedMob(destName) then
            self:Debug("Tracked kill detected: " .. destName)
            local playerData = {
                name = UnitName("player"),
                mob = destName,
                date = date("%Y-%m-%d")
            }

            self:StoreMobKill(playerData)
            local message = self:SerializeKillData(playerData)
            self:Debug("Broadcasting kill: " .. message)
            C_ChatInfo.SendAddonMessage("OFDQ_MOB_KILL", message, "GUILD")
        end
    end
end

function addon:StoreMobKill(data)
    local players = OFDQ_KillData.players
    players[data.name] = players[data.name] or {}
    players[data.name][data.date] = players[data.name][data.date] or {}
    players[data.name][data.date][data.mob] = (players[data.name][data.date][data.mob] or 0) + 1

    -- Announce if enabled
    if OFDQ_KillData[ANNOUNCE_PREFERENCE_KEY] then
        local totalKills = players[data.name][data.date][data.mob]
        local message = string.format("killed %s! (Total today: %d)",
            data.mob, totalKills)
        SendChatMessage(message, "EMOTE")
    end

    -- Debug message
    self:Debug(string.format("Stored kill: %s killed %s (%d kills on %s)",
        data.name, data.mob, players[data.name][data.date][data.mob], data.date))
end

-- Add helper function
function addon:CanPlayerUseChat()
    -- Basic checks for chat availability
    if IsInCombatLockdown() then return false end
    if not DEFAULT_CHAT_FRAME then return false end
    if GetCVar("ChatLocked") == "1" then return false end
    return true
end

addon:OnLoad()
