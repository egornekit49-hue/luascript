--// NEXUS V7 MOBILE — Единый оптимизированный скрипт
--// Поддержка Android / iPhone

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VIM = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Мобильные контролы
local Controls
pcall(function()
    local pm = require(player.PlayerScripts.PlayerModule)
    Controls = pm:GetControls()
end)

-- ---------------------- НАСТРОЙКИ ----------------------
local Settings = {
    speed = 50,
    step = 4,
    autoPunch = false,
    punchDelay = 0,        -- мс
    multiPunch = 10,
    auraRange = 12,
    punchX = 0.86,
    punchY = 0.80,
    skipBlockingTargets = true,
    esp = true,
    espAlpha = 0.30,
    espColor = Color3.fromRGB(255,0,0),
    reachMode = 0,         -- 0=off, 1=tp
    reachDistance = 30,
    noclip = false,
    flyEnabled = false,
}

-- Цвета
local COLORS = {
    bg = Color3.fromRGB(17,19,24),
    card = Color3.fromRGB(24,27,34),
    side = Color3.fromRGB(13,15,20),
    border = Color3.fromRGB(42,45,55),
    text = Color3.fromRGB(240,240,240),
    muted = Color3.fromRGB(145,150,165),
    green = Color3.fromRGB(120,210,60),
}

-- ---------------------- УТИЛИТЫ ----------------------
local function new(c, p, parent)
    local o = Instance.new(c)
    for k,v in pairs(p) do o[k]=v end
    o.Parent = parent
    return o
end

local function round(o, r)
    new("UICorner", {CornerRadius = UDim.new(0, r)}, o)
end

local function stroke(o)
    new("UIStroke", {Color = COLORS.border, Transparency = 0.4}, o)
end

-- ---------------------- GUI ----------------------
pcall(function() game.CoreGui.SuperGuiModern:Destroy() end)

local gui = new("ScreenGui", {
    Name = "SuperGuiModern",
    ResetOnSpawn = false,
    IgnoreGuiInset = false
}, game.CoreGui)

local window = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(620, 580),
    BackgroundColor3 = COLORS.bg,
    BorderSizePixel = 0
}, gui)
round(window, 16); stroke(window)

-- Отдельные кнопки скрытия не перехватывают касания игрового джойстика.
local reopenButton = new("TextButton", {
    Position = UDim2.fromOffset(12, 92),
    Size = UDim2.fromOffset(48, 48),
    Text = "N",
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    TextColor3 = COLORS.text,
    BackgroundColor3 = COLORS.side,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Visible = false,
    ZIndex = 50,
}, gui)
round(reopenButton, 14); stroke(reopenButton)

local closeButton = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -12, 0, 12),
    Size = UDim2.fromOffset(34, 34),
    Text = "×",
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    TextColor3 = COLORS.muted,
    BackgroundColor3 = COLORS.card,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    ZIndex = 20,
}, window)
round(closeButton, 10)

closeButton.Activated:Connect(function()
    window.Visible = false
    reopenButton.Visible = true
end)

reopenButton.Activated:Connect(function()
    window.Visible = true
    reopenButton.Visible = false
end)

-- Боковая панель
local side = new("Frame", {
    Size = UDim2.new(0, 145, 1, 0),
    BackgroundColor3 = COLORS.side,
    BorderSizePixel = 0
}, window)

new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(18, 18),
    Size = UDim2.new(1, -20, 0, 30),
    Text = "● NEXUS",
    TextColor3 = COLORS.text,
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    TextXAlignment = Enum.TextXAlignment.Left
}, side)

-- Основная область
local content = new("Frame", {
    Position = UDim2.fromOffset(145, 0),
    Size = UDim2.new(1, -145, 1, 0),
    BackgroundTransparency = 1
}, window)

local title = new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(20, 14),
    Size = UDim2.new(1, -40, 0, 30),
    Text = "Movement",
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    TextColor3 = COLORS.text,
    TextXAlignment = Enum.TextXAlignment.Left
}, content)

