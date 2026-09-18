-- Nexus Airbreak: client-side runtime movement; no game files are edited.
-- N toggles the panel, E/Q move vertically on PC. Touch has separate up/down buttons.
-- v2: HP protection while flying/airbreak (no fall damage, no anti-cheat drain).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local old = CoreGui:FindFirstChild("SuperGuiModern")
if old then
    local shutdown = old:FindFirstChild("NexusShutdown")
    if shutdown and shutdown:IsA("BindableFunction") then
        pcall(function() shutdown:Invoke() end)
    end
    old:Destroy()
end

local alive = true
local enabled = false
local flyEnabled = false
local speed = 35
local character, root, originalAnchored
local partCollisions = {}
local stepConnection, addedConnection
local connections = {}
local renderName = "NexusAirbreak_" .. tostring(player.UserId)
local flyRenderName = "NexusFly_" .. tostring(player.UserId)
local panel, dim, mini, toggle, toggleKnob, flyToggle, flyToggleKnob, stateLabel, speedBox
local upHeld, downHeld = false, false
local upButton, downButton
local mobileControls

-- ★ Защита HP
local healthConnection = nil
local healthProtectionActive = false
local savedFallDamage = nil

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

local function create(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props) do object[key] = value end
    object.Parent = parent
    return object
end

local function round(object, radius)
    create("UICorner", {CornerRadius = UDim.new(0, radius)}, object)
end

local function border(object)
    create("UIStroke", {Color = Color3.fromRGB(54, 62, 73), Transparency = 0.35, Thickness = 1}, object)
end

