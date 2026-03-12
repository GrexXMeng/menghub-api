local FIREBASE_URL = "https://menghub-5c6c2-default-rtdb.firebaseio.com"
local gameJobId    = game.JobId
local gamePlaceId  = tostring(game.PlaceId)

local TeleportService  = game:GetService("TeleportService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local SF_IsRefreshing  = false

local eventList = {
    "Baby Bloop Fish", "Bloop Fish", "Whales Pool", "Orcas Pool",
    "The Kraken Pool", "Ancient Depth Serpent", "Animal Pool", "Plesiosaur Hunt", "Goldwraith Hunt",
    "Reef Titan Hunt", "Sunken Reliquary", "Omnithal Hunt",
    "Animal Pool - Second Sea", "Octophant Pool Without Elephant",
    "Sea Leviathan Pool", "Isonade", "Forsaken Veil - Scylla",
    "Blue Moon - Second Sea", "Blue Moon - First Sea", "Great White Shark", "LEGO",
    "LEGO - Studolodon", "Mosslurker", "Narwhal", "Whale Shark",
    "Birthday Megalodon", "Colossal Blue Dragon", "Colossal Ancient Dragon",
    "Colossal Ethereal Dragon", "Megalodon Ancient", "Megalodon Default",
    "Megalodon Phantom", "Skeletal Leviathan Hunt", "Pliosaur Hunt",
    "Toxic Boil", "Flower Guardian Hunt", "Rotbloom Hunt"
}
local workspaceNameOverrides = {
    ["Ancient Depth Serpent"] = "The Depths - Serpent",
}
-- ============================================================
-- CUACA
-- ============================================================
local function getWeather()
    local lightVal = game:GetService("Lighting").ClockTime
    return (lightVal >= 6 and lightVal < 18) and "Day" or "Night"
end

local function SF_GetStarfall()
    for _, obj in pairs(workspace:GetChildren()) do
        if obj.Name == "StarCrater" and obj:IsA("Model") then
            return true
        end
    end
    return false
end
-- ============================================================
-- ACTIVE EVENTS
-- ============================================================
local function SF_GetActiveEvents()
    local activeEvents = {}
    local ok, fishingZones = pcall(function()
        return workspace:WaitForChild("zones", 3):WaitForChild("fishing", 3)
    end)
    if not ok or not fishingZones then return activeEvents end
    for _, eventName in ipairs(eventList) do
        local lookupName = workspaceNameOverrides[eventName] or eventName
        local eventZone = fishingZones:FindFirstChild(lookupName)
        if eventZone and eventZone:IsA("BasePart") then
            table.insert(activeEvents, eventName)
        end
    end
    return activeEvents
end

-- ============================================================
-- REQUEST HELPER
-- ============================================================
local function doRequest(opt)
    if type(request) == "function" then return request(opt)
    elseif type(syn) == "table" and syn.request then return syn.request(opt)
    elseif type(http) == "table" and http.request then return http.request(opt)
    end
end

-- ============================================================
-- FIREBASE
-- ============================================================
local function SF_Register()
    if gameJobId == "" then return end

    local isPrivate = false
    pcall(function() isPrivate = game.PrivateServerId ~= "" end)

    local currentEvents   = SF_GetActiveEvents()
    local currentWeather  = getWeather()
    local currentStarfall = SF_GetStarfall()
    local currentPlayers  = #game:GetService("Players"):GetPlayers()

    local uptimeSec = 0
    pcall(function()
        local uptimeLabel = game:GetService("Players").LocalPlayer.PlayerGui.serverInfo.serverInfo.uptime
        local function parseUptimeText(text)
            local d = tonumber(text:match("(%d+)D")) or 0
            local h = tonumber(text:match("(%d+)H")) or 0
            local m = tonumber(text:match("(%d+)M")) or 0
            local s = tonumber(text:match("(%d+)S")) or 0
            return d*86400 + h*3600 + m*60 + s
        end
        uptimeSec = parseUptimeText(uptimeLabel.Text)
    end)

    pcall(function()
        doRequest({
            Url     = FIREBASE_URL .. "/servers/" .. gameJobId .. ".json",
            Method  = "PATCH",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HttpService:JSONEncode({
                jobId        = gameJobId,
                placeId      = gamePlaceId,
                playerCount  = currentPlayers,
                maxPlayers   = game.Players.MaxPlayers,
                events       = currentEvents,
                starfall     = currentStarfall,
                weather      = currentWeather,
                isPrivate    = isPrivate,
                uptimeSeconds = uptimeSec,  -- BARU
                lastSeen     = { [".sv"] = "timestamp" }
            })
        })
    end)
end

local function SF_Fetch()
    local ok, res = pcall(function()
        return doRequest({ Url = FIREBASE_URL .. "/servers.json", Method = "GET" })
    end)
    if not ok or not res or res.StatusCode ~= 200 then return nil end
    local ok2, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not ok2 or type(data) ~= "table" then return {} end

    local nowMs = os.time() * 1000
    local list  = {}
    for _, s in pairs(data) do
        if type(s) == "table" and s.lastSeen and not s.isPrivate then  -- skip private
            local age = nowMs - (tonumber(s.lastSeen) or 0)
            if age < 12000 and s.jobId ~= gameJobId then
                table.insert(list, s)
            end
        end
    end
    table.sort(list, function(a, b)
        return #(a.events or {}) > #(b.events or {})
    end)
    return list
end

local function SF_Unregister()
    pcall(function()
        doRequest({
            Url    = FIREBASE_URL .. "/servers/" .. gameJobId .. ".json",
            Method = "DELETE"
        })
    end)
end

-- ============================================================
-- PALET WARNA
-- ============================================================
local C = {
    BG      = Color3.fromRGB(13, 13, 18),
    BG2     = Color3.fromRGB(20, 20, 28),
    BG3     = Color3.fromRGB(30, 30, 42),
    Text    = Color3.fromRGB(230, 230, 235),
    TextDim = Color3.fromRGB(110, 110, 130),
    Accent  = Color3.fromRGB(130, 180, 255),
    AccentH = Color3.fromRGB(160, 200, 255),
    Border  = Color3.fromRGB(35, 35, 50),
    Green   = Color3.fromRGB(80, 210, 120),
    Red     = Color3.fromRGB(220, 70, 70),
    PillBG  = Color3.fromRGB(22, 22, 32),
}

-- ============================================================
-- HELPERS
-- ============================================================
local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
end

local function stroke(p, col, t)
    local s = Instance.new("UIStroke")
    s.Color     = col or C.Border
    s.Thickness = t or 1
    s.Parent    = p
end

local function hover(btn, n, h)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = h }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = n }):Play()
    end)