local body = new("ScrollingFrame", {
    Position = UDim2.fromOffset(16, 54),
    Size = UDim2.new(1, -32, 1, -70),
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4
}, content)

local layout = new("UIListLayout", {
    Padding = UDim.new(0, 10)
}, body)

-- ---------------------- КОМПОНЕНТЫ UI ----------------------
local function makeCard(name, desc, height)
    local c = new("Frame", {
        Size = UDim2.new(1, -4, 0, height or 78),
        BackgroundColor3 = COLORS.card,
        BorderSizePixel = 0
    }, body)
    round(c, 12); stroke(c)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(15, 10),
        Size = UDim2.new(1, -30, 0, 20),
        Text = name,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = COLORS.text,
        TextXAlignment = Enum.TextXAlignment.Left
    }, c)

    local descLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(15, 30),
        Size = UDim2.new(1, -30, 0, 16),
        Text = desc,
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextColor3 = COLORS.muted,
        TextXAlignment = Enum.TextXAlignment.Left
    }, c)

    return c, descLabel
end

-- Переключатель (toggle)
local function createToggle(parent, initial)
    local state = initial or false
    local btn = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -15, 0.5, 5),
        Size = UDim2.fromOffset(48, 26),
        Text = "",
        BackgroundColor3 = state and Color3.fromRGB(60,90,35) or COLORS.border,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Active = true,
    }, parent)
    round(btn, 13)

    local knob = new("Frame", {
        Position = state and UDim2.fromOffset(26, 4) or UDim2.fromOffset(4, 4),
        Size = UDim2.fromOffset(18, 18),
        BackgroundColor3 = state and COLORS.green or COLORS.muted,
        BorderSizePixel = 0
    }, btn)
    round(knob, 9)

    local function set(v)
        state = v
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = v and Color3.fromRGB(60,90,35) or COLORS.border}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = v and UDim2.fromOffset(26, 4) or UDim2.fromOffset(4, 4),
            BackgroundColor3 = v and COLORS.green or COLORS.muted
        }):Play()
    end

    return set, function() return state end, btn
end

-- Степпер (+/-)
local function createStepper(parent, initial, minVal, maxVal, stepVal)
    local value = initial or 0
    local min = minVal or 0
    local max = maxVal or 100
    local step = stepVal or 1

    local minus = new("TextButton", {
        Position = UDim2.new(1, -120, 0.5, -12),
        Size = UDim2.fromOffset(24, 24),
        Text = "-",
        BackgroundColor3 = COLORS.bg,
        TextColor3 = COLORS.text,
        Active = true,
        AutoButtonColor = false,
    }, parent)
    local plus = new("TextButton", {
        Position = UDim2.new(1, -28, 0.5, -12),
        Size = UDim2.fromOffset(24, 24),
        Text = "+",
        BackgroundColor3 = COLORS.bg,
        TextColor3 = COLORS.green,
        Active = true,
        AutoButtonColor = false,
    }, parent)
    local box = new("TextBox", {
        Position = UDim2.new(1, -90, 0.5, -12),
        Size = UDim2.fromOffset(54, 24),
        Text = tostring(value),
        BackgroundColor3 = COLORS.bg,
        TextColor3 = COLORS.text,
        ClearTextOnFocus = false,
    }, parent)
    round(minus, 6); round(plus, 6); round(box, 6)

    local function set(v)
        v = math.clamp(tonumber(v) or value, min, max)
        value = v
        box.Text = tostring(v)
        return v
    end

    minus.Activated:Connect(function() set(value - step) end)
    plus.Activated:Connect(function() set(value + step) end)
    box.FocusLost:Connect(function() set(box.Text) end)

    return minus, box, plus, set, function() return value end
end

-- Кнопка в карточке
local function createButton(parent, text, yOffset, color)
    local btn = new("TextButton", {
        Size = UDim2.new(1, -20, 0, 34),
        Position = UDim2.fromOffset(10, yOffset or 18),
        Text = text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        BackgroundColor3 = color or COLORS.green,
        TextColor3 = Color3.new(1,1,1),
        Active = true,
        AutoButtonColor = false,
    }, parent)
    round(btn, 8)
    return btn