local function animate(object, props, duration)
    local tween = TweenService:Create(object, TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
    tween:Play()
    return tween
end

local accent = Color3.fromRGB(131, 210, 102)
local background = Color3.fromRGB(17, 20, 25)
local surface = Color3.fromRGB(26, 30, 37)
local text = Color3.fromRGB(237, 241, 245)
local muted = Color3.fromRGB(151, 160, 173)

local gui = create("ScreenGui", {
    Name = "SuperGuiModern", ResetOnSpawn = false, IgnoreGuiInset = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, CoreGui)

local function rememberPart(part)
    if part:IsA("BasePart") and partCollisions[part] == nil then
        partCollisions[part] = part.CanCollide
    end
end

-- ★ Включаем защиту HP
local function enableHealthProtection()
    local current = player.Character
    if not current then return end
    local hum = current:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    healthProtectionActive = true

    -- Отключаем состояния падения/рэгдолла, чтобы не получать урон от падения
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
    end)

    -- Подстраховка: если HP всё же упало — восстанавливаем
    if healthConnection then healthConnection:Disconnect() end
    healthConnection = hum.HealthChanged:Connect(function(newHealth)
        if healthProtectionActive and newHealth < hum.MaxHealth and newHealth > 0 then
            hum.Health = hum.MaxHealth
        end
    end)
end

-- ★ Выключаем защиту HP
local function disableHealthProtection()
    healthProtectionActive = false
    if healthConnection then
        healthConnection:Disconnect()
        healthConnection = nil
    end
end

-- ★ Каждый кадр восстанавливаем HP и ставим состояние "Running"
-- (сервер думает, что ты просто бежишь по земле)
local function maintainHealth(hum)
    if not hum or hum.Health <= 0 then return end
    if hum.Health < hum.MaxHealth then
        hum.Health = hum.MaxHealth
    end
    -- Принудительно ставим Running, если не бежим и не прыгаем
    pcall(function()
        if hum:GetState() ~= Enum.HumanoidStateType.Running
           and hum:GetState() ~= Enum.HumanoidStateType.Jumping
           and hum:GetState() ~= Enum.HumanoidStateType.Freefall then
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end)
end

local function stopAirbreak()
    if not enabled and not character then return end
    enabled = false
    pcall(function() RunService:UnbindFromRenderStep(renderName) end)
    if stepConnection then stepConnection:Disconnect(); stepConnection = nil end
    if addedConnection then addedConnection:Disconnect(); addedConnection = nil end

    if root and root.Parent and originalAnchored ~= nil then
        root.Anchored = originalAnchored
    end
    for part, canCollide in pairs(partCollisions) do
        if part.Parent then part.CanCollide = canCollide end
    end
    table.clear(partCollisions)
    character, root, originalAnchored = nil, nil, nil
    mobileControls = nil
    upHeld, downHeld = false, false
    if upButton then upButton.Visible = flyEnabled end
    if downButton then downButton.Visible = flyEnabled end
    if toggle and toggle.Parent then
        animate(toggle, {BackgroundColor3 = Color3.fromRGB(53, 59, 69)})
        animate(toggleKnob, {Position = UDim2.fromOffset(4, 4), BackgroundColor3 = muted})
    end
    if stateLabel and stateLabel.Parent then
        stateLabel.Text = "OFF  •  обычное управление не изменено"
        stateLabel.TextColor3 = muted
    end
    disableHealthProtection()
end

local function mobileMoveVector()
    local vector = Vector3.zero
    pcall(function()
        if mobileControls then vector = mobileControls:GetMoveVector() end
    end)
    return vector
end

local stopFly
local function startAirbreak()
    if enabled then return end
    if flyEnabled then stopFly() end
    local current = player.Character
    local currentRoot = current and current:FindFirstChild("HumanoidRootPart")
    local humanoid = current and current:FindFirstChildOfClass("Humanoid")
    if not currentRoot or not humanoid or humanoid.Health <= 0 then
        stateLabel.Text = "Нет живого персонажа — попробуй после появления"
        stateLabel.TextColor3 = Color3.fromRGB(239, 116, 119)
        return
    end

    character, root = current, currentRoot
    originalAnchored = root.Anchored
    enabled = true
    enableHealthProtection()  -- ★ включаем защиту
    if UserInputService.TouchEnabled then
        pcall(function()
            local scripts = player:FindFirstChild("PlayerScripts")
            local module = scripts and scripts:FindFirstChild("PlayerModule")
            if module then mobileControls = require(module):GetControls() end
        end)
    end
    for _, descendant in ipairs(character:GetDescendants()) do rememberPart(descendant) end
    addedConnection = character.DescendantAdded:Connect(rememberPart)

    stepConnection = RunService.Stepped:Connect(function()
        if not alive or not enabled or player.Character ~= character or not root.Parent then
            stopAirbreak()
            return
        end
        root.Anchored = true
        for part in pairs(partCollisions) do
            if part.Parent then part.CanCollide = false else partCollisions[part] = nil end
        end
        -- ★ Поддерживаем HP
        maintainHealth(humanoid)
    end)

    RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, function(dt)
        if not alive or not enabled or player.Character ~= character or not root.Parent then
            stopAirbreak()
            return
        end
        local camera = workspace.CurrentCamera
        if not camera then return end

        local direction = Vector3.zero
        local look = camera.CFrame.LookVector
        local right = camera.CFrame.RightVector
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction = direction + look end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction = direction - look end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction = direction + right end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction = direction - right end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) or upHeld then direction = direction + Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) or downHeld then direction = direction - Vector3.yAxis end

        if UserInputService.TouchEnabled then
            local stick = mobileMoveVector()
            if stick.Magnitude > 0 then
                local flatLook = Vector3.new(look.X, 0, look.Z)
                local flatRight = Vector3.new(right.X, 0, right.Z)
                if flatLook.Magnitude > 0 then flatLook = flatLook.Unit end
                if flatRight.Magnitude > 0 then flatRight = flatRight.Unit end
                direction = direction + flatRight * stick.X - flatLook * stick.Z
            elseif humanoid.MoveDirection.Magnitude > 0 then
                direction = direction + humanoid.MoveDirection
            end
        end

        if direction.Magnitude > 0 then
            local displacement = direction.Unit * speed * math.min(dt, 0.1)
            character:PivotTo(character:GetPivot() + displacement)
        end
        -- ★ Каждый кадр держим HP и Running state
        maintainHealth(humanoid)
    end)

    animate(toggle, {BackgroundColor3 = Color3.fromRGB(64, 101, 65)})
    animate(toggleKnob, {Position = UDim2.fromOffset(27, 4), BackgroundColor3 = accent})
    stateLabel.Text = "ON  •  E вверх / Q вниз"
    stateLabel.TextColor3 = accent
end

