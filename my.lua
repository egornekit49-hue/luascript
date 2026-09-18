-- Nexus Desync v1: Обход позиционного анти-чита через десинхронизацию
-- Для игры Steal a Brainrot

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
local oldAim = CoreGui:FindFirstChild("NexusAim")
if oldAim then oldAim:Destroy() end

local alive = true
local enabled = false
local flyEnabled = false
local speed = 35
local godmode = true
local character, root
local connections = {}
local renderName = "NexusDesync_" .. tostring(player.UserId)
local flyRenderName = "NexusFly_" .. tostring(player.UserId)
local panel, dim, mini
local toggle, toggleKnob, flyToggle, flyToggleKnob, godToggle, godToggleKnob
local stateLabel, speedBox
local upHeld, downHeld = false, false
local upButton, downButton
local mobileControls

local ghost, ghostPrimary
local hiddenParts = {}
local savedCameraSubject, savedCameraType
local healthConn, healthHeartbeat
local savedAnchored
local teleportHold = {}
local cameraForceConn = nil
local desyncConn = nil -- Соединение для десинхронизации

local function connect(signal, callback)
    local c = signal:Connect(callback)
    table.insert(connections, c)
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
local danger = Color3.fromRGB(239, 116, 119)

local gui = create("ScreenGui", {
    Name = "SuperGuiModern", ResetOnSpawn = false, IgnoreGuiInset = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, CoreGui)

-- ═══════════ GROUND ═══════════

local function getGroundPosition(position)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {}
    if character then table.insert(ignore, character) end
    if ghost then table.insert(ignore, ghost) end
    params.FilterDescendantsInstances = ignore

    local origin = Vector3.new(position.X, position.Y + 10, position.Z)
    local ray = workspace:Raycast(origin, Vector3.new(0, -2000, 0), params)
    if ray then return Vector3.new(position.X, ray.Position.Y + 3.5, position.Z) end
    return position
end

-- ═══════════ DESYNC (ключевой механизм) ═══════════

-- Эта функция создаёт иллюзию для сервера, что игрок стоит на месте,
-- в то время как клиент двигается свободно.
local function startDesync()
    if desyncConn then desyncConn:Disconnect() end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Сохраняем исходную позицию для сервера
    local serverPos = hrp.Position

    desyncConn = RunService.Heartbeat:Connect(function()
        if not (enabled or flyEnabled) then return end
        if not hrp.Parent then return end

        -- Отправляем серверу фейковую позицию (ту, где мы "стоим")
        -- Это заставляет сервер думать, что мы не двигаемся.
        -- В реальности же мы двигаем призрака.
        pcall(function()
            hrp.CFrame = CFrame.new(serverPos)
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
    end)
end

local function stopDesync()
    if desyncConn then desyncConn:Disconnect(); desyncConn = nil end
end

-- ═══════════ POSITION LOCK (для телепортов) ═══════════

local function clearLocks()
    for _, c in ipairs(teleportHold) do pcall(function() c:Disconnect() end) end
    teleportHold = {}
end

local function lockPosition(targetCFrame, duration)
    clearLocks()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    char:PivotTo(targetCFrame)

    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)

    local endTime = tick() + (duration or 4)
    local c = RunService.Heartbeat:Connect(function()
        if tick() > endTime or not hrp.Parent then c:Disconnect(); return end
        if (hrp.Position - targetCFrame.Position).Magnitude > 0.5 then
            pcall(function()
                hrp.CFrame = targetCFrame
                hrp.AssemblyLinearVelocity = Vector3.zero
            end)
        end
    end)
    table.insert(teleportHold, c)
end

-- ═══════════ GODMODE ═══════════

local function enableGodmode(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function() hum.MaxHealth = 1e9; hum.Health = 1e9 end)
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
    end)
    if healthConn then healthConn:Disconnect() end
    healthConn = hum:GetPropertyChangedSignal("Health"):Connect(function()
        if godmode and hum.Parent and hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
        end
    end)
    if healthHeartbeat then healthHeartbeat:Disconnect() end
    healthHeartbeat = RunService.Heartbeat:Connect(function()
        if not godmode then return end
        if hum.Parent and hum.Health < hum.MaxHealth then hum.Health = hum.MaxHealth end
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

-- ═══════════ AIM CROSSHAIR ═══════════

local aimGui = create("ScreenGui", {Name = "NexusAim", ResetOnSpawn = false, DisplayOrder = 999, IgnoreGuiInset = true}, CoreGui)
local aimFrame = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1, Visible = false,
}, aimGui)
create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = accent, BorderSizePixel = 0}, aimFrame)
create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = accent, BorderSizePixel = 0}, aimFrame)
create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = accent, BorderSizePixel = 0}, aimFrame)
local aimText = create("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 30),
    Size = UDim2.fromOffset(260, 30), BackgroundColor3 = background, BackgroundTransparency = 0.2,
    Text = "Наведись и кликни ЛКМ / тапни", TextColor3 = text,
    Font = Enum.Font.GothamMedium, TextSize = 12, BorderSizePixel = 0,
}, aimFrame)
round(aimText, 8); border(aimText)

