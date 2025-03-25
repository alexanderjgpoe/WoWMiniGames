local TexasHoldEm = _G.TexasHoldEm

if not TexasHoldEm then
    print("Error: TexasHoldEm is missing in the global scope!")
end

local mainMenu = CreateFrame("Frame", "MainMenu", UIParent, "BasicFrameTemplateWithInset")
mainMenu:SetSize(300, 200)
mainMenu:SetPoint("CENTER")
mainMenu:SetMovable(true)
mainMenu:EnableMouse(true)
mainMenu:RegisterForDrag("LeftButton")
mainMenu:SetScript("OnDragStart", mainMenu.StartMoving)
mainMenu:SetScript("OnDragStop", mainMenu.StopMovingOrSizing)
mainMenu:Show() -- Start hidden, show when needed

-- Title
mainMenu.title = mainMenu:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
mainMenu.title:SetPoint("TOP", mainMenu, "TOP", 0, -10)
mainMenu.title:SetText("WoW Mini Game Pack")

-- Button Creation Function
local function CreateGameButton(name, yOffset, onClick)
    local button = CreateFrame("Button", nil, mainMenu, "GameMenuButtonTemplate")
    button:SetSize(120, 30)
    button:SetPoint("TOP", mainMenu, "TOP", 0, yOffset)
    button:SetText(name)
    button:SetScript("OnClick", onClick)
    return button
end

-- Buttons for each game
local chessButton = CreateGameButton("Chess", -50, function()
    mainMenu:Hide()
    -- Call function to open Chess UI
end)

if not TexasHoldEm then
    print("Error: TexasHoldEm.lua did not load correctly. TexasHoldEm is nil.")
else
    print("TexasHoldEm loaded:", TexasHoldEm)
end

local pokerButton = CreateGameButton("Texas Hold 'Em", -90, function()
    mainMenu:Hide()
    TexasHoldEm:StartInviteProcess()
    -- Call function to open Poker UI
    --local game = TexasHoldEm:NewGame(6) -- Example for a 2-player game
    --TexasHoldEm:ShowUI()  
    print("Texas Hold 'Em game started!")
end)

-- Function to show the main menu
function ShowMainMenu()
    mainMenu:Show()
end
