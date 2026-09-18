-- Nexus Airbreak v4: Position spoof + godmode + HP protection
-- N toggles panel, E/Q vertical (PC), touch up/down buttons.

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
local godmode = true                       -- ★ включён по умолчанию
local character, root, originalAnchored
local connections = {}
local renderName = "NexusAirbreak_" .. tostring(player.UserId)
local flyRenderName = "NexusFly_" .. tostring(player.UserId)
local panel, dim, mini, toggle, toggleKnob, flyToggle, flyToggleKnob, godToggle, godToggleKnob, stateLabel, speedBox
local upHeld, downHeld = false, false
local upButton, downButton
local mobileControls

-- ═══════════ STATE ═══════════
local ghost, ghostPrimary
local hiddenParts = {}
local savedCameraSubject
local healthConn, healthHeartbeat
local savedAnchored, savedPos
local charConnections = {}

local function connect(signal, callback)
    local c = signal:Connect(callback)
    table.insert(connections, c)
    return c
end

local function connectChar(signal, callback)
    local c = signal:Connect(callback)
    table.insert(charConnections, c)
    return c
end

local function create(className, props, parent)
    local o = Instance.new(className)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end
local function round(o, r) create("UICorner", {CornerRadius = UDim.new(0, r)}, o) end
local function border(o) create("UIStroke", {Color = Color3.fromRGB(54, 62, 73), Transparency = 0.35, Thickness = 1}, o) end
local function animate(o, p, d) local t = TweenService:Create(o, TweenInfo.new(d or 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), p); t:Play(); return t end

local accent = Color3.fromRGB(131, 210, 102)
local background = Color3.fromRGB(17, 20, 25)
local surface = Color3.fromRGB(26, 30, 37)
local text = Color3.fromRGB(237, 241, 245)
local muted = Color3.fromRGB(151, 160, 173)