end

-- ============================================================
-- SCREEN GUI
-- ============================================================
if game:GetService("CoreGui"):FindFirstChild("SF_MengHub") then
    game:GetService("CoreGui"):FindFirstChild("SF_MengHub"):Destroy()
end

local SG = Instance.new("ScreenGui")
SG.Name           = "SF_MengHub"
SG.ResetOnSpawn   = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder   = 999
SG.IgnoreGuiInset = true   -- kunci biar ga digeser inset navbar game
SG.Parent         = game:GetService("CoreGui")

local ICON_CLOSE   = "\215"             -- Simbol Perkalian (×)
local SEP = " \226\128\162 "
local ICON_RELOAD  = "R"                -- Atau simbol alternatif yang aman

-- ============================================================
-- PILL BUTTON — tengah atas
-- ============================================================
local TopBtn = Instance.new("TextButton")
TopBtn.Size             = UDim2.new(0, 140, 0, 34)
TopBtn.AnchorPoint      = Vector2.new(0.5, 0)
TopBtn.Position         = UDim2.new(0.5, 0, 0, 46)
TopBtn.BackgroundColor3 = C.PillBG
TopBtn.Text             = ""
TopBtn.AutoButtonColor  = false
TopBtn.ZIndex           = 50
TopBtn.Parent           = SG
corner(TopBtn, 99)
stroke(TopBtn, C.Border, 1)
hover(TopBtn, C.PillBG, C.BG3)

-- Dot hijau
local Dot = Instance.new("Frame")
Dot.Size             = UDim2.new(0, 7, 0, 7)
Dot.Position         = UDim2.new(0, 16, 0.5, 0)
Dot.AnchorPoint      = Vector2.new(0, 0.5)
Dot.BackgroundColor3 = C.Green
Dot.ZIndex           = 51
Dot.Parent           = TopBtn
corner(Dot, 99)