end

-- ---------------------- СТРАНИЦЫ ----------------------
local pages = {
    Movement = {},
    Combat = {},
    ESP = {},
    Reach = {},
    Misc = {},
}
local currentPage = "Movement"
local pageButtons = {}

-- Создаём кнопки страниц в боковой панели
local function createPageButton(name, y)
    local btn = new("TextButton", {
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.new(1, 0, 0, 38),
        Text = name,
        TextColor3 = COLORS.muted,
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        Padding = UDim.new(0, 18),
        Active = true,
        AutoButtonColor = false,
    }, side)
    btn.Activated:Connect(function()
        currentPage = name
        title.Text = name
        for k, v in pairs(pageButtons) do
            v.TextColor3 = (k == name) and COLORS.text or COLORS.muted
        end
        for _, c in ipairs(body:GetChildren()) do
            if c:IsA("Frame") then c.Visible = (c:GetAttribute("Page") == name) end
        end
    end)
    return btn
end

-- Добавляем карточки на страницы
local function addCardToPage(pageName, card, descLabel)
    card:SetAttribute("Page", pageName)
    card.Visible = (pageName == currentPage)
    return card, descLabel
end

-- ---------------------- СОЗДАНИЕ КОНТРОЛОВ ----------------------
-- 1. Страница Movement
local pageMov = "Movement"
local cardMov, _ = makeCard("Walk Speed", "Character movement speed")
cardMov = addCardToPage(pageMov, cardMov)
local _, _, _, setSpeed, getSpeed = createStepper(cardMov, Settings.speed, 0, 300, Settings.step)
-- Применение скорости
RunService.Stepped:Connect(function()
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = getSpeed() end
end)

-- Fly
local flyCard, _ = makeCard("Fly", "Camera movement", 78)
flyCard = addCardToPage(pageMov, flyCard)
local flySet, flyState, flyToggle = createToggle(flyCard, false)
local flying = false
local bv, bg

local function stopFly()
    flying = false
    if bv then bv:Destroy(); bv = nil end
    if bg then bg:Destroy(); bg = nil end
    flySet(false)
end

local function startFly()
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(9e9,9e9,9e9)
    bv.Parent = root
    bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(9e9,9e9,9e9)
    bg.Parent = root
    flying = true
    flySet(true)
    task.spawn(function()
        while flying do
            local move = Vector3.zero
            if UIS.TouchEnabled then
                local vec = Controls and Controls:GetMoveVector() or Vector3.zero
                move = camera.CFrame.RightVector * vec.X - camera.CFrame.LookVector * vec.Z
            else
                if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + camera.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.S) then move = move - camera.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.A) then move = move - camera.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + camera.CFrame.RightVector end
            end
            bv.Velocity = move.Magnitude > 0.001 and move.Unit * getSpeed() or Vector3.zero
            bg.CFrame = camera.CFrame
            task.wait()
        end
    end)
end

-- Кнопка для Fly внутри карточки
local flyBtn = createButton(flyCard, "TOGGLE FLY", 48, COLORS.border)
local function toggleFly()
    if flyState() then stopFly() else startFly() end
end
flyBtn.Activated:Connect(toggleFly)
flyToggle.Activated:Connect(toggleFly)

-- 2. Страница Combat
local pageCom = "Combat"
-- Статус
local statusCard, statusLabel = makeCard("Status", "Auto Punch OFF", 58)
statusCard = addCardToPage(pageCom, statusCard)

-- Auto Punch
local autoCard, _ = makeCard("Auto Punch", "Automatic attack of nearest enemy", 78)
autoCard = addCardToPage(pageCom, autoCard)
local autoSet, autoState, autoToggle = createToggle(autoCard, false)

-- Настройки
local delayCard, _ = makeCard("Punch Delay", "Milliseconds between attacks", 78)
delayCard = addCardToPage(pageCom, delayCard)
local _, _, _, setDelay, getDelay = createStepper(delayCard, Settings.punchDelay, 0, 1000, 10)

