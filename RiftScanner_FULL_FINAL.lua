local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local request = http_request or request or (syn and syn.request) or (fluxus and fluxus.request) or getgenv().request
local WEBHOOK_URL = "https://discord.com/api/webhooks/1364542186833707018/47wVM3VbMFSvJWiEe03TskGZVau4qxQ2FEdMeL0OMHBJav4TIMLjwdcoZsUv6FQ1t2GL"

-- 🎯 Only track hatches from this player
local targetPlayerName = "masonhauser" -- 👈 Replace this with the exact player name

-- ✅ Disconnect old watcher if re-injected
if getgenv().hatchWatcher then
    getgenv().hatchWatcher:Disconnect()
end

-- ✅ Deduplication tracking
local lastMessage, lastTime = "", 0

-- ✅ GUI to show last hatch
local function createGui()
    local screenGui = Instance.new("ScreenGui", PlayerGui)
    screenGui.Name = "HatchNotifierGui"
    screenGui.ResetOnSpawn = false

    local frame = Instance.new("Frame", screenGui)
    frame.Size = UDim2.new(0, 300, 0, 60)
    frame.Position = UDim2.new(0.5, -150, 0.5, -30)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true

    local textLabel = Instance.new("TextLabel", frame)
    textLabel.Size = UDim2.new(1, -10, 1, -10)
    textLabel.Position = UDim2.new(0, 5, 0, 5)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextScaled = true
    textLabel.Text = "Waiting for hatches..."

    return textLabel
end

local guiLabel = createGui()

-- ✅ Strip Roblox RichText
local function stripTags(str)
    return str
        :gsub("<[^>]->", "")
        :gsub("&lt;", "<")
        :gsub("&gt;", ">")
        :gsub("&amp;", "&")
end

-- ✅ Odds + rarity logic
local function getRarityInfo(petName, odds)
    local lowerPet = petName:lower()
    local emoji = ""
    local color = 16753920

    if lowerPet:find("secret") then
        emoji = "🕵️‍♂️"
        color = 14423100
    elseif lowerPet:find("shiny") then
        emoji = "✨"
        color = 13458524
    elseif lowerPet:find("glitched") then
        emoji = "🧬"
        color = 10197915
    end

    local cleaned = odds:gsub("%%", ""):gsub(",", "")
    local numericOdds = tonumber(cleaned) or tonumber(string.format("%.10f", cleaned))

    if numericOdds and numericOdds <= 0.01 then
        color = 14483456
        emoji = emoji .. "🔥"
    end

    return emoji, color
end

-- ✅ Send to webhook + update GUI
local function sendEmbed(text)
    local clean = stripTags(text)
    local now = tick()

    if clean == lastMessage and now - lastTime < 3 then
        print("⚠️ Skipped duplicate:", clean)
        return
    end
    lastMessage, lastTime = clean, now

    -- 🔧 Match hatch message
    local player, pet, odds = clean:match("^(.-) just hatched a (.-) %((.-%%)%)$")
    if not player or not pet or not odds then
        print("❌ Failed to parse hatch line:", clean)
        return
    end

    -- 🎯 Only process if it's the target player
    if player ~= targetPlayerName then
        print("⏩ Ignored hatch from another player:", player)
        return
    end

    local emoji, color = getRarityInfo(pet, odds)

    local embed = {
        title = emoji ~= "" and (emoji .. " Hatch Alert!") or "🎉 Hatch Alert!",
        fields = {
            { name = "Player", value = player, inline = true },
            { name = "Pet", value = emoji .. " " .. pet, inline = true },
            { name = "Odds", value = odds, inline = true },
            { name = "Time", value = os.date("%B %d, %Y • %I:%M %p"), inline = false }
        },
        color = color
    }

    guiLabel.Text = player .. " → " .. pet .. " (" .. odds .. ")"

    local payload = HttpService:JSONEncode({ embeds = { embed } })

    local success, err = pcall(function()
        request({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = payload
        })
    end)

    if success then
        print("✅ Hatch Sent:", clean)
    else
        warn("❌ Webhook failed:", err)
    end
end

-- ✅ Hatch watcher
getgenv().hatchWatcher = TextChatService.MessageReceived:Connect(function(message)
    local raw = message.Text
    if not raw then return end

    local clean = stripTags(raw)
    print("[📨 Incoming Chat]:", raw)
    print("[🧼 Cleaned Text]:", clean)

    if clean:lower():find("just hatched") and not clean:lower():find("wow! someone just hatched") then
        sendEmbed(clean)
    end
end)

-- ✅ Force-open chat & topbar every 5s
task.spawn(function()
    while true do
        pcall(function()
            StarterGui:SetCore("ChatActive", true)
            StarterGui:SetCore("TopbarEnabled", true)
        end)
        task.wait(5)
    end
end)
