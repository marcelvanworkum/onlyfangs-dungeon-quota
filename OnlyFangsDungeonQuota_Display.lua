local addonName, addon = ...

-- Constants for UI layout
local FRAME_WIDTH = 1000
local FRAME_HEIGHT = 500
local ZONES = {
    ["Durotar"] = {
        ["Mottled Boar"] = true,
        ["Hare"] = true,
        ["Adder"] = true
    },
    ["The Barrens"] = {
        ["Plainstrider"] = true,
        ["Zhevra Runner"] = true,
        ["Savannah Lion"] = true
    }
}
local TRACKED_MOBS = {
    ["Durotar"] = {
        "Mottled Boar",
        "Hare",
        "Adder"
    },
    ["The Barrens"] = {
        "Plainstrider",
        "Zhevra Runner",
        "Savannah Lion"
    }
}
local COLUMN_LAYOUT = {
    player = { width = 200, label = "Player" },
    mobs = {
        ["Durotar"] = {
            { width = 300, name = "Mottled Boar" },
            { width = 200, name = "Hare" },
            { width = 200, name = "Adder" }
        },
        ["The Barrens"] = {
            { width = 300, name = "Plainstrider" },
            { width = 200, name = "Zhevra Runner" },
            { width = 200, name = "Savannah Lion" }
        }
    },
    total = { width = 100, label = "Total" }
}
local ANNOUNCE_PREFERENCE_KEY = "OFDQ_AnnounceKills"

-- Main frame creation
function addon:CreateMainFrame()
    local frame = CreateFrame("Frame", "OFDQMainFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")

    -- Make frame movable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Add title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -5)
    frame.title:SetText("OnlyFangs Dungeon Quota")

    -- Add date selector
    frame.dateDropdown = self:CreateDateDropdown(frame)
    local defaultDate = self:GetAvailableDates()[1] or date("%Y-%m-%d")
    UIDropDownMenu_SetText(frame.dateDropdown, defaultDate)

    -- Add zone selector
    frame.zoneDropdown = self:CreateZoneDropdown(frame)
    local defaultZone = next(ZONES) -- Gets first zone (Durotar)
    UIDropDownMenu_SetText(frame.zoneDropdown, defaultZone)

    -- Add announce checkbox
    frame.announceCheckbox = self:CreateAnnounceCheckbox(frame)
    frame.announceCheckbox:SetPoint("TOPLEFT", frame, "TOPLEFT", 500, -30)

    -- Add scrollable content area
    frame.content = self:CreateScrollableContent(frame)

    -- Initial display
    frame:SetScript("OnShow", function()
        addon:UpdateDisplay(defaultDate, defaultZone)
    end)

    frame:Hide()
    return frame
end