local gui = create("ScreenGui", {
    Name = "SuperGuiModern", ResetOnSpawn = false, IgnoreGuiInset = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, CoreGui)

-- ═══════════ GODMODE ═══════════

local function enableGodmode(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    -- Огромное HP
    pcall(function()
        hum.MaxHealth = 1e9
        hum.Health = 1e9
    end)

    -- Отключаем состояния падения/рэгдолла/PlatformStand
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
    end)

    -- Восстанавливаем HP на любое изменение
    if healthConn then healthConn:Disconnect() end
    healthConn = hum:GetPropertyChangedSignal("Health"):Connect(function()
        if godmode and hum.Parent and hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
        end
    end)

    -- Подстраховка через Heartbeat
    if healthHeartbeat then healthHeartbeat:Disconnect() end
    healthHeartbeat = RunService.Heartbeat:Connect(function()
        if not godmode then return end
        if hum.Parent and hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
        end
        -- Принудительно Running, чтобы сервер не считал тебя падающим
        pcall(function()
            local s = hum:GetState()
            if s ~= Enum.HumanoidStateType.Running
               and s ~= Enum.HumanoidStateType.Jumping
               and s ~= Enum.HumanoidStateType.Freefall then
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
        end)
    end)
end

local function disableGodmode()
    if healthConn then healthConn:Disconnect(); healthConn = nil end
    if healthHeartbeat then healthHeartbeat:Disconnect(); healthHeartbeat = nil end
end

-- ═══════════ SPOOF ═══════════

local function getGroundY(x, z, excludeChar)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {}
    if character then table.insert(ignore, character) end
    if ghost then table.insert(ignore, ghost) end
    params.FilterDescendantsInstances = ignore

    local ray = workspace:Raycast(Vector3.new(x, 500, z), Vector3.new(0, -2000, 0), params)
    if ray then return ray.Position.Y + 3.5 end
    return nil
end

local function hideChar(char)
    hiddenParts = {}
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then
            hiddenParts[d] = {t = d.Transparency, c = d.CanCollide}
            d.Transparency = 1
            d.CanCollide = false
        elseif d:IsA("Decal") or d:IsA("Texture") then
            hiddenParts[d] = {t = d.Transparency}
            d.Transparency = 1
        end
    end
end

local function restoreChar()
    for d, data in pairs(hiddenParts) do
        if d.Parent then
            if data.t ~= nil then d.Transparency = data.t end
            if data.c ~= nil then d.CanCollide = data.c end
        end
    end
    hiddenParts = {}
end

local function buildGhost(realChar)
    local ok, clone = pcall(function() return realChar:Clone() end)
    if not ok or not clone then return nil end

    clone.Name = "NexusGhost"
    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("Humanoid") or d:IsA("Script") or d:IsA("LocalScript")
           or d:IsA("Animator") or d:IsA("Sound") or d:IsA("ParticleEmitter")
           or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles")
           or d:IsA("Highlight") or d:IsA("SelectionBox") then
            d:Destroy()
        end
    end

    local primary = clone:FindFirstChild("HumanoidRootPart") or clone:FindFirstChildWhichIsA("BasePart")
    if not primary then clone:Destroy(); return nil end

    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = false
            d.CanCollide = false
            d.Massless = true
            d.CanQuery = false
            d.CanTouch = false
        end
    end

    primary.Anchored = true
    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("BasePart") and d ~= primary then
            local w = Instance.new("WeldConstraint")
            w.Part0 = primary
            w.Part1 = d
            w.Parent = primary
        end
    end

    clone.Parent = workspace
    return clone, primary
end

local function startSpoof(char)
    local currentRoot = char:FindFirstChild("HumanoidRootPart")
    if not currentRoot then return false end

    savedAnchored = currentRoot.Anchored
    savedPos = currentRoot.CFrame

    -- ★ Ставим настоящего персонажа на НАДЁЖНУЮ землю и якорим
    hideChar(char)
    currentRoot.Anchored = true

    -- Создаём призрака
    local newGhost, newPrimary = buildGhost(char)
    if not newGhost then return false end

    newGhost:PivotTo(char:GetPivot())
    ghost, ghostPrimary = newGhost, newPrimary

    -- Камера на призрака
    local cam = workspace.CurrentCamera
    if cam then
        savedCameraSubject = cam.CameraSubject
        cam.CameraSubject = newPrimary
    end

    return true
end

local function stopSpoof()
    if ghost then pcall(function() ghost:Destroy() end); ghost, ghostPrimary = nil, nil end
    restoreChar()

    local cam = workspace.CurrentCamera
    if cam and savedCameraSubject then
        pcall(function() cam.CameraSubject = savedCameraSubject end)
        savedCameraSubject = nil
    end
end

-- Настоящий персонаж всегда на земле, но в той же XZ что и призрак
local function syncRealCharToGround()
    if not root or not root.Parent or not ghostPrimary then return end
    local gp = ghostPrimary.Position
    local groundY = getGroundY(gp.X, gp.Z)
    if groundY then
        root.CFrame = CFrame.new(Vector3.new(gp.X, groundY, gp.Z))
    end
    -- Если под призраком пустота — оставляем персонажа на последней безопасной позиции
end

-- ═══════════ STOP/START ═══════════

local function resetToggleVisual(t, k)
    if t and t.Parent then
        animate(t, {BackgroundColor3 = Color3.fromRGB(53, 59, 69)})
        animate(k, {Position = UDim2.fromOffset(4, 4), BackgroundColor3 = muted})
    end
end

local function stopAirbreak()
    if not enabled and not character then return end
    enabled = false
    pcall(function() RunService:UnbindFromRenderStep(renderName) end)
    stopSpoof()

    if root and root.Parent then
        root.Anchored = savedAnchored or false
    end
    character, root = nil, nil
    mobileControls = nil
    upHeld, downHeld = false, false
    if upButton then upButton.Visible = false end
    if downButton then downButton.Visible = false end
    resetToggleVisual(toggle, toggleKnob)
    if stateLabel and stateLabel.Parent then
        stateLabel.Text = "OFF  •  обычное управление"
        stateLabel.TextColor3 = muted
    end
end

local function mobileMoveVector()
    local v = Vector3.zero
    pcall(function() if mobileControls then v = mobileControls:GetMoveVector() end end)
    return v
end

local stopFly
local function startAirbreak()
    if enabled then return end
    if flyEnabled then stopFly() end

    local cur = player.Character
    local curRoot = cur and cur:FindFirstChild("HumanoidRootPart")
    local hum = cur and cur:FindFirstChildOfClass("Humanoid")
    if not curRoot or not hum or hum.Health <= 0 then
        stateLabel.Text = "Нет живого персонажа"
        stateLabel.TextColor3 = Color3.fromRGB(239, 116, 119)
        return
    end

    character, root = cur, curRoot
    enabled = true

    if not startSpoof(cur) then
        enabled = false; character, root = nil, nil
        stateLabel.Text = "Не удалось создать призрака"
        stateLabel.TextColor3 = Color3.fromRGB(239, 116, 119)
        return
    end

    if godmode then enableGodmode(cur) end

    if UserInputService.TouchEnabled then
        pcall(function()
            local ps = player:FindFirstChild("PlayerScripts")
            local m = ps and ps:FindFirstChild("PlayerModule")
            if m then mobileControls = require(m):GetControls() end
        end)
    end

    -- Каждый Stepped — синхронизация позиции
    RunService.Stepped:Connect(function()
        if not alive or not enabled then return end
    end)

    connect(RunService.Stepped, function()
        if not alive or not enabled or player.Character ~= character or not ghostPrimary or not ghostPrimary.Parent then
            stopAirbreak(); return
        end
        syncRealCharToGround()
    end)

    RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, function(dt)
        if not alive or not enabled or player.Character ~= character or not ghostPrimary or not ghostPrimary.Parent then
            stopAirbreak(); return
        end
        local cam = workspace.CurrentCamera
        if not cam then return end

        local dir = Vector3.zero
        local look, right = cam.CFrame.LookVector, cam.CFrame.RightVector
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + look end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - look end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + right end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - right end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) or upHeld then dir = dir + Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) or downHeld then dir = dir - Vector3.yAxis end

        if UserInputService.TouchEnabled then
            local stick = mobileMoveVector()
            if stick.Magnitude > 0 then
                local fl = Vector3.new(look.X, 0, look.Z)
                local fr = Vector3.new(right.X, 0, right.Z)
                if fl.Magnitude > 0 then fl = fl.Unit end
                if fr.Magnitude > 0 then fr = fr.Unit end
                dir = dir + fr * stick.X - fl * stick.Z
            end
        end

        if dir.Magnitude > 0 then
            ghost:PivotTo(ghost:GetPivot() + dir.Unit * speed * math.min(dt, 0.1))
        end
    end)

    animate(toggle, {BackgroundColor3 = Color3.fromRGB(64, 101, 65)})
    animate(toggleKnob, {Position = UDim2.fromOffset(27, 4), BackgroundColor3 = accent})
    stateLabel.Text = "ON  •  godmode + ghost"
    stateLabel.TextColor3 = accent
