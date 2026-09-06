-- Nexus UI v4: Speed, Fly, Noclip, ESP, Auto-Punch + Reach (Teleport/Fake)
-- FIXED: Mobile punch via learned touch position

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

-- Мобильный джойстик
local mobileControls
pcall(function()
    local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
    mobileControls = playerModule:GetControls()
end)

-- Настройки
local SPEED = 50
local STEP = 4
local PUNCH_DELAY = 0
local MULTI_PUNCH = 10
local PUNCH_WHILE_BLOCKING = false
local BLOCK_SPEED_THRESHOLD = 0.5
local AURA_RANGE = 10
local SKIP_BLOCKING_TARGETS = true
local REACH_MODE = 0   -- 0=off, 1=teleport, 2=fake
local REACH_RANGE = 30

-- ESP
local ESP_ENABLED = true
local ESP_COLOR = Color3.fromRGB(255, 0, 0)
local ESP_ALPHA = 0.3
local SHOW_NAMES = true

local ESP_COLORS = {
    Color3.fromRGB(255,0,0), Color3.fromRGB(0,255,0), Color3.fromRGB(0,150,255),
    Color3.fromRGB(255,255,0), Color3.fromRGB(255,0,255), Color3.fromRGB(255,165,0),
    Color3.fromRGB(255,255,255), Color3.fromRGB(0,0,0),
}

local COLORS = {
    window = Color3.fromRGB(15,17,21), sidebar = Color3.fromRGB(12,14,18),
    surface = Color3.fromRGB(22,25,31), surfaceHover = Color3.fromRGB(28,32,40),
    border = Color3.fromRGB(42,46,56), text = Color3.fromRGB(238,241,246),
    muted = Color3.fromRGB(137,145,160), accent = Color3.fromRGB(128,211,67),
    accentDark = Color3.fromRGB(71,113,43), danger = Color3.fromRGB(239,91,105),
}

-- Вспомогательные функции
local function create(c,p,parent) local o=Instance.new(c) for k,v in pairs(p or {}) do o[k]=v end o.Parent=parent return o end
local function corner(p,r) return create("UICorner",{CornerRadius=UDim.new(0,r)},p) end
local function stroke(p,c,t) return create("UIStroke",{Color=c or COLORS.border,Transparency=t or 0,Thickness=1},p) end
local function tween(o,p,d) local info=TweenInfo.new(d or .22,Enum.EasingStyle.Quint,Enum.EasingDirection.Out) local a=TweenService:Create(o,info,p) a:Play() return a end

-- GUI
local oldGui = game:GetService("CoreGui"):FindFirstChild("SuperGuiModern")
if oldGui then oldGui:Destroy() end
local gui = create("ScreenGui",{Name="SuperGuiModern",ResetOnSpawn=false,IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},game:GetService("CoreGui"))
local scriptAlive = true
gui.Destroying:Connect(function() scriptAlive = false end)

local dim = create("Frame",{Name="Dim",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=1,BorderSizePixel=0,Active=false,Visible=not UserInputService.TouchEnabled},gui)
local panel = create("Frame",{Name="Window",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(620,560),BackgroundColor3=COLORS.window,BorderSizePixel=0,ClipsDescendants=true},gui)
corner(panel,14); stroke(panel,COLORS.border,.15)
local scale = create("UIScale",{Scale=1},panel)
local shadow=create("ImageLabel",{Name="Shadow",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.new(1,42,1,42),BackgroundTransparency=1,Image="rbxassetid://6014261993",ImageColor3=Color3.new(0,0,0),ImageTransparency=.35,ScaleType=Enum.ScaleType.Slice,SliceCenter=Rect.new(49,49,450,450),ZIndex=-1},panel)

local sidebar=create("Frame",{Size=UDim2.new(0,150,1,0),BackgroundColor3=COLORS.sidebar,BorderSizePixel=0},panel)
create("Frame",{AnchorPoint=Vector2.new(1,0),Position=UDim2.fromScale(1,0),Size=UDim2.new(0,1,1,0),BackgroundColor3=COLORS.border,BackgroundTransparency=.35,BorderSizePixel=0},sidebar)

local logo=create("TextLabel",{Position=UDim2.fromOffset(18,18),Size=UDim2.new(1,-36,0,32),BackgroundTransparency=1,Text="● NEXUS",TextColor3=COLORS.text,Font=Enum.Font.GothamBold,TextSize=16,TextXAlignment=Enum.TextXAlignment.Left},sidebar)
local dot=create("Frame",{Position=UDim2.fromOffset(18,53),Size=UDim2.fromOffset(5,5),BackgroundColor3=COLORS.accent,BorderSizePixel=0},sidebar); corner(dot,5)
create("TextLabel",{Position=UDim2.fromOffset(29,46),Size=UDim2.new(1,-38,0,20),BackgroundTransparency=1,Text="v4 touch learn",TextColor3=COLORS.muted,Font=Enum.Font.Gotham,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left},sidebar)

