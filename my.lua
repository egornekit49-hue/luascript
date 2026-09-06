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
    multiPunch = 8,
    auraRange = 12,
    punchX = 0.86,
    punchY = 0.74,
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

    btn.Activated:Connect(function() set(not state) end)
    return set, function() return state end
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
local flySet, flyState = createToggle(flyCard, false)
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
            bv.Velocity = move.Unit * getSpeed()
            bg.CFrame = camera.CFrame
            task.wait()
        end
    end)
end

-- Кнопка для Fly внутри карточки
local flyBtn = createButton(flyCard, "TOGGLE FLY", 48, COLORS.border)
flyBtn.Activated:Connect(function()
    if flyState() then stopFly() else startFly() end
end)

-- 2. Страница Combat
local pageCom = "Combat"
-- Статус
local statusCard, statusLabel = makeCard("Status", "Auto Punch OFF", 58)
statusCard = addCardToPage(pageCom, statusCard)

-- Auto Punch
local autoCard, _ = makeCard("Auto Punch", "Automatic attack of nearest enemy", 78)
autoCard = addCardToPage(pageCom, autoCard)
local autoSet, autoState = createToggle(autoCard, false)

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

-- Тестовая кнопка
local testCard, _ = makeCard("Test Punch", "Tap to verify mobile attack", 78)
testCard = addCardToPage(pageCom, testCard)
local testBtn = createButton(testCard, "TEST", 18, COLORS.green)
testBtn.Activated:Connect(function() punch() statusLabel.Text = "Punch sent" end)

-- Логика автопанча
local running = false
local lastTime = 0
local punchButton = nil

local function cachePunchButton()
    if punchButton and punchButton.Parent then return punchButton end
    local pg = player:WaitForChild("PlayerGui")
    for _, v in ipairs(pg:GetDescendants()) do
        if v:IsA("GuiButton") then
            local n = v.Name:lower()
            if n:find("punch") or n:find("attack") or n:find("hit") or n:find("jab") then
                punchButton = v
                return v
            end
        end
    end
    return nil
end
task.spawn(function() while task.wait(2) do cachePunchButton() end end)

local function touch(x, y)
    VIM:SendTouchEvent(0, Enum.UserInputState.Begin.Value, x, y)
    task.wait(0.015)
    VIM:SendTouchEvent(0, Enum.UserInputState.End.Value, x, y)
end

function punch()
    local btn = cachePunchButton()
    if btn then
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        touch(pos.X + size.X/2, pos.Y + size.Y/2)
        return true
    end
    local vp = camera.ViewportSize
    touch(vp.X * Settings.punchX, vp.Y * Settings.punchY)
    return true
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
            if hrp and hum and hum.Health > 0 then
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
                    for i = 1, getMulti() do
                        punch()
                        task.wait(0.01)
                    end
                    lastTime = tick()
                    statusLabel.Text = "Enemy detected ✓"
                end
            else
                statusLabel.Text = "Searching..."
            end
        end
        task.wait(0.03)
    end
end)

autoCard:FindFirstChildOfClass("TextButton").Activated:Connect(function()
    Settings.autoPunch = not Settings.autoPunch
    autoSet(Settings.autoPunch)
    statusLabel.Text = Settings.autoPunch and "Auto Punch ON" or "Auto Punch OFF"
end)

-- 3. Страница ESP
local pageESP = "ESP"
local espCard, _ = makeCard("ESP", "Show enemy highlights", 78)
espCard = addCardToPage(pageESP, espCard)
local espSet, espState = createToggle(espCard, Settings.esp)

local namesCard, _ = makeCard("Names", "Show player names", 78)
namesCard = addCardToPage(pageESP, namesCard)
local nameSet, nameState = createToggle(namesCard, true)

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

espCard:FindFirstChildOfClass("TextButton").Activated:Connect(function()
    Settings.esp = not Settings.esp
    espSet(Settings.esp)
    refreshESP()
end)

namesCard:FindFirstChildOfClass("TextButton").Activated:Connect(function()
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
local noclipSet, noclipState = createToggle(noclipCard, false)
noclipCard:FindFirstChildOfClass("TextButton").Activated:Connect(function()
    Settings.noclip = not Settings.noclip
    noclipSet(Settings.noclip)
end)

RunService.Stepped:Connect(function()
    if not Settings.noclip then return end
    local char = player.Character
    if char then
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BasePart") then
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
