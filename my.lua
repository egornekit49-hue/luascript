-- Nexus UI v2: Speed, Fly, Auto-Punch (Multi), ESP with Color Picker
-- v3.7 movement isolation: never mutate character movement during spawn/ring transitions.

local scriptAlive = true
local connections, cleanupCallbacks = {}, {}
local function bind(signal, callback)
    local connection = signal:Connect(function(...)
        if scriptAlive then return callback(...) end
    end)
    table.insert(connections, connection)
    return connection
end
local function cleanup()
    if not scriptAlive then return end
    scriptAlive = false
    for _, connection in ipairs(connections) do connection:Disconnect() end
    table.clear(connections)
    for _, callback in ipairs(cleanupCallbacks) do
        local ok, err = pcall(callback)
        if not ok then warn("[Nexus cleanup] " .. tostring(err)) end
    end
    table.clear(cleanupCallbacks)
end
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local desktopInput = UserInputService.KeyboardEnabled and UserInputService.MouseEnabled
local virtualInput
local function getVirtualInput()
    if virtualInput then return virtualInput end
    pcall(function() virtualInput = UserInputService:CreateVirtualInput() end)
    return virtualInput
end

-- Получаем актуальный Controls только по явному запросу. Некоторые режимы
-- пересоздают контроллер при входе на ринг, поэтому хранить его со старта нельзя.
local function getCurrentControls()
    local controls
    pcall(function()
        local scripts = player:FindFirstChild("PlayerScripts")
        local module = scripts and scripts:FindFirstChild("PlayerModule")
        if module then controls = require(module):GetControls() end
    end)
    return controls
end

-- Настройки по умолчанию
local SPEED = 50
local STEP = 4
local PUNCH_DELAY = 0            -- без дополнительной задержки между сериями
local MULTI_PUNCH = 10           -- десять вызовов подряд в серии
local MIN_SERIES_INTERVAL = 500  -- максимум две серии в секунду при delay = 0
local PUNCH_WHILE_BLOCKING = true
local BLOCK_SPEED_THRESHOLD = 0.5
local AURA_RANGE = 10 -- studs; controls activation, not the game's hit reach
local SKIP_BLOCKING_TARGETS = true

-- Настройки ESP
local ESP_ENABLED = true
local ESP_COLOR = Color3.fromRGB(255, 0, 0)
local ESP_ALPHA = 0.3
local SHOW_NAMES = true

-- Цветовая палитра для ESP
local ESP_COLORS = {
    Color3.fromRGB(255, 0, 0),   -- Красный
    Color3.fromRGB(0, 255, 0),   -- Зелёный
    Color3.fromRGB(0, 150, 255), -- Синий
    Color3.fromRGB(255, 255, 0), -- Жёлтый
    Color3.fromRGB(255, 0, 255), -- Фиолетовый
    Color3.fromRGB(255, 165, 0), -- Оранжевый
    Color3.fromRGB(255, 255, 255), -- Белый
    Color3.fromRGB(0, 0, 0),     -- Чёрный
}

local COLORS = {
    window = Color3.fromRGB(15, 17, 21),
    sidebar = Color3.fromRGB(12, 14, 18),
    surface = Color3.fromRGB(22, 25, 31),
    surfaceHover = Color3.fromRGB(28, 32, 40),
    border = Color3.fromRGB(42, 46, 56),
    text = Color3.fromRGB(238, 241, 246),
    muted = Color3.fromRGB(137, 145, 160),
    accent = Color3.fromRGB(128, 211, 67),
    accentDark = Color3.fromRGB(71, 113, 43),
    danger = Color3.fromRGB(239, 91, 105),
}

-- ---- Вспомогательные функции ----
local function create(className, properties, parent)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do object[key] = value end
    object.Parent = parent
    return object
end

local function corner(parent, radius)
    return create("UICorner", {CornerRadius = UDim.new(0, radius)}, parent)
end

local function stroke(parent, color, transparency)
    return create("UIStroke", {
        Color = color or COLORS.border,
        Transparency = transparency or 0,
        Thickness = 1,
    }, parent)
end

