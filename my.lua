-- ESP Chams + Nametags (универсальный, красивый интерфейс)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- ====== НАСТРОЙКИ ПО УМОЛЧАНИЮ ======
local ESP_ENABLED = true
local CHAM_COLOR = Color3.fromRGB(255, 0, 0) -- красный
local CHAM_TRANSPARENCY = 0.3 -- прозрачность заливки
local SHOW_NAMES = true

-- ====== GUI ======
local gui = Instance.new("ScreenGui")
gui.Name = "ESP_Gui"
gui.Parent = game:GetService("CoreGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(280, 220)
panel.Position = UDim2.new(0, 10, 1, -230)
panel.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -24, 0, 32)
title.Position = UDim2.fromOffset(12, 8)
title.BackgroundTransparency = 1
title.Text = "ESP Chams + Nametags"
title.TextColor3 = Color3.new(0.7, 1, 0.7)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

-- Кнопка вкл/выкл ESP
local espToggle = Instance.new("TextButton")
espToggle.Size = UDim2.fromOffset(100, 36)
espToggle.Position = UDim2.fromOffset(12, 52)
espToggle.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
espToggle.BorderSizePixel = 0
espToggle.Text = "ESP: ON"
espToggle.TextColor3 = Color3.new(1, 1, 1)
espToggle.Font = Enum.Font.GothamBold
espToggle.TextSize = 18
espToggle.Parent = panel
Instance.new("UICorner", espToggle).CornerRadius = UDim.new(0, 7)

-- Кнопка выбора цвета (циклично)
local colorButton = Instance.new("TextButton")
colorButton.Size = UDim2.fromOffset(100, 36)
colorButton.Position = UDim2.fromOffset(130, 52)
colorButton.BackgroundColor3 = CHAM_COLOR
colorButton.BorderSizePixel = 0
colorButton.Text = "Color"
colorButton.TextColor3 = Color3.new(1, 1, 1)
colorButton.Font = Enum.Font.GothamBold
colorButton.TextSize = 18
colorButton.Parent = panel
Instance.new("UICorner", colorButton).CornerRadius = UDim.new(0, 7)

-- Переключатель имён
local nameToggle = Instance.new("TextButton")
nameToggle.Size = UDim2.fromOffset(100, 36)
nameToggle.Position = UDim2.fromOffset(12, 100)
nameToggle.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
nameToggle.BorderSizePixel = 0
nameToggle.Text = "Names: ON"
nameToggle.TextColor3 = Color3.new(1, 1, 1)
nameToggle.Font = Enum.Font.GothamBold
nameToggle.TextSize = 18
nameToggle.Parent = panel
Instance.new("UICorner", nameToggle).CornerRadius = UDim.new(0, 7)

-- Ползунок прозрачности (упростим до кнопок + -)
local transpLabel = Instance.new("TextLabel")
transpLabel.Size = UDim2.fromOffset(80, 26)
transpLabel.Position = UDim2.fromOffset(12, 150)
transpLabel.BackgroundTransparency = 1
transpLabel.Text = "Alpha: 0.3"
transpLabel.TextColor3 = Color3.new(0.8, 1, 0.8)
transpLabel.Font = Enum.Font.Gotham
transpLabel.TextSize = 14
transpLabel.TextXAlignment = Enum.TextXAlignment.Left
transpLabel.Parent = panel

local transpMinus = Instance.new("TextButton")
transpMinus.Size = UDim2.fromOffset(30, 26)
transpMinus.Position = UDim2.fromOffset(100, 148)
transpMinus.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
transpMinus.BorderSizePixel = 0
transpMinus.Text = "-"
transpMinus.TextColor3 = Color3.new(1, 1, 1)
transpMinus.Font = Enum.Font.GothamBold
transpMinus.TextSize = 18
transpMinus.Parent = panel
Instance.new("UICorner", transpMinus).CornerRadius = UDim.new(0, 7)

local transpPlus = Instance.new("TextButton")
transpPlus.Size = UDim2.fromOffset(30, 26)
transpPlus.Position = UDim2.fromOffset(140, 148)
transpPlus.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
transpPlus.BorderSizePixel = 0
transpPlus.Text = "+"
transpPlus.TextColor3 = Color3.new(1, 1, 1)
transpPlus.Font = Enum.Font.GothamBold
transpPlus.TextSize = 18
transpPlus.Parent = panel
Instance.new("UICorner", transpPlus).CornerRadius = UDim.new(0, 7)

-- ====== ЛОГИКА ESP ======
local highlightObjects = {} -- player -> Highlight
local nameTags = {} -- player -> BillboardGui