local multiCard, _ = makeCard("Multi Punch", "Hits per attack", 78)
multiCard = addCardToPage(pageCom, multiCard)
local _, _, _, setMulti, getMulti = createStepper(multiCard, Settings.multiPunch, 1, 10, 1)

local rangeCard, _ = makeCard("Aura Range", "Detection distance", 78)
rangeCard = addCardToPage(pageCom, rangeCard)
local _, _, _, setRange, getRange = createStepper(rangeCard, Settings.auraRange, 1, 30, 1)

local blockCard, _ = makeCard("Skip Blocking", "Attack only after the enemy drops block", 78)
blockCard = addCardToPage(pageCom, blockCard)
local blockSet, blockState, blockToggle = createToggle(blockCard, Settings.skipBlockingTargets)

-- Тестовая кнопка
local testCard, _ = makeCard("Test Punch", "Tap to verify mobile attack", 78)
testCard = addCardToPage(pageCom, testCard)
local testBtn = createButton(testCard, "TEST", 18, COLORS.green)

-- Логика автопанча
local running = false
local lastTime = 0
local punchButton = nil
local punch

local function isVisible(guiObject)
    local current = guiObject
    while current and current:IsA("GuiObject") do
        if not current.Visible then return false end
        current = current.Parent
    end
    return guiObject.AbsoluteSize.X > 4 and guiObject.AbsoluteSize.Y > 4
end

local function cachePunchButton()
    if punchButton and punchButton.Parent and isVisible(punchButton) then return punchButton end
    punchButton = nil
    local pg = player:WaitForChild("PlayerGui")
    local best, bestScore
    for _, v in ipairs(pg:GetDescendants()) do
        if v:IsA("GuiButton") and isVisible(v) and not v:IsDescendantOf(gui) then
            local n = v.Name:lower()
            if n:find("punch") or n:find("attack") or n:find("hit") or n:find("jab") then
                punchButton = v
                return v
            end
            -- В Boxing Beta кнопка кулака иногда называется просто "button".
            -- Выбираем наиболее нижнюю крупную кнопку справа, не трогая джойстик слева.
            local center = v.AbsolutePosition + v.AbsoluteSize / 2
            local vp = camera.ViewportSize
            if center.X > vp.X * 0.68 and center.Y > vp.Y * 0.55 then
                local score = center.Y / math.max(vp.Y, 1) + math.min(v.AbsoluteSize.X, v.AbsoluteSize.Y) / 300
                if not bestScore or score > bestScore then
                    best, bestScore = v, score
                end
            end
        end
    end
    punchButton = best
    return best
end
task.spawn(function() while task.wait(2) do cachePunchButton() end end)

local touchSerial = 0
local function touch(x, y)
    -- Не используем ID 0: он может совпасть с пальцем на мобильном джойстике.
    touchSerial = (touchSerial % 1000) + 1
    local touchId = 900000 + touchSerial
    VIM:SendTouchEvent(touchId, Enum.UserInputState.Begin.Value, x, y)
    VIM:SendTouchEvent(touchId, Enum.UserInputState.End.Value, x, y)
end

local function getPunchPoint()
    local btn = cachePunchButton()
    if btn then
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        return pos.X + size.X/2, pos.Y + size.Y/2, btn.Name
    end
    local vp = camera.ViewportSize
    return vp.X * Settings.punchX, vp.Y * Settings.punchY, "fallback"
end

punch = function(count)
    local x, y, source = getPunchPoint()
    local ok, err = pcall(function()
        for _ = 1, math.clamp(count or 1, 1, 10) do
            touch(x, y)
        end
    end)
    return ok, ok and source or tostring(err)
end

testBtn.Activated:Connect(function()
    local ok, source = punch(1)
    statusLabel.Text = ok and ("Punch sent: " .. source) or ("Input error: " .. source)
end)

