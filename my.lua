-- Nexus Fly v3: Простой рабочий флай + хук против отката позиции
-- Steal a Brainrot

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

-- Cleanup
for _, name in ipairs({"SuperGuiModern", "NexusAim"}) do
    local old = CoreGui:FindFirstChild(name)
    if old then
        local sd = old:FindFirstChild("NexusShutdown")
        if sd and sd:IsA("BindableFunction") then pcall(function() sd:Invoke() end) end
        old:Destroy()
    end
end

-- ═══════════ SETTINGS ═══════════
local speed = 35
local godmode = true
local flyActive = false
local airbreakActive = false
local useHook = true   -- блокировка отката позиции

local char, hrp, hum
local connections = {}
local healthConn, healthHB
local originalNewIndex
local renderConn, stepConn

local function connect(sig, fn)
    local c = sig:Connect(fn)
    table.insert(connections, c)
    return c
end

local function create(cls, props, parent)
    local o = Instance.new(cls)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end
local function round(o, r) create("UICorner", {CornerRadius = UDim.new(0, r)}, o) end
local function border(o) create("UIStroke", {Color = Color3.fromRGB(54, 62, 73), Transparency = 0.35, Thickness = 1}, o) end
local function anim(o, p, d) local t = TweenService:Create(o, TweenInfo.new(d or 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), p); t:Play(); return t end

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

-- ═══════════ CHARACTER ═══════════
local function refreshChar()
    char = player.Character
    if not char then return false end
    hrp = char:FindFirstChild("HumanoidRootPart")
    hum = char:FindFirstChildOfClass("Humanoid")
    return hrp ~= nil and hum ~= nil
end

-- ═══════════ GODMODE ═══════════
local function enableGodmode()
    if not refreshChar() then return end
    pcall(function() hum.MaxHealth = 1e9; hum.Health = 1e9 end)
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    end)
    if healthConn then healthConn:Disconnect() end
    healthConn = hum:GetPropertyChangedSignal("Health"):Connect(function()
        if godmode and hum.Parent and hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
        end
    end)
    if healthHB then healthHB:Disconnect() end
    healthHB = RunService.Heartbeat:Connect(function()
        if not godmode then return end
        if hum.Parent and hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
        end
    end)
end

local function disableGodmode()
    if healthConn then healthConn:Disconnect(); healthConn = nil end
    if healthHB then healthHB:Disconnect(); healthHB = nil end
end

-- ═══════════ HOOK (блокировка отката позиции) ═══════════
local function installHook()
    if originalNewIndex or not useHook then return end
    local ok, mt = pcall(getrawmetatable, game)
    if not ok or not mt then return end
    originalNewIndex = mt.__newindex
    if not originalNewIndex then return end

    setreadonly(mt, false)
    mt.__newindex = newcclosure(function(self, key, value)
        -- Свои скрипты пропускаем
        if checkcaller() then
            return originalNewIndex(self, key, value)
        end
        -- ★ Блокируем ТОЛЬКО попытки игры перезаписать CFrame нашего HRP
        if (flyActive or airbreakActive) and key == "CFrame" and self == hrp then
            return  -- игнорируем
        end
        return originalNewIndex(self, key, value)
    end)
    setreadonly(mt, true)
end

local function uninstallHook()
    if not originalNewIndex then return end
    local ok, mt = pcall(getrawmetatable, game)
    if ok and mt then
        pcall(function()
            setreadonly(mt, false)
            mt.__newindex = originalNewIndex
            setreadonly(mt, true)
        end)
    end
    originalNewIndex = nil
end

