--[[

RoChess Stockfish by Driftsz
https://www.roblox.com/games/130878180532794/RoChess

Yes, I know this is (extremely) scuffed 🥀

]]

getgenv().configuration = {
    ["Server Url"]      = "http://127.0.0.1:5500",
    ["Stockfish Elo"]   = 2500,
    ["Stockfish Depth"] = 15
}

--// Prerequisites
if (configuration.ran) then
    error("[SYSTEM] This script has already been ran in this instance!\n")
end

local statusResponse = request({
    Url    = configuration["Server Url"] .. "/api/status",
    Method = "GET"
})

if (statusResponse.StatusCode == 200) then
    print("[SYSTEM] Server status request successful\n")
else
    error("[SYSTEM] Server responded with status code: " .. tostring(statusResponse.StatusCode) .. "\n")
end

--// Variables
local players           = game:GetService("Players")
local httpService       = game:GetService("HttpService")
local replicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer       = players.LocalPlayer
local playerBoard       = localPlayer.PlayerGui.ChessUI.Root.Board

local session           = require(replicatedStorage:WaitForChild("ChessClient"):WaitForChild("Session"))
local app               = require(replicatedStorage:WaitForChild("ChessClient"):WaitForChild("App"))

local colors            = {
    highlight = Color3.fromRGB(255, 47, 101),
    board     = {
        [0]   = Color3.fromRGB(95, 127, 160),
        [1]   = Color3.fromRGB(227, 234, 242)
    }
}

--// Functions
local function generateBoardMap() -- Generates a table, providing the correlation
                                  -- between positions and square indexes
    local boardMap = {}

    local files = "abcdefgh"
    local index = 0
    for j = 1, 8 do
        for k = 1, 8 do
            index              = index + 1

            position           = string.sub(files, k, k) .. tostring(j)
            boardMap[position] = index
        end
    end

    return boardMap
end

local function highlight(squares)
    local boardMap    = generateBoardMap() -- {"a1": 1, "a2": 2, ...}
    local squaresGui  = playerBoard.Squares

    local positionOne = boardMap[string.sub(squares, 1, 2)] -- Ex: 2 -> a2
    local positionTwo = boardMap[string.sub(squares, 3, 4)]

    squaresGui["S" .. positionOne].BackgroundColor3 = colors.highlight -- Covers the inputted squares
    squaresGui["S" .. positionTwo].BackgroundColor3 = colors.highlight -- with a red highlight
end

local function unhighlight() -- Iterates through all of the board squares and properly colors them
    for _, square in next, playerBoard.Squares:GetChildren() do
        if (not square:IsA("Frame")) then continue end

        local index = tonumber(square.Name:match("^S(%d+)$"))

        if (index and index >= 1 and index <= 64) then
            local row = math.floor((index - 1) / 8)
            local column = (index - 1) % 8

            square.BackgroundColor3 = colors.board[(row + column) % 2]
        end
    end
end

--[[-------------------------
               .__        
  _____ _____  |__| ____  
 /     \\__  \ |  |/    \ 
|  Y Y  \/ __ \|  |   |  \
|__|_|  (____  /__|___|  /
      \/     \/        \/ 

-------------------------]]--

configuration.ran = true

print("[SYSTEM] Initializing session.new hook...\n")

--// Detect New Game
local sessionNew
sessionNew = hookfunction(session.new, function(...)
    local sessionState = select(1, ...)

    if (sessionState ~= "idle") then
        local sessionArgs = select(2, ...)

        task.spawn(function() -- Spawn mostly due to the 'while' loop
        
            local curSession = {
                moves      = "", -- "e2e4 ..."
                turn       = "white", -- 'white' / 'black'
                active     = true, -- Whether or not the session is 
                                   -- still ongoing
                calculated = false, -- Whether or not stockfish is
                                    -- done processing the request
                localPlayer = {
                    color   = (sessionArgs.white["name"] == localPlayer.Name and "white") or "black"
                },

                opponent  = {
                    color = (sessionArgs.white["name"] ~= localPlayer.Name and "white") or "black",
                    name  = (sessionArgs.white["name"] ~= localPlayer.Name and sessionArgs.white["name"]) or sessionArgs.black["name"] or "Bot"
                },
            }

            print("[SYSTEM] New session:")
            print(" - " .. localPlayer.Name .. ": " .. curSession.localPlayer.color)
            print(" - " .. curSession.opponent.name .. ": " .. curSession.opponent.color .. "\n")

            print("[SYSTEM] Initializing move listener...\n")

            local lastFromHighlight = playerBoard.Squares.Highlights.LastFrom
            local lastToHighlight   = playerBoard.Squares.Highlights.LastTo

            local moveListener
            moveListener = lastFromHighlight:GetAttributeChangedSignal("Key"):Connect(function()
                task.wait() -- (Hopefully) allows 'lastToHighlight's' value to change as well

                local fromIndex = tonumber(lastFromHighlight:GetAttribute("Key"))
                local toIndex   = tonumber(lastToHighlight:GetAttribute("Key"))

                -- Convert the indexes to position
                for position, index in next, generateBoardMap() do
                    if (index == fromIndex) then fromIndex = position end
                    if (index == toIndex) then toIndex = position end
                end

                curSession.moves = curSession.moves .. fromIndex .. toIndex .. " "

                local movesArray = string.split(curSession.moves, " ")

                curSession.turn  = (#movesArray % 2 == 0 and "black") or "white"
                if (curSession.turn == "white") then curSession.calculated = false end

                unhighlight()

                print("[SYSTEM] Move: " .. movesArray[#movesArray - 1] .. "\n")
            end)

            --// Detects Game Over
            local oldGameOver = app.modals.gameOver
            local gameOver
            gameOver = hookfunction(app.modals.gameOver, function(...)
                curSession.active = false

                --local gameData = select(1, ...)
                --print("[SYSTEM] Game over: You " .. ((string.sub(gameData.result, 1, 1) == "1" and "won") or "lost") .. " due to " .. gameData.reason)
                return gameOver(...)
            end)

            --// Main Loop
            while (curSession.active) do
                task.wait() -- Prevents crashing har har har

                if ( 
                    curSession.turn ~= curSession.localPlayer.color or
                    curSession.calculated == true
                ) then
                    continue -- Skips the iteration
                end

                print("[SYSTEM] Calculating the best move...\n")

                local movesArray = string.split(curSession.moves, " ")

                local stockfishResponse = request({
                    Url    = configuration["Server Url"] .. "/api/stockfish",
                    Method = "POST",
                    Body   = httpService:JSONEncode({
                        moves = movesArray,
                        elo   = tonumber(configuration["Stockfish Elo"]),
                        depth = tonumber(configuration["Stockfish Depth"])
                    }),
                    Headers = {
                        ["Content-Type"] = "application/json"
                    }
                })

                if (stockfishResponse.StatusCode == 200) then
                    -- Success
                    local bestMove = stockfishResponse.Body
                    highlight(bestMove)
                    curSession.calculated = true

                    print("[SYSTEM] Calculated best move: " .. string.sub(bestMove, 1, 2) .. " -> " .. string.sub(bestMove, 3, 4) .. "\n")
                else
                    error("[SYSTEM] Invalid stockfish response. Returned status code: " .. tostring(stockfishResponse.StatusCode) .. "\n")
                end
            end

            -- Occurs after the game is overwith (AKA curSession.active = false)
            app.modals.gameOver = oldGameOver
            moveListener:Disconnect()

            return nil
        end)
    end

    return sessionNew(...)
end)

print("[SYSTEM] Script ran successfully!\n")
