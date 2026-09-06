-- Auto-Punch для Boxing Beta (Mobile-версия)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- ====== НАСТРОЙКИ ======
local PUNCH_DELAY = 500   -- задержка между ударами (мс)
local BLOCK_SPEED = 0.5   -- порог скорости для определения блока

-- ====== GUI (как был, без изменений) ======
local gui = Instance.new("ScreenGui")
gui.Name = "AutoPunchGui"
gui.Parent = game:GetService("CoreGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(260, 120)
panel.Position = UDim2.new(0, 20, 1, -140)
panel.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -24, 0, 32)
title.Position = UDim2.fromOffset(12, 8)
title.BackgroundTransparency = 1
title.Text = "Auto-Punch (Anti-Block)"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.fromOffset(120, 26)
statusLabel.Position = UDim2.fromOffset(12, 48)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: OFF"
statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 16
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = panel

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.fromOffset(80, 32)
toggleButton.Position = UDim2.fromOffset(170, 44)
toggleButton.BackgroundColor3 = Color3.fromRGB(65, 104, 190)
toggleButton.BorderSizePixel = 0
toggleButton.Text = "Вкл"
toggleButton.TextColor3 = Color3.new(1, 1, 1)
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 18
toggleButton.Parent = panel
Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(0, 7)

local delayBox = Instance.new("TextBox")
delayBox.Size = UDim2.fromOffset(60, 26)
delayBox.Position = UDim2.fromOffset(80, 84)
delayBox.BackgroundColor3 = Color3.fromRGB(44, 49, 62)
delayBox.BorderSizePixel = 0
delayBox.Text = tostring(PUNCH_DELAY)
delayBox.TextColor3 = Color3.new(1, 1, 1)
delayBox.Font = Enum.Font.GothamBold
delayBox.TextSize = 16
delayBox.ClearTextOnFocus = false
delayBox.Parent = panel
Instance.new("UICorner", delayBox).CornerRadius = UDim.new(0, 7)

local delayLabel = Instance.new("TextLabel")
delayLabel.Size = UDim2.fromOffset(70, 26)
delayLabel.Position = UDim2.fromOffset(12, 84)
delayLabel.BackgroundTransparency = 1
delayLabel.Text = "Задержка (мс):"
delayLabel.TextColor3 = Color3.fromRGB(185, 190, 205)
delayLabel.Font = Enum.Font.Gotham
delayLabel.TextSize = 13
delayLabel.TextXAlignment = Enum.TextXAlignment.Left
delayLabel.Parent = panel

-- ====== ПОИСК REMOTEEVENT ДЛЯ УДАРА ======
local punchRemote = nil
for _, service in ipairs({game:GetService("ReplicatedStorage"), game:GetService("Players").LocalPlayer.PlayerGui}) do
    for _, obj in ipairs(service:GetChildren()) do
        if obj:IsA("RemoteEvent") and (string.lower(obj.Name):find("punch") or string.lower(obj.Name):find("hit") or string.lower(obj.Name):find("attack")) then
            punchRemote = obj
            print("[Auto-Punch] Найден RemoteEvent для удара:", obj.Name)
            break
        end
    end
    if punchRemote then break end
end

-- ====== ЛОГИКА ======
local isRunning = false
local lastPunchTime = 0

local function getNearestEnemy()
    local character = player.Character
    if not character then return nil end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end

    local nearest = nil
    local nearestDist = math.huge
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            local otherChar = otherPlayer.Character
            if otherChar then
                local otherRoot = otherChar:FindFirstChild("HumanoidRootPart")
                if otherRoot then
                    local dist = (rootPart.Position - otherRoot.Position).Magnitude
                    if dist < nearestDist then
                        nearestDist = dist
                        nearest = otherChar
                    end
                end
            end
        end
    end
    return nearest
end

local function isBlocking(character)
    local humanoid = character and character:FindFirstChild("Humanoid")
    if not humanoid then return false end
    if humanoid.WalkSpeed <= BLOCK_SPEED then
        return true
    end
    return false
end

-- ИСПРАВЛЕННАЯ ФУНКЦИЯ УДАРА ДЛЯ ТЕЛЕФОНА
local function punch()
    if punchRemote then
        -- Если нашли RemoteEvent – используем его
        punchRemote:FireServer()
    else
        -- Иначе эмулируем касание в центре экрана
        local touchInput = {
            UserInputType = Enum.UserInputType.Touch,
            Position = UDim2.new(0.5, 0, 0.5, 0)
        }
        UserInputService:InputBegan(touchInput, false)
        task.wait(0.05)
        UserInputService:InputEnded(touchInput, false)
    end
end

local function autoPunchLoop()
    while isRunning do
        local enemy = getNearestEnemy()
        if enemy and not isBlocking(enemy) then
            local currentTime = tick() * 1000
            if currentTime - lastPunchTime >= PUNCH_DELAY then
                punch()
                lastPunchTime = currentTime
            end
        end
        task.wait(0.05)
    end
end

toggleButton.Activated:Connect(function()
    isRunning = not isRunning
    if isRunning then
        statusLabel.Text = "Status: ON"
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        toggleButton.Text = "Выкл"
        lastPunchTime = 0
        task.spawn(autoPunchLoop)
    else
        statusLabel.Text = "Status: OFF"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        toggleButton.Text = "Вкл"
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

print("[Auto-Punch] Скрипт для телефона загружен. Нажми 'Вкл'.")
if punchRemote then
    print("[Auto-Punch] Используется RemoteEvent: " .. punchRemote.Name)
else
    print("[Auto-Punch] RemoteEvent не найден, будет эмуляция касания.")
end