-- ═══════════ FLY / AIRBREAK ═══════════
local function getMoveDirection()
    local cam = workspace.CurrentCamera
    if not cam then return Vector3.zero end
    local dir = Vector3.zero
    local look, right = cam.CFrame.LookVector, cam.CFrame.RightVector

    if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + look end
    if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - look end
    if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + right end
    if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - right end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.yAxis end
    if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.yAxis end

    if UIS.TouchEnabled then
        local vec = Vector3.zero
        pcall(function()
            local ps = player:FindFirstChild("PlayerScripts")
            local m = ps and ps:FindFirstChild("PlayerModule")
            if m then vec = require(m):GetControls():GetMoveVector() end
        end)
        if vec.Magnitude > 0 then
            local fl = Vector3.new(look.X, 0, look.Z)
            local fr = Vector3.new(right.X, 0, right.Z)
            if fl.Magnitude > 0 then fl = fl.Unit end
            if fr.Magnitude > 0 then fr = fr.Unit end
            dir = dir + fr * vec.X - fl * vec.Z
        end
    end
    return dir
end

local function stopMovement()
    flyActive = false
    airbreakActive = false
    if renderConn then renderConn:Disconnect(); renderConn = nil end
    if stepConn then stepConn:Disconnect(); stepConn = nil end
    uninstallHook()
    -- Вернуть коллизии
    if char then
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") then
                d.CanCollide = true
            end
        end
    end
end

local function startMovement(isAirbreak)
    if not refreshChar() then return end
    if hum.Health <= 0 then return end

    stopMovement()
    flyActive = not isAirbreak
    airbreakActive = isAirbreak

    installHook()

    -- Noclip для airbreak
    if isAirbreak then
        stepConn = RunService.Stepped:Connect(function()
            if not airbreakActive or not char then return end
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") then d.CanCollide = false end
            end
        end)
    end

    -- ★ ДВИЖЕНИЕ: переписываем CFrame каждый кадр
    renderConn = RunService.RenderStepped:Connect(function(dt)
        if not (flyActive or airbreakActive) then return end
        if not refreshChar() then stopMovement(); return end
        if not hrp.Parent then stopMovement(); return end

        -- Обнуляем физику
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero

        -- ★ Пишем CFrame напрямую (из нашего скрипта — hook пропускает)
        local dir = getMoveDirection()
        if dir.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + dir.Unit * speed * math.min(dt, 0.1)
        end

        -- Чтобы игра не ресетила и не думала что ты падаешь — Running
        pcall(function()
            if hum:GetState() ~= Enum.HumanoidStateType.Running then
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
        end)
    end)
end

-- ═══════════ AIM TELEPORT ═══════════
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
    Text = "Тапни / кликни ЛКМ — телепорт", TextColor3 = text,
    Font = Enum.Font.GothamMedium, TextSize = 12, BorderSizePixel = 0,
}, aimFrame)
round(aimText, 8); border(aimText)

local aimMode = false
local aimClickConn = nil

local function stopAim()
    aimMode = false
    aimFrame.Visible = false
    if aimClickConn then aimClickConn:Disconnect(); aimClickConn = nil end
end

local function doTeleport(targetPos)
    if not refreshChar() then return end
    if not hrp.Parent then return end
    -- Ставим позицию
    hrp.CFrame = CFrame.new(targetPos)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
end

local function startAim()
    if aimMode then stopAim(); return end
    aimMode = true
    aimFrame.Visible = true

    aimClickConn = UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
           and input.UserInputType ~= Enum.UserInputType.Touch then return end

        local cam = workspace.CurrentCamera
        if not cam then stopAim(); return end
        local sp = (input.UserInputType == Enum.UserInputType.Touch) and input.Position or UIS:GetMouseLocation()
        local ray = cam:ViewportPointToRay(sp.X, sp.Y)

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local ignore = {}
        if player.Character then table.insert(ignore, player.Character) end
        params.FilterDescendantsInstances = ignore

        local result = workspace:Raycast(ray.Origin, ray.Direction * 8000, params)
        local targetPos = result and (result.Position + Vector3.new(0, 4, 0)) or (ray.Origin + ray.Direction * 300)
        doTeleport(targetPos)
        stopAim()
    end)
end

