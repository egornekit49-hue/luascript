-- ============================================================
-- NEXUS v4 - С ХУКАМИ ДЛЯ ОБХОДА ТЕЛЕПОРТАЦИИ
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- ==================== ХУКИ ====================

-- Хук на CFrame (обход телепортации)
local originalIndex
originalIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
    if not checkcaller() and self == hrp and key == "CFrame" then
        -- Возвращаем фейковую позицию (где ты "должен" быть)
        -- В реальности ты будешь в другом месте, но сервер этого не увидит
        return CFrame.new(0, 0, 0) -- Замени на свою фейковую позицию
    end
    return originalIndex(self, key)
end))

-- Хук на WalkSpeed (обход античита скорости)
local originalWalkSpeed
originalWalkSpeed = hookmetamethod(game, "__index", newcclosure(function(self, key)
    if not checkcaller() and self == humanoid and key == "WalkSpeed" then
        -- Сервер будет видеть 16, а ты можешь ставить 4000
        return 16
    end
    return originalWalkSpeed(self, key)
end))

-- Хук на JumpPower (если нужно)
local originalJumpPower
originalJumpPower = hookmetamethod(game, "__index", newcclosure(function(self, key)
    if not checkcaller() and self == humanoid and key == "JumpPower" then
        return 50 -- Стандартное значение
    end
    return originalJumpPower(self, key)
end))

-- ==================== NOCLIP ====================
local noclipEnabled = false

local function enableNoclip()
    noclipEnabled = true
    RunService.Stepped:Connect(function()
        if noclipEnabled and character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)
end

local function disableNoclip()
    noclipEnabled = false
    if character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

-- ==================== ОСТАЛЬНОЙ КОД ====================
-- Вставь сюда свой старый код (UI, Fly, ESP и т.д.)
-- ...