local aimMode = false
local aimClickConn = nil

local function stopAimMode()
    aimMode = false
    aimFrame.Visible = false
    if aimClickConn then aimClickConn:Disconnect(); aimClickConn = nil end
end

local function startAimMode()
    if aimMode then stopAimMode(); return end
    aimMode = true
    aimFrame.Visible = true

    aimClickConn = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
           and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local cam = workspace.CurrentCamera
        if not cam then stopAimMode(); return end
        local sp = (input.UserInputType == Enum.UserInputType.Touch) and input.Position or UserInputService:GetMouseLocation()
        local ray = cam:ViewportPointToRay(sp.X, sp.Y)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local ignore = {}
        if player.Character then table.insert(ignore, player.Character) end
        if ghost then table.insert(ignore, ghost) end
        params.FilterDescendantsInstances = ignore
        local result = workspace:Raycast(ray.Origin, ray.Direction * 8000, params)
        local targetPos = result and (result.Position + Vector3.new(0, 4, 0)) or (ray.Origin + ray.Direction * 500)
        local finalPos = getGroundPosition(targetPos)
        lockPosition(CFrame.new(finalPos), 5)
        if ghost and ghostPrimary and ghostPrimary.Parent then
            ghost:PivotTo(CFrame.new(finalPos))
        end
        stopAimMode()
    end)
end

-- ═══════════ TELEPORT ═══════════

local function teleportToPlayer(targetPlayer)
    if not targetPlayer or targetPlayer == player then return end
    local tChar = targetPlayer.Character
    if not tChar then return end
    local tRoot = tChar:FindFirstChild("HumanoidRootPart")
    if not tRoot then return end
    local finalPos = getGroundPosition(tRoot.Position + Vector3.new(3, 3, 3))
    lockPosition(CFrame.new(finalPos), 5)
    if ghost and ghostPrimary and ghostPrimary.Parent then
        ghost:PivotTo(CFrame.new(finalPos))
    end
end

local function teleportToNearest()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local nearest, dist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local h = plr.Character:FindFirstChild("HumanoidRootPart")
            if h then
                local d = (hrp.Position - h.Position).Magnitude
                if d < dist then dist = d; nearest = plr end
            end
        end
    end
    if nearest then teleportToPlayer(nearest) end
end

-- ═══════════ SPOOF ═══════════

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
    local ghostModel = Instance.new("Model")
    ghostModel.Name = "NexusGhost_" .. tostring(player.UserId)

    local primary
    local copies = {}

    for _, d in ipairs(realChar:GetDescendants()) do
        if d:IsA("BasePart") then
            local copy = d:Clone()
            copy.Anchored = false
            copy.CanCollide = false
            copy.Massless = true
            copy.CanQuery = false
            copy.CanTouch = false
            copy.Transparency = d.Transparency
            copy.Parent = ghostModel
            copies[d] = copy
            if d.Name == "HumanoidRootPart" then primary = copy end
        end
    end

    if not primary then
        ghostModel:Destroy()
        return nil
    end

    ghostModel.PrimaryPart = primary
    primary.Anchored = true

    for origPart, copyPart in pairs(copies) do
        if copyPart ~= primary then
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = primary
            weld.Part1 = copyPart
            weld.Parent = primary
        end
    end

    local hl = Instance.new("Highlight")
    hl.FillColor = accent
    hl.FillTransparency = 0.6
    hl.OutlineColor = accent
    hl.OutlineTransparency = 0.1
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = ghostModel
    hl.Parent = ghostModel

    ghostModel.Parent = workspace
    return ghostModel, primary
end