local function teleportToPlayer(plr)
    if not plr or plr == player then return end
    local t = plr.Character
    if not t then return end
    local th = t:FindFirstChild("HumanoidRootPart")
    if not th then return end
    doTeleport(th.Position + Vector3.new(0, 4, 0))
end

local function teleportNearest()
    if not refreshChar() then return end
    local nearest, dist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local h = p.Character:FindFirstChild("HumanoidRootPart")
            if h then
                local d = (hrp.Position - h.Position).Magnitude
                if d < dist then dist = d; nearest = p end
            end
        end
    end
    if nearest then teleportToPlayer(nearest) end
end

-- ═══════════ UI ═══════════
local dim = create("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = UIS.TouchEnabled and 0.7 or 1, BorderSizePixel = 0, Active = false,
}, gui)

local panel = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(430, 620), BackgroundColor3 = background,
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
    BackgroundTransparency = 1, Text = "FLY + HOOK  /  v3", TextColor3 = accent,
    Font = Enum.Font.GothamMedium, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
}, header)
local close = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18),
    Size = UDim2.fromOffset(34, 34), BackgroundColor3 = surface,
    BorderSizePixel = 0, Text = "×", TextColor3 = muted,
    Font = Enum.Font.GothamMedium, TextSize = 22, AutoButtonColor = false,
}, header)
round(close, 9)

create("Frame", {Position = UDim2.fromOffset(20, 76), Size = UDim2.new(1, -40, 0, 1), BackgroundColor3 = Color3.fromRGB(49, 55, 65), BorderSizePixel = 0}, panel)

local scroll = create("ScrollingFrame", {
    Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 1, -78),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 3, ScrollBarImageColor3 = accent,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, panel)
