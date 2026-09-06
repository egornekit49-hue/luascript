-- Modern responsive Speed / Fly / Auto-Punch UI
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local SPEED = 50
local STEP = 4
local PUNCH_DELAY = 500
local BLOCK_SPEED_THRESHOLD = 0.5

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

local oldGui = game:GetService("CoreGui"):FindFirstChild("SuperGuiModern")
if oldGui then oldGui:Destroy() end

local gui = create("ScreenGui", {
    Name = "SuperGuiModern",
    ResetOnSpawn = false,
    IgnoreGuiInset = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, game:GetService("CoreGui"))

local dim = create("Frame", {
    Name = "Dim",
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
}, gui)

local panel = create("Frame", {
    Name = "Window",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(540, 350),
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
    BackgroundTransparency = 1, Text = "utility panel", TextColor3 = COLORS.muted,
    Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
}, sidebar)

local navHolder = create("Frame", {
    Position = UDim2.fromOffset(10, 92), Size = UDim2.new(1, -20, 0, 104),
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
    button.Activated:Connect(function()
        if selectedPage == name then return end
        selectedPage = name
        pageTitle.Text = name
        pageSubtitle.Text = name == "Movement" and "Movement and flight settings" or "Automatic combat settings"
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

create("TextLabel", {
    AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -17),
    Size = UDim2.new(1, -36, 0, 30), BackgroundTransparency = 1,
    Text = "WASD  •  Space / Shift", TextColor3 = COLORS.muted,
    Font = Enum.Font.Gotham, TextSize = 9, TextWrapped = true,
}, sidebar)

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

local speedCard = makeCard(movementPage, "Walk speed", "Set character movement speed")
local decrease, valueBox, increase = makeStepper(speedCard, tostring(SPEED))
local flyCard = makeCard(movementPage, "Flight", "Camera-relative free movement")
local flyButton, setFlyToggle, getFlyToggle = makeToggle(flyCard)
local autoCard = makeCard(combatPage, "Auto punch", "Attacks nearest enemy when unblocked")
local toggleAuto, setAutoToggle, getAutoToggle = makeToggle(autoCard)
local delayCard = makeCard(combatPage, "Punch delay", "Delay between attacks in milliseconds")
local delayMinus, delayBox, delayPlus = makeStepper(delayCard, tostring(PUNCH_DELAY))

local restoreButton = create("TextButton", {
    Name = "Restore", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -18),
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
        panel.Size = UDim2.fromOffset(500, 320)
        panel.BackgroundTransparency = 1
        tween(panel, {Size = UDim2.fromOffset(540, 350), BackgroundTransparency = 0}, 0.28)
        tween(dim, {BackgroundTransparency = UserInputService.TouchEnabled and 0.65 or 1}, 0.25)
        restoreButton.Visible = false
    else
        local animation = tween(panel, {Size = UDim2.fromOffset(500, 320), BackgroundTransparency = 1}, 0.2)
        tween(dim, {BackgroundTransparency = 1}, 0.2)
        animation.Completed:Once(function()
            if not panelShown then panel.Visible = false; restoreButton.Visible = true end
        end)
    end
end

hideButton.Activated:Connect(function() setPanelShown(false) end)
restoreButton.Activated:Connect(function() setPanelShown(true) end)
hideButton.MouseEnter:Connect(function() tween(hideButton, {BackgroundColor3 = COLORS.surfaceHover, TextColor3 = COLORS.text}, 0.12) end)
hideButton.MouseLeave:Connect(function() tween(hideButton, {BackgroundColor3 = COLORS.surface, TextColor3 = COLORS.muted}, 0.12) end)

-- Dragging works with both mouse and touch.
local dragging, dragStart, startPosition, dragInput
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging, dragStart, startPosition = true, input.Position, panel.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
    end
end)

local function updateScale()
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
    scale.Scale = math.clamp(math.min((viewport.X - 24) / 540, (viewport.Y - 70) / 350), 0.62, 1)
end
updateScale()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale) end

-- Movement logic
local function getHumanoid()
    local character = player.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function setSpeed(value)
    local number = tonumber(value)
    if number then SPEED = math.clamp(math.floor(number), 0, 500) end
    valueBox.Text = tostring(SPEED)
    local humanoid = getHumanoid()
    if humanoid then humanoid.WalkSpeed = SPEED end
end

decrease.Activated:Connect(function() setSpeed(SPEED - STEP) end)
increase.Activated:Connect(function() setSpeed(SPEED + STEP) end)
valueBox.FocusLost:Connect(function() setSpeed(valueBox.Text) end)
RunService.Heartbeat:Connect(function()
    local humanoid = getHumanoid()
    if humanoid and humanoid.WalkSpeed ~= SPEED then humanoid.WalkSpeed = SPEED end
end)

local flying = false
local flyConnection
local function stopFly()
    flying = false
    if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
    setFlyToggle(false)
end

local function startFly()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    flying = true
    setFlyToggle(true)
    flyConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not flying or not root.Parent then return end
        local camera = workspace.CurrentCamera
        if not camera then return end
        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move -= Vector3.yAxis end
        if move.Magnitude > 0 then root.CFrame += move.Unit * SPEED * deltaTime end
    end)
end

flyButton.Activated:Connect(function() if getFlyToggle() then stopFly() else startFly() end end)
player.CharacterAdded:Connect(function(character)
    stopFly()
    character:WaitForChild("Humanoid").WalkSpeed = SPEED
end)

-- Combat logic
local isAutoOn = false
local lastPunchTime = 0
local function findPunchButton()
    for _, child in ipairs(player.PlayerGui:GetDescendants()) do
        if child:IsA("GuiButton") then
            local name = child.Name:lower()
            if name:find("punch") or name:find("attack") or name:find("hit") or name:find("fight") then return child end
        end
    end
end

local function punch()
    local button = findPunchButton()
    if button then
        firesignal(button.Activated)
    elseif VirtualInputManager then
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end
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
        local otherCharacter = other ~= player and other.Character
        local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")
        if otherRoot then
            local currentDistance = (root.Position - otherRoot.Position).Magnitude
            if currentDistance < distance then nearest, distance = otherCharacter, currentDistance end
        end
    end
    return nearest
end

local function autoPunchLoop()
    while isAutoOn do
        local enemy = getNearestEnemy()
        local now = time() * 1000
        if enemy and not isBlocking(enemy) and now - lastPunchTime >= PUNCH_DELAY then
            punch(); lastPunchTime = now
        end
        task.wait(0.05)
    end
end

toggleAuto.Activated:Connect(function()
    isAutoOn = not getAutoToggle()
    setAutoToggle(isAutoOn)
    if isAutoOn then lastPunchTime = 0; task.spawn(autoPunchLoop) end
end)

local function setDelay(value)
    local number = tonumber(value)
    if number then PUNCH_DELAY = math.clamp(math.floor(number), 0, 10000) end
    delayBox.Text = tostring(PUNCH_DELAY)
end
delayMinus.Activated:Connect(function() setDelay(PUNCH_DELAY - 50) end)
delayPlus.Activated:Connect(function() setDelay(PUNCH_DELAY + 50) end)
delayBox.FocusLost:Connect(function() setDelay(delayBox.Text) end)

setSpeed(SPEED)
panel.Size = UDim2.fromOffset(500, 320)
panel.BackgroundTransparency = 1
tween(panel, {Size = UDim2.fromOffset(540, 350), BackgroundTransparency = 0}, 0.35)
if UserInputService.TouchEnabled then tween(dim, {BackgroundTransparency = 0.65}, 0.3) end

print("[Nexus] Modern interface loaded")