local function startSpoof(char)
    local currentRoot = char:FindFirstChild("HumanoidRootPart")
    if not currentRoot then return false end
    savedAnchored = currentRoot.Anchored

    local newGhost, newPrimary = buildGhost(char)
    if not newGhost then
        warn("[Nexus] buildGhost вернул nil")
        return false
    end

    newGhost:PivotTo(char:GetPivot())
    ghost, ghostPrimary = newGhost, newPrimary

    hideChar(char)
    currentRoot.Anchored = true

    -- Запускаем десинхронизацию
    startDesync()

    local cam = workspace.CurrentCamera
    if cam then
        savedCameraSubject = cam.CameraSubject
        savedCameraType = cam.CameraType
        cam.CameraSubject = newPrimary
        cam.CameraType = Enum.CameraType.Custom
    end

    if cameraForceConn then cameraForceConn:Disconnect() end
    cameraForceConn = RunService.Heartbeat:Connect(function()
        if not (enabled or flyEnabled) then return end
        if not ghostPrimary or not ghostPrimary.Parent then return end
        local c = workspace.CurrentCamera
        if c and c.CameraSubject ~= ghostPrimary then
            c.CameraSubject = ghostPrimary
            c.CameraType = Enum.CameraType.Custom
        end
    end)

    return true
end

local function stopSpoofAndTeleport()
    stopDesync() -- Останавливаем десинхронизацию

    if cameraForceConn then cameraForceConn:Disconnect(); cameraForceConn = nil end

    if ghost then pcall(function() ghost:Destroy() end) end
    ghost, ghostPrimary = nil, nil
    restoreChar()

    local cam = workspace.CurrentCamera
    if cam and savedCameraSubject then
        pcall(function() cam.CameraSubject = savedCameraSubject end)
        if savedCameraType then cam.CameraType = savedCameraType end
        savedCameraSubject = nil
        savedCameraType = nil
    end
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
    stopSpoofAndTeleport()
    if root and root.Parent then root.Anchored = savedAnchored or false end
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
        stateLabel.TextColor3 = danger
        return
    end

    character, root = cur, curRoot
    enabled = true

    if not startSpoof(cur) then
        enabled = false; character, root = nil, nil
        stateLabel.Text = "Ошибка призрака"
        stateLabel.TextColor3 = danger
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
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) or upHeld then dir = dir + Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or downHeld then dir = dir - Vector3.yAxis end

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
    stateLabel.Text = "ON  •  SPACE/↑ вверх, SHIFT/↓ вниз"
    stateLabel.TextColor3 = accent
end

stopFly = function()
    if not flyEnabled then return end
    flyEnabled = false
    pcall(function() RunService:UnbindFromRenderStep(flyRenderName) end)
    stopSpoofAndTeleport()
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
        stateLabel.TextColor3 = danger
        return
    end

    character, root = cur, curRoot
    flyEnabled = true

    if not startSpoof(cur) then
        flyEnabled = false; character, root = nil, nil
        stateLabel.Text = "Ошибка призрака"
        stateLabel.TextColor3 = danger
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
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) or upHeld then dir = dir + Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or downHeld then dir = dir - Vector3.yAxis end
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
    stateLabel.Text = "FLY ON  •  SPACE/↑ вверх, SHIFT/↓ вниз"
    stateLabel.TextColor3 = accent
end

local function shutdown(destroyGui)
    if not alive then return end
    alive = false
    stopAimMode()
    stopAirbreak()
    stopFly()
    disableGodmode()
    clearLocks()
    for _, c in ipairs(connections) do c:Disconnect() end
    table.clear(connections)
    if destroyGui ~= false and gui and gui.Parent then gui:Destroy() end
    if aimGui and aimGui.Parent then aimGui:Destroy() end
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
    Size = UDim2.fromOffset(430, 640), BackgroundColor3 = background,
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
    BackgroundTransparency = 1, Text = "DESYNC + GHOST  /  SAB", TextColor3 = accent,
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

local scroll = create("ScrollingFrame", {
    Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 1, -78),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 3, ScrollBarImageColor3 = accent,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, panel)
create("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)
create("UIPadding", {
    PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 14),
    PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20),
}, scroll)

local function makeCard(title, desc, height)
    local c = create("Frame", {
        Size = UDim2.new(1, 0, 0, height or 82), BackgroundColor3 = surface,
        BorderSizePixel = 0,
    }, scroll)
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
    return c
end

local function makeToggleIn(parent)
    local tg = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -17, 0.5, 0),
        Size = UDim2.fromOffset(51, 27), BackgroundColor3 = Color3.fromRGB(53, 59, 69),
        BorderSizePixel = 0, Text = "", AutoButtonColor = false,
    }, parent)
    round(tg, 14)
    local kn = create("Frame", {
        Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(19, 19),
        BackgroundColor3 = muted, BorderSizePixel = 0,
    }, tg)
    round(kn, 10)
    return tg, kn
end

local airCard = makeCard("Airbreak (desync)", "Призрак летает, тело стоит")
toggle, toggleKnob = makeToggleIn(airCard)

local flyCard = makeCard("Fly (desync)", "Свободный полёт призраком")
flyToggle, flyToggleKnob = makeToggleIn(flyCard)