local navHolder=create("Frame",{Position=UDim2.fromOffset(10,92),Size=UDim2.new(1,-20,0,160),BackgroundTransparency=1},sidebar)
create("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},navHolder)

local pages={}; local navButtons={}; local selectedPage="Movement"
local content=create("Frame",{Position=UDim2.fromOffset(150,0),Size=UDim2.new(1,-150,1,0),BackgroundTransparency=1},panel)
local header=create("Frame",{Size=UDim2.new(1,0,0,62),BackgroundTransparency=1},content)
local pageTitle=create("TextLabel",{Position=UDim2.fromOffset(22,12),Size=UDim2.new(1,-72,0,24),BackgroundTransparency=1,Text="Movement",TextColor3=COLORS.text,Font=Enum.Font.GothamBold,TextSize=17,TextXAlignment=Enum.TextXAlignment.Left},header)
local pageSubtitle=create("TextLabel",{Position=UDim2.fromOffset(22,35),Size=UDim2.new(1,-72,0,17),BackgroundTransparency=1,Text="Movement, flight, noclip",TextColor3=COLORS.muted,Font=Enum.Font.Gotham,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left},header)
local hideButton=create("TextButton",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-14,0,14),Size=UDim2.fromOffset(34,34),BackgroundColor3=COLORS.surface,BorderSizePixel=0,Text="×",TextColor3=COLORS.muted,Font=Enum.Font.GothamMedium,TextSize=21,AutoButtonColor=false},header); corner(hideButton,9); stroke(hideButton,COLORS.border,.4)

local body=create("Frame",{Position=UDim2.fromOffset(22,64),Size=UDim2.new(1,-44,1,-82),BackgroundTransparency=1,ClipsDescendants=true},content)

local function makePage(name)
    local page=create("ScrollingFrame",{Name=name,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,ScrollBarImageColor3=COLORS.accent,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=name==selectedPage},body)
    create("UIListLayout",{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder},page); pages[name]=page; return page
end
local movementPage=makePage("Movement"); local combatPage=makePage("Combat"); local espPage=makePage("ESP")

local function makeNav(name,glyph)
    local button=create("TextButton",{Name=name,Size=UDim2.new(1,0,0,44),BackgroundColor3=COLORS.surface,BackgroundTransparency=name==selectedPage and 0 or 1,BorderSizePixel=0,Text="   "..glyph.."   "..name,TextColor3=name==selectedPage and COLORS.text or COLORS.muted,Font=Enum.Font.GothamMedium,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,AutoButtonColor=false},navHolder)
    corner(button,9)
    local marker=create("Frame",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,0,0.5,0),Size=UDim2.fromOffset(3,20),BackgroundColor3=COLORS.accent,BackgroundTransparency=name==selectedPage and 0 or 1,BorderSizePixel=0},button); corner(marker,3)
    navButtons[name]={button=button,marker=marker}
    button.Activated:Connect(function()
        if selectedPage==name then return end
        selectedPage=name; pageTitle.Text=name
        local sub=name=="Movement" and "Movement and flight settings" or name=="Combat" and "Auto punch, multi-hit, reach" or "Visuals and color picker"
        pageSubtitle.Text=sub
        for pn,p in pairs(pages) do p.Visible=pn==name end
        for bn,data in pairs(navButtons) do
            local active=bn==name
            tween(data.button,{BackgroundTransparency=active and 0 or 1,TextColor3=active and COLORS.text or COLORS.muted})
            tween(data.marker,{BackgroundTransparency=active and 0 or 1})
        end
    end)
end
makeNav("Movement","◇"); makeNav("Combat","◎"); makeNav("ESP","◈")
create("TextLabel",{AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,18,1,-17),Size=UDim2.new(1,-36,0,30),BackgroundTransparency=1,Text="WASD • Space / Shift",TextColor3=COLORS.muted,Font=Enum.Font.Gotham,TextSize=9,TextWrapped=true},sidebar)

local function makeCard(parent,titleText,desc,height)
    local card=create("Frame",{Size=UDim2.new(1,-4,0,height or 74),BackgroundColor3=COLORS.surface,BorderSizePixel=0},parent)
    corner(card,11); stroke(card,COLORS.border,.45)
    create("TextLabel",{Position=UDim2.fromOffset(15,11),Size=UDim2.new(1,-30,0,20),BackgroundTransparency=1,Text=titleText,TextColor3=COLORS.text,Font=Enum.Font.GothamMedium,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left},card)
    create("TextLabel",{Position=UDim2.fromOffset(15,32),Size=UDim2.new(1,-30,0,17),BackgroundTransparency=1,Text=desc,TextColor3=COLORS.muted,Font=Enum.Font.Gotham,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left},card)
    return card
end

local function makeStepper(parent,defaultText)
    local holder=create("Frame",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-14,0.5,7),Size=UDim2.fromOffset(128,34),BackgroundColor3=COLORS.window,BorderSizePixel=0},parent)
    corner(holder,8); stroke(holder,COLORS.border,.25)
    local minus=create("TextButton",{Size=UDim2.fromOffset(34,34),BackgroundTransparency=1,Text="−",TextColor3=COLORS.muted,Font=Enum.Font.GothamMedium,TextSize=18},holder)
    local box=create("TextBox",{Position=UDim2.fromOffset(34,0),Size=UDim2.fromOffset(60,34),BackgroundTransparency=1,Text=defaultText,TextColor3=COLORS.text,Font=Enum.Font.GothamBold,TextSize=12,ClearTextOnFocus=false},holder)
    local plus=create("TextButton",{Position=UDim2.fromOffset(94,0),Size=UDim2.fromOffset(34,34),BackgroundTransparency=1,Text="+",TextColor3=COLORS.accent,Font=Enum.Font.GothamMedium,TextSize=18},holder)
    return minus,box,plus