-- Date dropdown creation
function addon:CreateDateDropdown(frame)
    local dateDropdown = CreateFrame("Frame", "OFDQDateDropdown", frame, "UIDropDownMenuTemplate")
    dateDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)

    UIDropDownMenu_Initialize(dateDropdown, function(self, level)
        local dates = addon:GetAvailableDates()
        local info = UIDropDownMenu_CreateInfo()

        for _, date in ipairs(dates) do
            info.text = date
            info.func = function()
                UIDropDownMenu_SetText(dateDropdown, date)
                addon:UpdateDisplay(date, UIDropDownMenu_GetText(OFDQZoneDropdown))
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    return dateDropdown
end

-- Scrollable content area creation
function addon:CreateScrollableContent(frame)
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(FRAME_WIDTH - 40, FRAME_HEIGHT)
    scrollFrame:SetScrollChild(content)

    return content
end

-- Get sorted list of available dates
function addon:GetAvailableDates()
    local dates, seen = {}, {}
    for _, playerData in pairs(OFDQ_KillData.players) do
        for date in pairs(playerData) do
            if not seen[date] then
                table.insert(dates, date)
                seen[date] = true
            end
        end
    end
    table.sort(dates, function(a, b) return a > b end)
    return dates
end

-- Update display with current data
function addon:UpdateDisplay(date, zone)
    local content = OFDQMainFrame.content
    self:ClearContent(content)

    -- Create headers
    local xOffset = self:CreateHeaders(content, zone)
    local yOffset = -40

    -- Display player data for selected zone
    self:DisplayPlayerData(content, date, zone, xOffset, yOffset)
end

-- Clear existing content
function addon:ClearContent(content)
    -- Hide and remove all child frames
    local children = { content:GetChildren() }
    for _, child in pairs(children) do
        child:Hide()
        child:SetParent(nil)
    end

    -- Clear all font strings and textures
    local regions = { content:GetRegions() }
    for _, region in pairs(regions) do
        region:Hide()
        region:SetParent(nil)
    end

    -- Reset the scroll position
    if content:GetParent() then
        content:GetParent():SetVerticalScroll(0)
    end
end

-- Create column headers
function addon:CreateHeaders(content, zone)
    local xOffset = 20
    local yOffset = -10

    -- Player header
    local nameHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameHeader:SetPoint("TOPLEFT", content, "TOPLEFT", xOffset, yOffset)
    nameHeader:SetText(COLUMN_LAYOUT.player.label)
    xOffset = xOffset + COLUMN_LAYOUT.player.width

    -- Mob headers for selected zone
    for _, mobInfo in ipairs(COLUMN_LAYOUT.mobs[zone]) do
        local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        header:SetPoint("TOPLEFT", content, "TOPLEFT", xOffset, yOffset)
        header:SetText(mobInfo.name)
        xOffset = xOffset + mobInfo.width
    end

    -- Total header
    local totalHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    totalHeader:SetPoint("TOPLEFT", content, "TOPLEFT", xOffset, yOffset)
    totalHeader:SetText(COLUMN_LAYOUT.total.label)

    return xOffset
end

-- Display player data rows
function addon:DisplayPlayerData(content, date, zone, xOffset, yOffset)
    for playerName, playerDates in pairs(OFDQ_KillData.players) do
        if playerDates[date] then
            self:DisplayPlayerRow(content, playerName, playerDates[date], zone, yOffset)
            yOffset = yOffset - 20
        end
    end
end

-- Display a single player row
function addon:DisplayPlayerRow(content, playerName, playerData, zone, yOffset)
    local xOffset = 20
    local playerTotal = 0

    -- Player name
    local nameText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", content, "TOPLEFT", xOffset, yOffset)
    nameText:SetText(playerName)
    xOffset = xOffset + COLUMN_LAYOUT.player.width

    -- Mob kills for selected zone
    for _, mobInfo in ipairs(COLUMN_LAYOUT.mobs[zone]) do
        local kills = playerData[mobInfo.name] or 0
        playerTotal = playerTotal + kills

        local killsText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        killsText:SetPoint("TOPLEFT", content, "TOPLEFT", xOffset, yOffset)
        killsText:SetText(tostring(kills))
        xOffset = xOffset + mobInfo.width
    end

    -- Total kills
    local totalText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    totalText:SetPoint("TOPLEFT", content, "TOPLEFT", xOffset, yOffset)
    totalText:SetText(tostring(playerTotal))
end

-- Slash Commands
SLASH_OFDQUI1 = '/ofdqui'
SlashCmdList["OFDQUI"] = function(msg)
    if OFDQMainFrame and OFDQMainFrame:IsShown() then
        OFDQMainFrame:Hide()
        return
    end

    if not OFDQMainFrame then
        addon:CreateMainFrame()
    end

    -- Clear and recreate content
    if OFDQMainFrame.content then
        addon:ClearContent(OFDQMainFrame.content)
    end

    -- Show frame (which triggers OnShow)
    OFDQMainFrame:Show()
end

-- Debug/Testing Command
SLASH_OFDQTEST1 = '/ofdqtest'
SlashCmdList["OFDQTEST"] = function(msg)
    local testPlayers = { UnitName("player"), "codezugger", "codecode" }
    local testDates = {
        "2025-01-03", -- Today
        "2025-01-02", -- Yesterday
        "2025-01-01"  -- Day before
    }

    for _, testDate in ipairs(testDates) do
        for _, playerName in ipairs(testPlayers) do
            OFDQ_KillData.players[playerName] = OFDQ_KillData.players[playerName] or {}
            OFDQ_KillData.players[playerName][testDate] = OFDQ_KillData.players[playerName][testDate] or {}

            -- Add kills for each zone
            for zoneName, mobList in pairs(TRACKED_MOBS) do
                for _, mobName in ipairs(mobList) do
                    local currentKills = OFDQ_KillData.players[playerName][testDate][mobName] or 0
                    local newKills = math.random(1, 20)
                    OFDQ_KillData.players[playerName][testDate][mobName] = currentKills + newKills
                    addon:Debug(string.format("[%s][%s][%s] Added %d kills of %s (total now: %d)",
                        playerName,
                        testDate,
                        zoneName,
                        newKills,
                        mobName,
                        OFDQ_KillData.players[playerName][testDate][mobName]
                    ))
                end
            end
        end
    end

    -- Refresh UI if shown
    if OFDQMainFrame and OFDQMainFrame:IsShown() then
        OFDQMainFrame:Hide()
        OFDQMainFrame:Show()
        addon:UpdateDisplay(testDates[1], "Durotar") -- Show today's Durotar data by default
    end
end

-- Add announce checkbox
function addon:CreateAnnounceCheckbox(frame)
    local checkbox = CreateFrame("CheckButton", "OFDQAnnounceCheckbox", frame, "ChatConfigCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", frame, "TOPLEFT", 200, -30)
    getglobal(checkbox:GetName() .. 'Text'):SetText("Announce kills")

    -- Load saved preference
    checkbox:SetChecked(OFDQ_KillData[ANNOUNCE_PREFERENCE_KEY])

    checkbox:SetScript("OnClick", function(self)
        OFDQ_KillData[ANNOUNCE_PREFERENCE_KEY] = self:GetChecked()
    end)

    return checkbox
end

-- Add zone dropdown creation
function addon:CreateZoneDropdown(frame)
    local zoneDropdown = CreateFrame("Frame", "OFDQZoneDropdown", frame, "UIDropDownMenuTemplate")
    zoneDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 250, -30)

    UIDropDownMenu_Initialize(zoneDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for zoneName, _ in pairs(ZONES) do
            info.text = zoneName
            info.func = function()
                UIDropDownMenu_SetText(zoneDropdown, zoneName)
                addon:UpdateDisplay(UIDropDownMenu_GetText(OFDQDateDropdown), zoneName)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    return zoneDropdown
end