local godCard = makeCard("Godmode", "Бессмертие + HP restore")
godToggle, godToggleKnob = makeToggleIn(godCard)
if godmode then
    godToggle.BackgroundColor3 = Color3.fromRGB(64, 101, 65)
    godToggleKnob.Position = UDim2.fromOffset(27, 4)
    godToggleKnob.BackgroundColor3 = accent
end

local speedCard = makeCard("Скорость полёта", "Скорость призрака", 82)
local minus = create("TextButton", {
    Position = UDim2.new(1, -150, 0, 42), Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = background, BorderSizePixel = 0, Text = "−",
    TextColor3 = muted, Font = Enum.Font.GothamBold, TextSize = 17,
}, speedCard)
speedBox = create("TextBox", {
    Position = UDim2.new(1, -118, 0, 42), Size = UDim2.fromOffset(55, 30),
    BackgroundColor3 = background, BorderSizePixel = 0, Text = tostring(speed),
    TextColor3 = text, Font = Enum.Font.GothamBold, TextSize = 12,
    ClearTextOnFocus = false,
}, speedCard)
local plus = create("TextButton", {
    Position = UDim2.new(1, -61, 0, 42), Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = background, BorderSizePixel = 0, Text = "+",
    TextColor3 = accent, Font = Enum.Font.GothamBold, TextSize = 17,
}, speedCard)
for _, o in ipairs({minus, speedBox, plus}) do round(o, 8) end

local tpCard = makeCard("Телепорт", "T = прицел, Y = ближайший", 60)
local function flatBtn(parent, label, x, y, w, h)
    local b = create("TextButton", {
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
        BackgroundColor3 = background, BorderSizePixel = 0,
        Text = label, TextColor3 = accent, Font = Enum.Font.GothamBold,
        TextSize = 11, AutoButtonColor = false,
    }, parent)
    round(b, 8); border(b)
    return b
end
local tpCursorBtn = flatBtn(tpCard, "TP ПО ПРИЦЕЛУ", 16, 14, 175, 34)
local tpNearBtn = flatBtn(tpCard, "К БЛИЖАЙШЕМУ", 205, 14, 175, 34)

local plCard = makeCard("Игроки", "Тапни имя — телепорт", 200)
local playerListFrame = create("ScrollingFrame", {
    Position = UDim2.fromOffset(12, 60), Size = UDim2.new(1, -24, 0, 130),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 2, ScrollBarImageColor3 = accent,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, plCard)
create("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, playerListFrame)

local playerListButtons = {}
local function rebuildPlayerList()
    for _, b in ipairs(playerListButtons) do b:Destroy() end
    playerListButtons = {}
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then table.insert(list, plr) end
    end
    table.sort(list, function(a, b) return a.Name:lower() < b.Name:lower() end)
    if #list == 0 then
        local empty = create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1,
            Text = "Нет других игроков", TextColor3 = muted,
            Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        }, playerListFrame)
        table.insert(playerListButtons, empty)
        return
    end
    for _, plr in ipairs(list) do
        local b = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = background,
            BorderSizePixel = 0, Text = "  " .. plr.Name,
            TextColor3 = text, Font = Enum.Font.GothamMedium, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false,
        }, playerListFrame)
        round(b, 7)
        b.Activated:Connect(function() teleportToPlayer(plr) end)
        table.insert(playerListButtons, b)
    end
end
rebuildPlayerList()
Players.PlayerAdded:Connect(rebuildPlayerList)
Players.PlayerRemoving:Connect(function() task.defer(rebuildPlayerList) end)

stateLabel = create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
    Text = "OFF  •  обычное управление",
    TextColor3 = muted, Font = Enum.Font.GothamMedium, TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 99,
}, scroll)

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
connect(tpCursorBtn.Activated, function() startAimMode() end)
connect(tpNearBtn.Activated, teleportToNearest)
connect(close.Activated, function() setPanelVisible(false) end)
connect(mini.Activated, function() setPanelVisible(true) end)

connect(UserInputService.InputBegan, function(input, processed)
    if processed then return end
    if UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.N then setPanelVisible(not panel.Visible)
    elseif input.KeyCode == Enum.KeyCode.T then startAimMode()
    elseif input.KeyCode == Enum.KeyCode.Y then teleportToNearest() end
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
    scale.Scale = math.clamp(math.min((vp.X - 20) / 430, (vp.Y - 60) / 640), 0.5, 1)
    if UserInputService.TouchEnabled then
        panel.AnchorPoint = Vector2.new(0.5, 0)
        panel.Position = UDim2.new(0.5, 0, 0, 10)
    end
end
resize()
if workspace.CurrentCamera then connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), resize) end

print("[Nexus Desync] Загружено. Спуфинг через десинхронизацию.")
