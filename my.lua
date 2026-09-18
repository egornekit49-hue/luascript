-- Nexus Fly v4: Рабочий Fly + Airbreak + Brainrot ESP
-- Steal a Brainrot

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local VIM = game:GetService("VirtualInputManager")

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
local espActive = true          -- ESP брейнротов
local chamsActive = true        -- Chams (подсветка)
local useHook = true

local char, hrp, hum
local connections = {}
local healthConn, healthHB
local originalNewIndex
local renderConn, stepConn
local espObjects = {}           -- [model] = {highlight, billboard}

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
        if checkcaller() then
            return originalNewIndex(self, key, value)
        end
        if (flyActive or airbreakActive) and key == "CFrame" and self == hrp then
            return
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

    if isAirbreak then
        stepConn = RunService.Stepped:Connect(function()
            if not airbreakActive or not char then return end
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") then d.CanCollide = false end
            end
        end)
    end

    renderConn = RunService.RenderStepped:Connect(function(dt)
        if not (flyActive or airbreakActive) then return end
        if not refreshChar() then stopMovement(); return end
        if not hrp.Parent then stopMovement(); return end

        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero

        local dir = getMoveDirection()
        if dir.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + dir.Unit * speed * math.min(dt, 0.1)
        end

        pcall(function()
            if hum:GetState() ~= Enum.HumanoidStateType.Running then
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
        end)
    end)
end

-- ═══════════ BRAINROT ESP ═══════════
-- Данные о брейнротах (название -> цена, доход)
local BRAINROT_DATA = {
    -- Common
    ["Noobini Pizzanini"] = {price = 25, income = 1},
    ["Lirili Larila"] = {price = 250, income = 3},
    ["Tim Cheese"] = {price = 500, income = 5},
    ["FluriFlura"] = {price = 750, income = 7},
    ["Trippi Troppi"] = {price = 2000, income = 15},
    -- Rare
    ["Holy Arepa"] = {price = 5000, income = 35},
    -- Epic
    ["Bananita"] = {price = 25000, income = 120},
    -- Legendary
    ["Skibidi Toilet"] = {price = 300000, income = 1000},
    -- Mythic
    ["Rhino Helicopterino"] = {price = 11000, income = 55},
    -- Secret (примеры)
    ["Polaroidini"] = {price = 55000000, income = 55000000},
    ["Signore Carapace"] = {price = 275000000, income = 275000000},
    ["Arcadragon"] = {price = 215000000, income = 215000000},
    ["Elefanto Frigo"] = {price = 185000000, income = 185000000},
    ["Love Love Bear"] = {price = 225000000, income = 225000000},
    ["Antonio"] = {price = 125000000, income = 125000000},
    ["Griffin"] = {price = 400000000, income = 400000000},
    ["Dragon Gingerini"] = {price = 350000000, income = 350000000},
    ["Kalika Bros"] = {price = 115000000, income = 115000000},
    ["Dragon Aquanini"] = {price = 375000000, income = 375000000},
    ["Fishino Clownino"] = {price = 120000000, income = 120000000},
    ["Orchidox"] = {price = 155000000, income = 155000000},
    -- Brainrot God
    ["OG Dragon Gingerini"] = {price = 300000000000, income = 300000000},
}

local function getBrainrotInfo(modelName)
    -- Пытаемся найти название в данных
    for name, data in pairs(BRAINROT_DATA) do
        if modelName:find(name) then
            return name, data.price, data.income
        end
    end
    return modelName, nil, nil
end

local function createBrainrotESP(model)
    if not model:IsA("Model") then return end
    -- Проверяем, похоже ли это на брейнрота (есть Humanoid или PrimaryPart)
    local primary = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
    if not primary then return end

    local name, price, income = getBrainrotInfo(model.Name)

    -- Highlight (Chams)
    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(255, 200, 50)
    hl.FillTransparency = 0.5
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.OutlineTransparency = 0.1
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = model
    hl.Parent = model

    -- Billboard с информацией
    local bill = Instance.new("BillboardGui")
    bill.Size = UDim2.fromOffset(160, 50)
    bill.StudsOffset = Vector3.new(0, 3, 0)
    bill.AlwaysOnTop = true
    bill.Adornee = primary
    bill.Parent = model

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0, 22)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextStrokeTransparency = 0.3
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    nameLabel.Parent = bill

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Position = UDim2.new(0, 0, 0, 22)
    infoLabel.Size = UDim2.new(1, 0, 0, 18)
    infoLabel.BackgroundTransparency = 1
    if price and income then
        infoLabel.Text = "$" .. tostring(price) .. " | +$" .. tostring(income) .. "/s"
    else
        infoLabel.Text = "?"
    end
    infoLabel.TextColor3 = accent
    infoLabel.TextStrokeTransparency = 0.5
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 11
    infoLabel.Parent = bill

    espObjects[model] = {highlight = hl, billboard = bill}