local function tween(object, properties, duration)
    local info = TweenInfo.new(duration or 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local animation = TweenService:Create(object, info, properties)
    animation:Play()
    return animation
end

-- ---- GUI ----
local oldGui = game:GetService("CoreGui"):FindFirstChild("SuperGuiModern")
if oldGui then
    local shutdown = oldGui:FindFirstChild("NexusShutdown")
    if shutdown and shutdown:IsA("BindableFunction") then pcall(function() shutdown:Invoke() end) end
    oldGui:Destroy()
end

local gui = create("ScreenGui", {
    Name = "SuperGuiModern",
    ResetOnSpawn = false,
    IgnoreGuiInset = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, game:GetService("CoreGui"))

local shutdown = Instance.new("BindableFunction")
shutdown.Name = "NexusShutdown"
shutdown.OnInvoke = cleanup
shutdown.Parent = gui
gui.Destroying:Connect(cleanup)

local dim = create("Frame", {
    Name = "Dim",
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Active = false,
    Visible = not UserInputService.TouchEnabled,
}, gui)

local panel = create("Frame", {
    Name = "Window",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(600, 420), -- чуть больше для ESP
    BackgroundColor3 = COLORS.window,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, gui)
corner(panel, 14)
stroke(panel, COLORS.border, 0.15)

local scale = create("UIScale", {Scale = 1}, panel)
local shadow = create("ImageLabel", {
    Name = "Shadow",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(1, 42, 1, 42),
    BackgroundTransparency = 1,
    Image = "rbxassetid://6014261993",
    ImageColor3 = Color3.new(0, 0, 0),
    ImageTransparency = 0.35,
    ScaleType = Enum.ScaleType.Slice,
    SliceCenter = Rect.new(49, 49, 450, 450),
    ZIndex = -1,
}, panel)

local sidebar = create("Frame", {
    Size = UDim2.new(0, 150, 1, 0),
    BackgroundColor3 = COLORS.sidebar,
    BorderSizePixel = 0,
}, panel)
create("Frame", {
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
    Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = COLORS.border,
    BackgroundTransparency = 0.35, BorderSizePixel = 0,
}, sidebar)

local logo = create("TextLabel", {
    Position = UDim2.fromOffset(18, 18), Size = UDim2.new(1, -36, 0, 32),
    BackgroundTransparency = 1, Text = "●  NEXUS", TextColor3 = COLORS.text,
    Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left,
}, sidebar)
local dot = create("Frame", {
    Position = UDim2.fromOffset(18, 53), Size = UDim2.fromOffset(5, 5),
    BackgroundColor3 = COLORS.accent, BorderSizePixel = 0,
}, sidebar)
corner(dot, 5)
create("TextLabel", {
    Position = UDim2.fromOffset(29, 46), Size = UDim2.new(1, -38, 0, 20),
    BackgroundTransparency = 1, Text = "v3.7 movement isolation", TextColor3 = COLORS.muted,
    Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
}, sidebar)

local navHolder = create("Frame", {
    Position = UDim2.fromOffset(10, 92), Size = UDim2.new(1, -20, 0, 160),
    BackgroundTransparency = 1,
}, sidebar)
create("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, navHolder)

local pages = {}
local navButtons = {}
local selectedPage = "Movement"

local content = create("Frame", {
    Position = UDim2.fromOffset(150, 0), Size = UDim2.new(1, -150, 1, 0),
    BackgroundTransparency = 1,
}, panel)

local header = create("Frame", {
    Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1,
}, content)
local pageTitle = create("TextLabel", {
    Position = UDim2.fromOffset(22, 12), Size = UDim2.new(1, -72, 0, 24),
    BackgroundTransparency = 1, Text = "Movement", TextColor3 = COLORS.text,
    Font = Enum.Font.GothamBold, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left,
}, header)
local pageSubtitle = create("TextLabel", {
    Position = UDim2.fromOffset(22, 35), Size = UDim2.new(1, -72, 0, 17),
    BackgroundTransparency = 1, Text = "Movement and flight settings", TextColor3 = COLORS.muted,
    Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
}, header)
local hideButton = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14),
    Size = UDim2.fromOffset(34, 34), BackgroundColor3 = COLORS.surface,
    BorderSizePixel = 0, Text = "×", TextColor3 = COLORS.muted,
    Font = Enum.Font.GothamMedium, TextSize = 21, AutoButtonColor = false,
}, header)
corner(hideButton, 9)
stroke(hideButton, COLORS.border, 0.4)

local body = create("Frame", {
    Position = UDim2.fromOffset(22, 64), Size = UDim2.new(1, -44, 1, -82),
    BackgroundTransparency = 1, ClipsDescendants = true,
}, content)

local function makePage(name)
    local page = create("ScrollingFrame", {
        Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = COLORS.accent,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = name == selectedPage,
    }, body)
    create("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, page)
    pages[name] = page
    return page
end

local movementPage = makePage("Movement")
local combatPage = makePage("Combat")
local espPage = makePage("ESP")

local function makeNav(name, glyph)
    local button = create("TextButton", {
        Name = name, Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = COLORS.surface,
        BackgroundTransparency = name == selectedPage and 0 or 1, BorderSizePixel = 0,
        Text = "   " .. glyph .. "   " .. name, TextColor3 = name == selectedPage and COLORS.text or COLORS.muted,
        Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
    }, navHolder)
    corner(button, 9)
    local marker = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(3, 20), BackgroundColor3 = COLORS.accent,
        BackgroundTransparency = name == selectedPage and 0 or 1, BorderSizePixel = 0,
    }, button)
    corner(marker, 3)
    navButtons[name] = {button = button, marker = marker}
    bind(button.Activated, function()
        if selectedPage == name then return end
        selectedPage = name
        pageTitle.Text = name
        local sub = ""
        if name == "Movement" then sub = "Movement and flight settings"
        elseif name == "Combat" then sub = "Auto punch and multi-hit settings"
        elseif name == "ESP" then sub = "Visuals and color picker" end
        pageSubtitle.Text = sub
        for pageName, page in pairs(pages) do page.Visible = pageName == name end
        for buttonName, data in pairs(navButtons) do
            local active = buttonName == name
            tween(data.button, {BackgroundTransparency = active and 0 or 1, TextColor3 = active and COLORS.text or COLORS.muted})
            tween(data.marker, {BackgroundTransparency = active and 0 or 1})
        end
    end)
end

makeNav("Movement", "◇")
makeNav("Combat", "◎")
makeNav("ESP", "◈")

create("TextLabel", {
    AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -17),
    Size = UDim2.new(1, -36, 0, 30), BackgroundTransparency = 1,
    Text = "WASD  •  Space / Shift", TextColor3 = COLORS.muted,
    Font = Enum.Font.Gotham, TextSize = 9, TextWrapped = true,
}, sidebar)

-- ---- Компоненты UI ----
local function makeCard(parent, titleText, description, height)
    local card = create("Frame", {
        Size = UDim2.new(1, -4, 0, height or 74), BackgroundColor3 = COLORS.surface,
        BorderSizePixel = 0,
    }, parent)
    corner(card, 11)
    stroke(card, COLORS.border, 0.45)
    create("TextLabel", {
        Position = UDim2.fromOffset(15, 11), Size = UDim2.new(1, -30, 0, 20),
        BackgroundTransparency = 1, Text = titleText, TextColor3 = COLORS.text,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
    }, card)
    create("TextLabel", {
        Position = UDim2.fromOffset(15, 32), Size = UDim2.new(1, -30, 0, 17),
        BackgroundTransparency = 1, Text = description, TextColor3 = COLORS.muted,
        Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
    }, card)
    return card
end

local function makeStepper(parent, defaultText)
    local holder = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 7),
        Size = UDim2.fromOffset(128, 34), BackgroundColor3 = COLORS.window, BorderSizePixel = 0,
    }, parent)
    corner(holder, 8)
    stroke(holder, COLORS.border, 0.25)
    local minus = create("TextButton", {Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1, Text = "−", TextColor3 = COLORS.muted, Font = Enum.Font.GothamMedium, TextSize = 18}, holder)
    local box = create("TextBox", {Position = UDim2.fromOffset(34, 0), Size = UDim2.fromOffset(60, 34), BackgroundTransparency = 1, Text = defaultText, TextColor3 = COLORS.text, Font = Enum.Font.GothamBold, TextSize = 12, ClearTextOnFocus = false}, holder)
    local plus = create("TextButton", {Position = UDim2.fromOffset(94, 0), Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1, Text = "+", TextColor3 = COLORS.accent, Font = Enum.Font.GothamMedium, TextSize = 18}, holder)
    return minus, box, plus