end

local function makeToggle(parent)
    local button=create("TextButton",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-16,0.5,7),Size=UDim2.fromOffset(48,26),BackgroundColor3=COLORS.border,BorderSizePixel=0,Text="",AutoButtonColor=false},parent)
    corner(button,13)
    local knob=create("Frame",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,4,0.5,0),Size=UDim2.fromOffset(18,18),BackgroundColor3=COLORS.muted,BorderSizePixel=0},button); corner(knob,9)
    local enabled=false
    local function set(v) enabled=v; tween(button,{BackgroundColor3=enabled and COLORS.accentDark or COLORS.border}); tween(knob,{Position=enabled and UDim2.new(1,-22,0.5,0) or UDim2.new(0,4,0.5,0),BackgroundColor3=enabled and COLORS.accent or COLORS.muted}) end
    return button,set,function() return enabled end
end

-- ---- Movement ----
local speedCard=makeCard(movementPage,"Walk speed","Set character movement speed")
local dec,valBox,inc=makeStepper(speedCard,tostring(SPEED))
local flyCard=makeCard(movementPage,"Flight (BodyVelocity)","Camera-relative free movement (mobile-friendly)")
local flyBtn,setFly,getFly=makeToggle(flyCard)
local noclipCard=makeCard(movementPage,"Noclip","Disable collisions; may fall through floors",94)
local noclipBtn,setNoclip,getNoclip=makeToggle(noclipCard)
local noclipConn,origColl={},nil

local function restoreColl()
    for p,c in pairs(origColl) do if p.Parent then p.CanCollide=c end end; table.clear(origColl) end
local function stopNoclip() if noclipConn then noclipConn:Disconnect(); noclipConn=nil end; restoreColl(); setNoclip(false) end
noclipBtn.Activated:Connect(function()
    if getNoclip() then stopNoclip(); return end
    setNoclip(true)
    noclipConn=RunService.Stepped:Connect(function()
        if not scriptAlive then stopNoclip(); return end
        local char=player.Character
        if char~=noclipCharacter then restoreColl(); noclipCharacter=char end
        if not char then return end
        for _,part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                if origColl[part]==nil then origColl[part]=part.CanCollide end
                part.CanCollide=false
            end
        end
    end)
end); gui.Destroying:Connect(stopNoclip)

-- ---- Combat ----
local autoCard=makeCard(combatPage,"Auto punch","Attacks nearest enemy when unblocked")
local autoBtn,setAuto,getAuto=makeToggle(autoCard)
local status=create("TextLabel",{Name="AttackStatus",Size=UDim2.new(1,-4,0,44),BackgroundTransparency=1,Text="Auto punch: OFF",TextColor3=COLORS.muted,Font=Enum.Font.Gotham,TextSize=11,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left},combatPage)
local learnBtn=create("TextButton",{Name="LearnPunch",Size=UDim2.new(1,-4,0,44),BackgroundColor3=COLORS.surface,BorderSizePixel=0,Text="🔴 Learn punch position (tap once)",TextColor3=COLORS.text,Font=Enum.Font.GothamMedium,TextSize=12,AutoButtonColor=false},combatPage); corner(learnBtn,9)
local testBtn=create("TextButton",{Name="TestTouch",Size=UDim2.new(1,-4,0,44),BackgroundColor3=COLORS.surface,BorderSizePixel=0,Text="Test learned punch",TextColor3=COLORS.text,Font=Enum.Font.GothamMedium,TextSize=12,AutoButtonColor=false},combatPage); corner(testBtn,9)
local delayCard=makeCard(combatPage,"Punch delay (ms)","Delay between attack series")
local dMin,dBox,dPlus=makeStepper(delayCard,tostring(PUNCH_DELAY))
local multiCard=makeCard(combatPage,"Multi-punch count","Number of punches per activation (1-10)",94)
local mMin,mBox,mPlus=makeStepper(multiCard,tostring(MULTI_PUNCH))
local blockCard=makeCard(combatPage,"Punch while blocking","Allow punching even when you are blocking")
local bToggle,setBToggle,getBToggle=makeToggle(blockCard)
local rangeCard=makeCard(combatPage,"Aura range (studs)","Auto punch activation distance",94)
local rMin,rBox,rPlus=makeStepper(rangeCard,tostring(AURA_RANGE))
local skipBlockCard=makeCard(combatPage,"Skip blocking enemies","ON: wait until enemy drops block",94)
local skipToggle,setSkipToggle,getSkipToggle=makeToggle(skipBlockCard)