local function isBlocking(character)
    for _, name in ipairs({"Blocking", "IsBlocking", "Block", "block"}) do
        local attr = character:GetAttribute(name)
        if attr == true then return true end
        local value = character:FindFirstChild(name, true)
        if value and value:IsA("BoolValue") and value.Value then return true end
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            local animation = track.Animation
            local label = ((track.Name or "") .. " " .. (animation and animation.Name or "")):lower()
            if label:find("block") or label:find("guard") then return true end
        end
    end
    return false
end

blockToggle.Activated:Connect(function()
    Settings.skipBlockingTargets = not Settings.skipBlockingTargets
    blockSet(Settings.skipBlockingTargets)
end)

local function canAttack(character)
    return not blockState() or not isBlocking(character)
end

local function sendBurst()
    local count = getMulti()
    local ok, source = punch(count)
    if ok then
        statusLabel.Text = string.format("Sent %d touches: %s", count, source)
    else
        statusLabel.Text = "Input error: " .. source
    end
    return ok
end

local function nearestEnemy()
    local my = player.Character
    if not my then return end
    local root = my:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local nearest = nil
    local dist = getRange()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 and canAttack(plr.Character) then
                local d = (root.Position - hrp.Position).Magnitude
                if d < dist then
                    dist = d
                    nearest = plr.Character
                end
            end
        end
    end
    return nearest
end

task.spawn(function()
    running = true
    while running do
        if Settings.autoPunch then
            local enemy = nearestEnemy()
            if enemy then
                if tick() - lastTime >= getDelay() / 1000 then
                    sendBurst()
                    lastTime = tick()
                end
            else
                statusLabel.Text = "Searching..."
            end
        end
        task.wait(0.03)
    end
end)

autoToggle.Activated:Connect(function()
    Settings.autoPunch = not Settings.autoPunch
    autoSet(Settings.autoPunch)
    statusLabel.Text = Settings.autoPunch and "Auto Punch ON" or "Auto Punch OFF"
end)

-- 3. Страница ESP
local pageESP = "ESP"
local espCard, _ = makeCard("ESP", "Show enemy highlights", 78)
espCard = addCardToPage(pageESP, espCard)
local espSet, espState, espToggle = createToggle(espCard, Settings.esp)

local namesCard, _ = makeCard("Names", "Show player names", 78)
namesCard = addCardToPage(pageESP, namesCard)
local nameSet, nameState, nameToggle = createToggle(namesCard, true)

local espObjects = {}

local function removeESP(plr)
    if espObjects[plr] then
        espObjects[plr]:Destroy()
        espObjects[plr] = nil
    end
end

local function createESP(plr)
    if plr == player or not espState() then return end
    local char = plr.Character
    if not char then return end
    removeESP(plr)
    local hl = Instance.new("Highlight")
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillColor = Settings.espColor
    hl.FillTransparency = Settings.espAlpha
    hl.OutlineTransparency = 0.15
    hl.Adornee = char
    hl.Parent = char
    if nameState() then
        local head = char:FindFirstChild("Head")
        if head then
            local bill = Instance.new("BillboardGui")
            bill.Size = UDim2.fromOffset(120, 28)
            bill.StudsOffset = Vector3.new(0, 2.5, 0)
            bill.AlwaysOnTop = true
            bill.Adornee = head
            bill.Parent = hl
            local txt = Instance.new("TextLabel")
            txt.Size = UDim2.fromScale(1, 1)
            txt.BackgroundTransparency = 1
            txt.Font = Enum.Font.GothamBold
            txt.Text = plr.Name
            txt.TextColor3 = Color3.new(1,1,1)
            txt.TextStrokeTransparency = 0.3
            txt.TextSize = 18
            txt.Parent = bill
        end
    end
    espObjects[plr] = hl
end

local function refreshESP()
    for p in pairs(espObjects) do removeESP(p) end
    if not espState() then return end
    for _, plr in ipairs(Players:GetPlayers()) do createESP(plr) end
end

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(0.3)
        createESP(plr)
    end)
end)
Players.PlayerRemoving:Connect(removeESP)

