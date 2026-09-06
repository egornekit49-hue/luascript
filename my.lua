-- Универсальный скрипт: Speed + Fly + Auto-Punch (Anti-Block)
-- Для Boxing Beta (и других игр)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

-- ====== НАСТРОЙКИ ======
local SPEED = 50               -- скорость бега/полёта (без ограничений)
local STEP = 4                 -- шаг кнопок +/-
local FLY_SPEED = 50           -- скорость полёта (используется та же SPEED, но можно разделить)
local PUNCH_DELAY = 500        -- задержка между ударами (мс)
local BLOCK_SPEED_THRESHOLD = 0.5  -- порог WalkSpeed, при котором считаем, что игрок блокирует

-- ====== GUI ======
local gui = Instance.new("ScreenGui")
gui.Name = "SuperGui"
gui.Parent = game:GetService("CoreGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(300, 280)
panel.Position = UDim2.new(0, 10, 1, -290)
panel.BackgroundColor3 = Color3.fromRGB(30, 60, 30)  -- тёмно-зелёный
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -24, 0, 32)
title.Position = UDim2.fromOffset(12, 8)
title.BackgroundTransparency = 1
title.Text = "Speed + Fly + Anti-Block"
title.TextColor3 = Color3.new(0.7, 1, 0.7)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

-- ====== СКОРОСТЬ ======
local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.fromOffset(60, 26)
speedLabel.Position = UDim2.fromOffset(12, 48)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "Speed:"
speedLabel.TextColor3 = Color3.new(0.8, 1, 0.8)
speedLabel.Font = Enum.Font.GothamBold
speedLabel.TextSize = 16
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Parent = panel

local valueBox = Instance.new("TextBox")
valueBox.Size = UDim2.fromOffset(70, 30)
valueBox.Position = UDim2.fromOffset(80, 44)
valueBox.BackgroundColor3 = Color3.fromRGB(44, 49, 62)
valueBox.BorderSizePixel = 0
valueBox.Text = tostring(SPEED)
valueBox.TextColor3 = Color3.new(1, 1, 1)
valueBox.Font = Enum.Font.GothamBold
valueBox.TextSize = 18
valueBox.ClearTextOnFocus = false
valueBox.Parent = panel
Instance.new("UICorner", valueBox).CornerRadius = UDim.new(0, 7)

local decrease = Instance.new("TextButton")
decrease.Size = UDim2.fromOffset(40, 30)
decrease.Position = UDim2.fromOffset(160, 44)
decrease.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
decrease.BorderSizePixel = 0
decrease.Text = "-"
decrease.TextColor3 = Color3.new(1, 1, 1)
decrease.Font = Enum.Font.GothamBold
decrease.TextSize = 24
decrease.Parent = panel
Instance.new("UICorner", decrease).CornerRadius = UDim.new(0, 7)

local increase = Instance.new("TextButton")
increase.Size = UDim2.fromOffset(40, 30)
increase.Position = UDim2.fromOffset(210, 44)
increase.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
increase.BorderSizePixel = 0
increase.Text = "+"
increase.TextColor3 = Color3.new(1, 1, 1)
increase.Font = Enum.Font.GothamBold
increase.TextSize = 24
increase.Parent = panel
Instance.new("UICorner", increase).CornerRadius = UDim.new(0, 7)

-- ====== ПОЛЁТ ======
local flyButton = Instance.new("TextButton")
flyButton.Size = UDim2.fromOffset(100, 32)
flyButton.Position = UDim2.fromOffset(12, 88)
flyButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
flyButton.BorderSizePixel = 0
flyButton.Text = "Fly: OFF"
flyButton.TextColor3 = Color3.new(1, 1, 1)
flyButton.Font = Enum.Font.GothamBold
flyButton.TextSize = 18
flyButton.Parent = panel
Instance.new("UICorner", flyButton).CornerRadius = UDim.new(0, 7)

-- ====== АВТО-УДАР ======
local autoLabel = Instance.new("TextLabel")
autoLabel.Size = UDim2.fromOffset(100, 26)
autoLabel.Position = UDim2.fromOffset(12, 132)
autoLabel.BackgroundTransparency = 1
autoLabel.Text = "Auto-Punch: OFF"
autoLabel.TextColor3 = Color3.fromRGB(1, 0.5, 0.5)
autoLabel.Font = Enum.Font.GothamBold
autoLabel.TextSize = 16
autoLabel.TextXAlignment = Enum.TextXAlignment.Left
autoLabel.Parent = panel

