local WoWMiniGames = LibStub("AceAddon-3.0"):NewAddon("WoWMiniGames", "AceComm-3.0", "AceEvent-3.0")

local ADDON_PREFIX = "WoWMiniGames"

-- Function to send a message using AceComm
function WoWMiniGames:SendGameMessage(target, game, msgType, data)
    local message = game .. ":" .. msgType .. ":" .. data  -- Format: "Poker:BET:50"
    self:SendCommMessage(ADDON_PREFIX, message, "WHISPER", target)
end

-- Function to handle incoming messages
function WoWMiniGames:OnGameMessage(prefix, message, channel, sender)
    if prefix ~= ADDON_PREFIX then return end  -- Ignore other addons

    local game, msgType, data = strsplit(":", message, 3)

    if game == "Poker" then
        if msgType == "INVITE" then
            TexasHoldEm:ShowInvitePopup(sender)
        elseif msgType == "JOIN" then
            TexasHoldEm:AddPlayerToGame(data)
        elseif msgType == "DECLINE" then
            print(data .. " declined the invitation.")
        elseif msgType == "BET" then
            print(sender .. " bet: " .. data)
        elseif msgType == "FOLD" then
            print(sender .. " folded")
        elseif msgType == "DEAL" then
            print("Dealing new hand...")
        end
    elseif game == "Chess" then
        if msgType == "MOVE" then
            print(sender .. " moved: " .. data)
        end
    end
end

function TexasHoldEm:SendInvites(invitedPlayers)
    for _, player in ipairs(invitedPlayers) do
        WoWMiniGames:SendGameMessage(player, "Poker", "INVITE", UnitName("player"))
    end
end

function TexasHoldEm:ShowInvitePopup(host)
    StaticPopupDialogs["TEXAS_HOLDEM_INVITE"] = {
        text = host .. " invited you to play Texas Hold 'Em. Set your purse amount (min 500g):",
        button1 = "Join",
        button2 = "Decline",
        hasEditBox = true,
        OnShow = function(self)
            self.editBox:SetText("500") -- Default purse
        end,
        OnAccept = function(self)
            local purse = tonumber(self.editBox:GetText())
            if purse and purse >= 500 then
                WoWMiniGames:SendGameMessage(host, "Poker", "JOIN", UnitName("player") .. ":" .. purse)
            else
                print("Invalid purse amount. Must be at least 500g.")
            end
        end,
        OnCancel = function()
            WoWMiniGames:SendGameMessage(host, "Poker", "DECLINE", UnitName("player"))
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show("TEXAS_HOLDEM_INVITE")
end


-- Register AceComm for receiving messages
function WoWMiniGames:OnInitialize()
    self:RegisterComm(ADDON_PREFIX, "OnGameMessage")
end