end

stopFly = function()
    if not flyEnabled then return end
    flyEnabled = false
    pcall(function() RunService:UnbindFromRenderStep(flyRenderName) end)
    stopSpoof()
    if root and root.Parent then root.Anchored = savedAnchored or false end
    character, root = nil, nil
    mobileControls = nil
    upHeld, downHeld = false, false
    if upButton then upButton.Visible = false end
    if downButton then downButton.Visible = false end
    resetToggleVisual(flyToggle, flyToggleKnob)
    if stateLabel and stateLabel.Parent then
        stateLabel.Text = "OFF  •  обычное управление"
        stateLabel.TextColor3 = muted
    end
end

local function startFly()
    if flyEnabled then return end
    if enabled then stopAirbreak() end

    local cur = player.Character
    local curRoot = cur and cur:FindFirstChild("HumanoidRootPart")
    local hum = cur and cur:FindFirstChildOfClass("Humanoid")
    if not curRoot or not hum or hum.Health <= 0 then
        stateLabel.Text = "Нет живого персонажа"
        stateLabel.TextColor3 = Color3.fromRGB(239, 116, 119)
        return
    end

    character, root = cur, curRoot
    flyEnabled = true

    if not startSpoof(cur) then
        flyEnabled = false; character, root = nil, nil
        stateLabel.Text = "Ошибка"
        stateLabel.TextColor3 = Color3.fromRGB(239, 116, 119)
        return
    end

    if godmode then enableGodmode(cur) end

    if UserInputService.TouchEnabled then
        pcall(function()
            local ps = player:FindFirstChild("PlayerScripts")
            local m = ps and ps:FindFirstChild("PlayerModule")
            if m then mobileControls = require(m):GetControls() end
        end)
    end
    if upButton then upButton.Visible = true end
    if downButton then downButton.Visible = true end

    connect(RunService.Stepped, function()
        if not alive or not flyEnabled or player.Character ~= character or not ghostPrimary or not ghostPrimary.Parent then
            stopFly(); return
        end
        syncRealCharToGround()
    end)

    RunService:BindToRenderStep(flyRenderName, Enum.RenderPriority.Camera.Value + 1, function(dt)
        if not alive or not flyEnabled or player.Character ~= character or not ghostPrimary or not ghostPrimary.Parent then
            stopFly(); return
        end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local dir = Vector3.zero
        local look, right = cam.CFrame.LookVector, cam.CFrame.RightVector
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + look end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - look end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + right end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - right end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) or upHeld then dir = dir + Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) or downHeld then dir = dir - Vector3.yAxis end
        if UserInputService.TouchEnabled then
            local stick = mobileMoveVector()
            local fl = Vector3.new(look.X, 0, look.Z)
            local fr = Vector3.new(right.X, 0, right.Z)
            if fl.Magnitude > 0 then fl = fl.Unit end
            if fr.Magnitude > 0 then fr = fr.Unit end
            dir = dir + fr * stick.X - fl * stick.Z
        end
        if dir.Magnitude > 0 then
            ghost:PivotTo(ghost:GetPivot() + dir.Unit * speed * math.min(dt, 0.1))
        end
    end)

    animate(flyToggle, {BackgroundColor3 = Color3.fromRGB(64, 101, 65)})
    animate(flyToggleKnob, {Position = UDim2.fromOffset(27, 4), BackgroundColor3 = accent})
    stateLabel.Text = "FLY ON  •  godmode + ghost"
    stateLabel.TextColor3 = accent