end

local function removeBrainrotESP(model)
    if espObjects[model] then
        pcall(function() espObjects[model].highlight:Destroy() end)
        pcall(function() espObjects[model].billboard:Destroy() end)
        espObjects[model] = nil
    end
end

local function refreshBrainrotESP()
    -- Удаляем старые
    for model in pairs(espObjects) do
        removeBrainrotESP(model)
    end
    if not espActive then return end

    -- Ищем брейнротов в Workspace
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then
            -- Простая эвристика: модель с Humanoid или PrimaryPart, не игрок
            if (obj:FindFirstChildOfClass("Humanoid") or obj.PrimaryPart)
               and not Players:GetPlayerFromCharacter(obj) then
                -- Пропускаем своего персонажа
                if obj ~= char then
                    createBrainrotESP(obj)
                end
            end
        end
    end
end

-- Следим за новыми объектами в Workspace
local function onDescendantAdded(obj)
    if not espActive then return end
    if obj:IsA("Model") and obj ~= char then
        if obj:FindFirstChildOfClass("Humanoid") or obj.PrimaryPart then
            if not Players:GetPlayerFromCharacter(obj) then
                task.wait(0.1)
                createBrainrotESP(obj)
            end
        end
    end
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
    Size = UDim2.fromOffset(430, 680), BackgroundColor3 = background,
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
    BackgroundTransparency = 1, Text = "FLY + ESP  /  v4", TextColor3 = accent,
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

-- ESP Brainrot
local espCard = makeCard("Brainrot ESP", "Названия, цены, доход")
local espToggle, espKnob = makeToggle(espCard)
if espActive then
    espToggle.BackgroundColor3 = Color3.fromRGB(64, 101, 65)
    espKnob.Position = UDim2.fromOffset(27, 4)
    espKnob.BackgroundColor3 = accent
end

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

connect(espToggle.Activated, function()
    espActive = not espActive
    if espActive then
        anim(espToggle, {BackgroundColor3 = Color3.fromRGB(64, 101, 65)})
        anim(espKnob, {Position = UDim2.fromOffset(27, 4), BackgroundColor3 = accent})
        refreshBrainrotESP()
    else
        anim(espToggle, {BackgroundColor3 = Color3.fromRGB(53, 59, 69)})
        anim(espKnob, {Position = UDim2.fromOffset(4, 4), BackgroundColor3 = muted})
        for model in pairs(espObjects) do removeBrainrotESP(model) end
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
    if flyActive or airbreakActive then installHook() end
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
    scale.Scale = math.clamp(math.min((vp.X - 20) / 430, (vp.Y - 60) / 680), 0.5, 1)
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

    -- Показываем кнопки когда fly/airbreak активны
    task.spawn(function()
        while gui.Parent do
            local active = flyActive or airbreakActive
            upBtn.Visible = active
            dnBtn.Visible = active
            task.wait(0.2)
        end
    end)

    connect(upBtn.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            pcall(function() VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game) end)
        end
    end)
    connect(upBtn.InputEnded, function()
        pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game) end)
    end)
    connect(dnBtn.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            pcall(function() VIM:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game) end)
        end
    end)
    connect(dnBtn.InputEnded, function()
        pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game) end)
    end)
end

-- Запускаем ESP при старте
task.spawn(function()
    task.wait(2)
    refreshBrainrotESP()
    -- Следим за новыми брейнротами
    workspace.DescendantAdded:Connect(onDescendantAdded)
end)

print("[Nexus v4] Загружено. Fly, Airbreak, Brainrot ESP.")