-- Label
local TopLbl = Instance.new("TextLabel")
TopLbl.Size                   = UDim2.new(1, -32, 1, 0)
TopLbl.Position               = UDim2.new(0, 30, 0, 0)
TopLbl.BackgroundTransparency = 1
TopLbl.Text                   = "        SERVERS"
TopLbl.TextColor3             = C.Text
TopLbl.TextSize               = 13
TopLbl.Font                   = Enum.Font.GothamBold
TopLbl.TextXAlignment         = Enum.TextXAlignment.Left
TopLbl.ZIndex                 = 51
TopLbl.Parent                 = TopBtn

-- ============================================================
-- PANEL UTAMA — centered
-- ============================================================
local Panel = Instance.new("Frame")
Panel.Size             = UDim2.new(0, 420, 0, 460)
Panel.AnchorPoint      = Vector2.new(0.5, 0)
Panel.Position         = UDim2.new(0.5, 0, 0, 88)  -- 46 + 34 + 8
Panel.BackgroundColor3 = C.BG
Panel.Visible          = false
Panel.ZIndex           = 40
Panel.ClipsDescendants = true
Panel.Parent           = SG
corner(Panel, 10)
stroke(Panel, C.Border, 1)

-- ============================================================
-- HEADER
-- ============================================================
local Header = Instance.new("Frame")
Header.Size             = UDim2.new(1, 0, 0, 52)
Header.BackgroundColor3 = C.BG2
Header.ZIndex           = 41
Header.Parent           = Panel
corner(Header, 10)

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size                   = UDim2.new(1, -100, 1, 0)
TitleLbl.Position               = UDim2.new(0, 18, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text                   = "Available Servers"
TitleLbl.TextColor3             = C.Text
TitleLbl.TextSize               = 14
TitleLbl.Font                   = Enum.Font.GothamBold
TitleLbl.TextXAlignment         = Enum.TextXAlignment.Left
TitleLbl.ZIndex                 = 42
TitleLbl.Parent                 = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size             = UDim2.new(0, 30, 0, 30)
CloseBtn.Position         = UDim2.new(1, -50, 0.5, 0)
CloseBtn.AnchorPoint      = Vector2.new(1, 0.5)
CloseBtn.BackgroundColor3 = C.BG3
CloseBtn.Text             = ICON_CLOSE
CloseBtn.TextColor3       = C.TextDim
CloseBtn.TextSize         = 18
CloseBtn.Font             = Enum.Font.GothamBold
CloseBtn.AutoButtonColor  = false
CloseBtn.ZIndex           = 42
CloseBtn.Parent           = Header
corner(CloseBtn, 6)
hover(CloseBtn, C.BG3, C.Border)

local RefBtn = Instance.new("TextButton")
RefBtn.Size             = UDim2.new(0, 30, 0, 30)
RefBtn.Position         = UDim2.new(1, -14, 0.5, 0)
RefBtn.AnchorPoint      = Vector2.new(1, 0.5)
RefBtn.BackgroundColor3 = C.BG3
RefBtn.Text             = ICON_RELOAD
RefBtn.TextColor3       = C.TextDim
RefBtn.TextSize         = 20 -- Ukurannya pas buat simbol ini
RefBtn.Font             = Enum.Font.GothamBold
RefBtn.AutoButtonColor  = false
RefBtn.ZIndex           = 42
RefBtn.Parent           = Header
corner(RefBtn, 6)
hover(RefBtn, C.BG3, C.Border)

-- ============================================================
-- SEARCH BAR
-- ============================================================
local SearchWrap = Instance.new("Frame")
SearchWrap.Size             = UDim2.new(1, -24, 0, 34)
SearchWrap.Position         = UDim2.new(0, 12, 0, 60)
SearchWrap.BackgroundColor3 = C.BG2
SearchWrap.ZIndex           = 41
SearchWrap.Parent           = Panel
corner(SearchWrap, 7)
stroke(SearchWrap, C.Border, 1)

local SearchIco = Instance.new("TextLabel")
SearchIco.Size                   = UDim2.new(0, 32, 1, 0)
SearchIco.BackgroundTransparency = 1
SearchIco.Text                   = "/"
SearchIco.TextColor3             = C.TextDim
SearchIco.TextSize               = 12
SearchIco.Font                   = Enum.Font.GothamBold
SearchIco.ZIndex                 = 42
SearchIco.Parent                 = SearchWrap

local SearchBox = Instance.new("TextBox")
SearchBox.Size                   = UDim2.new(1, -36, 1, 0)
SearchBox.Position               = UDim2.new(0, 32, 0, 0)
SearchBox.BackgroundTransparency = 1
SearchBox.PlaceholderText        = "Filter by event name..."
SearchBox.PlaceholderColor3      = Color3.fromRGB(70, 70, 90)
SearchBox.Text                   = ""
SearchBox.TextColor3             = C.Text
SearchBox.TextSize               = 12
SearchBox.Font                   = Enum.Font.Gotham
SearchBox.TextXAlignment         = Enum.TextXAlignment.Left
SearchBox.ClearTextOnFocus       = false
SearchBox.ZIndex                 = 42
SearchBox.Parent                 = SearchWrap

-- ============================================================
-- SCROLL LIST
-- ============================================================
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size                   = UDim2.new(1, -24, 1, -104)
Scroll.Position               = UDim2.new(0, 12, 0, 102)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel        = 0
Scroll.ScrollBarThickness     = 3
Scroll.ScrollBarImageColor3   = C.Border
Scroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
Scroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
Scroll.ZIndex                 = 41
Scroll.Parent                 = Panel

local Layout = Instance.new("UIListLayout")
Layout.Padding   = UDim.new(0, 6)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent    = Scroll

local PaddingBot = Instance.new("UIPadding")
PaddingBot.PaddingBottom = UDim.new(0, 10)
PaddingBot.Parent        = Scroll

local StatusLbl = Instance.new("TextLabel")
StatusLbl.Name                   = "StatusLbl"
StatusLbl.Size                   = UDim2.new(1, 0, 0, 60)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Text                   = "Press  ?  to load servers"
StatusLbl.TextColor3             = C.TextDim
StatusLbl.TextSize               = 12
StatusLbl.Font                   = Enum.Font.Gotham
StatusLbl.ZIndex                 = 42
StatusLbl.Parent                 = Scroll

-- ============================================================
-- BUILD CARD
-- ============================================================
local function getNextSunkenIn(uptimeSec)
    -- Kalau 0 atau nil, skip
    if not uptimeSec or uptimeSec == 0 then return "—" end
    
    local uptimeMin = uptimeSec / 60
    local n = 0
    local nextSpawnMin
    repeat
        nextSpawnMin = 60 + 70 * n
        n = n + 1
    until nextSpawnMin > uptimeMin
    local diffSec = math.floor(nextSpawnMin * 60 - uptimeSec)
    local m = math.floor(diffSec / 60)
    return string.format("In %dM", m)
end

local function buildCard(s, idx)
    local hasEvents = #(s.events or {}) > 0
    local evStr     = hasEvents and table.concat(s.events, "  ·  ") or "No active events"
    local isFull    = (s.playerCount or 0) >= (s.maxPlayers or 20)

    local Card = Instance.new("Frame")
    Card.Size             = UDim2.new(1, 0, 0, 62)
    Card.BackgroundColor3 = C.BG2
    Card.ZIndex           = 42
    Card.LayoutOrder      = idx
    Card.Parent           = Scroll
    corner(Card, 8)
    stroke(Card, C.Border, 1)

    if hasEvents then
        local AccentBar = Instance.new("Frame")
        AccentBar.Size             = UDim2.new(0, 2, 0, 32)
        AccentBar.Position         = UDim2.new(0, 0, 0.5, 0)
        AccentBar.AnchorPoint      = Vector2.new(0, 0.5)
        AccentBar.BackgroundColor3 = C.Accent
        AccentBar.ZIndex           = 43
        AccentBar.Parent           = Card
        corner(AccentBar, 99)
    end

    local EvLbl = Instance.new("TextLabel")
    EvLbl.Size                   = UDim2.new(1, -90, 0, 20)
    EvLbl.Position               = UDim2.new(0, 16, 0, 12)
    EvLbl.BackgroundTransparency = 1
    EvLbl.Text                   = evStr
    EvLbl.TextColor3             = hasEvents and C.Text or C.TextDim
    EvLbl.TextSize               = 12
    EvLbl.Font                   = hasEvents and Enum.Font.GothamBold or Enum.Font.Gotham
    EvLbl.TextXAlignment         = Enum.TextXAlignment.Left
    EvLbl.TextTruncate           = Enum.TextTruncate.AtEnd
    EvLbl.ZIndex                 = 43
    EvLbl.Parent                 = Card

    local isStar = s.starfall == true
    local starText = isStar and "Active" or "None"
    local sunkenStr = s.uptimeSeconds and s.uptimeSeconds > 0 
    and getNextSunkenIn(s.uptimeSeconds) 
    or nil

    local InfoLbl = Instance.new("TextLabel")
    InfoLbl.Size                   = UDim2.new(1, -90, 0, 16)
    InfoLbl.Position               = UDim2.new(0, 16, 0, 36)
    InfoLbl.BackgroundTransparency = 1
    InfoLbl.RichText = true
    InfoLbl.Text = string.format(
        "%d / %d players%s<font color='%s'>Starfall: %s</font>%s%s%s",
        s.playerCount or 0,
        s.maxPlayers or 20,
        SEP,
        isStar and "rgb(255,210,100)" or "rgb(110,110,130)",
        starText,
        SEP,
        s.weather or "\226\128\148", -- Simbol dash (—) aman
        sunkenStr and (SEP .. "<font color='rgb(100,200,255)'>Next Sunken: " .. sunkenStr .. "</font>") or ""
    )
    InfoLbl.TextColor3             = C.TextDim
    InfoLbl.TextSize               = 10
    InfoLbl.Font                   = Enum.Font.Gotham
    InfoLbl.TextXAlignment         = Enum.TextXAlignment.Left
    InfoLbl.ZIndex                 = 43
    InfoLbl.Parent                 = Card

    local JoinBtn = Instance.new("TextButton")
    JoinBtn.Size             = UDim2.new(0, 60, 0, 28)
    JoinBtn.Position         = UDim2.new(1, -14, 0.5, 0)
    JoinBtn.AnchorPoint      = Vector2.new(1, 0.5)
    JoinBtn.BackgroundColor3 = isFull and Color3.fromRGB(30,30,42) or (isStar and Color3.fromRGB(255, 210, 100) or Color3.fromRGB(130, 180, 255))
    JoinBtn.Text             = isFull and "FULL" or "JOIN"
    JoinBtn.TextColor3       = isFull and C.TextDim or C.BG
    JoinBtn.TextSize         = 10
    JoinBtn.Font             = Enum.Font.GothamBold
    JoinBtn.AutoButtonColor  = false
    JoinBtn.ZIndex           = 43
    JoinBtn.Parent           = Card
    corner(JoinBtn, 99)

    if not isFull then
        hover(JoinBtn, C.Accent, C.AccentH)
        JoinBtn.MouseButton1Click:Connect(function()
            JoinBtn.Text = "Checking..."
            
            -- CEK 1: Ambil data terbaru server itu dari Firebase
            local ok, res = pcall(function()
                return doRequest({
                    Url = FIREBASE_URL .. "/servers/" .. s.jobId .. ".json",
                    Method = "GET"
                })
            end)
            
            local data = (ok and res.StatusCode == 200) and HttpService:JSONDecode(res.Body) or nil
            
            -- CEK 2: Kalau data ga ada atau udah basi (lebih dari 15 detik), HAPUS.
            if not data or (os.time() * 1000 - (tonumber(data.lastSeen) or 0)) > 15000 then
                JoinBtn.Text = "EXPIRED"
                JoinBtn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
                
                -- Langsung hapus sampah dari database biar ga muncul di refresh berikutnya
                task.spawn(function()
                    doRequest({ Url = FIREBASE_URL .. "/servers/" .. s.jobId .. ".json", Method = "DELETE" })
                end)
                
                task.wait(1)
                doRefresh() -- Refresh list otomatis
                return
            end
            
            -- CEK 3: Kalau lolos, baru Teleport
            JoinBtn.Text = "Joining..."
            TeleportService:TeleportToPlaceInstance(game.PlaceId, s.jobId, game.Players.LocalPlayer)
        end)
    end
end

-- ============================================================
-- REFRESH
-- ============================================================
local function clearCards()
    for _, c in ipairs(Scroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
end

function doRefresh()
    if SF_IsRefreshing then return end
    SF_IsRefreshing = true
    clearCards()
    StatusLbl.Text    = "Loading..."
    StatusLbl.Visible = true

    task.spawn(function()
        local servers = SF_Fetch()

        if not servers then
            StatusLbl.Text  = "Failed to connect"
            SF_IsRefreshing = false
            return
        end

        local query    = SearchBox.Text:lower()
        local filtered = {}
        for _, s in ipairs(servers) do
            if query == "" then
                table.insert(filtered, s)
            else
                for _, ev in ipairs(s.events or {}) do
                    if ev:lower():find(query, 1, true) then
                        table.insert(filtered, s)
                        break
                    end
                end
            end
        end

        clearCards()
        if #filtered == 0 then
            StatusLbl.Text    = "No active servers found"
            StatusLbl.Visible = true
        else
            StatusLbl.Visible = false
            for i, s in ipairs(filtered) do buildCard(s, i) end
        end

        SF_IsRefreshing = false
    end)
end

-- ============================================================
-- ANIMASI PANEL
-- ============================================================
local isOpen = false

local function openPanel()
    Panel.Visible = true
    Panel.Size    = UDim2.new(0, 420, 0, 0)
    TweenService:Create(Panel, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {
        Size = UDim2.new(0, 420, 0, 460)
    }):Play()
    isOpen = true
end

local function closePanel()
    isOpen = false
    local tw = TweenService:Create(Panel, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {
        Size = UDim2.new(0, 420, 0, 0)
    })
    tw:Play()
    tw.Completed:Once(function() Panel.Visible = false end)
end

-- ============================================================
-- EVENTS
-- ============================================================
local dragging = false
local dragStart, startPos

TopBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging  = true
        dragStart = input.Position
        startPos  = TopBtn.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
    and input.UserInputType ~= Enum.UserInputType.Touch then return end

    local delta = input.Position - dragStart

    local newX = startPos.X.Scale + (delta.X / SG.AbsoluteSize.X)
    local newY = startPos.Y.Scale + (delta.Y / SG.AbsoluteSize.Y)

    -- Clamp biar ga keluar layar
    newX = math.clamp(newX, 0.05, 0.95)
    newY = math.clamp(newY, 0,    0.92)

    TopBtn.Position = UDim2.new(newX, 0, newY, 0)

    -- Panel ngikutin posisi pill
    Panel.Position = UDim2.new(newX, 0, newY + (TopBtn.Size.Y.Offset / SG.AbsoluteSize.Y) + 0.005, 0)
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

TopBtn.MouseButton1Click:Connect(function()
    if isOpen then closePanel() else openPanel() end
end)

CloseBtn.MouseButton1Click:Connect(function()
    closePanel()
end)

RefBtn.MouseButton1Click:Connect(function()
    TweenService:Create(RefBtn, TweenInfo.new(0.3), { Rotation = 180 }):Play()
    task.delay(0.35, function()
        TweenService:Create(RefBtn, TweenInfo.new(0), { Rotation = 0 }):Play()
    end)
    doRefresh()
end)

SearchBox.FocusLost:Connect(function(enter)
    if enter then doRefresh() end
end)

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if not isOpen then return end
    local pos = input.Position
    local function inBounds(obj)
        local a = obj.AbsolutePosition
        local s = obj.AbsoluteSize
        return pos.X >= a.X and pos.X <= a.X + s.X and pos.Y >= a.Y and pos.Y <= a.Y + s.Y
    end
    if not inBounds(Panel) and not inBounds(TopBtn) then
        closePanel()
    end
end)

local function SF_CleanDatabase()
    local ok, res = pcall(function()
        return doRequest({ Url = FIREBASE_URL .. "/servers.json", Method = "GET" })
    end)
    if not ok or not res or res.StatusCode ~= 200 then return end
    
    local ok2, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not ok2 or type(data) ~= "table" then return end

    local nowMs = os.time() * 1000
    for id, s in pairs(data) do
        if type(s) == "table" and s.lastSeen then
            local age = nowMs - tonumber(s.lastSeen)
            -- Kalau server nggak update lebih dari 25 detik, hapus paksa dari database
            if age > 25000 then
                task.spawn(function()
                    doRequest({ 
                        Url = FIREBASE_URL .. "/servers/" .. id .. ".json", 
                        Method = "DELETE" 
                    })
                end)
            end
        end
    end
end

-- ============================================================
-- HEARTBEAT REGISTER
-- ============================================================
task.spawn(function()
    repeat task.wait(1) until game:IsLoaded()
    SF_Register()

    task.wait(1)
    doRefresh()
    
    while task.wait(8) do
        SF_Register()
    end
end)
task.spawn(function()
    while task.wait(30) do -- Tiap 30 detik bersihin database
        SF_CleanDatabase() -- Pakai fungsi cleaner yang gue kasih sebelumnya
    end
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
    if player == game.Players.LocalPlayer then
        SF_Unregister()
    end
end)

warn("Server Finder v5 Loaded")