end

local function shutdown(destroyGui)
    if not alive then return end
    alive = false
    stopAirbreak()
    stopFly()
    disableGodmode()
    for _, c in ipairs(connections) do c:Disconnect() end
    for _, c in ipairs(charConnections) do c:Disconnect() end
    table.clear(connections); table.clear(charConnections)
    if destroyGui ~= false and gui and gui.Parent then gui:Destroy() end
end

local shutdownFunction = Instance.new("BindableFunction")
shutdownFunction.Name = "NexusShutdown"
shutdownFunction.OnInvoke = function() shutdown(true) end
shutdownFunction.Parent = gui
connect(gui.Destroying, function() shutdown(false) end)

-- ═══════════ UI ═══════════

dim = create("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = UserInputService.TouchEnabled and 0.7 or 1,
    BorderSizePixel = 0, Active = false,
}, gui)

panel = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(420, 500), BackgroundColor3 = background,
    BorderSizePixel = 0, ClipsDescendants = true,
}, gui)
round(panel, 16); border(panel)
local scale = create("UIScale", {Scale = 1}, panel)

local header = create("Frame", {Size = UDim2.new(1, 0, 0, 77), BackgroundTransparency = 1}, panel)
create("TextLabel", {
    Position = UDim2.fromOffset(22, 17), Size = UDim2.new(1, -100, 0, 25),
    BackgroundTransparency = 1, Text = "●  NEXUS", TextColor3 = text,
    Font = Enum.Font.GothamBold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left,
}, header)
create("TextLabel", {
    Position = UDim2.fromOffset(24, 43), Size = UDim2.new(1, -100, 0, 18),
    BackgroundTransparency = 1, Text = "SPOOF + GODMODE  /  v4", TextColor3 = accent,
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

local function makeCard(y, h, title, desc)
    local c = create("Frame", {
        Position = UDim2.fromOffset(20, y), Size = UDim2.new(1, -40, 0, h),
        BackgroundColor3 = surface, BorderSizePixel = 0,
    }, panel)
    round(c, 12); border(c)
    create("TextLabel", {
        Position = UDim2.fromOffset(16, 13), Size = UDim2.new(1, -96, 0, 22),
        BackgroundTransparency = 1, Text = title, TextColor3 = text,
        Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
    }, c)
    create("TextLabel", {
        Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -96, 0, 18),
        BackgroundTransparency = 1, Text = desc, TextColor3 = muted,
        Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
    }, c)
    local tg = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -17, 0.5, 0),
        Size = UDim2.fromOffset(51, 27), BackgroundColor3 = Color3.fromRGB(53, 59, 69),
        BorderSizePixel = 0, Text = "", AutoButtonColor = false,
    }, c)
    round(tg, 14)
    local kn = create("Frame", {
        Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(19, 19),
        BackgroundColor3 = muted, BorderSizePixel = 0,
    }, tg)
    round(kn, 10)
    return tg, kn
end