create("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)
create("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20)}, scroll)

local function makeCard(title, desc, h)
    local c = create("Frame", {Size = UDim2.new(1, 0, 0, h or 82), BackgroundColor3 = surface, BorderSizePixel = 0}, scroll)
    round(c, 12); border(c)
    create("TextLabel", {Position = UDim2.fromOffset(16, 13), Size = UDim2.new(1, -96, 0, 22), BackgroundTransparency = 1, Text = title, TextColor3 = text, Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left}, c)
    create("TextLabel", {Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -96, 0, 18), BackgroundTransparency = 1, Text = desc, TextColor3 = muted, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, c)
    return c
end

local function makeToggle(parent)
    local tg = create("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -17, 0.5, 0), Size = UDim2.fromOffset(51, 27), BackgroundColor3 = Color3.fromRGB(53, 59, 69), BorderSizePixel = 0, Text = "", AutoButtonColor = false}, parent)
    round(tg, 14)
    local kn = create("Frame", {Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(19, 19), BackgroundColor3 = muted, BorderSizePixel = 0}, tg)
    round(kn, 10)
    return tg, kn
end

-- Fly
local flyCard = makeCard("Fly", "Свободный полёт (SPACE/SHIFT)")
local flyToggle, flyKnob = makeToggle(flyCard)

-- Airbreak
local abCard = makeCard("Airbreak", "Полёт сквозь стены")
local abToggle, abKnob = makeToggle(abCard)

-- Godmode
local godCard = makeCard("Godmode", "Бессмертие + HP restore")
local godToggle, godKnob = makeToggle(godCard)
if godmode then
    godToggle.BackgroundColor3 = Color3.fromRGB(64, 101, 65)
    godKnob.Position = UDim2.fromOffset(27, 4)
    godKnob.BackgroundColor3 = accent
end

-- Speed
local spCard = makeCard("Скорость", "Скорость полёта", 82)
local minus = create("TextButton", {Position = UDim2.new(1, -150, 0, 42), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = background, BorderSizePixel = 0, Text = "−", TextColor3 = muted, Font = Enum.Font.GothamBold, TextSize = 17}, spCard)
local spBox = create("TextBox", {Position = UDim2.new(1, -118, 0, 42), Size = UDim2.fromOffset(55, 30), BackgroundColor3 = background, BorderSizePixel = 0, Text = tostring(speed), TextColor3 = text, Font = Enum.Font.GothamBold, TextSize = 12, ClearTextOnFocus = false}, spCard)
local plus = create("TextButton", {Position = UDim2.new(1, -61, 0, 42), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = background, BorderSizePixel = 0, Text = "+", TextColor3 = accent, Font = Enum.Font.GothamBold, TextSize = 17}, spCard)
for _, o in ipairs({minus, spBox, plus}) do round(o, 8) end

-- Teleport
local tpCard = makeCard("Телепорт", "T = прицел, Y = ближайший", 60)
local function flatBtn(parent, label, x, y, w, h)
    local b = create("TextButton", {Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = background, BorderSizePixel = 0, Text = label, TextColor3 = accent, Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false}, parent)
    round(b, 8); border(b)
    return b
end
local tpAim = flatBtn(tpCard, "TP ПО ПРИЦЕЛУ", 16, 14, 175, 34)
local tpNear = flatBtn(tpCard, "К БЛИЖАЙШЕМУ", 205, 14, 175, 34)

-- Player list
local plCard = makeCard("Игроки", "Тапни имя — телепорт", 200)
local plList = create("ScrollingFrame", {
    Position = UDim2.fromOffset(12, 60), Size = UDim2.new(1, -24, 0, 130),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 2, ScrollBarImageColor3 = accent,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, plCard)
create("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, plList)

local plButtons = {}
local function rebuildList()
    for _, b in ipairs(plButtons) do b:Destroy() end
    plButtons = {}
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then table.insert(list, p) end
    end
    table.sort(list, function(a, b) return a.Name:lower() < b.Name:lower() end)
    if #list == 0 then
        local e = create("TextLabel", {Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "Нет игроков", TextColor3 = muted, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, plList)
        table.insert(plButtons, e)
        return
    end
    for _, p in ipairs(list) do
        local b = create("TextButton", {Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = background, BorderSizePixel = 0, Text = "  " .. p.Name, TextColor3 = text, Font = Enum.Font.GothamMedium, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false}, plList)
        round(b, 7)
        b.Activated:Connect(function() teleportToPlayer(p) end)
        table.insert(plButtons, b)
    end
end
rebuildList()
Players.PlayerAdded:Connect(rebuildList)
Players.PlayerRemoving:Connect(function() task.defer(rebuildList) end)

local stateLabel = create("TextLabel", {Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Text = "Готово", TextColor3 = muted, Font = Enum.Font.GothamMedium, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 99}, scroll)

local mini = create("TextButton", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = background, BorderSizePixel = 0, Text = "N", TextColor3 = accent, Font = Enum.Font.GothamBold, TextSize = 19, Visible = false}, gui)
round(mini, 16); border(mini)

local function setPanel(v) panel.Visible = v; dim.Visible = v; mini.Visible = not v end

local function setFly(on)
    anim(flyToggle, {BackgroundColor3 = on and Color3.fromRGB(64, 101, 65) or Color3.fromRGB(53, 59, 69)})
    anim(flyKnob, {Position = on and UDim2.fromOffset(27, 4) or UDim2.fromOffset(4, 4), BackgroundColor3 = on and accent or muted})
end
local function setAB(on)
    anim(abToggle, {BackgroundColor3 = on and Color3.fromRGB(64, 101, 65) or Color3.fromRGB(53, 59, 69)})
    anim(abKnob, {Position = on and UDim2.fromOffset(27, 4) or UDim2.fromOffset(4, 4), BackgroundColor3 = on and accent or muted})
end

connect(flyToggle.Activated, function()
    if flyActive then
        stopMovement(); setFly(false); stateLabel.Text = "OFF"
    else
        startMovement(false)
        if flyActive then setFly(true); setAB(false); stateLabel.Text = "FLY ON — SPACE вверх, SHIFT вниз" end
    end
end)

connect(abToggle.Activated, function()
    if airbreakActive then
        stopMovement(); setAB(false); stateLabel.Text = "OFF"
    else
        startMovement(true)
        if airbreakActive then setAB(true); setFly(false); stateLabel.Text = "AIRBREAK ON" end
    end
end)

connect(godToggle.Activated, function()
    godmode = not godmode
    if godmode then
        anim(godToggle, {BackgroundColor3 = Color3.fromRGB(64, 101, 65)})
        anim(godKnob, {Position = UDim2.fromOffset(27, 4), BackgroundColor3 = accent})
        enableGodmode()
    else
        anim(godToggle, {BackgroundColor3 = Color3.fromRGB(53, 59, 69)})
        anim(godKnob, {Position = UDim2.fromOffset(4, 4), BackgroundColor3 = muted})
        disableGodmode()
    end
end)

connect(minus.Activated, function() speed = math.clamp(speed - 5, 5, 200); spBox.Text = tostring(speed) end)
connect(plus.Activated, function() speed = math.clamp(speed + 5, 5, 200); spBox.Text = tostring(speed) end)
connect(spBox.FocusLost, function() speed = math.clamp(tonumber(spBox.Text) or speed, 5, 200); spBox.Text = tostring(speed) end)
connect(tpAim.Activated, startAim)
connect(tpNear.Activated, teleportNearest)
connect(close.Activated, function() setPanel(false) end)
connect(mini.Activated, function() setPanel(true) end)

connect(UIS.InputBegan, function(input, processed)
    if processed then return end
    if UIS:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.N then setPanel(not panel.Visible)
    elseif input.KeyCode == Enum.KeyCode.T then startAim()
    elseif input.KeyCode == Enum.KeyCode.Y then teleportNearest() end
end)

-- Auto refresh on respawn
player.CharacterAdded:Connect(function()
    task.wait(0.3)
    refreshChar()
    if godmode then enableGodmode() end
    -- Пересоздать hook если активен
    if flyActive or airbreakActive then
        installHook()
    end
end)
connect(player.CharacterRemoving, function()
    stopMovement()
    setFly(false); setAB(false)
end)

refreshChar()
if godmode then enableGodmode() end

-- Scale
local function resize()
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
    scale.Scale = math.clamp(math.min((vp.X - 20) / 430, (vp.Y - 60) / 620), 0.5, 1)
    if UIS.TouchEnabled then
        panel.AnchorPoint = Vector2.new(0.5, 0)
        panel.Position = UDim2.new(0.5, 0, 0, 10)
    end
end
resize()
if workspace.CurrentCamera then connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), resize) end

-- Мобильные кнопки
if UIS.TouchEnabled then
    local function vbtn(label, y)
        local b = create("TextButton", {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, y), Size = UDim2.fromOffset(55, 55), BackgroundColor3 = background, BackgroundTransparency = 0.15, BorderSizePixel = 0, Text = label, TextColor3 = accent, Font = Enum.Font.GothamBold, TextSize = 22, Visible = false}, gui)
        round(b, 16); border(b); return b
    end
    local upBtn = vbtn("↑", -160)
    local dnBtn = vbtn("↓", -95)
    connect(UIS.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.Touch then
            if i.Position and upBtn.Visible and dnBtn.Visible then end
        end
    end)
    connect(upBtn.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            -- эмулируем клавишу
            pcall(function()
                local vim = game:GetService("VirtualInputManager")
                vim:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            end)
        end
    end)
    connect(upBtn.InputEnded, function()
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
    end)
    connect(dnBtn.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            pcall(function()
                local vim = game:GetService("VirtualInputManager")
                vim:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game)
            end)
        end
    end)
    connect(dnBtn.InputEnded, function()
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
        end)
    end)
    -- Показываем кнопки когда fly/airbreak активны
    task.spawn(function()
        while gui.Parent do
            local active = flyActive or airbreakActive
            upBtn.Visible = active
            dnBtn.Visible = active
            task.wait(0.2)
        end
    end)
end

print("[Nexus v3] Загружено. Fly/Airbreak работают через CFrame + hook.")