stopFly = function()
    if not flyEnabled then return end
    flyEnabled = false
    pcall(function() RunService:UnbindFromRenderStep(flyRenderName) end)
    if root and root.Parent and originalAnchored ~= nil then root.Anchored = originalAnchored end
    character, root, originalAnchored = nil, nil, nil
    mobileControls = nil
    upHeld, downHeld = false, false
    if upButton then upButton.Visible = false end
    if downButton then downButton.Visible = false end
    if flyToggle and flyToggle.Parent then
        animate(flyToggle, {BackgroundColor3 = Color3.fromRGB(53, 59, 69)})
        animate(flyToggleKnob, {Position = UDim2.fromOffset(4, 4), BackgroundColor3 = muted})
    end
    if stateLabel and stateLabel.Parent then
        stateLabel.Text = "OFF  •  обычное управление не изменено"
        stateLabel.TextColor3 = muted
    end
    disableHealthProtection()
end

local function startFly()
    if flyEnabled then return end
    if enabled then stopAirbreak() end
    local current = player.Character
    local currentRoot = current and current:FindFirstChild("HumanoidRootPart")
    local humanoid = current and current:FindFirstChildOfClass("Humanoid")
    if not currentRoot or not humanoid or humanoid.Health <= 0 then
        stateLabel.Text = "Нет живого персонажа — попробуй после появления"
        stateLabel.TextColor3 = Color3.fromRGB(239, 116, 119)
        return
    end
    character, root = current, currentRoot
    originalAnchored = root.Anchored
    flyEnabled = true
    enableHealthProtection()  -- ★ включаем защиту
    if UserInputService.TouchEnabled then
        pcall(function()
            local scripts = player:FindFirstChild("PlayerScripts")
            local module = scripts and scripts:FindFirstChild("PlayerModule")
            if module then mobileControls = require(module):GetControls() end
        end)
    end
    RunService:BindToRenderStep(flyRenderName, Enum.RenderPriority.Camera.Value + 1, function(dt)
        if not alive or not flyEnabled or player.Character ~= character or not root.Parent then
            stopFly()
            return
        end
        root.Anchored = true
        local camera = workspace.CurrentCamera
        if not camera then return end
        local direction = Vector3.zero
        local look, right = camera.CFrame.LookVector, camera.CFrame.RightVector
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction = direction + look end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction = direction - look end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction = direction + right end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction = direction - right end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) or upHeld then direction = direction + Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) or downHeld then direction = direction - Vector3.yAxis end
        if UserInputService.TouchEnabled then
            local stick = mobileMoveVector()
            local flatLook = Vector3.new(look.X, 0, look.Z)
            local flatRight = Vector3.new(right.X, 0, right.Z)
            if flatLook.Magnitude > 0 then flatLook = flatLook.Unit end
            if flatRight.Magnitude > 0 then flatRight = flatRight.Unit end
            direction = direction + flatRight * stick.X - flatLook * stick.Z
        end
        if direction.Magnitude > 0 then
            character:PivotTo(character:GetPivot() + direction.Unit * speed * math.min(dt, 0.1))
        end
        -- ★ Каждый кадр держим HP и Running state
        maintainHealth(humanoid)
    end)
    if upButton then upButton.Visible = true end
    if downButton then downButton.Visible = true end
    animate(flyToggle, {BackgroundColor3 = Color3.fromRGB(64, 101, 65)})
    animate(flyToggleKnob, {Position = UDim2.fromOffset(27, 4), BackgroundColor3 = accent})
    stateLabel.Text = "FLY ON  •  E вверх / Q вниз"
    stateLabel.TextColor3 = accent
end

local function shutdown(destroyGui)
    if not alive then return end
    alive = false
    stopAirbreak()
    stopFly()
    for _, connection in ipairs(connections) do connection:Disconnect() end
    table.clear(connections)
    if destroyGui ~= false and gui and gui.Parent then gui:Destroy() end
end

local shutdownFunction = Instance.new("BindableFunction")
shutdownFunction.Name = "NexusShutdown"
shutdownFunction.OnInvoke = function() shutdown(true) end
shutdownFunction.Parent = gui
connect(gui.Destroying, function() shutdown(false) end)

dim = create("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = UserInputService.TouchEnabled and 0.7 or 1,
    BorderSizePixel = 0, Active = false,
}, gui)
panel = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(420, 432), BackgroundColor3 = background,
    BorderSizePixel = 0, ClipsDescendants = true,
}, gui)
round(panel, 16)
border(panel)
local scale = create("UIScale", {Scale = 1}, panel)