-- Reach
local reachCard=makeCard(combatPage,"Reach mode","Teleport or Fake",120)
local reachLabel=create("TextLabel",{Position=UDim2.fromOffset(15,58),Size=UDim2.new(1,-30,0,20),BackgroundTransparency=1,Text="Mode: OFF",TextColor3=COLORS.text,Font=Enum.Font.GothamBold,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left},reachCard)
local reachTele=create("TextButton",{Size=UDim2.fromOffset(80,30),Position=UDim2.fromOffset(15,82),BackgroundColor3=COLORS.surface,BorderSizePixel=0,Text="Teleport",TextColor3=COLORS.text,Font=Enum.Font.GothamMedium,TextSize=12,AutoButtonColor=false},reachCard); corner(reachTele,6); stroke(reachTele,COLORS.border,.3)
local reachFake=create("TextButton",{Size=UDim2.fromOffset(80,30),Position=UDim2.fromOffset(105,82),BackgroundColor3=COLORS.surface,BorderSizePixel=0,Text="Fake",TextColor3=COLORS.text,Font=Enum.Font.GothamMedium,TextSize=12,AutoButtonColor=false},reachCard); corner(reachFake,6); stroke(reachFake,COLORS.border,.3)
local reachOff=create("TextButton",{Size=UDim2.fromOffset(80,30),Position=UDim2.fromOffset(195,82),BackgroundColor3=COLORS.surface,BorderSizePixel=0,Text="OFF",TextColor3=COLORS.text,Font=Enum.Font.GothamMedium,TextSize=12,AutoButtonColor=false},reachCard); corner(reachOff,6); stroke(reachOff,COLORS.border,.3)
local reachRangeCard=makeCard(combatPage,"Reach max range (studs)","Maximum distance",94)
local rchMin,rchBox,rchPlus=makeStepper(reachRangeCard,tostring(REACH_RANGE))

-- ---- ESP ----
local espCard=makeCard(espPage,"ESP Enabled","Show highlights and nametags")
local espBtn,setEsp,getEsp=makeToggle(espCard)
local nameCard=makeCard(espPage,"Show Names","Display player names")
local nameBtn,setName,getName=makeToggle(nameCard)
local colorCard=makeCard(espPage,"Color Picker","Select highlight color",140)
local palHolder=create("Frame",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-14,0.5,30),Size=UDim2.fromOffset(160,60),BackgroundTransparency=1},colorCard)
create("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Right,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder},palHolder)
local colorBtns={}
for _,color in ipairs(ESP_COLORS) do
    local b=create("TextButton",{Size=UDim2.fromOffset(28,28),BackgroundColor3=color,BorderSizePixel=0,Text="",AutoButtonColor=false},palHolder); corner(b,6); stroke(b,COLORS.border,.3)
    b.Activated:Connect(function() ESP_COLOR=color; refreshESP() end)
    table.insert(colorBtns,b)
end
local alphaCard=makeCard(espPage,"Alpha (transparency)","Fill transparency (0-1)",74)
local aMin,aBox,aPlus=makeStepper(alphaCard,string.format("%.2f",ESP_ALPHA))

-- ---- Restore window ----
local restoreBtn=create("TextButton",{Name="Restore",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-18,0,18),Size=UDim2.fromOffset(52,52),BackgroundColor3=COLORS.window,BorderSizePixel=0,Text="N",TextColor3=COLORS.accent,Font=Enum.Font.GothamBold,TextSize=18,AutoButtonColor=false,Visible=false},gui); corner(restoreBtn,16); stroke(restoreBtn,COLORS.accent,.35)
local panelShown=true
local function setPanelShown(shown)
    if panelShown==shown then return end; panelShown=shown
    if shown then
        panel.Visible=true; panel.Size=UDim2.fromOffset(580,520); panel.BackgroundTransparency=1
        tween(panel,{Size=UDim2.fromOffset(620,560),BackgroundTransparency=0},.28)
        tween(dim,{BackgroundTransparency=UserInputService.TouchEnabled and .65 or 1},.25)
        restoreBtn.Visible=false
    else
        local a=tween(panel,{Size=UDim2.fromOffset(580,520),BackgroundTransparency=1},.2)
        tween(dim,{BackgroundTransparency=1},.2)
        a.Completed:Once(function() if not panelShown then panel.Visible=false; restoreBtn.Visible=true end end)
    end
end
hideButton.Activated:Connect(function() setPanelShown(false) end)
restoreBtn.Activated:Connect(function() setPanelShown(true) end)

-- Dragging
local drag,dragStart,startPos,dragInput
header.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
        drag,dragStart,startPos=true,inp.Position,panel.Position
        inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then drag=false end end)
    end
end)
header.InputChanged:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch then dragInput=inp end end)
UserInputService.InputChanged:Connect(function(inp) if drag and inp==dragInput then local d=inp.Position-dragStart; panel.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end end)

local function updateScale()
    local vp=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800,600)
    scale.Scale=math.clamp(math.min((vp.X-24)/620,(vp.Y-120)/560),.48,1)
    if UserInputService.TouchEnabled then panel.AnchorPoint=Vector2.new(0.5,0); panel.Position=UDim2.new(0.5,0,0,8) end
end
updateScale(); if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale) end

-- ---- Movement ----
local function getHumanoid()
    local char=player.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end
local function setSpeed(v)
    local n=tonumber(v); if n then SPEED=math.clamp(math.floor(n),0,500) end; valBox.Text=tostring(SPEED)
    local hum=getHumanoid(); if hum then hum.WalkSpeed=SPEED end
end
dec.Activated:Connect(function() setSpeed(SPEED-STEP) end)
inc.Activated:Connect(function() setSpeed(SPEED+STEP) end)
valBox.FocusLost:Connect(function() setSpeed(valBox.Text) end)
local speedConn=RunService.Heartbeat:Connect(function()
    if not scriptAlive then speedConn:Disconnect(); return end
    local hum=getHumanoid(); if hum and hum.WalkSpeed~=SPEED then hum.WalkSpeed=SPEED end
end)