espToggle.Activated:Connect(function()
    Settings.esp = not Settings.esp
    espSet(Settings.esp)
    refreshESP()
end)

nameToggle.Activated:Connect(function()
    nameSet(not nameState())
    refreshESP()
end)

refreshESP()

-- 4. Страница Reach
local pageReach = "Reach"
local reachCard, _ = makeCard("Reach Mode", "Teleport reach", 110)
reachCard = addCardToPage(pageReach, reachCard)
local reachOff = createButton(reachCard, "OFF", 66, COLORS.border)
local reachTP = createButton(reachCard, "TP", 66, COLORS.green)
reachOff.Position = UDim2.fromOffset(12, 66)
reachTP.Position = UDim2.fromOffset(112, 66)
reachOff.Activated:Connect(function() Settings.reachMode = 0 end)
reachTP.Activated:Connect(function() Settings.reachMode = 1 end)

local distCard, _ = makeCard("Reach Distance", "Maximum studs", 78)
distCard = addCardToPage(pageReach, distCard)
local _, _, _, setReachDist, getReachDist = createStepper(distCard, Settings.reachDistance, 5, 100, 5)

-- Рейч (перехват панча)
local function tpPunch(enemy)
    if Settings.reachMode ~= 1 then return end
    local my = player.Character
    if not my then return end
    local root = my:FindFirstChild("HumanoidRootPart")
    local eroot = enemy:FindFirstChild("HumanoidRootPart")
    if not root or not eroot then return end
    local old = root.CFrame
    root.CFrame = eroot.CFrame * CFrame.new(0,0,2)
    task.wait(0.03)
    root.CFrame = old
end

-- Можно подключить к автопанчу (добавим в nearestEnemy, но там нет врага, можно модифицировать)
-- Для простоты, оставим как отдельную функцию.

-- 5. Страница Misc
local pageMisc = "Misc"
local noclipCard, _ = makeCard("Noclip", "Disable collisions", 78)
noclipCard = addCardToPage(pageMisc, noclipCard)
local noclipSet, noclipState, noclipToggle = createToggle(noclipCard, false)
local originalCollision = setmetatable({}, {__mode = "k"})
noclipToggle.Activated:Connect(function()
    Settings.noclip = not Settings.noclip
    noclipSet(Settings.noclip)
    if not Settings.noclip then
        for part, canCollide in pairs(originalCollision) do
            if part.Parent then part.CanCollide = canCollide end
        end
        table.clear(originalCollision)
    end
end)

RunService.Stepped:Connect(function()
    if not Settings.noclip then return end
    local char = player.Character
    if char then
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BasePart") then
                if originalCollision[v] == nil then originalCollision[v] = v.CanCollide end
                v.CanCollide = false
            end
        end
    end
end)

-- ---------------------- НАВИГАЦИЯ ----------------------
local pageNames = {"Movement", "Combat", "ESP", "Reach", "Misc"}
for i, name in ipairs(pageNames) do
    local btn = createPageButton(name, 60 + (i-1)*42)
    pageButtons[name] = btn
    if name == currentPage then btn.TextColor3 = COLORS.text end
end

-- Показываем только страницу по умолчанию
for _, c in ipairs(body:GetChildren()) do
    if c:IsA("Frame") then
        c.Visible = (c:GetAttribute("Page") == currentPage)
    end
end

-- ---------------------- МОБИЛЬНОЕ МАСШТАБИРОВАНИЕ ----------------------
local scale = Instance.new("UIScale")
scale.Parent = window

local function resize()
    local vp = camera.ViewportSize
    scale.Scale = math.clamp(math.min((vp.X - 20)/620, (vp.Y - 80)/580), 0.55, 1)
    if UIS.TouchEnabled then
        window.AnchorPoint = Vector2.new(0.5, 0)
        window.Position = UDim2.new(0.5, 0, 0, 8)
    end
end
resize()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)

-- ---------------------- ГОТОВО ----------------------
print("NEXUS V7 MOBILE (объединённый) ЗАГРУЖЕН")
