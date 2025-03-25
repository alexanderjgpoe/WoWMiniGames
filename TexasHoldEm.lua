-- Texas Hold 'Em Logic for WoW Mini Game Addon
local TexasHoldEm = {}
_G.TexasHoldEm = TexasHoldEm  -- Make it globally accessible
print("TexasHoldEm is now set globally!")

-- Constants
TexasHoldEm.joinedPlayers = {}
local SUITS = {H = "hearts", D = "diamonds", C = "clubs", S = "spades"}
local VALUES = {"2", "3", "4", "5", "6", "7", "8", "9", "10", "Jack", "Queen", "King", "Ace"}
local GOLD_TO_CHIPS_RATIO = 100  -- 1 gold = 100 chips

function TexasHoldEm:ShowInviteUI()
    if self.inviteFrame then self.inviteFrame:Show() return end

    -- Create frame
    local frame = CreateFrame("Frame", "TexasHoldEmInviteFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(300, 400)
    frame:SetPoint("CENTER")
    
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -10)
    frame.title:SetText("Invite Players")

    -- Scrollable player list
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(280, 300)
    scrollFrame:SetPoint("TOP", frame, "TOP", 0, -40)
    
    local content = CreateFrame("Frame")
    scrollFrame:SetScrollChild(content)
    content:SetSize(260, 400)

    local invitedPlayers = {}

    -- Create checkboxes for available players
    local yOffset = 0
    for i = 1, GetNumGroupMembers() do
        local playerName = GetRaidRosterInfo(i)
        if playerName and playerName ~= UnitName("player") then
            local checkbox = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
            checkbox:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -yOffset)
            checkbox:SetScript("OnClick", function(self)
                if self:GetChecked() then
                    table.insert(invitedPlayers, playerName)
                else
                    for index, name in ipairs(invitedPlayers) do
                        if name == playerName then
                            table.remove(invitedPlayers, index)
                            break
                        end
                    end
                end
            end)

            local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            label:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
            label:SetText(playerName)

            yOffset = yOffset + 30
        end
    end

    -- Invite button
    local inviteButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    inviteButton:SetSize(120, 30)
    inviteButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
    inviteButton:SetText("Send Invites")
    inviteButton:SetScript("OnClick", function()
        TexasHoldEm:SendInvites(invitedPlayers)
        frame:Hide()
    end)

    self.inviteFrame = frame
end