local header = create("Frame", {Size = UDim2.new(1, 0, 0, 77), BackgroundTransparency = 1}, panel)
create("TextLabel", {
    Position = UDim2.fromOffset(22, 17), Size = UDim2.new(1, -100, 0, 25),
    BackgroundTransparency = 1, Text = "●  NEXUS", TextColor3 = text,
    Font = Enum.Font.GothamBold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left,
}, header)
create("TextLabel", {
    Position = UDim2.fromOffset(24, 43), Size = UDim2.new(1, -100, 0, 18),
    BackgroundTransparency = 1, Text = "AIRBREAK  /  CLIENT RUNTIME", TextColor3 = accent,
    Font = Enum.Font.GothamMedium, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
}, header)
local close = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18),
    Size = UDim2.fromOffset(34, 34), BackgroundColor3 = surface,
    BorderSizePixel = 0, Text = "×", TextColor3 = muted,
    Font = Enum.Font.GothamMedium, TextSize = 22, AutoButtonColor = false,
}, header)
round(close, 9)

create("Frame", {
    Position = UDim2.fromOffset(20, 76), Size = UDim2.new(1, -40, 0, 1),
    BackgroundColor3 = Color3.fromRGB(49, 55, 65), BorderSizePixel = 0,
}, panel)
local card = create("Frame", {
    Position = UDim2.fromOffset(20, 96), Size = UDim2.new(1, -40, 0, 88),
    BackgroundColor3 = surface, BorderSizePixel = 0,
}, panel)
round(card, 12)
border(card)
create("TextLabel", {
    Position = UDim2.fromOffset(16, 13), Size = UDim2.new(1, -96, 0, 22),
    BackgroundTransparency = 1, Text = "Airbreak + noclip", TextColor3 = text,
    Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
}, card)
create("TextLabel", {
    Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -96, 0, 18),
    BackgroundTransparency = 1, Text = "Свободный полёт сквозь стены", TextColor3 = muted,
    Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
}, card)
toggle = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -17, 0.5, 0),
    Size = UDim2.fromOffset(51, 27), BackgroundColor3 = Color3.fromRGB(53, 59, 69),
    BorderSizePixel = 0, Text = "", AutoButtonColor = false,
}, card)
round(toggle, 14)
toggleKnob = create("Frame", {
    Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(19, 19),
    BackgroundColor3 = muted, BorderSizePixel = 0,
}, toggle)
round(toggleKnob, 10)

local speedCard = create("Frame", {
    Position = UDim2.fromOffset(20, 286), Size = UDim2.new(1, -40, 0, 66),
    BackgroundColor3 = surface, BorderSizePixel = 0,
}, panel)
round(speedCard, 12)
border(speedCard)
create("TextLabel", {
    Position = UDim2.fromOffset(16, 18), Size = UDim2.new(1, -145, 0, 26),
    BackgroundTransparency = 1, Text = "Скорость полёта", TextColor3 = text,
    Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
}, speedCard)

local minus = create("TextButton", {
    Position = UDim2.new(1, -122, 0, 16), Size = UDim2.fromOffset(30, 34),
    BackgroundColor3 = background, BorderSizePixel = 0, Text = "−",
    TextColor3 = muted, Font = Enum.Font.GothamBold, TextSize = 17,
}, speedCard)
speedBox = create("TextBox", {
    Position = UDim2.new(1, -90, 0, 16), Size = UDim2.fromOffset(55, 34),
    BackgroundColor3 = background, BorderSizePixel = 0, Text = tostring(speed),
    TextColor3 = text, Font = Enum.Font.GothamBold, TextSize = 12,
    ClearTextOnFocus = false,
}, speedCard)
local plus = create("TextButton", {
    Position = UDim2.new(1, -33, 0, 16), Size = UDim2.fromOffset(30, 34),
    BackgroundColor3 = background, BorderSizePixel = 0, Text = "+",
    TextColor3 = accent, Font = Enum.Font.GothamBold, TextSize = 17,
}, speedCard)
for _, object in ipairs({minus, speedBox, plus}) do round(object, 8) end

