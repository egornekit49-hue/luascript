-- Nexus Airbreak v3: Position spoofing (server sees you on ground, you fly as ghost).
-- N toggles panel, E/Q vertical (PC), touch has up/down buttons.

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

-- ═══ SPOOFING STATE ═══
local ghost = nil
local ghostPrimary = nil
local hiddenParts = {}         -- [part] = {transparency, canCollide}
local savedCameraSubject = nil
local healthConnection = nil

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

-- ═══════════════ SPOOFING HELPERS ═══════════════

local function getGroundPosition(fromPos)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {}
    if character then table.insert(ignore, character) end
    if ghost then table.insert(ignore, ghost) end
    params.FilterDescendantsInstances = ignore

    local origin = Vector3.new(fromPos.X, fromPos.Y + 5, fromPos.Z)
    local ray = workspace:Raycast(origin, Vector3.new(0, -1000, 0), params)
    if ray then
        return ray.Position + Vector3.new(0, 3.5, 0)
    end
    -- Если не нашли — используем спавн
    local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
    if spawn then return spawn.Position + Vector3.new(0, 4, 0) end
    return fromPos
end

local function hideRealCharacter(char)
    hiddenParts = {}
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then
            hiddenParts[d] = {transparency = d.Transparency, canCollide = d.CanCollide}
            d.Transparency = 1
            d.CanCollide = false
        elseif d:IsA("Decal") or d:IsA("Texture") then
            hiddenParts[d] = {transparency = d.Transparency}
            d.Transparency = 1
        end
    end
end

local function restoreRealCharacter()
    for d, data in pairs(hiddenParts) do
        if d.Parent then
            if data.transparency ~= nil then d.Transparency = data.transparency end
            if data.canCollide ~= nil then d.CanCollide = data.canCollide end
        end
    end
    hiddenParts = {}
end

local function createGhost(realChar)
    local ok, clone = pcall(function() return realChar:Clone() end)
    if not ok or not clone then return nil end

    clone.Name = "NexusGhost"
    -- Удаляем всё, что может физически/скриптово влиять
    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("Humanoid") or d:IsA("Script") or d:IsA("LocalScript")
           or d:IsA("Animator") or d:IsA("Sound") or d:IsA("ParticleEmitter")
           or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
            d:Destroy()
        end
    end

    local primary = clone:FindFirstChild("HumanoidRootPart") or clone:FindFirstChildWhichIsA("BasePart")
    if not primary then
        clone:Destroy()
        return nil
    end

    -- Отключаем физику на всех частях
    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = false
            d.CanCollide = false
            d.Massless = true
            d.CanQuery = false
            d.CanTouch = false
        end
    end

    -- Замораживаем все через Weld к primary
    primary.Anchored = true
    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("BasePart") and d ~= primary then
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = primary
            weld.Part1 = d
            weld.Parent = primary
        end
    end

    clone.Parent = workspace
    return clone, primary
end

local function startSpoof(char)
    local currentRoot = char:FindFirstChild("HumanoidRootPart")
    if not currentRoot then return false end

    -- 1. Находим безопасную точку на земле
    local safePos = getGroundPosition(currentRoot.Position)

    -- 2. Прячем настоящего персонажа и ставим на землю
    hideRealCharacter(char)
    currentRoot.Anchored = true
    currentRoot.CFrame = CFrame.new(safePos)
    originalAnchored = true

    -- 3. Создаём призрака
    local newGhost, newPrimary = createGhost(char)
    if not newGhost then return false end

    newGhost:PivotTo(char:GetPivot())
    ghost = newGhost
    ghostPrimary = newPrimary

    -- 4. Камера смотрит на призрака
    local cam = workspace.CurrentCamera
    if cam then
        savedCameraSubject = cam.CameraSubject
        cam.CameraSubject = newPrimary
    end

    -- 5. Держим HP на всякий случай
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        end)
        if healthConnection then healthConnection:Disconnect() end
        healthConnection = hum.HealthChanged:Connect(function(h)
            if (enabled or flyEnabled) and h < hum.MaxHealth and h > 0 then
                hum.Health = hum.MaxHealth
            end
        end)
    end

    return true
end

local function stopSpoof()
    if ghost then
        pcall(function() ghost:Destroy() end)
        ghost = nil
        ghostPrimary = nil
    end

    restoreRealCharacter()

    local cam = workspace.CurrentCamera
    if cam and savedCameraSubject then
        pcall(function() cam.CameraSubject = savedCameraSubject end)
        savedCameraSubject = nil
    end

    if healthConnection then
        healthConnection:Disconnect()
        healthConnection = nil
    end
end

-- Двигаем настоящего персонажа, чтобы он следовал за призраком по XZ, но был на земле
local function updateRealCharacterPosition()
    if not root or not root.Parent or not ghostPrimary then return end
    local gp = ghostPrimary.Position
    local safePos = getGroundPosition(gp)
    root.CFrame = CFrame.new(safePos)
end

-- ═══════════════ END SPOOFING ═══════════════