end

local function makeToggle(parent)
    local button = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 7),
        Size = UDim2.fromOffset(48, 26), BackgroundColor3 = COLORS.border,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false,
    }, parent)
    corner(button, 13)
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0),
        Size = UDim2.fromOffset(18, 18), BackgroundColor3 = COLORS.muted, BorderSizePixel = 0,
    }, button)
    corner(knob, 9)
    local enabled = false
    local function set(value)
        enabled = value
        tween(button, {BackgroundColor3 = enabled and COLORS.accentDark or COLORS.border})
        tween(knob, {Position = enabled and UDim2.new(1, -22, 0.5, 0) or UDim2.new(0, 4, 0.5, 0), BackgroundColor3 = enabled and COLORS.accent or COLORS.muted})
    end
    return button, set, function() return enabled end
end

-- ---- Movement Page ----
local speedCard = makeCard(movementPage, "Walk speed", "Set character movement speed")
local decrease, valueBox, increase = makeStepper(speedCard, tostring(SPEED))

local flyCard = makeCard(movementPage, "Flight (BodyVelocity)", "Camera-relative free movement (mobile-friendly)")
local flyButton, setFlyToggle, getFlyToggle = makeToggle(flyCard)

local noclipCard = makeCard(movementPage, "Noclip", "Disable character collisions; may also pass through floors", 94)
local noclipButton, setNoclipToggle, getNoclipToggle = makeToggle(noclipCard)
local noclipConnection
local originalCollisions = {}
local noclipCharacter

local function restoreCollisions()
    for part, canCollide in pairs(originalCollisions) do
        if part.Parent then part.CanCollide = canCollide end
    end
    table.clear(originalCollisions)
end

local function stopNoclip()
    if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end
    restoreCollisions()
    noclipCharacter = nil
    if scriptAlive then setNoclipToggle(false) end
end

bind(noclipButton.Activated, function()
    if getNoclipToggle() then stopNoclip(); return end
    setNoclipToggle(true)
    noclipConnection = bind(RunService.Stepped, function()
        if not scriptAlive then stopNoclip(); return end
        local character = player.Character
        if character ~= noclipCharacter then
            restoreCollisions()
            noclipCharacter = character
        end
        if not character then return end
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if originalCollisions[part] == nil then originalCollisions[part] = part.CanCollide end
                part.CanCollide = false
            end
        end
    end)
end)
table.insert(cleanupCallbacks, stopNoclip)

-- ---- Combat Page ----
local autoCard = makeCard(combatPage, "Auto punch", "Attacks nearest enemy when unblocked")
local toggleAuto, setAutoToggle, getAutoToggle = makeToggle(autoCard)

local attackStatus = create("TextLabel", {
    Name = "AttackStatus", Size = UDim2.new(1, -4, 0, 44),
    BackgroundTransparency = 1, Text = "Auto punch: OFF",
    TextColor3 = COLORS.muted, Font = Enum.Font.Gotham, TextSize = 11,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
}, combatPage)

local bindPunchButton = create("TextButton", {
    Name = "BindPunch", Size = UDim2.new(1, -4, 0, 44),
    BackgroundColor3 = COLORS.surface, BorderSizePixel = 0,
    Text = "Select attack button", TextColor3 = COLORS.text,
    Font = Enum.Font.GothamMedium, TextSize = 12, AutoButtonColor = false,
}, combatPage)
corner(bindPunchButton, 9)

local testTouchButton = create("TextButton", {
    Name = "TestTouch", Size = UDim2.new(1, -4, 0, 44),
    BackgroundColor3 = COLORS.surface, BorderSizePixel = 0,
    Text = "Test one touch", TextColor3 = COLORS.text,
    Font = Enum.Font.GothamMedium, TextSize = 12, AutoButtonColor = false,
}, combatPage)
corner(testTouchButton, 9)

local delayCard = makeCard(combatPage, "Punch delay (ms)", "Delay between attack series")
local delayMinus, delayBox, delayPlus = makeStepper(delayCard, tostring(PUNCH_DELAY))

local multiCard = makeCard(combatPage, "Multi-punch count", "Number of punches per activation (1-10)", 94)
local multiMinus, multiBox, multiPlus = makeStepper(multiCard, tostring(MULTI_PUNCH))

local blockCard = makeCard(combatPage, "Punch while blocking", "Allow punching even when you are blocking")
local blockToggle, setBlockToggle, getBlockToggle = makeToggle(blockCard)

local rangeCard = makeCard(combatPage, "Aura range (studs)", "Auto punch activation distance", 94)
local rangeMinus, rangeBox, rangePlus = makeStepper(rangeCard, tostring(AURA_RANGE))
local targetBlockCard = makeCard(combatPage, "Skip blocking enemies", "ON: wait until enemy drops block; OFF: any target", 94)
local targetBlockToggle, setTargetBlockToggle, getTargetBlockToggle = makeToggle(targetBlockCard)

-- ---- ESP Page ----
local espCard = makeCard(espPage, "ESP Enabled", "Show player highlights and nametags")
local espToggle, setEspToggle, getEspToggle = makeToggle(espCard)

local nameCard = makeCard(espPage, "Show Names", "Display player names above heads")
local nameToggle, setNameToggle, getNameToggle = makeToggle(nameCard)

local colorCard = makeCard(espPage, "Color Picker", "Select highlight color", 140)
-- Палитра цветов
local paletteHolder = create("Frame", {
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 30),
    Size = UDim2.fromOffset(160, 60), BackgroundTransparency = 1,
}, colorCard)
local paletteGrid = create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, paletteHolder)