function TexasHoldEm:StartInviteProcess()
    -- Create input pop-up for blinds
    StaticPopupDialogs["TEXAS_HOLDEM_BLINDS"] = {
        text = "Enter small and big blind amounts (min 10g small, 20g big):",
        button1 = "OK",
        button2 = "Cancel",
        hasEditBox = true,
        OnShow = function(self)
            self.editBox:SetText("10,20") -- Default values
        end,
        OnAccept = function(self)
            local input = self.editBox:GetText()
            local smallBlind, bigBlind = strsplit(",", input)
            smallBlind, bigBlind = tonumber(smallBlind), tonumber(bigBlind)

            if smallBlind and bigBlind and smallBlind >= 10 and bigBlind >= 20 then
                TexasHoldEm.smallBlindAmount = smallBlind
                TexasHoldEm.bigBlindAmount = bigBlind
                TexasHoldEm:ShowInviteUI()
            else
                print("Invalid blinds. Try again.")
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show("TEXAS_HOLDEM_BLINDS")
end

function TexasHoldEm:AddPlayerToGame(data)
    local playerName, purse = strsplit(":", data)
    purse = tonumber(purse)

    if not purse or purse < 500 then return end  -- Ensure valid purse

    table.insert(self.joinedPlayers, {name = playerName, purse = purse})
    print(playerName .. " joined with a purse of " .. purse .. "g.")

    if #self.joinedPlayers > 1 then
        TexasHoldEm:StartGame()
    end
end


--[[function TexasHoldEm:AddPlayerToGame(playerName)
    table.insert(self.joinedPlayers, playerName)
    print(playerName .. " has joined the game.")

    -- Start the game when all invited players respond
    if #self.joinedPlayers > 1 then
        TexasHoldEm:StartGame()
    end
end--]]

function TexasHoldEm:StartGame()
    local numPlayers = #self.joinedPlayers
    if numPlayers < 2 then
        print("Not enough players to start.")
        return
    end

    local game = TexasHoldEm:NewGame(numPlayers)
    game.players = {}

    for i, playerName in ipairs(self.joinedPlayers) do
        game.players[i] = {
            name = playerName,
            hand = {table.remove(game.deck), table.remove(game.deck)},
            gold = GetMoney(),
            currentBet = 0,
            hasFolded = false
        }
    end
    
    -- Apply chosen blind amounts
    local smallBlind = (game.dealerButton % numPlayers) + 1
    local bigBlind = (smallBlind % numPlayers) + 1
    game.players[smallBlind].currentBet = TexasHoldEm.smallBlindAmount
    game.players[bigBlind].currentBet = TexasHoldEm.bigBlindAmount
    game.pot = TexasHoldEm.smallBlindAmount + TexasHoldEm.bigBlindAmount

    self.currentGame = game
    self:UpdatePlayerUI(game)
end


-- Create a deck of 52 cards
function TexasHoldEm:CreateDeck()
    local deck = {}
    for suitKey, suitName in pairs(SUITS) do
        for _, value in ipairs(VALUES) do
            local card = {
                value = value,         -- "A", "K", "2", etc.
                suit = suitKey,        -- "C", "D", "H", "S"
                texture = "Interface/AddOns/WoWMiniGames/Textures/Cards/" .. value .. " of " .. suitName .. ".blp"
            }
            table.insert(deck, card)
        end
    end
    return deck
end

local deck = TexasHoldEm:CreateDeck()

-- Shuffle the deck
function TexasHoldEm:ShuffleDeck(deck)
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
end
TexasHoldEm:ShuffleDeck(deck)



-- Deal hole cards to players
function TexasHoldEm:DealHoleCards(deck, numPlayers)
    local players = {}
    for i = 1, numPlayers do
        players[i] = {
            hand = {table.remove(deck), table.remove(deck)},
            chips = GetMoney() / GOLD_TO_CHIPS_RATIO,  -- Convert player gold to chips
            currentBet = 0,
            hasFolded = false
        }
    end
    return players
end

-- Deal community cards
function TexasHoldEm:DealCommunityCards(game, count)
    for i = 1, count do
        if #game.deck == 0 then return end  -- Safety check

        local card = table.remove(game.deck)
        table.insert(game.communityCards, card)

        print("Dealt Community Card: " .. card.value .. " of " .. card.suit)
    end

    self:UpdateCommunityCardUI(game)
end

---------------------------------------------------------------
-- For Testing
---------------------------------------------------------------
function TexasHoldEm:DealNextCommunityCard(game)
    if not game.communityCards then game.communityCards = {} end

    if #game.communityCards < 3 then
        table.insert(game.communityCards, table.remove(game.deck))  -- Flop (first 3)
    elseif #game.communityCards == 3 then
        table.insert(game.communityCards, table.remove(game.deck))  -- Turn
    elseif #game.communityCards == 4 then
        table.insert(game.communityCards, table.remove(game.deck))  -- River
    else
        print("All community cards have already been dealt!")
        return
    end

    self:UpdateCommunityCardUI(game)
end
---------------------------------------------------------------

function TexasHoldEm:UpdateCommunityCardUI(game)
    if not self.frame or not game.communityCards then return end

    for i, card in ipairs(game.communityCards) do
        local cardTexture = self.frame["communityCard" .. i]
        if not cardTexture then
            -- Create a new texture for this card
            cardTexture = self.frame:CreateTexture(nil, "OVERLAY")
            cardTexture:SetSize(50, 70)  -- Adjust as needed
            cardTexture:SetPoint("CENTER", self.frame, "CENTER", (i - 2) * 60, 0)
            self.frame["communityCard" .. i] = cardTexture
        end
        cardTexture:SetTexture(card.texture)
    end
end

-- Initialize a new game
function TexasHoldEm:NewGame(numPlayers)
    if numPlayers < 2 or numPlayers > 6 then
        print("Texas Hold 'Em requires 2 to 6 players.")
        return nil
    end

    local game = {}
    game.deck = self:CreateDeck()
    self:ShuffleDeck(game.deck)
    
    game.players = {}
    local totalSeats = numPlayers + 1 -- Players + AI Dealer
    local seatPositions = {  
        {x = 0, y = -120},  -- Player 1 (Bottom)
        {x = -150, y = -60}, -- Player 2 (Bottom Left)
        {x = -150, y = 60},  -- Player 3 (Top Left)
        {x = 0, y = 120},    -- Player 4 (Top)
        {x = 150, y = 60},   -- Player 5 (Top Right)
        {x = 150, y = -60}   -- Player 6 (Bottom Right)
    }

    for i = 1, numPlayers do
        game.players[i] = {
            seat = seatPositions[i],
            hand = {table.remove(game.deck), table.remove(game.deck)},
            gold = GetMoney(),
            currentBet = 0,
            hasFolded = false
        }
    end

    -- **Set the Dealer Button and Blinds**
    game.dealerButton = 1 -- Start with Player 1 as dealer
    game.currentBet = 100  -- Big blind amount
    game.pot = 0
    
    -- **Blinds: Small & Big**
    local smallBlind = (game.dealerButton % numPlayers) + 1
    local bigBlind = (smallBlind % numPlayers) + 1
    game.players[smallBlind].currentBet = 50
    game.players[bigBlind].currentBet = 100
    game.pot = 150  

    -- **Set Turn Order**
    game.currentTurn = (bigBlind % numPlayers) + 1  -- First player after big blind

    -- **Track Betting Rounds**
    game.bettingRound = 1  -- Pre-flop

    self.currentGame = game
    self:UpdatePlayerUI(game)

    return game
end

--[[function TexasHoldEm:NewGame(numPlayers)
    if numPlayers < 2 or numPlayers > 6 then
        print("Texas Hold 'Em requires 2 to 6 players.")
        return nil
    end

    local game = {}
    game.deck = self:CreateDeck()
    self:ShuffleDeck(game.deck)
    
    game.players = {}
    local totalSeats = numPlayers + 1 -- Players + AI Dealer
    local seatPositions = {
        {x = 0, y = -120},  -- Bottom (Player 1)
        {x = -150, y = -60}, -- Bottom Left
        {x = -150, y = 60},  -- Top Left
        {x = 0, y = 120},    -- Top (AI Dealer)
        {x = 150, y = 60},   -- Top Right
        {x = 150, y = -60}   -- Bottom Right
    }

    for i = 1, numPlayers do
        game.players[i] = {
            seat = seatPositions[i],
            hand = {table.remove(game.deck), table.remove(game.deck)},
            gold = GetMoney(), -- Use actual gold amount 
            currentBet = 0,   
            hasFolded = false
        }
    end

    -- **Assign AI Dealer**
    game.dealer = {
        seat = seatPositions[totalSeats],  
        isAI = true
    }

    -- Set the Dealer Button and Blinds
    game.dealerButton = 1 -- Start with Player 1 as dealer
    game.currentBet = 100  -- Big blind amount
    game.pot = 0

    -- **Set the initial minimum bet (big blind & small blind)**
    game.currentBet = 100  -- Set the first required bet (adjustable)
    game.pot = 0
    
    -- Apply blinds
    if numPlayers >= 2 then
        game.players[1].currentBet = 50  -- Small blind
        game.players[2].currentBet = 100 -- Big blind
        game.pot = 150  -- Initial pot from blinds
    end

    game.currentTurn = 3  -- The player after the big blind goes first

    self.currentGame = game

    -- **Update UI immediately after dealing**
    if self.frame then
        self:UpdatePlayerUI(game)
    end

    return game
end--]]


function TexasHoldEm:UpdatePlayerUI(game)
    if not self.frame then return end

    for i, player in ipairs(game.players) do
        -- Card 1
        local card1 = self.frame["playerCard" .. i .. "_1"]
        if not card1 then
            card1 = self.frame:CreateTexture(nil, "OVERLAY")
            card1:SetSize(50, 70)
            card1:SetPoint("CENTER", self.frame, "CENTER", player.seat.x - 30, player.seat.y)
            self.frame["playerCard" .. i .. "_1"] = card1
        end

        -- Card 2
        local card2 = self.frame["playerCard" .. i .. "_2"]
        if not card2 then
            card2 = self.frame:CreateTexture(nil, "OVERLAY")
            card2:SetSize(50, 70)
            card2:SetPoint("CENTER", self.frame, "CENTER", player.seat.x + 30, player.seat.y)
            self.frame["playerCard" .. i .. "_2"] = card2
        end

        -- Assign textures
        if i == 1 then
            -- Show player's own cards
            card1:SetTexture(player.hand[1].texture)
            card2:SetTexture(player.hand[2].texture)
        else
            -- Hide other players' cards by showing the back
            card1:SetTexture("Interface/AddOns/WoWMiniGames/Textures/Cards/Card Back Skull.blp")
            card2:SetTexture("Interface/AddOns/WoWMiniGames/Textures/Cards/Card Back Skull.blp")
        end
    end

    -- Update the total pot display
    if self.frame.potDisplay then
        self.frame.potDisplay:SetText("Pot: " .. game.pot .. "g")
    end

    for i, player in ipairs(game.players) do
        if not player.seat then
            print("Error: Player seat missing for player " .. i)
            return
        end

        -- Update or create the player's bet display
        local betText = self.frame["playerBet" .. i]
        if not betText then
            betText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            betText:SetPoint("CENTER", self.frame, "CENTER", player.seat.x, player.seat.y + 40)
            self.frame["playerBet" .. i] = betText
        end
        betText:SetText("|cffffd700" .. player.currentBet .. "g|r")
    end
end

function TexasHoldEm:NextTurn(game)
    repeat
        game.currentTurn = game.currentTurn % #game.players + 1
    until not game.players[game.currentTurn].hasFolded
end

-- Betting functions
function TexasHoldEm:PlaceBet(game, playerIndex, amount)
    if playerIndex ~= game.currentTurn then
        print("It's not your turn!")
        return false, "Not your turn"
    end

    local player = game.players[playerIndex]
    if player.hasFolded then return false, "Player has folded" end
    if amount > player.gold then return false, "Not enough gold" end
    
    player.gold = player.gold - amount
    player.currentBet = player.currentBet + amount
    game.pot = game.pot + amount
    game.currentBet = math.max(game.currentBet, player.currentBet)

    -- Broadcast the bet to other players
    local msg = playerIndex .. ":" .. amount
    WoWMiniGames:SendGameMessage("RAID", "Poker", "BET", msg)

    self:NextTurn(game)

    -- Check if the betting round should advance
    TexasHoldEm:AdvanceBettingRound(game)

    self:UpdatePlayerUI(game)  -- Update UI to show bets
    return true, "Bet placed"
end


function TexasHoldEm:Call(game, playerIndex)
    local player = game.players[playerIndex]
    if player.hasFolded then return false, "Player has folded" end
    local amountToCall = game.currentBet - player.currentBet
    return self:PlaceBet(game, playerIndex, amountToCall)
end

function TexasHoldEm:Raise(game, playerIndex, raiseAmount)
    local player = game.players[playerIndex]
    if not player.currentBet then player.currentBet = 0 end  -- Ensure it's always a number
    if player.hasFolded then return false, "Player has folded" end

    local totalBet = game.currentBet + raiseAmount
    return self:PlaceBet(game, playerIndex, totalBet - player.currentBet)
end
function TexasHoldEm:Fold(game, playerIndex)
    game.players[playerIndex].hasFolded = true
end

function TexasHoldEm:AdvanceBettingRound(game)
    -- Check if all active players have matched the highest bet
    local maxBet = game.currentBet
    for _, player in ipairs(game.players) do
        if not player.hasFolded and player.currentBet < maxBet then
            return -- Betting round isn't over yet
        end
    end

    -- Betting round complete, advance game state
    if game.bettingRound == 1 then
        print("Flop!")
        TexasHoldEm:DealCommunityCards(game, 3)  -- Deal 3 cards (flop)
    elseif game.bettingRound == 2 then
        print("Turn!")
        TexasHoldEm:DealCommunityCards(game, 1)  -- Deal 1 card (turn)
    elseif game.bettingRound == 3 then
        print("River!")
        TexasHoldEm:DealCommunityCards(game, 1)  -- Deal 1 card (river)
    else
        print("Showdown!")  -- Final phase, determine winner
    end

    game.bettingRound = game.bettingRound + 1
    game.currentBet = 0 -- Reset betting for next round
    for _, player in ipairs(game.players) do
        player.currentBet = 0
    end

    -- Rotate turn order (back to first active player)
    TexasHoldEm:NextTurn(game)
end

function TexasHoldEm:RotateDealerButton(game)
    local numPlayers = #game.players

    -- Move dealer button to next player
    repeat
        game.dealerButton = (game.dealerButton % numPlayers) + 1
    until not game.players[game.dealerButton].hasFolded

    -- Assign new blinds
    game.smallBlind = (game.dealerButton % numPlayers) + 1
    game.bigBlind = (game.smallBlind % numPlayers) + 1

    -- Collect blinds into the pot
    game.players[game.smallBlind].currentBet = 50
    game.players[game.bigBlind].currentBet = 100
    game.pot = 150

    print("New Dealer: Player " .. game.dealerButton)
    print("Small Blind: Player " .. game.smallBlind)
    print("Big Blind: Player " .. game.bigBlind)

    -- Set next turn (player after big blind)
    game.currentTurn = (game.bigBlind % numPlayers) + 1

    -- Reset game state for a new round
    game.bettingRound = 1
    game.currentBet = 100
    for _, player in ipairs(game.players) do
        player.currentBet = 0
        player.hasFolded = false
    end

    self:UpdatePlayerUI(game)
end



-- UI Setup
local function CreatePokerUI()
    if TexasHoldEm.frame then return end -- Prevent multiple frames

    -- Create the main poker window
    local frame = CreateFrame("Frame", "TexasHoldEmFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(550, 500)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -10)
    frame.title:SetText("Texas Hold 'Em")

    -- Card Table
    local cardTable = frame:CreateTexture(nil, "ARTWORK")
    cardTable:SetSize(512, 384)
    cardTable:SetPoint("CENTER", frame, "CENTER", 0, 0)
    cardTable:SetTexture("Interface/AddOns/WoWMiniGames/Textures/Cards/card table no outlines.blp")
    frame.cardTable = cardTable  -- Store reference inside frame




    -- Add Card Texture
    --local cardTexture = frame:CreateTexture(nil, "OVERLAY")
    --cardTexture:SetSize(36, 64)  -- Adjust size as needed
    --cardTexture:SetPoint("CENTER", frame, "CENTER", 0, 0) -- Center in frame
    --local texturePath = "Interface/AddOns/WoWMiniGames/Textures/Cards/King of diamonds.blp"
    --cardTexture:SetTexture(DisplayCard)

    --[[if not cardTexture:GetTexture() then
        print("ERROR: Texture failed to load ->", DisplayCard)
    else
        print("SUCCESS: Texture loaded ->", DisplayCard)
    end--]]
    
    -- Close Button
    local closeButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    closeButton:SetSize(80, 25)
    closeButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
    closeButton:SetText("Close")
    closeButton:SetScript("OnClick", function() frame:Hide() end)

    local dealButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    dealButton:SetSize(120, 30)
    dealButton:SetPoint("LEFT", closeButton, "LEFT", -150, 0)
    dealButton:SetText("Deal Next Card")
    dealButton:SetScript("OnClick", function()
    TexasHoldEm:DealNextCommunityCard(TexasHoldEm.currentGame)
    end)

    TexasHoldEm.frame = frame

    -- Betting Input Field
    local betInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    betInput:SetSize(50, 30)
    betInput:SetPoint("BOTTOM", frame, "BOTTOM", -60, 70)
    betInput:SetAutoFocus(false)
    betInput:SetNumeric(true) -- Only allow numbers
    betInput:SetMaxLetters(6)
    betInput:SetText("0")

    -- Betting Buttons
    local function CreateBetButton(name, xOffset, onClick)
        local button = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
        button:SetSize(80, 25)
        button:SetPoint("BOTTOM", frame, "BOTTOM", xOffset, 50)
        button:SetText(name)
        button:SetScript("OnClick", onClick)
    return button
    end

    local callButton = CreateBetButton("Call", -150, function()
        TexasHoldEm:Call(TexasHoldEm.currentGame, 1)
    end)

    local raiseButton = CreateBetButton("Raise", -60, function()
        local betAmount = tonumber(betInput:GetText())
        if betAmount and betAmount > 0 then
            TexasHoldEm:Raise(TexasHoldEm.currentGame, 1, betAmount)
        else
            print("Enter a valid raise amount.")
        end
    end)

    local foldButton = CreateBetButton("Fold", 30, function()
        TexasHoldEm:Fold(TexasHoldEm.currentGame, 1)
    end)

    local checkButton = CreateBetButton("Check", 120, function()
        print("Player checks.")
    end)

    -- Pot Display
    local potDisplay = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    potDisplay:SetPoint("TOP", frame, "TOP", 0, -30)
    potDisplay:SetText("Pot: 0g")
    frame.potDisplay = potDisplay  -- Store reference

end

function TexasHoldEm:ShowUI()
    if not self.frame then
        CreatePokerUI()
    end
    self.frame:Show()

    -- Ensure player cards update when the UI is shown
    if self.currentGame then
        self:UpdatePlayerUI(self.currentGame)
    end
end


-- Deal a card
local dealtCard = table.remove(deck)  -- Removes the top card from the deck
print("Dealt Card:", dealtCard.value, "of", dealtCard.suit, "Texture:", dealtCard.texture)

function TexasHoldEm:DisplayCard(frame, card)
    if card and card.texture then
        frame:SetTexture(card.texture)
    else
        frame:SetTexture("Interface/Icons/INV_Misc_QuestionMark") -- Debugging placeholder
    end
end

function TexasHoldEm:EndHand(game)
    print("Round over! Determining the winner...")
    
    -- (Winner calculation logic goes here)

    -- Rotate dealer button for next round
    TexasHoldEm:ProcessPayouts(game)
end

function TexasHoldEm:DetermineWinner(game)
    local winningPlayers = {}  -- Stores players who have the best hand
    local bestHandStrength = nil  -- Track the best hand's strength
    
    for _, player in ipairs(game.players) do
        if not player.hasFolded then
            local handStrength = TexasHoldEm:EvaluateHand(player.hand, game.communityCards)
            
            if not bestHandStrength or handStrength > bestHandStrength then
                winningPlayers = {player}
                bestHandStrength = handStrength
            elseif handStrength == bestHandStrength then
                table.insert(winningPlayers, player)
            end
        end
    end
    
    return winningPlayers
end

-- Track debts between players
TexasHoldEm.debts = {}

function TexasHoldEm:ProcessPayouts(game)
    local winners = TexasHoldEm:DetermineWinner(game)
    local totalPot = game.pot
    local numWinners = #winners
    local payouts = {}
    
    -- Calculate how much each winner gets
    for _, player in ipairs(winners) do
        payouts[player.name] = totalPot / numWinners
    end
    
    -- Track debts directly
    for _, player in ipairs(game.players) do
        if not payouts[player.name] then
            local owedAmount = player.currentBet
            if owedAmount > 0 then
                for _, winner in ipairs(winners) do
                    TexasHoldEm.debts[player.name] = TexasHoldEm.debts[player.name] or {}
                    TexasHoldEm.debts[player.name][winner.name] = (TexasHoldEm.debts[player.name][winner.name] or 0) + (owedAmount / numWinners)
                end
            end
        end
    end
    
    -- Reset game state for next hand
    TexasHoldEm:RotateDealerButton(game)
end

-- Function to display what players owe and allow cashout
function TexasHoldEm:ShowCashout()
    print("Final Cashout Summary:")
    for debtor, creditors in pairs(TexasHoldEm.debts) do
        for creditor, amount in pairs(creditors) do
            print(debtor .. " owes " .. creditor .. " " .. amount .. " gold.")
        end
    end
end