local function stopAirbreak()
    if not enabled and not character then return end
    enabled = false
    pcall(function() RunService:UnbindFromRenderStep(renderName) end)
    if stepConnection then stepConnection:Disconnect(); stepConnection = nil end
    if addedConnection then addedConnection:Disconnect(); addedConnection = nil end

    -- Останавливаем спуфинг (вернёт настоящего персонажа)
    stopSpoof()

    if root and root.Parent then
        root.Anchored = false
    end
    for part, canCollide in pairs(partCollisions) do
        if part.Parent then part.CanCollide = canCollide end
    end
    table.clear(partCollisions)
    character, root, originalAnchored = nil, nil, nil
    mobileControls = nil
    upHeld, downHeld = false, false
    if upButton then upButton.Visible = false end
    if downButton then downButton.Visible = false end
    if toggle and toggle.Parent then
        animate(toggle, {BackgroundColor3 = Color3.fromRGB(53, 59, 69)})
        animate(toggleKnob, {Position = UDim2.fromOffset(4, 4), BackgroundColor3 = muted})
    end
    if stateLabel and stateLabel.Parent then
        stateLabel.Text = "OFF  •  обычное управление не изменено"
        stateLabel.TextColor3 = muted
    end
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
        stateLabel.Text = "Нет живого персонажа"
        stateLabel.TextColor3 = Color3.fromRGB(239, 116, 119)
        return
    end

    character, root = current, currentRoot
    enabled = true

    -- ★ Запускаем спуфинг
    if not startSpoof(current) then
        enabled = false
        character, root = nil, nil
        stateLabel.Text = "Не удалось создать призрака"
        stateLabel.TextColor3 = Color3.fromRGB(239, 116, 119)
        return
    end

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
        if not alive or not enabled or player.Character ~= character or not ghostPrimary or not ghostPrimary.Parent then
            stopAirbreak()
            return
        end
        updateRealCharacterPosition()
    end)

    RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, function(dt)
        if not alive or not enabled or player.Character ~= character or not ghostPrimary or not ghostPrimary.Parent then
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
            end
        end

        if direction.Magnitude > 0 then
            local displacement = direction.Unit * speed * math.min(dt, 0.1)
            ghost:PivotTo(ghost:GetPivot() + displacement)
        end
    end)

    animate(toggle, {BackgroundColor3 = Color3.fromRGB(64, 101, 65)})
    animate(toggleKnob, {Position = UDim2.fromOffset(27, 4), BackgroundColor3 = accent})
    stateLabel.Text = "ON  •  призрак активен (сервер видит на земле)"
    stateLabel.TextColor3 = accent
end

stopFly = function()
    if not flyEnabled then return end
    flyEnabled = false
    pcall(function() RunService:UnbindFromRenderStep(flyRenderName) end)
    stopSpoof()
    if root and root.Parent then root.Anchored = false end
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
end

local function startFly()
    if flyEnabled then return end
    if enabled then stopAirbreak() end
    local current = player.Character
    local currentRoot = current and current:FindFirstChild("HumanoidRootPart")
    local humanoid = current and current:FindFirstChildOfClass("Humanoid")
    if not currentRoot or not humanoid or humanoid.Health <= 0 then
        stateLabel.Text = "Нет живого персонажа"
        stateLabel.TextColor3 = Color3.fromRGB(239, 116, 119)
        return
    end
    character, root = current, currentRoot
    flyEnabled = true

    if not startSpoof(current) then
        flyEnabled = false
        character, root = nil, nil
        stateLabel.Text = "Не удалось создать призрака"
        stateLabel.TextColor3 = Color3.fromRGB(239, 116, 119)
        return
    end

    if UserInputService.TouchEnabled then
        pcall(function()
            local scripts = player:FindFirstChild("PlayerScripts")
            local module = scripts and scripts:FindFirstChild("PlayerModule")
            if module then mobileControls = require(module):GetControls() end
        end)
    end
    if upButton then upButton.Visible = true end
    if downButton then downButton.Visible = true end

    stepConnection = RunService.Stepped:Connect(function()
        if not alive or not flyEnabled or player.Character ~= character or not ghostPrimary or not ghostPrimary.Parent then
            stopFly()
            return
        end
        updateRealCharacterPosition()
    end)

    RunService:BindToRenderStep(flyRenderName, Enum.RenderPriority.Camera.Value + 1, function(dt)
        if not alive or not flyEnabled or player.Character ~= character or not ghostPrimary or not ghostPrimary.Parent then
            stopFly()
            return
        end
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
            ghost:PivotTo(ghost:GetPivot() + direction.Unit * speed * math.min(dt, 0.1))
        end
    end)

    animate(flyToggle, {BackgroundColor3 = Color3.fromRGB(64, 101, 65)})
    animate(flyToggleKnob, {Position = UDim2.fromOffset(27, 4), BackgroundColor3 = accent})
    stateLabel.Text = "FLY ON  •  призрак активен"
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

-- ═══════════════ UI ═══════════════
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
    BackgroundTransparency = 1, Text = "SPOOF MODE  /  v3", TextColor3 = accent,
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
    BackgroundTransparency = 1, Text = "Airbreak (ghost mode)", TextColor3 = text,
    Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
}, card)
create("TextLabel", {
    Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -96, 0, 18),
    BackgroundTransparency = 1, Text = "Сервер видит вас на земле", TextColor3 = muted,
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
    Text = "Spoof: настоящий чар на земле, призрак летает.",
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
    BackgroundTransparency = 1, Text = "Fly (ghost mode)", TextColor3 = text,
    Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
}, flyCard)
create("TextLabel", {
    Position = UDim2.fromOffset(16, 35), Size = UDim2.new(1, -96, 0, 18),
    BackgroundTransparency = 1, Text = "Полёт без урона и noclip", TextColor3 = muted,
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

print("[Nexus v3 Spoof] Loaded. Ghost mode active when toggled.")