local colorButtons = {}
local refreshESP
for i, color in ipairs(ESP_COLORS) do
    local btn = create("TextButton", {
        Size = UDim2.fromOffset(28, 28), BackgroundColor3 = color,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false,
    }, paletteHolder)
    corner(btn, 6)
    stroke(btn, COLORS.border, 0.3)
    bind(btn.Activated, function()
        ESP_COLOR = color
        -- обновить все ESP
        refreshESP()
    end)
    colorButtons[#colorButtons+1] = btn
end

local alphaCard = makeCard(espPage, "Alpha (transparency)", "Fill transparency (0-1)", 74)
local alphaMinus, alphaBox, alphaPlus = makeStepper(alphaCard, string.format("%.2f", ESP_ALPHA))

-- ---- Восстановление окна ----
local restoreButton = create("TextButton", {
    Name = "Restore", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18),
    Size = UDim2.fromOffset(52, 52), BackgroundColor3 = COLORS.window, BorderSizePixel = 0,
    Text = "N", TextColor3 = COLORS.accent, Font = Enum.Font.GothamBold, TextSize = 18,
    AutoButtonColor = false, Visible = false,
}, gui)
corner(restoreButton, 16)
stroke(restoreButton, COLORS.accent, 0.35)

local panelShown = true
local function setPanelShown(shown)
    if panelShown == shown then return end
    panelShown = shown
    if shown then
        panel.Visible = true
        panel.Size = UDim2.fromOffset(560, 400)
        panel.BackgroundTransparency = 1
        tween(panel, {Size = UDim2.fromOffset(600, 420), BackgroundTransparency = 0}, 0.28)
        tween(dim, {BackgroundTransparency = UserInputService.TouchEnabled and 0.65 or 1}, 0.25)
        restoreButton.Visible = false
    else
        local animation = tween(panel, {Size = UDim2.fromOffset(560, 400), BackgroundTransparency = 1}, 0.2)
        tween(dim, {BackgroundTransparency = 1}, 0.2)
        animation.Completed:Once(function()
            if not panelShown then panel.Visible = false; restoreButton.Visible = true end
        end)
    end
end

bind(hideButton.Activated, function() setPanelShown(false) end)
bind(restoreButton.Activated, function() setPanelShown(true) end)
bind(hideButton.MouseEnter, function() tween(hideButton, {BackgroundColor3 = COLORS.surfaceHover, TextColor3 = COLORS.text}, 0.12) end)
bind(hideButton.MouseLeave, function() tween(hideButton, {BackgroundColor3 = COLORS.surface, TextColor3 = COLORS.muted}, 0.12) end)

bind(UserInputService.InputBegan, function(input, gameProcessed)
    if gameProcessed or not desktopInput then return end
    if input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.Insert then
        setPanelShown(not panelShown)
    end
end)

-- ---- Перетаскивание ----
local dragging, dragStart, startPosition, dragInput
bind(header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging, dragStart, startPosition = true, input.Position, panel.Position
        bind(input.Changed, function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
bind(header.InputChanged, function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)
bind(UserInputService.InputChanged, function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
    end
end)

-- ---- Масштабирование ----
local function updateScale()
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
    scale.Scale = math.clamp(math.min((viewport.X - 24) / 600, (viewport.Y - 120) / 420), 0.48, 1)
    if UserInputService.TouchEnabled then
        -- Держим окно выше системного джойстика и кнопки прыжка.
        panel.AnchorPoint = Vector2.new(0.5, 0)
        panel.Position = UDim2.new(0.5, 0, 0, 8)
    end
end
updateScale()
if workspace.CurrentCamera then bind(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), updateScale) end

-- ---- Логика Movement ----
local function getHumanoid()
    local character = player.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function setSpeed(value, applyNow)
    local number = tonumber(value)
    if number then SPEED = math.clamp(math.floor(number), 0, 500) end
    valueBox.Text = tostring(SPEED)
    if applyNow then
        local humanoid = getHumanoid()
        if humanoid then humanoid.WalkSpeed = SPEED end
    end
end

bind(decrease.Activated, function() setSpeed(SPEED - STEP, true) end)
bind(increase.Activated, function() setSpeed(SPEED + STEP, true) end)
bind(valueBox.FocusLost, function() setSpeed(valueBox.Text, true) end)

local movementStatusCard = makeCard(movementPage, "Movement state", "Read-only diagnostics after respawn / ring entry", 94)
local movementStatus = create("TextLabel", {
    Position = UDim2.fromOffset(15, 56), Size = UDim2.new(1, -30, 0, 28),
    BackgroundTransparency = 1, Text = "", TextColor3 = COLORS.muted,
    TextSize = 10, Font = Enum.Font.Gotham, TextWrapped = true,
}, movementStatusCard)
task.spawn(function()
    while scriptAlive do
        local h = getHumanoid()
        local root = h and h.Parent:FindFirstChild("HumanoidRootPart")
        movementStatus.Text = h and string.format("Speed %g | Platform %s | Sit %s | Anchored %s | Move %.2f",
            h.WalkSpeed, tostring(h.PlatformStand), tostring(h.Sit), tostring(root and root.Anchored), h.MoveDirection.Magnitude)
            or "Waiting for character"
        task.wait(0.5)
    end
end)

local restoreMoveCard = makeCard(movementPage, "Restore movement", "Stops Nexus movers and re-enables Roblox controls", 94)
local restoreMoveButton = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 7),
    Size = UDim2.fromOffset(128, 34), BackgroundColor3 = COLORS.window,
    BorderSizePixel = 0, Text = "RESTORE", TextColor3 = COLORS.accent,
    Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false,
}, restoreMoveCard)
corner(restoreMoveButton, 8)
stroke(restoreMoveButton, COLORS.border, 0.25)

-- ---- Flight (BodyVelocity) ----
local flying = false
local flyBodyVelocity, flyBodyGyro, flyConnection
local flightHumanoid

local function removeNexusMovers(character)
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local removed = false
    for _, child in ipairs(root:GetChildren()) do
        if child.Name == "NexusFlyVelocity" or child.Name == "NexusFlyGyro" then
            child:Destroy()
            removed = true
        end
    end
    return removed
end