local toggleAuto = Instance.new("TextButton")
toggleAuto.Size = UDim2.fromOffset(80, 32)
toggleAuto.Position = UDim2.fromOffset(120, 128)
toggleAuto.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
toggleAuto.BorderSizePixel = 0
toggleAuto.Text = "Вкл"
toggleAuto.TextColor3 = Color3.new(1, 1, 1)
toggleAuto.Font = Enum.Font.GothamBold
toggleAuto.TextSize = 18
toggleAuto.Parent = panel
Instance.new("UICorner", toggleAuto).CornerRadius = UDim.new(0, 7)

local delayLabel = Instance.new("TextLabel")
delayLabel.Size = UDim2.fromOffset(70, 26)
delayLabel.Position = UDim2.fromOffset(12, 176)
delayLabel.BackgroundTransparency = 1
delayLabel.Text = "Delay (ms):"
delayLabel.TextColor3 = Color3.new(0.8, 1, 0.8)
delayLabel.Font = Enum.Font.Gotham
delayLabel.TextSize = 14
delayLabel.TextXAlignment = Enum.TextXAlignment.Left
delayLabel.Parent = panel

local delayBox = Instance.new("TextBox")
delayBox.Size = UDim2.fromOffset(60, 26)
delayBox.Position = UDim2.fromOffset(100, 172)
delayBox.BackgroundColor3 = Color3.fromRGB(44, 49, 62)
delayBox.BorderSizePixel = 0
delayBox.Text = tostring(PUNCH_DELAY)
delayBox.TextColor3 = Color3.new(1, 1, 1)
delayBox.Font = Enum.Font.GothamBold
delayBox.TextSize = 16
delayBox.ClearTextOnFocus = false
delayBox.Parent = panel
Instance.new("UICorner", delayBox).CornerRadius = UDim.new(0, 7)

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -24, 0, 26)
hint.Position = UDim2.fromOffset(12, 212)
hint.BackgroundTransparency = 1
hint.Text = "WASD + Space/Shift (Fly)"
hint.TextColor3 = Color3.fromRGB(185, 190, 205)
hint.Font = Enum.Font.Gotham
hint.TextSize = 13
hint.Parent = panel

-- ====== ЛОГИКА СКОРОСТИ ======
local function getHumanoid()
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChild("Humanoid")
end

local function setSpeed(newSpeed)
    local val = tonumber(newSpeed)
    if val then SPEED = val end
    valueBox.Text = tostring(SPEED)
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = SPEED end
end

decrease.Activated:Connect(function() setSpeed(SPEED - STEP) end)
increase.Activated:Connect(function() setSpeed(SPEED + STEP) end)
valueBox.FocusLost:Connect(function() setSpeed(valueBox.Text) end)

-- Постоянное обновление скорости (против сбросов)
RunService.Heartbeat:Connect(function()
    local hum = getHumanoid()
    if hum and hum.WalkSpeed ~= SPEED then hum.WalkSpeed = SPEED end
end)

player.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid")
    hum.WalkSpeed = SPEED
end)
task.wait(0.5)
setSpeed(SPEED)

-- ====== ЛОГИКА ПОЛЁТА ======
local flying = false
local flyBV, flyBG, flyConn