-- ---- Flight ----
local flying=false; local flyBV,flyBG,flyConn; local flightHum,prevPlatformStand
local function stopFly()
    flying=false; if flyConn then flyConn:Disconnect(); flyConn=nil end
    if flyBV then flyBV:Destroy(); flyBV=nil end; if flyBG then flyBG:Destroy(); flyBG=nil end
    setFly(false); if flightHum and flightHum.Parent then flightHum.PlatformStand=prevPlatformStand end; flightHum=nil
end
gui.Destroying:Connect(stopFly)
local function startFly()
    local char=player.Character; if not char then return end
    local root=char:FindFirstChild("HumanoidRootPart"); if not root then return end
    local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    flightHum=hum; prevPlatformStand=hum.PlatformStand
    if not UserInputService.TouchEnabled then hum.PlatformStand=true end
    flyBV=Instance.new("BodyVelocity"); flyBV.MaxForce=Vector3.new(1e6,1e6,1e6); flyBV.Parent=root
    flyBG=Instance.new("BodyGyro"); flyBG.MaxTorque=Vector3.new(1e6,1e6,1e6); flyBG.Parent=root
    flying=true; setFly(true)
    flyConn=RunService.Heartbeat:Connect(function(dt)
        if not flying or not root.Parent then return end
        local cam=workspace.CurrentCamera; if not cam then return end
        local move=Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move=move+cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move=move-cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move=move-cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move=move+cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move=move+Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move=move-Vector3.yAxis end
        if UserInputService.TouchEnabled then
            local stick=hum.MoveDirection; local world=stick.Magnitude>0
            if not world and mobileControls then stick=mobileControls:GetMoveVector() end
            local flatLook=Vector3.new(cam.CFrame.LookVector.X,0,cam.CFrame.LookVector.Z)
            local flatRight=Vector3.new(cam.CFrame.RightVector.X,0,cam.CFrame.RightVector.Z)
            if flatLook.Magnitude>0 then flatLook=flatLook.Unit end
            if flatRight.Magnitude>0 then flatRight=flatRight.Unit end
            if world then move=move+stick else move=move+flatRight*stick.X-flatLook*stick.Z end
        end
        if move.Magnitude>0 then
            move=move.Unit*SPEED; flyBV.Velocity=move; flyBG.CFrame=CFrame.lookAt(root.Position,root.Position+move)
        else flyBV.Velocity=Vector3.zero end
    end)
end
flyBtn.Activated:Connect(function() if getFly() then stopFly() else startFly() end end)
player.CharacterAdded:Connect(function(char) stopFly(); char:WaitForChild("Humanoid").WalkSpeed=SPEED end)

-- ---- LEARN PUNCH POSITION ----
local punchPos = nil  -- абсолютные координаты на экране (Vector2)
local learning = false
learnBtn.Activated:Connect(function()
    if learning then return end
    learning = true
    learnBtn.Text = "👆 Tap the punch button NOW"
    learnBtn.BackgroundColor3 = COLORS.danger
    status.Text = "Learning mode: tap the actual punch button"
    status.TextColor3 = COLORS.text
    local connection
    connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            -- Запоминаем позицию касания
            punchPos = input.Position
            connection:Disconnect()
            learning = false
            learnBtn.Text = "✅ Punch learned! (" .. math.round(punchPos.X) .. ", " .. math.round(punchPos.Y) .. ")"
            learnBtn.BackgroundColor3 = COLORS.accentDark
            status.Text = "Punch position saved. Use Test button."
            status.TextColor3 = COLORS.muted
            -- Визуально показываем точку на экране
            local dotMarker = create("Frame", {
                Size = UDim2.fromOffset(20,20),
                Position = UDim2.new(0, punchPos.X-10, 0, punchPos.Y-10),
                BackgroundColor3 = Color3.fromRGB(0,255,0),
                BackgroundTransparency = 0.3,
                BorderSizePixel = 0,
                ZIndex = 999,
            }, gui)
            corner(dotMarker, 10)
            task.delay(2, function() dotMarker:Destroy() end)
        end
    end)
    task.delay(8, function()
        if learning then
            connection:Disconnect()
            learning = false
            learnBtn.Text = "🔴 Timeout. Try again."
            learnBtn.BackgroundColor3 = COLORS.surface
            status.Text = "Learning timed out. Tap Learn again."
            status.TextColor3 = COLORS.danger
        end
    end)
end)

-- ---- Punch function using learned position ----
local function punch()
    if punchPos then
        -- эмулируем касание в запомненной точке
        local ok, err = pcall(function()
            VirtualInputManager:SendTouchEvent(999, 0, punchPos.X, punchPos.Y)
            task.wait(0.05)
            VirtualInputManager:SendTouchEvent(999, 1, punchPos.X, punchPos.Y)
        end)
        if ok then return true end
        -- если не сработало, пробуем через button:Click() поиском по имени
    end
    -- fallback: поиск кнопки
    if player.PlayerGui then
        for _, child in ipairs(player.PlayerGui:GetDescendants()) do
            if child:IsA("GuiButton") then
                local name = child.Name:lower()
                if name:find("punch") or name:find("attack") or name:find("fight") or name:find("hit") or name:find("jab") then
                    pcall(function() child:Click() end)
                    return true
                end
            end
        end
    end
    return false
end