local function stopFly()
    local wasFlying = flying
    flying = false
    if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
    if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity = nil end
    if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro = nil end
    local character = player.Character
    local removedMover = removeNexusMovers(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local shouldRestore = wasFlying or removedMover or humanoid == flightHumanoid
    if shouldRestore and humanoid and humanoid.Health > 0 then
        -- Старые версии Fly могли оставить PlatformStand включённым, поэтому
        -- при явном выключении выводим Humanoid из физического состояния полёта.
        humanoid.PlatformStand = false
        humanoid.Sit = false
        humanoid.AutoRotate = true
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        task.defer(function()
            if scriptAlive and player.Character == character and humanoid.Parent and humanoid.Health > 0 then
                humanoid:ChangeState(Enum.HumanoidStateType.Running)
                local controls = getCurrentControls()
                if controls then pcall(function() controls:Enable() end) end
            end
        end)
    end
    flightHumanoid = nil
    if scriptAlive then setFlyToggle(false) end
end

table.insert(cleanupCallbacks, stopFly)

local function startFly()
    local character = player.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    removeNexusMovers(character)
    flightHumanoid = hum
    -- Не переводим Humanoid в PlatformStand: именно это состояние оставляло
    -- персонажа без обычной ходьбы после выключения Fly.

    flyBodyVelocity = Instance.new("BodyVelocity")
    flyBodyVelocity.Name = "NexusFlyVelocity"
    flyBodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    flyBodyVelocity.Parent = root

    flyBodyGyro = Instance.new("BodyGyro")
    flyBodyGyro.Name = "NexusFlyGyro"
    flyBodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    flyBodyGyro.Parent = root

    flying = true
    setFlyToggle(true)

    flyConnection = bind(RunService.Heartbeat, function(deltaTime)
        if not flying then return end
        if not scriptAlive or player.Character ~= character or not root.Parent
            or character:FindFirstChild("HumanoidRootPart") ~= root or hum.Health <= 0
            or root.Anchored then stopFly(); return end
        local camera = workspace.CurrentCamera
        if not camera then return end

        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.yAxis end

        -- На телефоне GetMoveVector читает именно левый джойстик.
        if UserInputService.TouchEnabled then
            -- MoveDirection работает с большинством мобильных контроллеров;
            -- PlayerModule используется как запасной вариант.
            local stick = hum.MoveDirection
            local stickIsWorldSpace = stick.Magnitude > 0
            local controls = getCurrentControls()
            if not stickIsWorldSpace and controls then
                stick = controls:GetMoveVector()
            end
            local flatLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
            local flatRight = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
            if flatLook.Magnitude > 0 then flatLook = flatLook.Unit end
            if flatRight.Magnitude > 0 then flatRight = flatRight.Unit end
            if stickIsWorldSpace then
                move = move + stick
            else
                move = move + flatRight * stick.X - flatLook * stick.Z
            end
        end

        if move.Magnitude > 0 then
            move = move.Unit * SPEED
            flyBodyVelocity.Velocity = move
            -- Поворот в сторону движения
            flyBodyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + move)
        else
            flyBodyVelocity.Velocity = Vector3.zero
        end
    end)
end

bind(flyButton.Activated, function()
    if getFlyToggle() then stopFly() else startFly() end
end)

bind(player.CharacterRemoving, function()
    stopFly()
    stopNoclip()
end)

bind(player.CharacterAdded, function(character)
    -- Do not write WalkSpeed, PlatformStand or control state here. Boxing Beta
    -- owns those values while it moves a player into/out of the ring.
    stopNoclip()
    removeNexusMovers(character)
    if scriptAlive then setFlyToggle(false) end
end)

bind(restoreMoveButton.Activated, function()
    stopFly()
    stopNoclip()
    local controls = getCurrentControls()
    if controls then pcall(function() controls:Enable() end) end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root then
        for _, name in ipairs({"NexusFlyVelocity", "NexusFlyGyro"}) do
            local mover = root:FindFirstChild(name)
            if mover then mover:Destroy() end
        end
    end
    if humanoid and humanoid.Health > 0 then
        humanoid.PlatformStand = false
        humanoid.Sit = false
        humanoid.AutoRotate = true
        humanoid.WalkSpeed = SPEED
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end
end)

-- ---- Логика Combat (Auto-Punch with Multi) ----
local isAutoOn = false
local lastPunchTime = 0
local selectedPunchButton
local selectedTouchOffset
local selectedButtonPath
local selectedButtonClass

local function buttonVisibilityIssue(object)
    if not object or not object:IsDescendantOf(player.PlayerGui) then return "Selected button was removed" end
    local ancestor = object
    while ancestor and ancestor ~= player.PlayerGui do
        if ancestor:IsA("GuiObject") and not ancestor.Visible then
            return "Hidden: " .. ancestor:GetFullName()
        end
        if ancestor:IsA("ScreenGui") and not ancestor.Enabled then
            return "Disabled: " .. ancestor:GetFullName()
        end
        ancestor = ancestor.Parent
    end
    return nil
end

local function resolveSelectedButton()
    local issue = buttonVisibilityIssue(selectedPunchButton)
    if not issue then return selectedPunchButton end
    -- Rebind only an unambiguous visible replacement at the selected path.
    local replacement
    if selectedButtonPath then
        for _, candidate in ipairs(player.PlayerGui:GetDescendants()) do
            if candidate.ClassName == selectedButtonClass and candidate:GetFullName() == selectedButtonPath
                and not buttonVisibilityIssue(candidate) then
                if replacement then return nil, "Multiple replacements; select attack button again" end
                replacement = candidate
            end
        end
    end
    if replacement then selectedPunchButton = replacement; return replacement end
    return nil, issue
end
local touchBusy = false
local touchFailure
local touchTesting = false
local syntheticTouchId = 912837
local selectingPunch = false
local selectionConnections = {}
local selectionGeneration = 0

local function stopSelectingPunch()
    selectingPunch = false
    selectionGeneration = selectionGeneration + 1
    for _, connection in ipairs(selectionConnections) do connection:Disconnect() end
    table.clear(selectionConnections)
end
table.insert(cleanupCallbacks, stopSelectingPunch)

bind(bindPunchButton.Activated, function()
    stopSelectingPunch()
    selectingPunch = true
    local generation = selectionGeneration
    attackStatus.Text = "Tap the actual punch button once; then reopen N"
    attackStatus.TextColor3 = COLORS.muted
    local function observe(object)
        if not object:IsA("GuiButton") then return end
        table.insert(selectionConnections, bind(object.InputBegan, function(input)
            if not selectingPunch or not scriptAlive then return end
            if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            if buttonVisibilityIssue(object) then return end
            selectedPunchButton = object
            selectedButtonPath = object:GetFullName()
            selectedButtonClass = object.ClassName
            selectedTouchOffset = input and Vector2.new(input.Position.X, input.Position.Y) - object.AbsolutePosition or nil
            touchFailure = nil
            stopSelectingPunch()
            bindPunchButton.Text = "Selected: " .. object.Name
            attackStatus.Text = "Bound: " .. object:GetFullName()
            attackStatus.TextColor3 = COLORS.muted
        end))
    end
    for _, object in ipairs(player.PlayerGui:GetDescendants()) do observe(object) end
    table.insert(selectionConnections, bind(player.PlayerGui.DescendantAdded, observe))
    setPanelShown(false)
    task.delay(20, function()
        if selectingPunch and generation == selectionGeneration and scriptAlive then
            stopSelectingPunch()
            attackStatus.Text = "No button selected. Equip fists and try Select attack button again."
            attackStatus.TextColor3 = COLORS.danger
        end
    end)
end)