local function startFly()
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not root or not hum then return end
    hum.PlatformStand = true
    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    flyBV.Parent = root
    flyBG = Instance.new("BodyGyro")
    flyBG.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    flyBG.Parent = root
    local function update()
        if not root or not flyBV then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local fwd = cam.CFrame.LookVector
        local right = cam.CFrame.RightVector
        local up = cam.CFrame.UpVector
        local dir = Vector3.new(0,0,0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + fwd end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - fwd end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - right end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + right end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + up end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - up end
        if dir.Magnitude > 0 then dir = dir.Unit * SPEED else dir = Vector3.new(0,0,0) end
        flyBV.Velocity = dir
        if dir.Magnitude > 0.1 then
            flyBG.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
        end
    end
    flyConn = RunService.Heartbeat:Connect(update)
    flying = true
    flyButton.Text = "Fly: ON"
    flyButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
end

local function stopFly()
    if flyConn then flyConn:Disconnect() flyConn = nil end
    if flyBV then flyBV:Destroy() flyBV = nil end
    if flyBG then flyBG:Destroy() flyBG = nil end
    local hum = getHumanoid()
    if hum then hum.PlatformStand = false end
    flying = false
    flyButton.Text = "Fly: OFF"
    flyButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
end

flyButton.Activated:Connect(function()
    if flying then stopFly() else startFly() end
end)
player.CharacterAdded:Connect(function()
    if flying then stopFly() end
end)

-- ====== АВТО-УДАР (ANTI-BLOCK) ======
local isAutoOn = false
local wasBlocking = false
local lastPunchTime = 0

-- Поиск RemoteEvent для удара (глубже)
local function findPunchRemote()
    local candidates = {}
    -- Ищем во всех сервисах
    for _, service in ipairs({ReplicatedStorage, game:GetService("Players"), game:GetService("Workspace")}) do
        for _, obj in ipairs(service:GetDescendants()) do
            if obj:IsA("RemoteEvent") and (string.lower(obj.Name):find("punch") or string.lower(obj.Name):find("hit") or string.lower(obj.Name):find("attack") or string.lower(obj.Name):find("damage")) then
                table.insert(candidates, obj)
            end
        end
    end
    -- Если несколько, берём тот, у которого имя наиболее подходящее
    for _, ev in ipairs(candidates) do
        if string.lower(ev.Name):find("punch") then return ev end
    end
    return candidates[1] -- или nil
end
local punchRemote = findPunchRemote()
if punchRemote then
    print("[Auto-Punch] RemoteEvent найден:", punchRemote.Name)
else
    print("[Auto-Punch] RemoteEvent не найден, будет попытка через клавишу Q")
end

-- Функция удара
local function punch()
    if punchRemote then
        -- Попробуем вызвать без аргументов или с пустой таблицей
        local success, err = pcall(function()
            punchRemote:FireServer()
        end)
        if not success then
            -- Если не сработало, попробуем с аргументом
            pcall(function()
                punchRemote:FireServer({})
            end)
        end
    else
        -- Альтернатива: эмуляция клавиши Q (если удар привязан к Q)
        UserInputService:SetKeyDown(Enum.KeyCode.Q)
        task.wait(0.05)
        UserInputService:SetKeyUp(Enum.KeyCode.Q)
    end
end

local function getNearestEnemy()
    local char = player.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local nearest, minDist = nil, math.huge
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player then
            local oChar = other.Character
            if oChar then
                local oRoot = oChar:FindFirstChild("HumanoidRootPart")
                if oRoot then
                    local dist = (root.Position - oRoot.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        nearest = oChar
                    end
                end
            end
        end
    end
    return nearest
end

local function isBlocking(char)
    local hum = char and char:FindFirstChild("Humanoid")
    if not hum then return false end
    -- Проверяем скорость (может падать при блоке)
    if hum.WalkSpeed <= BLOCK_SPEED_THRESHOLD then
        return true
    end
    -- Проверяем анимацию
    local animator = hum:FindFirstChild("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            if track.Animation and track.Animation.Name and string.lower(track.Animation.Name):find("block") then
                return true
            end
        end
    end
    return false
end

local function autoPunchLoop()
    while isAutoOn do
        local enemy = getNearestEnemy()
        if enemy then
            local nowBlocking = isBlocking(enemy)
            -- Переход: был блок -> сейчас не блок
            if wasBlocking and not nowBlocking then
                local currentTime = tick() * 1000
                if currentTime - lastPunchTime >= PUNCH_DELAY then
                    punch()
                    lastPunchTime = currentTime
                end
            end
            wasBlocking = nowBlocking
        else
            wasBlocking = false
        end
        task.wait(0.05)
    end
end

toggleAuto.Activated:Connect(function()
    isAutoOn = not isAutoOn
    if isAutoOn then
        autoLabel.Text = "Auto-Punch: ON"
        autoLabel.TextColor3 = Color3.fromRGB(0.5, 1, 0.5)
        toggleAuto.Text = "Выкл"
        wasBlocking = false
        lastPunchTime = 0
        task.spawn(autoPunchLoop)
    else
        autoLabel.Text = "Auto-Punch: OFF"
        autoLabel.TextColor3 = Color3.fromRGB(1, 0.5, 0.5)
        toggleAuto.Text = "Вкл"
        wasBlocking = false
    end
end)

delayBox.FocusLost:Connect(function()
    local newDelay = tonumber(delayBox.Text)
    if newDelay and newDelay >= 0 then
        PUNCH_DELAY = newDelay
    else
        delayBox.Text = tostring(PUNCH_DELAY)
    end
end)

print("[SuperScript] Загружен. Скорость, полёт и авто-удар активны.")