stateLabel = create("TextLabel", {
    Position = UDim2.fromOffset(22, 362), Size = UDim2.new(1, -44, 0, 22),
    BackgroundTransparency = 1, Text = "OFF  •  обычное управление не изменено",
    TextColor3 = muted, Font = Enum.Font.GothamMedium, TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
}, panel)
create("TextLabel", {
    Position = UDim2.fromOffset(22, 390), Size = UDim2.new(1, -44, 0, 25),
    BackgroundTransparency = 1,
    Text = "Клиентский режим: сервер игры может возвращать позицию.",
    TextColor3 = muted, Font = Enum.Font.Gotham, TextSize = 10,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

local flyCard = create("Frame", {
    Position = UDim2.fromOffset(20, 194), Size = UDim2.new(1, -40, 0, 82),
    BackgroundColor3 = surface, BorderSizePixel = 0,
}, panel)
round(flyCard, 12)
border(flyCard)
create("TextLabel", {
    Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -96, 0, 22),
    BackgroundTransparency = 1, Text = "Fly", TextColor3 = text,
    Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
}, flyCard)
create("TextLabel", {
    Position = UDim2.fromOffset(16, 35), Size = UDim2.new(1, -96, 0, 18),
    BackgroundTransparency = 1, Text = "Свободный полёт без noclip", TextColor3 = muted,
    Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
}, flyCard)
flyToggle = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -17, 0.5, 0),
    Size = UDim2.fromOffset(51, 27), BackgroundColor3 = Color3.fromRGB(53, 59, 69),
    BorderSizePixel = 0, Text = "", AutoButtonColor = false,
}, flyCard)
round(flyToggle, 14)
flyToggleKnob = create("Frame", {
    Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(19, 19),
    BackgroundColor3 = muted, BorderSizePixel = 0,
}, flyToggle)
round(flyToggleKnob, 10)

mini = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18),
    Size = UDim2.fromOffset(52, 52), BackgroundColor3 = background,
    BorderSizePixel = 0, Text = "N", TextColor3 = accent,
    Font = Enum.Font.GothamBold, TextSize = 19, Visible = false,
}, gui)
round(mini, 16)
border(mini)

local function setPanelVisible(visible)
    panel.Visible = visible
    dim.Visible = visible
    mini.Visible = not visible
end

local function setSpeed(value)
    local number = tonumber(value)
    if number and number == number then speed = math.clamp(math.floor(number), 5, 200) end
    speedBox.Text = tostring(speed)
end

connect(toggle.Activated, function()
    if enabled then stopAirbreak() else startAirbreak() end
end)
connect(flyToggle.Activated, function()
    if flyEnabled then stopFly() else startFly() end
end)
connect(minus.Activated, function() setSpeed(speed - 5) end)
connect(plus.Activated, function() setSpeed(speed + 5) end)
connect(speedBox.FocusLost, function() setSpeed(speedBox.Text) end)
connect(close.Activated, function() setPanelVisible(false) end)
connect(mini.Activated, function() setPanelVisible(true) end)
connect(UserInputService.InputBegan, function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.N then setPanelVisible(not panel.Visible) end
end)
connect(player.CharacterRemoving, function()
    stopAirbreak()
    stopFly()
end)

if UserInputService.TouchEnabled then
    local function verticalButton(label, y)
        local button = create("TextButton", {
            AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, y),
            Size = UDim2.fromOffset(55, 55), BackgroundColor3 = background,
            BackgroundTransparency = 0.15, BorderSizePixel = 0,
            Text = label, TextColor3 = accent, Font = Enum.Font.GothamBold,
            TextSize = 22, Visible = false,
        }, gui)
        round(button, 16)
        border(button)
        return button
    end
    upButton = verticalButton("↑", -160)
    downButton = verticalButton("↓", -95)
    local function setVerticalVisible()
        upButton.Visible = enabled
        downButton.Visible = enabled
    end
    connect(toggle.Activated, function() task.defer(setVerticalVisible) end)
    connect(player.CharacterRemoving, function()
        upButton.Visible, downButton.Visible = false, false
    end)
    connect(upButton.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then upHeld = true end
    end)
    connect(upButton.InputEnded, function() upHeld = false end)
    connect(downButton.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then downHeld = true end
    end)
    connect(downButton.InputEnded, function() downHeld = false end)
end

local function resize()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
    scale.Scale = math.clamp(math.min((viewport.X - 20) / 420, (viewport.Y - 60) / 432), 0.55, 1)
    if UserInputService.TouchEnabled then
        panel.AnchorPoint = Vector2.new(0.5, 0)
        panel.Position = UDim2.new(0.5, 0, 0, 10)
    end
end
resize()
if workspace.CurrentCamera then connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), resize) end

print("[Nexus Airbreak v2] Loaded; HP protection active; N = show/hide")