toggle, toggleKnob = makeCard(96, 88, "Airbreak (ghost)", "Сервер видит на земле")
flyToggle, flyToggleKnob = makeCard(194, 82, "Fly (ghost)", "Полёт без урона")
godToggle, godToggleKnob = makeCard(286, 82, "Godmode", "Бессмертие + HP restore")

-- Начальное состояние godmode
if godmode then
    godToggle.BackgroundColor3 = Color3.fromRGB(64, 101, 65)
    godToggleKnob.Position = UDim2.fromOffset(27, 4)
    godToggleKnob.BackgroundColor3 = accent
end

-- Speed card
local speedCard = create("Frame", {
    Position = UDim2.fromOffset(20, 378), Size = UDim2.new(1, -40, 0, 66),
    BackgroundColor3 = surface, BorderSizePixel = 0,
}, panel)
round(speedCard, 12); border(speedCard)
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
for _, o in ipairs({minus, speedBox, plus}) do round(o, 8) end

stateLabel = create("TextLabel", {
    Position = UDim2.fromOffset(22, 456), Size = UDim2.new(1, -44, 0, 22),
    BackgroundTransparency = 1, Text = "OFF  •  обычное управление",
    TextColor3 = muted, Font = Enum.Font.GothamMedium, TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

mini = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18),
    Size = UDim2.fromOffset(52, 52), BackgroundColor3 = background,
    BorderSizePixel = 0, Text = "N", TextColor3 = accent,
    Font = Enum.Font.GothamBold, TextSize = 19, Visible = false,
}, gui)
round(mini, 16); border(mini)

local function setPanelVisible(v) panel.Visible = v; dim.Visible = v; mini.Visible = not v end
local function setSpeed(v)
    local n = tonumber(v)
    if n and n == n then speed = math.clamp(math.floor(n), 5, 200) end
    speedBox.Text = tostring(speed)
end

connect(toggle.Activated, function() if enabled then stopAirbreak() else startAirbreak() end end)
connect(flyToggle.Activated, function() if flyEnabled then stopFly() else startFly() end end)
connect(godToggle.Activated, function()
    godmode = not godmode
    if godmode then
        animate(godToggle, {BackgroundColor3 = Color3.fromRGB(64, 101, 65)})
        animate(godToggleKnob, {Position = UDim2.fromOffset(27, 4), BackgroundColor3 = accent})
        if character then enableGodmode(character) end
    else
        animate(godToggle, {BackgroundColor3 = Color3.fromRGB(53, 59, 69)})
        animate(godToggleKnob, {Position = UDim2.fromOffset(4, 4), BackgroundColor3 = muted})
        disableGodmode()
    end
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
connect(player.CharacterRemoving, function() stopAirbreak(); stopFly() end)

if UserInputService.TouchEnabled then
    local function vbtn(label, y)
        local b = create("TextButton", {
            AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, y),
            Size = UDim2.fromOffset(55, 55), BackgroundColor3 = background,
            BackgroundTransparency = 0.15, BorderSizePixel = 0,
            Text = label, TextColor3 = accent, Font = Enum.Font.GothamBold,
            TextSize = 22, Visible = false,
        }, gui)
        round(b, 16); border(b); return b
    end
    upButton = vbtn("↑", -160)
    downButton = vbtn("↓", -95)
    connect(upButton.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then upHeld = true end
    end)
    connect(upButton.InputEnded, function() upHeld = false end)
    connect(downButton.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then downHeld = true end
    end)
    connect(downButton.InputEnded, function() downHeld = false end)
end

-- ═══════════ ХУК НА ЛЮБОЙ УРОН ═══════════
-- Навешиваем на текущего и на новых персонажей
local function hookChar(char)
    if godmode then enableGodmode(char) end
end
if player.Character then hookChar(player.Character) end
player.CharacterAdded:Connect(function(c)
    task.wait(0.1)
    hookChar(c)
end)

local function resize()
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
    scale.Scale = math.clamp(math.min((vp.X - 20) / 420, (vp.Y - 60) / 500), 0.55, 1)
    if UserInputService.TouchEnabled then
        panel.AnchorPoint = Vector2.new(0.5, 0)
        panel.Position = UDim2.new(0.5, 0, 0, 10)
    end
end
resize()
if workspace.CurrentCamera then connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), resize) end

print("[Nexus v4] Spoof + Godmode loaded.")