local discoveredPunchButton
local nextPunchButtonScan = 0
local function findPunchButton()
    if selectedPunchButton and selectedPunchButton:IsDescendantOf(player.PlayerGui) then
        return selectedPunchButton
    end
    selectedPunchButton = nil
    if not player.PlayerGui then return nil end
    if discoveredPunchButton and not buttonVisibilityIssue(discoveredPunchButton) then
        return discoveredPunchButton
    end
    discoveredPunchButton = nil
    if time() < nextPunchButtonScan then return nil end
    nextPunchButtonScan = time() + 2
    for _, child in ipairs(player.PlayerGui:GetDescendants()) do
        if child:IsA("GuiButton") and not buttonVisibilityIssue(child) then
            local name = child.Name:lower()
            if name:find("punch") or name:find("attack") or name:find("hit") or name:find("fight") then
                discoveredPunchButton = child
                return child
            end
        end
    end
    return nil
end

local function findBlockButton()
    if not player.PlayerGui then return nil end
    for _, child in ipairs(player.PlayerGui:GetDescendants()) do
        if child:IsA("GuiButton") then
            local name = child.Name:lower()
            if name:find("block") or name:find("guard") or name:find("defend") then
                return child
            end
        end
    end
    return nil
end

local function sendMouseClick(point)
    local pressed, pressError = pcall(function()
        local inputSender = getVirtualInput()
        if inputSender then
            inputSender:SendMouseButton(point, Enum.UserInputType.MouseButton1, true, 0)
        else
            VirtualInputManager:SendMouseButtonEvent(point.X, point.Y, 0, true, game, 0)
        end
    end)
    local released, releaseError = pcall(function()
        local inputSender = getVirtualInput()
        if inputSender then
            inputSender:SendMouseButton(point, Enum.UserInputType.MouseButton1, false, 0)
        else
            VirtualInputManager:SendMouseButtonEvent(point.X, point.Y, 0, false, game, 0)
        end
    end)
    if not pressed or not released then return false, tostring(not pressed and pressError or releaseError) end
    return true, true
end

local function activateGuiButton(button)
    local issue = buttonVisibilityIssue(button)
    if issue then return false, issue end
    local center = button.AbsolutePosition + button.AbsoluteSize / 2

    -- На ПК нужен настоящий mouse input: firesignal может завершиться без ошибки,
    -- но игра не обязана слушать GuiButton.Activated.
    if desktopInput then
        local ok, result = sendMouseClick(center)
        return ok and result, ok and nil or result
    end

    if type(firesignal) == "function" then
        local ok, message = pcall(function() firesignal(button.Activated) end)
        if ok then return true end
        return false, "Activated failed: " .. tostring(message)
    end
    return false, "No supported attack input on this device (firesignal unavailable)"
end

local function sendSelectedTouch()
    if touchBusy then return false, "Touch already in progress" end
    if not selectedTouchOffset then return false, "Select using a real screen tap first" end
    if panel.Visible then return false, "Hide Nexus with X before touch attacks" end
    local object, issue = resolveSelectedButton()
    if not object then return false, issue end
    local point = object.AbsolutePosition + selectedTouchOffset
    touchBusy = true
    local pressed, pressError = pcall(function()
        VirtualInputManager:SendTouchEvent(syntheticTouchId, Enum.UserInputState.Begin.Value, point.X, point.Y)
    end)
    if pressed then RunService.Heartbeat:Wait() end
    -- Always attempt release, even if the menu was destroyed while waiting.
    local released, releaseError = pcall(function()
        VirtualInputManager:SendTouchEvent(syntheticTouchId, Enum.UserInputState.End.Value, point.X, point.Y)
    end)
    touchBusy = false
    if not pressed or not released then
        touchFailure = "Touch API rejected: " .. tostring(not pressed and pressError or releaseError)
        return false, touchFailure
    end
    return true
end

bind(testTouchButton.Activated, function()
    if touchTesting then return end
    if isAutoOn then
        attackStatus.Text = "Turn Auto punch OFF before the single-touch test"
        return
    end
    if not selectedPunchButton then attackStatus.Text = "Select attack button first"; return end
    touchTesting = true
    touchFailure = nil
    setPanelShown(false)
    task.delay(0.4, function()
        if not scriptAlive then touchTesting = false; return end
        local ok, sent, message = pcall(sendSelectedTouch)
        touchTesting = false
        if not scriptAlive then return end
        attackStatus.Text = ok and sent and "Touch sent. Confirm whether an actual punch happened."
            or tostring(ok and message or sent)
        attackStatus.TextColor3 = ok and sent and COLORS.muted or COLORS.danger
    end)
end)

local attackInputRoute = "unknown"
local function punch()
    if UserInputService.TouchEnabled and selectedButtonPath then
        attackInputRoute = "Touch: " .. selectedButtonPath
        return sendSelectedTouch()
    end
    if selectedPunchButton then
        if not selectedPunchButton:IsDescendantOf(player.PlayerGui) then
            selectedPunchButton = nil
            return false, "Selected button was recreated; select the punch button again"
        end
        attackInputRoute = "Selected GUI: " .. selectedPunchButton.Name
        if UserInputService.TouchEnabled then
            attackInputRoute = "Touch: " .. selectedPunchButton.Name
            return sendSelectedTouch()
        end
        return activateGuiButton(selectedPunchButton)
    end
    -- Tool activation does not inject mouse input or change the touch controller.
    -- Equip the fighting tool before enabling Auto punch.
    local button = findPunchButton()
    if button and button:IsA("GuiButton") then
        attackInputRoute = "GUI: " .. button.Name
        return activateGuiButton(button)
    end

    local character = player.Character
    local equippedTool = character and character:FindFirstChildOfClass("Tool")
    if equippedTool then
        attackInputRoute = "Tool: " .. equippedTool.Name
        local ok, message = pcall(function()
            equippedTool:Activate()
            equippedTool:Deactivate()
        end)
        if not ok then return false, attackInputRoute .. ": " .. tostring(message) end
        return true
    end

    if desktopInput then
        local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
        attackInputRoute = "Desktop center click"
        local ok, result = sendMouseClick(viewport / 2)
        return ok and result, ok and nil or result
    end
    return false, "No equipped Tool or named attack button. Equip fists first."