local colors = {
    Color3.fromRGB(255, 0, 0),   -- красный
    Color3.fromRGB(0, 255, 0),   -- зелёный
    Color3.fromRGB(0, 150, 255), -- синий
    Color3.fromRGB(255, 255, 0), -- жёлтый
    Color3.fromRGB(255, 0, 255), -- фиолетовый
    Color3.fromRGB(255, 165, 0), -- оранжевый
}
local colorIndex = 1

local function updateColorDisplay()
    colorButton.BackgroundColor3 = CHAM_COLOR
end

local function createHighlightForPlayer(plr)
    if plr == player then return end
    local char = plr.Character
    if not char then return end
    -- Удаляем старый, если есть
    if highlightObjects[plr] then
        highlightObjects[plr]:Destroy()
        highlightObjects[plr] = nil
    end
    if nameTags[plr] then
        nameTags[plr]:Destroy()
        nameTags[plr] = nil
    end

    if not ESP_ENABLED then return end

    -- Highlight
    local hl = Instance.new("Highlight")
    hl.Adornee = char
    hl.FillColor = CHAM_COLOR
    hl.FillTransparency = CHAM_TRANSPARENCY
    hl.OutlineColor = Color3.new(1, 1, 1)
    hl.OutlineTransparency = 0.2
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char
    highlightObjects[plr] = hl

    -- BillboardGui с именем
    if SHOW_NAMES then
        local bill = Instance.new("BillboardGui")
        bill.Adornee = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        bill.Size = UDim2.fromOffset(100, 30)
        bill.StudsOffset = Vector3.new(0, 2, 0)
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

local function removeESPForPlayer(plr)
    if highlightObjects[plr] then
        highlightObjects[plr]:Destroy()
        highlightObjects[plr] = nil
    end
    if nameTags[plr] then
        nameTags[plr]:Destroy()
        nameTags[plr] = nil
    end
end

local function refreshAllESP()
    -- Очистить всё
    for plr, hl in pairs(highlightObjects) do
        hl:Destroy()
    end
    highlightObjects = {}
    for plr, tag in pairs(nameTags) do
        tag:Destroy()
    end
    nameTags = {}

    -- Заново создать для всех
    for _, plr in ipairs(Players:GetPlayers()) do
        createHighlightForPlayer(plr)
    end
end

-- События
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.2) -- ждём загрузку частей
        createHighlightForPlayer(plr)
    end)
    if plr.Character then
        task.wait(0.2)
        createHighlightForPlayer(plr)
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    removeESPForPlayer(plr)
end)

-- Кнопки управления
espToggle.Activated:Connect(function()
    ESP_ENABLED = not ESP_ENABLED
    espToggle.Text = ESP_ENABLED and "ESP: ON" or "ESP: OFF"
    if ESP_ENABLED then
        refreshAllESP()
    else
        for plr, hl in pairs(highlightObjects) do hl:Destroy() end
        highlightObjects = {}
        for plr, tag in pairs(nameTags) do tag:Destroy() end
        nameTags = {}
    end
end)

colorButton.Activated:Connect(function()
    colorIndex = colorIndex % #colors + 1
    CHAM_COLOR = colors[colorIndex]
    updateColorDisplay()
    if ESP_ENABLED then
        -- обновить цвета у всех
        for plr, hl in pairs(highlightObjects) do
            hl.FillColor = CHAM_COLOR
        end
    end
end)

nameToggle.Activated:Connect(function()
    SHOW_NAMES = not SHOW_NAMES
    nameToggle.Text = SHOW_NAMES and "Names: ON" or "Names: OFF"
    if ESP_ENABLED then
        refreshAllESP()
    end
end)

transpMinus.Activated:Connect(function()
    CHAM_TRANSPARENCY = math.max(0, CHAM_TRANSPARENCY - 0.05)
    transpLabel.Text = "Alpha: " .. string.format("%.2f", CHAM_TRANSPARENCY)
    if ESP_ENABLED then
        for plr, hl in pairs(highlightObjects) do
            hl.FillTransparency = CHAM_TRANSPARENCY
        end
    end
end)

transpPlus.Activated:Connect(function()
    CHAM_TRANSPARENCY = math.min(1, CHAM_TRANSPARENCY + 0.05)
    transpLabel.Text = "Alpha: " .. string.format("%.2f", CHAM_TRANSPARENCY)
    if ESP_ENABLED then
        for plr, hl in pairs(highlightObjects) do
            hl.FillTransparency = CHAM_TRANSPARENCY
        end
    end
end)

-- Первоначальная загрузка
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= player then
        task.wait(0.1)
        createHighlightForPlayer(plr)
    end
end
updateColorDisplay()
print("[ESP] Chams + Nametags загружены. Наслаждайся!")