-- ---- Reach logic (teleport/fake) ----
local function teleportToEnemy(enemyChar)
    if not enemyChar then return nil end
    local myChar=player.Character; if not myChar then return nil end
    local myRoot=myChar:FindFirstChild("HumanoidRootPart"); local enemyRoot=enemyChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not enemyRoot then return nil end
    local myPos=myRoot.Position; local dir=(enemyRoot.Position-myPos).Unit
    local targetPos=enemyRoot.Position-dir*1.5
    myRoot.CFrame=CFrame.new(targetPos); return myPos
end
local function returnToPosition(pos) local myChar=player.Character; if not myChar then return end; local r=myChar:FindFirstChild("HumanoidRootPart"); if r then r.CFrame=CFrame.new(pos) end end

local remoteHooked=false; local punchRemote=nil
local function hookRemote()
    if remoteHooked then return end
    for _,svc in ipairs({game:GetService("ReplicatedStorage"), game:GetService("Workspace"), game:GetService("Players")}) do
        for _,obj in ipairs(svc:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                local n=obj.Name:lower()
                if n:find("punch") or n:find("attack") or n:find("hit") or n:find("damage") then
                    punchRemote=obj
                    local orig=obj.FireServer
                    obj.FireServer=function(self,...)
                        local args={...}
                        local nearestPos=nil
                        local myChar=player.Character; local myRoot=myChar and myChar:FindFirstChild("HumanoidRootPart")
                        if myRoot then
                            local minDist=math.huge
                            for _,other in ipairs(Players:GetPlayers()) do
                                if other~=player then
                                    local oChar=other.Character; local oRoot=oChar and oChar:FindFirstChild("HumanoidRootPart")
                                    if oRoot then
                                        local dist=(myRoot.Position-oRoot.Position).Magnitude
                                        if dist<minDist then minDist=dist; nearestPos=oRoot.Position end
                                    end
                                end
                            end
                        end
                        if nearestPos then
                            for i,arg in ipairs(args) do
                                if type(arg)=="Vector3" or type(arg)=="CFrame" then args[i]=nearestPos; break end
                            end
                        end
                        return orig(self, unpack(args))
                    end
                    remoteHooked=true; print("[Fake Reach] Remote hooked:",obj.Name)
                    return
                end
            end
        end
    end
    print("[Fake Reach] No RemoteEvent found. Trying tool extend.")
    -- extend tool if possible
    local char=player.Character
    if char then
        local tool=char:FindFirstChildOfClass("Tool")
        if tool then
            local handle=tool:FindFirstChild("Handle")
            if handle then handle.Size=Vector3.new(50,50,50) end
            if tool:FindFirstChild("AttackRange") then tool.AttackRange.Value=999 end
            if tool:FindFirstChild("Reach") then tool.Reach.Value=999 end
        end
    end
    remoteHooked=true
end

local function getOwnBlockTracks()
    local tracks={}; local hum=getHumanoid(); local anim=hum and hum:FindFirstChildOfClass("Animator")
    if anim then for _,tr in ipairs(anim:GetPlayingAnimationTracks()) do
        local an=tr.Animation; if an and an.Name:lower():find("block") then table.insert(tracks,tr) end
    end end
    return tracks
end

local function performMultiPunch()
    local ownBlockTracks = PUNCH_WHILE_BLOCKING and getOwnBlockTracks() or {}
    local useReach = REACH_MODE == 1
    local useFake = REACH_MODE == 2
    local originalPos = nil
    local enemyChar = nil
    if useReach then
        -- find nearest enemy in range
        local myChar=player.Character; local myRoot=myChar and myChar:FindFirstChild("HumanoidRootPart")
        if myRoot then
            local minDist=math.huge
            for _,other in ipairs(Players:GetPlayers()) do
                if other~=player then
                    local oChar=other.Character; local oRoot=oChar and oChar:FindFirstChild("HumanoidRootPart")
                    if oRoot then
                        local dist=(myRoot.Position-oRoot.Position).Magnitude
                        if dist<=REACH_RANGE and dist<minDist then minDist=dist; enemyChar=oChar end
                    end
                end
            end
        end
        if enemyChar then originalPos=teleportToEnemy(enemyChar) end
    elseif useFake then
        if not remoteHooked then hookRemote() end
    end

    for _=1,MULTI_PUNCH do
        if not scriptAlive then if useReach and originalPos then returnToPosition(originalPos) end; return false end
        local ok,err=pcall(punch)
        if not ok then if useReach and originalPos then returnToPosition(originalPos) end; return false,err end
    end
    if useReach and originalPos then returnToPosition(originalPos) end

    if #ownBlockTracks > 0 then
        task.spawn(function()
            local untilTime = tick() + 0.2
            local restored = false
            while scriptAlive and tick() < untilTime do
                for _,tr in ipairs(ownBlockTracks) do
                    if not tr.IsPlaying then pcall(function() tr:Play(0) end); restored=true end
                end
                task.wait()
            end
            if scriptAlive and restored then
                local blockBtn = nil
                if player.PlayerGui then
                    for _,c in ipairs(player.PlayerGui:GetDescendants()) do
                        if c:IsA("GuiButton") and c.Name:lower():find("block") then blockBtn=c; break end
                    end
                end
                if blockBtn then pcall(function() blockBtn:Click() end) end
            end
        end)
    end
    return true
end

-- ---- Auto punch loop ----
local isAutoOn=false; local lastPunchTime=0; local autoGen=0
local function isBlocking(char)
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    if hum.WalkSpeed <= BLOCK_SPEED_THRESHOLD then return true end
    local anim=hum:FindFirstChildOfClass("Animator")
    if anim then
        for _,tr in ipairs(anim:GetPlayingAnimationTracks()) do
            local an=tr.Animation
            if an and an.Name:lower():find("block") then return true end
        end
    end
    return false
end
local function getNearestEnemy()
    local char=player.Character; local root=char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local nearest,dist=nil,math.huge
    for _,other in ipairs(Players:GetPlayers()) do
        if other~=player then
            local oChar=other.Character; local oRoot=oChar and oChar:FindFirstChild("HumanoidRootPart")
            local oHum=oChar and oChar:FindFirstChildOfClass("Humanoid")
            if oRoot and oHum and oHum.Health>0 then
                local d=(root.Position-oRoot.Position).Magnitude
                if d<=AURA_RANGE and d<dist and (not SKIP_BLOCKING_TARGETS or not isBlocking(oChar)) then
                    nearest,dist=oChar,d
                end
            end
        end
    end
    return nearest
end
local function autoPunchLoop(gen)
    while scriptAlive and isAutoOn and gen==autoGen do
        if learning then RunService.Heartbeat:Wait(); continue end
        local enemy=getNearestEnemy()
        local now=tick()*1000
        if enemy then
            local enemyBlocking=isBlocking(enemy)
            local selfBlocking=isBlocking(player.Character)
            local can=(PUNCH_WHILE_BLOCKING or not selfBlocking) and (not SKIP_BLOCKING_TARGETS or not enemyBlocking)
            if can and now-lastPunchTime>=PUNCH_DELAY then
                local ok,err=pcall(performMultiPunch)
                if not ok then
                    status.Text="Error: "..tostring(err)
                    status.TextColor3=COLORS.danger
                    task.wait(1)
                    if not scriptAlive or gen~=autoGen then break end
                else
                    local mode=REACH_MODE==1 and "[Teleport] " or REACH_MODE==2 and "[Fake] " or ""
                    status.Text=mode.."Punched "..MULTI_PUNCH.."x"
                    status.TextColor3=COLORS.muted
                end
                lastPunchTime=now
            elseif not can then
                status.Text="Waiting: block filter"
                status.TextColor3=COLORS.muted
            end
        else
            status.Text="Waiting: target"
            status.TextColor3=COLORS.muted
        end
        RunService.Heartbeat:Wait()
    end
end
local lastAutoTap=-math.huge
autoBtn.Activated:Connect(function()
    local now=os.clock(); if now-lastAutoTap<.3 then return end; lastAutoTap=now
    autoGen=autoGen+1; isAutoOn=not isAutoOn; setAuto(isAutoOn)
    status.Text=isAutoOn and "Auto ON" or "Auto OFF"
    status.TextColor3=COLORS.muted
    if isAutoOn then
        lastPunchTime=0
        local gen=autoGen
        task.spawn(function()
            local ok,err=pcall(autoPunchLoop,gen)
            if not ok and scriptAlive and isAutoOn and gen==autoGen then
                status.Text="ERROR: "..tostring(err)
                status.TextColor3=COLORS.danger
            end
        end)
    end
end)

-- ---- Delays, etc ----
local function setDelay(v) local n=tonumber(v); if n then PUNCH_DELAY=math.clamp(math.floor(n),0,10000) end; dBox.Text=tostring(PUNCH_DELAY) end
dMin.Activated:Connect(function() setDelay(PUNCH_DELAY-50) end)
dPlus.Activated:Connect(function() setDelay(PUNCH_DELAY+50) end)
dBox.FocusLost:Connect(function() setDelay(dBox.Text) end)

local function setMulti(v) local n=tonumber(v); if n then MULTI_PUNCH=math.clamp(math.floor(n),1,10) end; mBox.Text=tostring(MULTI_PUNCH) end
mMin.Activated:Connect(function() setMulti(MULTI_PUNCH-1) end)
mPlus.Activated:Connect(function() setMulti(MULTI_PUNCH+1) end)
mBox.FocusLost:Connect(function() setMulti(mBox.Text) end)

local function setAura(v) local n=tonumber(v); if n and n==n and math.abs(n)<math.huge then AURA_RANGE=math.clamp(math.floor(n),1,100) end; rBox.Text=tostring(AURA_RANGE) end
rMin.Activated:Connect(function() setAura(AURA_RANGE-1) end)
rPlus.Activated:Connect(function() setAura(AURA_RANGE+1) end)
rBox.FocusLost:Connect(function() setAura(rBox.Text) end)

skipToggle.Activated:Connect(function() SKIP_BLOCKING_TARGETS=not getSkipToggle(); setSkipToggle(SKIP_BLOCKING_TARGETS) end)
bToggle.Activated:Connect(function() PUNCH_WHILE_BLOCKING=not getBToggle(); setBToggle(PUNCH_WHILE_BLOCKING) end)

-- Reach buttons
local function setReachMode(mode)
    REACH_MODE=mode
    local txt = mode==0 and "Mode: OFF" or mode==1 and "Mode: Teleport" or "Mode: Fake"
    reachLabel.Text=txt
    if mode==2 and not remoteHooked then hookRemote() end
    if mode~=2 and remoteHooked then remoteHooked=false end
end
reachTele.Activated:Connect(function() setReachMode(1) end)
reachFake.Activated:Connect(function() setReachMode(2) end)
reachOff.Activated:Connect(function() setReachMode(0) end)

local function setReachRange(v) local n=tonumber(v); if n and n==n and math.abs(n)<math.huge then REACH_RANGE=math.clamp(math.floor(n),1,100) end; rchBox.Text=tostring(REACH_RANGE) end
rchMin.Activated:Connect(function() setReachRange(REACH_RANGE-1) end)
rchPlus.Activated:Connect(function() setReachRange(REACH_RANGE+1) end)
rchBox.FocusLost:Connect(function() setReachRange(rchBox.Text) end)

testBtn.Activated:Connect(function()
    if not punchPos then status.Text="Learn punch position first!"; status.TextColor3=COLORS.danger; return end
    local ok,err=pcall(punch)
    status.Text=ok and "Test punch sent" or "Test failed: "..tostring(err)
    status.TextColor3=ok and COLORS.muted or COLORS.danger
end)

-- ---- ESP ----
local highlightObjs={}; local nameTags={}
refreshESP=function()
    for _,hl in pairs(highlightObjs) do hl:Destroy() end; highlightObjs={}
    for _,tag in pairs(nameTags) do tag:Destroy() end; nameTags={}
    for _,plr in ipairs(Players:GetPlayers()) do if plr~=player then createESPForPlayer(plr) end end
end
createESPForPlayer=function(plr)
    if plr==player then return end
    local char=plr.Character; if not char then return end
    if not ESP_ENABLED then return end
    local hl=Instance.new("Highlight"); hl.Adornee=char; hl.FillColor=ESP_COLOR; hl.FillTransparency=ESP_ALPHA; hl.OutlineColor=Color3.new(1,1,1); hl.OutlineTransparency=0.2; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=char; highlightObjs[plr]=hl
    if SHOW_NAMES then
        local head=char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        if head then
            local bill=Instance.new("BillboardGui"); bill.Adornee=head; bill.Size=UDim2.fromOffset(120,30); bill.StudsOffset=Vector3.new(0,2.5,0); bill.AlwaysOnTop=true; bill.Parent=char
            local lab=Instance.new("TextLabel"); lab.Size=UDim2.new(1,0,1,0); lab.BackgroundTransparency=1; lab.Text=plr.Name; lab.TextColor3=Color3.new(1,1,1); lab.Font=Enum.Font.GothamBold; lab.TextSize=18; lab.TextStrokeColor3=Color3.new(0,0,0); lab.TextStrokeTransparency=0.3; lab.Parent=bill; nameTags[plr]=bill
        end
    end
end
local function removeESPForPlayer(plr) if highlightObjs[plr] then highlightObjs[plr]:Destroy(); highlightObjs[plr]=nil end; if nameTags[plr] then nameTags[plr]:Destroy(); nameTags[plr]=nil end end
Players.PlayerAdded:Connect(function(plr) plr.CharacterAdded:Connect(function() task.wait(.2); createESPForPlayer(plr) end); if plr.Character then task.wait(.2); createESPForPlayer(plr) end end)
Players.PlayerRemoving:Connect(removeESPForPlayer)
espBtn.Activated:Connect(function() ESP_ENABLED=not getEsp(); setEsp(ESP_ENABLED); if ESP_ENABLED then refreshESP() else for _,hl in pairs(highlightObjs) do hl:Destroy() end; highlightObjs={}; for _,tag in pairs(nameTags) do tag:Destroy() end; nameTags={} end end)
nameBtn.Activated:Connect(function() SHOW_NAMES=not getName(); setName(SHOW_NAMES); refreshESP() end)
aMin.Activated:Connect(function() ESP_ALPHA=math.max(0,math.floor((ESP_ALPHA-.05)*100)/100); aBox.Text=string.format("%.2f",ESP_ALPHA); for _,hl in pairs(highlightObjs) do hl.FillTransparency=ESP_ALPHA end end)
aPlus.Activated:Connect(function() ESP_ALPHA=math.min(1,math.floor((ESP_ALPHA+.05)*100)/100); aBox.Text=string.format("%.2f",ESP_ALPHA); for _,hl in pairs(highlightObjs) do hl.FillTransparency=ESP_ALPHA end end)
aBox.FocusLost:Connect(function() local v=tonumber(aBox.Text); if v then ESP_ALPHA=math.clamp(v,0,1) end; aBox.Text=string.format("%.2f",ESP_ALPHA); for _,hl in pairs(highlightObjs) do hl.FillTransparency=ESP_ALPHA end end)

for _,plr in ipairs(Players:GetPlayers()) do if plr~=player then task.wait(.1); createESPForPlayer(plr) end end

-- ---- Init ----
setSpeed(SPEED)
setBToggle(PUNCH_WHILE_BLOCKING)
setSkipToggle(SKIP_BLOCKING_TARGETS)
setEsp(ESP_ENABLED)
setName(SHOW_NAMES)
aBox.Text=string.format("%.2f",ESP_ALPHA)

panel.Size=UDim2.fromOffset(580,520)
panel.BackgroundTransparency=1
tween(panel,{Size=UDim2.fromOffset(620,560),BackgroundTransparency=0},.35)
if UserInputService.TouchEnabled then tween(dim,{BackgroundTransparency=.65},.3) end

print("[Nexus v4] Loaded. Learn punch position, then enable Auto.")