end

local autoGeneration = 0
local function performMultiPunch(generation)
    local burstCharacter = player.Character
    local function cancelled()
        return not scriptAlive or not isAutoOn or generation ~= autoGeneration
            or player.Character ~= burstCharacter or panel.Visible
    end
    -- Меню уже закрывается пользователем один раз; не меняем его Visible в боевом цикле.
    for _ = 1, MULTI_PUNCH do
        if cancelled() then return false, "Attack cancelled" end
        local sent, reason = punch()
        if not sent then return false, reason end
    end

    -- Между отдельными вызовами серии нет дополнительного task.wait.
    -- Частота новых серий ограничивается отдельно в autoPunchLoop.

    return true
end

local function isBlocking(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    if humanoid.WalkSpeed <= BLOCK_SPEED_THRESHOLD then return true end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            local animation = track.Animation
            if animation and animation.Name:lower():find("block") then return true end
        end
    end
    return false
end

local function getNearestEnemy()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local nearest, distance = nil, math.huge
    for _, other in ipairs(Players:GetPlayers()) do
        if other == player then continue end
        local otherCharacter = other.Character
        local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")
        local otherHumanoid = otherCharacter and otherCharacter:FindFirstChildOfClass("Humanoid")
        if otherRoot and otherHumanoid and otherHumanoid.Health > 0 then
            local currentDistance = (root.Position - otherRoot.Position).Magnitude
            if currentDistance <= AURA_RANGE and currentDistance < distance
                and (not SKIP_BLOCKING_TARGETS or not isBlocking(otherCharacter)) then
                nearest, distance = otherCharacter, currentDistance
            end
        end
    end
    return nearest
end

local function autoPunchLoop(generation)
    while scriptAlive and isAutoOn and generation == autoGeneration do
        if selectingPunch or touchTesting then RunService.Heartbeat:Wait(); continue end
        if panel.Visible then
            attackStatus.Text = "Close Nexus with X to start Auto Punch"
            attackStatus.TextColor3 = COLORS.muted
            task.wait(0.1)
            continue
        end
        local enemy = getNearestEnemy()
        local now = tick() * 1000
        if enemy then
            local enemyBlocking = isBlocking(enemy)
            local selfBlocking = isBlocking(player.Character)
            local canPunch = (PUNCH_WHILE_BLOCKING or not selfBlocking)
                and (not SKIP_BLOCKING_TARGETS or not enemyBlocking)
            local seriesInterval = math.max(PUNCH_DELAY, MIN_SERIES_INTERVAL)
            if canPunch and now - lastPunchTime >= seriesInterval then
                local ok, sent, reason = pcall(performMultiPunch, generation)
                if not ok or not sent then
                    local detail = not ok and tostring(sent) or tostring(reason or "Unknown attack input error")
                    attackStatus.Text = "PAUSED: " .. detail
                    attackStatus.TextColor3 = COLORS.danger
                    -- Keep the user's selection, but show that attacks are unavailable.
                    -- Retry slowly rather than flooding errors every frame.
                    task.wait(1)
                    if not scriptAlive or generation ~= autoGeneration then break end
                else
                    attackStatus.Text = string.format("%s | %d calls | limiter %dms", attackInputRoute, MULTI_PUNCH, seriesInterval)
                    attackStatus.TextColor3 = COLORS.muted
                end
                lastPunchTime = tick() * 1000
            elseif not canPunch then
                attackStatus.Text = "Waiting: block filter"
                attackStatus.TextColor3 = COLORS.muted
            end
        else
            attackStatus.Text = "Waiting: no eligible target in range"
            attackStatus.TextColor3 = COLORS.muted
        end
        -- Проверка цели не обязана выполняться все 60+ кадров в секунду.
        task.wait(0.1)
    end
end

local lastAutoTap = -math.huge
bind(toggleAuto.Activated, function()
    -- Ignore duplicate activation events from one rapid touch.
    local now = os.clock()
    if now - lastAutoTap < 0.3 then return end
    lastAutoTap = now
    autoGeneration = autoGeneration + 1
    isAutoOn = not isAutoOn
    setAutoToggle(isAutoOn)
    attackStatus.Text = isAutoOn and "Checking attack input..." or "Auto punch: OFF"
    attackStatus.TextColor3 = COLORS.muted
    if isAutoOn then
        touchFailure = nil
        lastPunchTime = 0
        local generation = autoGeneration
        task.spawn(function()
            local ok, message = pcall(autoPunchLoop, generation)
            if not ok and scriptAlive and isAutoOn and generation == autoGeneration then
                attackStatus.Text = "ERROR v3.7: " .. tostring(message)
                attackStatus.TextColor3 = COLORS.danger
                warn("[Nexus v3.7] " .. tostring(message))
            end
        end)
    end
end)

local function setDelay(value)
    local number = tonumber(value)
    if number then PUNCH_DELAY = math.clamp(math.floor(number), 0, 10000) end
    delayBox.Text = tostring(PUNCH_DELAY)
end
bind(delayMinus.Activated, function() setDelay(PUNCH_DELAY - 50) end)
bind(delayPlus.Activated, function() setDelay(PUNCH_DELAY + 50) end)
bind(delayBox.FocusLost, function() setDelay(delayBox.Text) end)

local function setMulti(value)
    local number = tonumber(value)
    if number then MULTI_PUNCH = math.clamp(math.floor(number), 1, 10) end
    multiBox.Text = tostring(MULTI_PUNCH)
end
bind(multiMinus.Activated, function() setMulti(MULTI_PUNCH - 1) end)
bind(multiPlus.Activated, function() setMulti(MULTI_PUNCH + 1) end)
bind(multiBox.FocusLost, function() setMulti(multiBox.Text) end)

local function setAuraRange(value)
    local number = tonumber(value)
    if number and number == number and math.abs(number) < math.huge then
        AURA_RANGE = math.clamp(math.floor(number), 1, 100)
    end
    rangeBox.Text = tostring(AURA_RANGE)
end
bind(rangeMinus.Activated, function() setAuraRange(AURA_RANGE - 1) end)
bind(rangePlus.Activated, function() setAuraRange(AURA_RANGE + 1) end)
bind(rangeBox.FocusLost, function() setAuraRange(rangeBox.Text) end)
bind(targetBlockToggle.Activated, function()
    SKIP_BLOCKING_TARGETS = not getTargetBlockToggle()
    setTargetBlockToggle(SKIP_BLOCKING_TARGETS)
end)

bind(blockToggle.Activated, function()
    PUNCH_WHILE_BLOCKING = not getBlockToggle()
    setBlockToggle(PUNCH_WHILE_BLOCKING)
end)

-- ---- Логика ESP ----
local highlightObjects = {}
local nameTags = {}
local createESPForPlayer

refreshESP = function()
    -- Удаляем всё
    for plr, hl in pairs(highlightObjects) do hl:Destroy() end
    highlightObjects = {}
    for plr, tag in pairs(nameTags) do tag:Destroy() end
    nameTags = {}
    -- Заново создаём
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            createESPForPlayer(plr)
        end
    end
end

createESPForPlayer = function(plr)
    if plr == player then return end
    local char = plr.Character
    if not scriptAlive or not char or not ESP_ENABLED then return end
    if highlightObjects[plr] then highlightObjects[plr]:Destroy(); highlightObjects[plr] = nil end
    if nameTags[plr] then nameTags[plr]:Destroy(); nameTags[plr] = nil end

    -- Highlight
    local hl = Instance.new("Highlight")
    hl.Adornee = char
    hl.FillColor = ESP_COLOR
    hl.FillTransparency = ESP_ALPHA
    hl.OutlineColor = Color3.new(1, 1, 1)
    hl.OutlineTransparency = 0.2
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char
    highlightObjects[plr] = hl

    -- Nametag
    if SHOW_NAMES then
        local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        if head then
            local bill = Instance.new("BillboardGui")
            bill.Adornee = head
            bill.Size = UDim2.fromOffset(120, 30)
            bill.StudsOffset = Vector3.new(0, 2.5, 0)
            bill.AlwaysOnTop = true
            bill.Parent = char
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Text = plr.Name
            label.TextColor3 = Color3.new(1, 1, 1)
            label.Font = Enum.Font.GothamBold
            label.TextSize = 18
            label.TextStrokeColor3 = Color3.new(0, 0, 0)
            label.TextStrokeTransparency = 0.3
            label.Parent = bill
            nameTags[plr] = bill
        end
    end
end

local function removeESPForPlayer(plr)
    if highlightObjects[plr] then highlightObjects[plr]:Destroy(); highlightObjects[plr] = nil end
    if nameTags[plr] then nameTags[plr]:Destroy(); nameTags[plr] = nil end
end

table.insert(cleanupCallbacks, function()
    for _, hl in pairs(highlightObjects) do hl:Destroy() end
    for _, tag in pairs(nameTags) do tag:Destroy() end
    table.clear(highlightObjects)
    table.clear(nameTags)
end)
-- Обработчики для ESP
bind(Players.PlayerAdded, function(plr)
    bind(plr.CharacterAdded, function()
        task.wait(0.2)
        createESPForPlayer(plr)
    end)
    if plr.Character then
        task.wait(0.2)
        createESPForPlayer(plr)
    end
end)

bind(Players.PlayerRemoving, function(plr)
    removeESPForPlayer(plr)
end)

bind(espToggle.Activated, function()
    ESP_ENABLED = not getEspToggle()
    setEspToggle(ESP_ENABLED)
    if ESP_ENABLED then refreshESP() else
        for plr, hl in pairs(highlightObjects) do hl:Destroy() end
        highlightObjects = {}
        for plr, tag in pairs(nameTags) do tag:Destroy() end
        nameTags = {}
    end
end)

bind(nameToggle.Activated, function()
    SHOW_NAMES = not getNameToggle()
    setNameToggle(SHOW_NAMES)
    refreshESP()
end)

bind(alphaMinus.Activated, function()
    ESP_ALPHA = math.max(0, math.floor((ESP_ALPHA - 0.05) * 100) / 100)
    alphaBox.Text = string.format("%.2f", ESP_ALPHA)
    for plr, hl in pairs(highlightObjects) do hl.FillTransparency = ESP_ALPHA end
end)
bind(alphaPlus.Activated, function()
    ESP_ALPHA = math.min(1, math.floor((ESP_ALPHA + 0.05) * 100) / 100)
    alphaBox.Text = string.format("%.2f", ESP_ALPHA)
    for plr, hl in pairs(highlightObjects) do hl.FillTransparency = ESP_ALPHA end
end)
bind(alphaBox.FocusLost, function()
    local val = tonumber(alphaBox.Text)
    if val then ESP_ALPHA = math.clamp(val, 0, 1) end
    alphaBox.Text = string.format("%.2f", ESP_ALPHA)
    for plr, hl in pairs(highlightObjects) do hl.FillTransparency = ESP_ALPHA end
end)

-- Инициализация ESP для существующих игроков
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= player then
        bind(plr.CharacterAdded, function() task.wait(0.2); createESPForPlayer(plr) end)
        task.wait(0.1)
        createESPForPlayer(plr)
    end
end

-- ---- Инициализация ----
setSpeed(SPEED, false)
setBlockToggle(PUNCH_WHILE_BLOCKING)
setTargetBlockToggle(SKIP_BLOCKING_TARGETS)
setEspToggle(ESP_ENABLED)
setNameToggle(SHOW_NAMES)
alphaBox.Text = string.format("%.2f", ESP_ALPHA)

panel.Size = UDim2.fromOffset(560, 400)
panel.BackgroundTransparency = 1
tween(panel, {Size = UDim2.fromOffset(600, 420), BackgroundTransparency = 0}, 0.35)
if UserInputService.TouchEnabled then tween(dim, {BackgroundTransparency = 0.65}, 0.3) end

print("[Nexus v3.7] Movement isolation loaded")
