-- Client-side Luau. Reads PlayerGui text; fills Codes without submitting.
-- Keep Codes open. Images/video announcements cannot be read by this script.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
assert(player, "Run this script on the client")
local playerGui = player:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("SammyCodeReader")
if old then old:Destroy() end

local ui = Instance.new("ScreenGui")
ui.Name = "SammyCodeReader"
ui.ResetOnSpawn = false
ui.DisplayOrder = 10000
ui.Parent = playerGui
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(330, 126)
panel.Position = UDim2.new(1, -345, 1, -145)
panel.BackgroundColor3 = Color3.fromRGB(24, 27, 35)
panel.Parent = ui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 68)
status.Position = UDim2.fromOffset(10, 4)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.Font = Enum.Font.Gotham
status.TextSize = 14
status.TextWrapped = true
status.Text = "Sammy: открой Codes. Читаю объявления сверху."
status.Parent = panel
local function button(text, x, width)
    local b = Instance.new("TextButton")
    b.Position = UDim2.fromOffset(x, 80)
    b.Size = UDim2.fromOffset(width, 32)
    b.BackgroundColor3 = Color3.fromRGB(58, 86, 130)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 14
    b.Font = Enum.Font.Gotham
    b.Text = text
    b.Parent = panel
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end
local pause = button("Пауза", 10, 145)
local close = button("Закрыть", 165, 155)
local running = true
pause.Activated:Connect(function()
    running = not running
    pause.Text = running and "Пауза" or "Продолжить"
end)
close.Activated:Connect(function() ui:Destroy() end)

local ignore = {}
for word in ("CODE CODES SAMMY SUBMIT REDEEM HERE UPDATE EVENT THANKS THANK YOU FROM THIS THAT WILL IS THE FREE"):gmatch("%S+") do
    ignore[word] = true
end
local function valid(token)
    return token and #token >= 4 and #token <= 40
        and token:match("^[%w_%-]+$") and not ignore[token:upper()]
end
local function extract(text)
    -- Match offsets in lowercase, extract from original to retain code case.
    local lower = text:lower()
    local _, finish = lower:find("%f[%a]code%f[%A]%s+is%s*[:=]?%s*")
    if not finish then _, finish = lower:find("%f[%a]code%f[%A]%s*[:=]%s*") end
    if not finish then _, finish = lower:find("%f[%a]code%f[%A]%s+") end
    if finish then
        local token = text:sub(finish + 1):match("^[%s\"'`]*([%w_%-]+)")
        if valid(token) then return token end
    end
    for line in text:gmatch("[^\r\n]+") do
        line = line:gsub("^%s*[Ss][Aa][Mm][Mm][Yy]%s*:%s*", "")
        local token = line:match("^%s*[\"'`]?([%w_%-]+)[\"'`!%.]?%s*$")
        if valid(token) and #token >= 5 and token == token:upper() then return token end
    end
end
local function visible(object)
    if object.AbsoluteSize.X <= 0 or object.AbsoluteSize.Y <= 0 then return false end
    local ancestor = object
    while ancestor and ancestor ~= playerGui do
        if ancestor:IsA("GuiObject") and not ancestor.Visible then return false end
        if ancestor:IsA("ScreenGui") and not ancestor.Enabled then return false end
        if ancestor:IsA("CanvasGroup") and ancestor.GroupTransparency >= 1 then return false end
        ancestor = ancestor.Parent
    end
    return ancestor == playerGui
end
local labels, boxes, observed, connections = {}, {}, {}, {}
local function track(object)
    if object:IsDescendantOf(ui) then return end
    if object:IsA("TextLabel") or object:IsA("TextButton") then labels[object] = true end
    if object:IsA("TextBox") then boxes[object] = true end
end
for _, object in playerGui:GetDescendants() do track(object) end
table.insert(connections, playerGui.DescendantAdded:Connect(track))
table.insert(connections, playerGui.DescendantRemoving:Connect(function(object)
    labels[object], boxes[object], observed[object] = nil, nil, nil
end))
local function codeField()
    local best, bestScore = nil, 0
    for box in pairs(boxes) do
        if visible(box) then
            local score = 0
            if box.PlaceholderText:lower():find("code", 1, true) then score = 100 end
            if box.Name:lower():find("code", 1, true) then score = score + 30 end
            local ancestor = box.Parent
            while ancestor and ancestor ~= playerGui do
                if ancestor.Name:lower():find("code", 1, true) then score = score + 10; break end
                ancestor = ancestor.Parent
            end
            if score > bestScore then best, bestScore = box, score end
        end
    end
    return best
end
local pending, lastFilled, elapsed = nil, nil, 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
    elapsed = elapsed + dt
    if not running or elapsed < 0.2 then return end
    elapsed = 0
    local camera = workspace.CurrentCamera
    if not camera then return end
    local height = camera.ViewportSize.Y
    for label in pairs(labels) do
        local y = label.AbsolutePosition.Y
        -- Exclude hidden text, chat, and the code dialog itself.
        local path = label:GetFullName():lower()
        if visible(label) and label.TextTransparency < 1 and y >= 0 and y < height * 0.35
            and not path:find("chat", 1, true) and not path:find("codes", 1, true) then
            local text = label.ContentText
            if observed[label] ~= text then
                observed[label] = text
                local code = extract(text)
                if code and code ~= lastFilled then
                    pending = { code = code, time = os.clock() }
                    status.Text = "Найден: " .. code .. " — открой Codes"
                end
            end
        else
            observed[label] = nil
        end
    end
    if pending then
        if os.clock() - pending.time > 60 then
            pending = nil
            status.Text = "Код не введён: поле Codes не найдено за 60 секунд."
            return
        end
        local field = codeField()
        if field then
            field.Text = pending.code
            lastFilled = pending.code
            pending = nil
            status.Text = "Вписан: " .. lastFilled .. "\nПроверь код и нажми Submit."
        end
    end
end))
ui.Destroying:Connect(function()
    for _, connection in connections do connection:Disconnect() end
end)
