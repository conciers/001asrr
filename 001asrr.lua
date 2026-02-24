-- Load Millenium UI library
local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/i77lhm/Libraries/refs/heads/main/Millenium/Library.lua"))()

-- Services
local players = game:GetService("Players")
local run = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local ws = game:GetService("Workspace")
local rs = game:GetService("ReplicatedStorage")
local camera = ws.CurrentCamera
local lp = players.LocalPlayer
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:FindService("CoreGui")
local debris = game:GetService("Debris")

-- Flags table
local flags = library.flags

-- ============================================
-- Global Variables
-- ============================================
local aimTarget = nil
local lastTargetUpdate = 0
local espDrawings = {}
local forceHitActive = false
local forceHitTarget = nil
local forceHitHighlight = nil
local chamsEnabled = false
local chamsHighlights = {}
local chamsTag = "AtlantaChams"

-- Self accessories
local wings = {}
local hat = nil

-- Forcefield tracking
local forceFieldTimers = {}
local FORCEFIELD_DURATION = 3

-- FOV Circles
local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Thickness = 1
fovCircle.Filled = false
fovCircle.NumSides = 64
fovCircle.Radius = 100

local fovCircle2 = Drawing.new("Circle")
fovCircle2.Visible = false
fovCircle2.Color = Color3.fromRGB(255, 255, 255)
fovCircle2.Thickness = 1
fovCircle2.Filled = false
fovCircle2.NumSides = 64
fovCircle2.Radius = 100

-- Force hit tracer (with optional glow)
local forceHitTracer = Drawing.new("Line")
forceHitTracer.Visible = false
forceHitTracer.Color = Color3.fromRGB(255, 0, 0)
forceHitTracer.Thickness = 2

local forceHitTracerGlow = Drawing.new("Line")
forceHitTracerGlow.Visible = false
forceHitTracerGlow.Color = Color3.fromRGB(255, 0, 0)
forceHitTracerGlow.Thickness = 4
forceHitTracerGlow.Transparency = 0.5

-- Auto reload variables
local TOOLS = {"[Revolver]","[DoubleBarrel]","[TacticalShotgun]","[SMG]","[Shotgun]","[Silencer]"}
local lastReload = {}
local reloadCd = 0.4

-- ============================================
-- Config System
-- ============================================
local configPath = "AtlantaConfigs"
if not isfolder(configPath) then
    makefolder(configPath)
end

local function saveConfig(name)
    local data = {}
    for flag, value in pairs(flags) do
        if type(value) == "table" and value.Color then
            data[flag] = {Color = value.Color:ToHex(), Transparency = value.Transparency}
        elseif type(value) == "table" and value.key then
            data[flag] = {key = tostring(value.key), mode = value.mode, active = value.active}
        else
            data[flag] = value
        end
    end
    writefile(configPath .. "/" .. name .. ".json", game:GetService("HttpService"):JSONEncode(data))
    library.notifications:create_notification({name = "Config", info = "Saved: " .. name})
end

local function loadConfig(name)
    local file = configPath .. "/" .. name .. ".json"
    if isfile(file) then
        local data = game:GetService("HttpService"):JSONDecode(readfile(file))
        for flag, value in pairs(data) do
            if library.config_flags[flag] then
                if type(value) == "table" and value.Color then
                    library.config_flags[flag](Color3.fromHex(value.Color), value.Transparency)
                elseif type(value) == "table" and value.key then
                    library.config_flags[flag]({key = Enum.KeyCode[value.key], mode = value.mode, active = value.active})
                else
                    library.config_flags[flag](value)
                end
            end
        end
        library.notifications:create_notification({name = "Config", info = "Loaded: " .. name})
    end
end

local function listConfigs()
    local files = listfiles(configPath)
    local names = {}
    for _, file in ipairs(files) do
        local name = file:match("([^/\\]+)%.json$")
        if name then table.insert(names, name) end
    end
    return names
end

local function deleteConfig(name)
    local file = configPath .. "/" .. name .. ".json"
    if isfile(file) then
        delfile(file)
        library.notifications:create_notification({name = "Config", info = "Deleted: " .. name})
    end
end

-- ============================================
-- FOV Update Function
-- ============================================
local function updateFOVCircles()
    if not flags["fov_show"] then
        fovCircle.Visible = false
        fovCircle2.Visible = false
        return
    end
    local radius = flags["fov_radius"] or 100
    local color = flags["fov_color"] and flags["fov_color"].Color or Color3.new(1,1,1)
    local thickness = flags["fov_thickness"] or 1
    local fillTransparency = flags["fov_fill_transparency"] or 1
    local style = flags["fov_style"] or "Screen Center"
    
    fovCircle.Thickness = thickness
    fovCircle2.Thickness = thickness
    fovCircle.Filled = fillTransparency < 1
    fovCircle2.Filled = fillTransparency < 1
    fovCircle.Transparency = fillTransparency
    fovCircle2.Transparency = fillTransparency
    
    fovCircle.Visible = false
    fovCircle2.Visible = false
    
    if style == "Screen Center" then
        fovCircle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
        fovCircle.Radius = radius
        fovCircle.Color = color
        fovCircle.Visible = true
    elseif style == "Mouse" then
        fovCircle.Position = Vector2.new(uis:GetMouseLocation().X, uis:GetMouseLocation().Y)
        fovCircle.Radius = radius
        fovCircle.Color = color
        fovCircle.Visible = true
    elseif style == "Both" then
        fovCircle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
        fovCircle.Radius = radius
        fovCircle.Color = color
        fovCircle.Visible = true
        fovCircle2.Position = Vector2.new(uis:GetMouseLocation().X, uis:GetMouseLocation().Y)
        fovCircle2.Radius = radius
        fovCircle2.Color = color
        fovCircle2.Visible = true
    end
end

local function getClosestPlayerInFOV(center)
    local radius = flags["fov_radius"] or 100
    local closest = nil
    local closestDist = math.huge
    
    for _, plr in ipairs(players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local pos, onScreen = camera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    local screenPos = Vector2.new(pos.X, pos.Y)
                    local dist = (screenPos - center).Magnitude
                    if dist <= radius and dist < closestDist then
                        closestDist = dist
                        closest = plr
                    end
                end
            end
        end
    end
    return closest
end

-- ============================================
-- Target Aim (Mouse Hook)
-- ============================================
local Combat = {
    Target = {
        Enabled = false,
        Keybind = Enum.KeyCode.E,
        Prediction = 0.2,
        Bodyparts = {"Head", "HumanoidRootPart"},
        CurrentTarget = nil
    }
}

local function closestPlayerToMouse()
    local closestPlayer = nil
    local closestDistance = math.huge
    local mousePosition = Vector2.new(uis:GetMouseLocation().X, uis:GetMouseLocation().Y)
    
    for _, player in ipairs(players:GetPlayers()) do
        if player ~= lp then
            local character = player.Character
            if character then
                for _, bodyPart in ipairs(Combat.Target.Bodyparts) do
                    if character:FindFirstChild(bodyPart) then
                        local part = character[bodyPart]
                        local partPosition = part.Position
                        
                        if Combat.Target.Prediction > 0 then
                            local velocity = part.Velocity
                            partPosition = partPosition + (velocity * Combat.Target.Prediction)
                        end
                        
                        local screenPos, onScreen = camera:WorldToViewportPoint(partPosition)
                        
                        if onScreen then
                            local targetPosition = Vector2.new(screenPos.X, screenPos.Y)
                            local distance = (mousePosition - targetPosition).Magnitude
                            
                            if distance < closestDistance then
                                closestPlayer = part
                                closestDistance = distance
                            end
                        end
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

local mouse = lp:GetMouse()
local mt = getrawmetatable(game)
local oldIndex = mt.__index
setreadonly(mt, false)

mt.__index = newcclosure(function(self, key)
    if not checkcaller() and self == mouse and Combat.Target.Enabled and (key == "Hit" or key == "Target") then
        local targetPart = Combat.Target.CurrentTarget or closestPlayerToMouse()
        if targetPart then
            if key == "Hit" then
                return targetPart.CFrame
            elseif key == "Target" then
                return targetPart
            end
        end
    end
    return oldIndex(self, key)
end)

uis.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Combat.Target.Keybind then
        if not Combat.Target.CurrentTarget then
            Combat.Target.CurrentTarget = closestPlayerToMouse()
            Combat.Target.Enabled = true
        else
            Combat.Target.CurrentTarget = nil
            Combat.Target.Enabled = false
        end
    end
end)

-- Target Aim FOV (auto-select)
run.Heartbeat:Connect(function()
    if flags["target_aim_enabled"] and flags["target_fov_enabled"] then
        local style = flags["fov_style"] or "Screen Center"
        local center
        if style == "Screen Center" then
            center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
        else -- "Mouse" or "Both" -> use mouse position
            center = Vector2.new(uis:GetMouseLocation().X, uis:GetMouseLocation().Y)
        end
        local target = getClosestPlayerInFOV(center)
        if target then
            Combat.Target.CurrentTarget = target
        end
    end
end)

-- ============================================
-- Forcefield Tracking
-- ============================================
local function onCharacterAdded(plr, char)
    char.ChildAdded:Connect(function(child)
        if child:IsA("ForceField") then
            forceFieldTimers[plr] = tick()
        end
    end)
    if char:FindFirstChildOfClass("ForceField") then
        forceFieldTimers[plr] = tick()
    end
end

for _, plr in ipairs(players:GetPlayers()) do
    if plr.Character then onCharacterAdded(plr, plr.Character) end
    plr.CharacterAdded:Connect(function(char) onCharacterAdded(plr, char) end)
end

players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char) onCharacterAdded(plr, char) end)
end)

-- ============================================
-- Force Hit (Instant) with bullet visuals/sounds
-- ============================================
local MainEvent = rs:FindFirstChild("MainEvent")

local function LockTarget()
    local closest = nil
    local best = math.huge
    local m = uis:GetMouseLocation()
    for _, plr in ipairs(players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChild("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local scr = camera:WorldToViewportPoint(hrp.Position)
                local dist = (Vector2.new(scr.X, scr.Y) - m).Magnitude
                if dist < best then
                    best = dist
                    closest = plr
                end
            end
        end
    end
    return closest
end

local function ResolveTarget(hrp)
    return hrp.Position + hrp.Velocity * 0.065
end

local function HasForceField(plr)
    return plr.Character and plr.Character:FindFirstChildOfClass("ForceField") ~= nil
end

local function CanShoot(plr)
    return not HasForceField(plr)
end

local function PlayShootSound()
    if flags["bullet_sound"] and flags["bullet_sound"] ~= "None" then
        local soundId = flags["bullet_sound"] == "Gunshot" and "rbxassetid://9120386868" or "rbxassetid://269332701"
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = 0.5
        sound.Parent = workspace.CurrentCamera
        sound:Play()
        debris:AddItem(sound, 1)
    end
end

local function ShootForceHit(t)
    if not t or not t.Character then return false end
    if not CanShoot(t) then return false end
    local hrp = t.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local myHRP = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return false end
    local dist = (myHRP.Position - hrp.Position).Magnitude
    if dist > (flags["forcehit_max_distance"] or 200) then return false end
    local pos = ResolveTarget(hrp)
    if MainEvent then
        local args = {
            "Shoot",
            {
                {
                    {Normal = pos, Instance = hrp, Position = pos},
                    {Normal = pos, Instance = hrp, Position = pos},
                    {Normal = pos, Instance = hrp, Position = pos},
                    {Normal = pos, Instance = hrp, Position = pos},
                    {Normal = pos, Instance = hrp, Position = pos}
                },
                {
                    {thePart = hrp, theOffset = Vector3.new()},
                    {thePart = hrp, theOffset = Vector3.new()},
                    {thePart = hrp, theOffset = Vector3.new()},
                    {thePart = hrp, theOffset = Vector3.new()},
                    {thePart = hrp, theOffset = Vector3.new()}
                },
                myHRP.Position,
                myHRP.Position,
                workspace:GetServerTimeNow()
            }
        }
        pcall(function() MainEvent:FireServer(unpack(args)) end)
        
        -- Play sound
        PlayShootSound()
        
        return true
    end
    return false
end

-- Manual toggle with key (keybind added in UI)
uis.InputBegan:Connect(function(input, gp)
    if gp then return end
    if flags["forcehit_enabled"] and not flags["forcehit_auto_fov"] and input.KeyCode == flags["forcehit_key"] then
        forceHitActive = not forceHitActive
        forceHitTarget = forceHitActive and LockTarget() or nil
        if not forceHitActive and forceHitHighlight then
            forceHitHighlight:Destroy()
            forceHitHighlight = nil
        end
    end
end)

run.RenderStepped:Connect(function()
    updateFOVCircles()
    
    if flags["forcehit_enabled"] and flags["forcehit_auto_fov"] then
        local style = flags["fov_style"] or "Screen Center"
        local center
        if style == "Screen Center" then
            center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
        else -- "Mouse" or "Both"
            center = Vector2.new(uis:GetMouseLocation().X, uis:GetMouseLocation().Y)
        end
        forceHitTarget = getClosestPlayerInFOV(center)
        forceHitActive = forceHitTarget ~= nil
    end
    
    if forceHitActive and forceHitTarget and forceHitTarget.Character then
        -- Only shoot if no forcefield (instant)
        if CanShoot(forceHitTarget) then
            local hrp = forceHitTarget.Character:FindFirstChild("HumanoidRootPart")
            local myHRP = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
            if hrp and myHRP then
                local p1 = camera:WorldToViewportPoint(myHRP.Position)
                local p2 = camera:WorldToViewportPoint(hrp.Position)
                
                -- Draw tracer
                if flags["bullet_tracer"] then
                    forceHitTracer.From = Vector2.new(p1.X, p1.Y)
                    forceHitTracer.To = Vector2.new(p2.X, p2.Y)
                    forceHitTracer.Visible = true
                    forceHitTracer.Color = flags["tracer_color"] and flags["tracer_color"].Color or Color3.fromRGB(255,0,0)
                    forceHitTracer.Thickness = flags["tracer_thickness"] or 2
                    
                    if flags["bullet_tracer_glow"] then
                        forceHitTracerGlow.From = Vector2.new(p1.X, p1.Y)
                        forceHitTracerGlow.To = Vector2.new(p2.X, p2.Y)
                        forceHitTracerGlow.Visible = true
                        forceHitTracerGlow.Color = forceHitTracer.Color
                        forceHitTracerGlow.Thickness = forceHitTracer.Thickness + 2
                    else
                        forceHitTracerGlow.Visible = false
                    end
                else
                    forceHitTracer.Visible = false
                    forceHitTracerGlow.Visible = false
                end
                
                ShootForceHit(forceHitTarget)
            else
                forceHitTracer.Visible = false
                forceHitTracerGlow.Visible = false
            end
        else
            forceHitTracer.Visible = false
            forceHitTracerGlow.Visible = false
        end
        
        -- Highlight
        if flags["target_highlight"] then
            if not forceHitHighlight or forceHitHighlight.Adornee ~= forceHitTarget.Character then
                if forceHitHighlight then forceHitHighlight:Destroy() end
                forceHitHighlight = Instance.new("Highlight")
                forceHitHighlight.FillColor = flags["forcehit_cham_color"] and flags["forcehit_cham_color"].Color or Color3.fromRGB(255,0,0)
                forceHitHighlight.FillTransparency = flags["forcehit_cham_transparency"] or 0.3
                forceHitHighlight.OutlineColor = Color3.new(1,1,1)
                forceHitHighlight.OutlineTransparency = 0
                forceHitHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                forceHitHighlight.Adornee = forceHitTarget.Character
                forceHitHighlight.Parent = CoreGui
            end
        elseif forceHitHighlight then
            forceHitHighlight:Destroy()
            forceHitHighlight = nil
        end
    else
        forceHitTracer.Visible = false
        forceHitTracerGlow.Visible = false
        if forceHitHighlight then
            forceHitHighlight:Destroy()
            forceHitHighlight = nil
        end
    end
end)

-- ============================================
-- Auto Reload
-- ============================================
_G._AutoReloadConnection = run.RenderStepped:Connect(function()
    if not flags["rage_autoreload"] then return end
    local c = lp.Character
    if not c then return end
    for _, n in ipairs(TOOLS) do
        local t = c:FindFirstChild(n)
        if t and (not lastReload[n] or tick() - lastReload[n] >= reloadCd) then
            local s = t:FindFirstChild("Script")
            local a = s and s:FindFirstChild("Ammo")
            if a and a:IsA("IntValue") and a.Value == 0 then
                lastReload[n] = tick()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, nil)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, nil)
            end
        end
    end
end)

-- ============================================
-- ESP (Enhanced)
-- ============================================
local fontOptions = {"System", "Plex", "Monospace", "UI"}
local fontIndices = {System = 0, Plex = 1, Monospace = 2, UI = 3}
local function getFontIndex(name)
    return fontIndices[name] or 3
end

local function createESP(plr)
    local esp = {}
    esp.box = Drawing.new("Square")
    esp.box.Visible = false
    esp.box.Color = flags["box_color"] and flags["box_color"].Color or Color3.new(1,1,1)
    esp.box.Thickness = flags["box_thickness"] or 1
    esp.box.Filled = false
    
    esp.name = Drawing.new("Text")
    esp.name.Visible = false
    esp.name.Color = flags["name_color"] and flags["name_color"].Color or Color3.new(1,1,1)
    esp.name.Center = true
    esp.name.Size = 16
    esp.name.Font = getFontIndex(flags["esp_font"] or "UI")
    esp.name.Outline = flags["esp_name_outline"] or false
    esp.name.OutlineColor = Color3.new(0,0,0)
    
    esp.nameBg = Drawing.new("Square")
    esp.nameBg.Visible = false
    esp.nameBg.Filled = true
    esp.nameBg.Color = flags["esp_name_bg_color"] and flags["esp_name_bg_color"].Color or Color3.new(0,0,0)
    esp.nameBg.Transparency = flags["esp_name_bg_transparency"] or 0.5
    
    esp.healthBar = Drawing.new("Line")
    esp.healthBar.Visible = false
    esp.healthBar.Thickness = 4
    
    esp.healthBarBg = Drawing.new("Line")
    esp.healthBarBg.Visible = false
    esp.healthBarBg.Thickness = 4
    esp.healthBarBg.Color = Color3.new(0,0,0)
    esp.healthBarBg.Transparency = 0.3
    
    esp.healthText = Drawing.new("Text")
    esp.healthText.Visible = false
    esp.healthText.Color = Color3.new(1,1,1)
    esp.healthText.Center = true
    esp.healthText.Size = 14
    esp.healthText.Font = getFontIndex(flags["esp_font"] or "UI")
    
    esp.distance = Drawing.new("Text")
    esp.distance.Visible = false
    esp.distance.Color = flags["distance_color"] and flags["distance_color"].Color or Color3.new(1,1,1)
    esp.distance.Center = true
    esp.distance.Size = 14
    esp.distance.Font = getFontIndex(flags["esp_font"] or "UI")
    
    esp.weapon = Drawing.new("Text")
    esp.weapon.Visible = false
    esp.weapon.Color = flags["weapon_color"] and flags["weapon_color"].Color or Color3.new(1,1,1)
    esp.weapon.Center = true
    esp.weapon.Size = 14
    esp.weapon.Font = getFontIndex(flags["esp_font"] or "UI")
    
    -- Head dot
    esp.head = Drawing.new("Circle")
    esp.head.Visible = false
    esp.head.Radius = flags["head_dot_size"] or 4
    esp.head.Filled = true
    esp.head.Color = flags["head_dot_color"] and flags["head_dot_color"].Color or Color3.new(1,1,1)
    esp.head.NumSides = 16
    
    -- Tracer from crosshair
    esp.tracer = Drawing.new("Line")
    esp.tracer.Visible = false
    esp.tracer.Color = flags["tracer_color"] and flags["tracer_color"].Color or Color3.new(1,1,1)
    esp.tracer.Thickness = 1
    
    -- Skeleton
    esp.skeleton = {}
    for i = 1, 5 do
        esp.skeleton[i] = Drawing.new("Line")
        esp.skeleton[i].Visible = false
        esp.skeleton[i].Color = flags["skeleton_color"] and flags["skeleton_color"].Color or Color3.new(1,1,1)
        esp.skeleton[i].Thickness = 1
    end
    
    espDrawings[plr] = esp
end

local function updateESP(plr)
    local esp = espDrawings[plr]
    if not esp then createESP(plr) esp = espDrawings[plr] end
    if not flags["esp_enabled"] or not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") then
        -- Hide all
        esp.box.Visible = false
        esp.name.Visible = false
        esp.nameBg.Visible = false
        esp.healthBar.Visible = false
        esp.healthBarBg.Visible = false
        esp.healthText.Visible = false
        esp.distance.Visible = false
        esp.weapon.Visible = false
        esp.head.Visible = false
        esp.tracer.Visible = false
        for _, line in ipairs(esp.skeleton) do line.Visible = false end
        return
    end
    
    local hrp = plr.Character.HumanoidRootPart
    local head = plr.Character:FindFirstChild("Head")
    local hum = plr.Character:FindFirstChild("Humanoid")
    local rootPos, onScreen = camera:WorldToViewportPoint(hrp.Position)
    local myHRP = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    
    -- Distance check
    local myPos = myHRP and myHRP.Position
    local dist = myPos and (myPos - hrp.Position).Magnitude or math.huge
    if flags["esp_max_distance"] and dist > flags["esp_max_distance"] then
        onScreen = false
    end
    
    if not onScreen then
        -- Hide if off-screen
        esp.box.Visible = false
        esp.name.Visible = false
        esp.nameBg.Visible = false
        esp.healthBar.Visible = false
        esp.healthBarBg.Visible = false
        esp.healthText.Visible = false
        esp.distance.Visible = false
        esp.weapon.Visible = false
        esp.head.Visible = false
        esp.tracer.Visible = false
        for _, line in ipairs(esp.skeleton) do line.Visible = false end
        return
    end
    
    -- Get bounding box size
    local size = hrp.Size.Y * 3
    if head then
        local headPos, _ = camera:WorldToViewportPoint(head.Position)
        local height = math.abs(rootPos.Y - headPos.Y) * 2
        size = height
    end
    
    local boxHeight = size * 2
    local boxWidth = boxHeight * 0.6
    local boxY = rootPos.Y - boxHeight/2
    local boxX = rootPos.X - boxWidth/2
    
    -- Box
    if flags["esp_boxes"] then
        esp.box.Visible = true
        esp.box.Color = flags["box_color"] and flags["box_color"].Color or Color3.new(1,1,1)
        esp.box.Thickness = flags["box_thickness"] or 1
        esp.box.Position = Vector2.new(boxX, boxY)
        esp.box.Size = Vector2.new(boxWidth, boxHeight)
    else
        esp.box.Visible = false
    end
    
    -- Name with background
    if flags["esp_names"] then
        esp.name.Visible = true
        esp.name.Color = flags["name_color"] and flags["name_color"].Color or Color3.new(1,1,1)
        esp.name.Position = Vector2.new(rootPos.X, boxY - 20)
        esp.name.Text = plr.Name
        esp.name.Outline = flags["esp_name_outline"] or false
        
        if flags["esp_name_bg"] then
            esp.nameBg.Visible = true
            local textSize = esp.name.TextBounds
            esp.nameBg.Position = Vector2.new(rootPos.X - textSize.X/2 - 2, boxY - 20 - textSize.Y/2 - 2)
            esp.nameBg.Size = Vector2.new(textSize.X + 4, textSize.Y + 4)
            esp.nameBg.Color = flags["esp_name_bg_color"] and flags["esp_name_bg_color"].Color or Color3.new(0,0,0)
            esp.nameBg.Transparency = flags["esp_name_bg_transparency"] or 0.5
        else
            esp.nameBg.Visible = false
        end
    else
        esp.name.Visible = false
        esp.nameBg.Visible = false
    end
    
    -- Health bar and text
    if flags["esp_healthbar"] and hum then
        local healthPercent = hum.Health / hum.MaxHealth
        local barX = boxX - 8
        if flags["healthbar_side"] == "Right" then
            barX = boxX + boxWidth + 4
        end
        local barStart = Vector2.new(barX, boxY + boxHeight)
        local barEnd = Vector2.new(barX, boxY)
        
        -- Background
        esp.healthBarBg.From = barStart
        esp.healthBarBg.To = barEnd
        esp.healthBarBg.Visible = true
        
        -- Foreground
        esp.healthBar.From = barStart
        esp.healthBar.To = barStart:Lerp(barEnd, healthPercent)
        local high = flags["health_high"] and flags["health_high"].Color or Color3.new(0,1,0)
        local low = flags["health_low"] and flags["health_low"].Color or Color3.new(1,0,0)
        esp.healthBar.Color = high:Lerp(low, 1 - healthPercent)
        esp.healthBar.Visible = true
        
        if flags["esp_health_text"] then
            esp.healthText.Visible = true
            local textPosX = barX - 15
            if flags["healthbar_side"] == "Right" then
                textPosX = barX + 10
            end
            esp.healthText.Position = Vector2.new(textPosX, boxY + boxHeight + 5)
            if flags["health_text_format"] == "Percentage" then
                esp.healthText.Text = math.floor(healthPercent * 100) .. "%"
            else
                esp.healthText.Text = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)
            end
            esp.healthText.Color = esp.healthBar.Color
        else
            esp.healthText.Visible = false
        end
    else
        esp.healthBar.Visible = false
        esp.healthBarBg.Visible = false
        esp.healthText.Visible = false
    end
    
    -- Distance
    if flags["esp_distance"] and myPos then
        esp.distance.Visible = true
        esp.distance.Color = flags["distance_color"] and flags["distance_color"].Color or Color3.new(1,1,1)
        esp.distance.Position = Vector2.new(rootPos.X, boxY + boxHeight + 20)
        esp.distance.Text = math.floor(dist) .. " studs"
    else
        esp.distance.Visible = false
    end
    
    -- Weapon
    if flags["esp_weapon"] then
        esp.weapon.Visible = true
        esp.weapon.Color = flags["weapon_color"] and flags["weapon_color"].Color or Color3.new(1,1,1)
        esp.weapon.Position = Vector2.new(rootPos.X, boxY + boxHeight + 36)
        local tool = plr.Character:FindFirstChildOfClass("Tool")
        esp.weapon.Text = tool and tool.Name or "None"
    else
        esp.weapon.Visible = false
    end
    
    -- Head dot
    if flags["esp_head_dot"] and head then
        local headPos, _ = camera:WorldToViewportPoint(head.Position)
        esp.head.Visible = true
        esp.head.Position = Vector2.new(headPos.X, headPos.Y)
        esp.head.Color = flags["head_dot_color"] and flags["head_dot_color"].Color or Color3.new(1,1,1)
        esp.head.Radius = flags["head_dot_size"] or 4
    else
        esp.head.Visible = false
    end
    
    -- Tracer from crosshair
    if flags["esp_tracer"] and myHRP and hrp then
        local start = Vector2.new(uis:GetMouseLocation().X, uis:GetMouseLocation().Y)
        local endPos = Vector2.new(rootPos.X, rootPos.Y)
        esp.tracer.From = start
        esp.tracer.To = endPos
        esp.tracer.Visible = true
        esp.tracer.Color = flags["tracer_color"] and flags["tracer_color"].Color or Color3.new(1,1,1)
        esp.tracer.Thickness = flags["tracer_thickness"] or 1
    else
        esp.tracer.Visible = false
    end
    
    -- Skeleton
    if flags["esp_skeleton"] and head and hrp then
        local headPos, _ = camera:WorldToViewportPoint(head.Position)
        local rootPos2 = Vector2.new(rootPos.X, rootPos.Y)
        esp.skeleton[1].From = Vector2.new(headPos.X, headPos.Y)
        esp.skeleton[1].To = rootPos2
        esp.skeleton[1].Visible = true
        esp.skeleton[1].Color = flags["skeleton_color"] and flags["skeleton_color"].Color or Color3.new(1,1,1)
        
        local leftArm = plr.Character:FindFirstChild("Left Arm") or plr.Character:FindFirstChild("LeftHand")
        local rightArm = plr.Character:FindFirstChild("Right Arm") or plr.Character:FindFirstChild("RightHand")
        if leftArm then
            local laPos, _ = camera:WorldToViewportPoint(leftArm.Position)
            esp.skeleton[2].From = rootPos2
            esp.skeleton[2].To = Vector2.new(laPos.X, laPos.Y)
            esp.skeleton[2].Visible = true
            esp.skeleton[2].Color = flags["skeleton_color"] and flags["skeleton_color"].Color or Color3.new(1,1,1)
        end
        if rightArm then
            local raPos, _ = camera:WorldToViewportPoint(rightArm.Position)
            esp.skeleton[3].From = rootPos2
            esp.skeleton[3].To = Vector2.new(raPos.X, raPos.Y)
            esp.skeleton[3].Visible = true
            esp.skeleton[3].Color = flags["skeleton_color"] and flags["skeleton_color"].Color or Color3.new(1,1,1)
        end
    else
        for _, line in ipairs(esp.skeleton) do line.Visible = false end
    end
end

run.RenderStepped:Connect(function()
    for _, plr in ipairs(players:GetPlayers()) do
        if plr ~= lp then updateESP(plr) end
    end
end)

players.PlayerRemoving:Connect(function(plr)
    -- Destroy all ESP drawings for that player
    if espDrawings[plr] then
        for _, drawing in pairs(espDrawings[plr]) do
            drawing:Remove()
        end
        espDrawings[plr] = nil
    end
end)

-- Config flags for ESP updates
library.config_flags["esp_font"] = function(font)
    for _, esp in pairs(espDrawings) do
        if esp.name then esp.name.Font = getFontIndex(font) end
        if esp.healthText then esp.healthText.Font = getFontIndex(font) end
        if esp.distance then esp.distance.Font = getFontIndex(font) end
        if esp.weapon then esp.weapon.Font = getFontIndex(font) end
    end
end

library.config_flags["box_thickness"] = function(v)
    for _, esp in pairs(espDrawings) do
        if esp.box then esp.box.Thickness = v end
    end
end

library.config_flags["head_dot_size"] = function(v)
    for _, esp in pairs(espDrawings) do
        if esp.head then esp.head.Radius = v end
    end
end

-- ============================================
-- Simplified Chams (On/Off with color)
-- ============================================
local function applyChamsToPlayer(plr)
    if plr == lp then return end
    if not flags["chams_enabled"] then
        if chamsHighlights[plr] then
            chamsHighlights[plr]:Destroy()
            chamsHighlights[plr] = nil
        end
        return
    end
    if not plr.Character then return end
    
    if chamsHighlights[plr] then
        chamsHighlights[plr]:Destroy()
        chamsHighlights[plr] = nil
    end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = chamsTag
    highlight.FillColor = flags["chams_color"] and flags["chams_color"].Color or Color3.fromRGB(255,0,0)
    highlight.FillTransparency = 0.3
    highlight.OutlineColor = Color3.new(1,1,1)
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = plr.Character
    highlight.Parent = plr.Character
    
    chamsHighlights[plr] = highlight
end

local function refreshAllChams()
    for plr, _ in pairs(chamsHighlights) do
        if chamsHighlights[plr] then
            chamsHighlights[plr]:Destroy()
            chamsHighlights[plr] = nil
        end
    end
    if flags["chams_enabled"] then
        for _, plr in ipairs(players:GetPlayers()) do
            if plr ~= lp then
                applyChamsToPlayer(plr)
            end
        end
    end
end

players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        if flags["chams_enabled"] then
            task.wait(0.1)
            applyChamsToPlayer(plr)
        end
    end)
end)

for _, plr in ipairs(players:GetPlayers()) do
    if plr ~= lp then
        plr.CharacterAdded:Connect(function()
            applyChamsToPlayer(plr)
        end)
        if plr.Character then
            applyChamsToPlayer(plr)
        end
    end
end

library.config_flags["chams_enabled"] = function(v)
    refreshAllChams()
end
library.config_flags["chams_color"] = function()
    refreshAllChams()
end

-- ============================================
-- Self Wings (Angelic Neon) - Fixed with error handling
-- ============================================
local function destroyWings()
    for _, w in ipairs(wings) do
        if w then pcall(function() w:Destroy() end) end
    end
    wings = {}
end

local function createWings()
    destroyWings()
    if not flags["wings_enabled"] or not lp.Character then return end
    
    local char = lp.Character
    local humanoidRootPart = char:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    local color = flags["wings_color"] and flags["wings_color"].Color or Color3.fromRGB(255,255,255)
    
    local function makeWing(side)
        local part = Instance.new("Part")
        part.Name = "Wing_" .. side
        part.Size = Vector3.new(1, 2, 0.5)
        part.Material = Enum.Material.Neon
        part.Color = color
        part.Transparency = 0.2
        part.Anchored = false
        part.CanCollide = false
        part.Parent = char
        
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.Wedge
        mesh.Parent = part
        
        local weld = Instance.new("Weld")
        weld.Part0 = humanoidRootPart
        weld.Part1 = part
        if side == "Left" then
            weld.C0 = CFrame.new(-1.5, 0.5, 0) * CFrame.Angles(0, math.rad(-30), math.rad(-20))
        else
            weld.C0 = CFrame.new(1.5, 0.5, 0) * CFrame.Angles(0, math.rad(30), math.rad(20))
        end
        weld.Parent = part
        return part
    end
    
    pcall(function()
        local leftWing = makeWing("Left")
        local rightWing = makeWing("Right")
        wings = {leftWing, rightWing}
    end)
end

lp.CharacterAdded:Connect(function()
    task.wait(0.5)
    if flags["wings_enabled"] then
        createWings()
    end
end)

library.config_flags["wings_enabled"] = function(v)
    if v then createWings() else destroyWings() end
end

library.config_flags["wings_color"] = function(color)
    if wings then
        for _, w in ipairs(wings) do
            w.Color = color
        end
    end
end

-- ============================================
-- Self Hat (Chinese Neon Hat) - Fixed with custom mesh
-- ============================================
local function destroyHat()
    if hat then
        pcall(function() hat:Destroy() end)
        hat = nil
    end
end

local function createHat()
    destroyHat()
    if not flags["hat_enabled"] or not lp.Character then return end
    
    local char = lp.Character
    local head = char:FindFirstChild("Head")
    if not head then return end
    
    pcall(function()
        local hatPart = Instance.new("Part")
        hatPart.Name = "ChineseHat"
        hatPart.Size = Vector3.new(2, 2, 2) -- size of the part
        hatPart.Material = Enum.Material.Neon
        hatPart.Color = flags["hat_color"] and flags["hat_color"].Color or Color3.fromRGB(255,0,0)
        hatPart.Transparency = 0.1
        hatPart.Anchored = false
        hatPart.CanCollide = false
        hatPart.Parent = char
        
        -- Use a custom cone mesh
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshId = "rbxassetid://20368050" -- cone mesh
        mesh.TextureId = "" -- no texture
        mesh.Scale = Vector3.new(2, 2, 2) -- scale to fit
        mesh.Parent = hatPart
        
        local weld = Instance.new("Weld")
        weld.Part0 = head
        weld.Part1 = hatPart
        weld.C0 = CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, 0) -- position above head
        weld.Parent = hatPart
        
        hat = hatPart
    end)
end

lp.CharacterAdded:Connect(function()
    task.wait(0.5)
    if flags["hat_enabled"] then
        createHat()
    end
end)

library.config_flags["hat_enabled"] = function(v)
    if v then createHat() else destroyHat() end
end

library.config_flags["hat_color"] = function(color)
    if hat then
        hat.Color = color
    end
end

-- ============================================
-- God Mode
-- ============================================
local godModeActive = false
local godModeTrack
local godModeHeartbeat
local godModeAnimConn
local godModeEmoteId = "rbxassetid://70883871260184"
local godModeFreezeTime = 0.1265

local function gethumanoid()
    local char = lp.Character or lp.CharacterAdded:Wait()
    return char:WaitForChild("Humanoid")
end

local function godModeCleanup()
    if godModeTrack then godModeTrack:Stop() godModeTrack:Destroy() godModeTrack = nil end
    if godModeHeartbeat then godModeHeartbeat:Disconnect() godModeHeartbeat = nil end
    if godModeAnimConn then godModeAnimConn:Disconnect() godModeAnimConn = nil end
end

local function godModeAnimFunc()
    if not godModeActive then return end
    local hum = gethumanoid()
    if not hum then return end
    godModeCleanup()
    local anim = Instance.new("Animation")
    anim.AnimationId = godModeEmoteId
    godModeTrack = hum:LoadAnimation(anim)
    godModeTrack:Play(0, 1, 1)
    godModeHeartbeat = run.Heartbeat:Connect(function()
        if godModeTrack and godModeActive then
            godModeTrack.TimePosition = godModeFreezeTime
            godModeTrack:AdjustSpeed(0)
        end
    end)
    godModeAnimConn = hum.AnimationPlayed:Connect(function(newtrack)
        if godModeActive and godModeTrack and newtrack ~= godModeTrack then
            task.delay(0.02 + math.random() * 0.03, godModeAnimFunc)
        end
    end)
end

function startGodMode()
    if godModeActive then return end
    godModeActive = true
    godModeAnimFunc()
end

function stopGodMode()
    godModeActive = false
    godModeCleanup()
end

lp.CharacterAdded:Connect(function()
    task.wait(0.25)
    if godModeActive then godModeAnimFunc() end
end)

-- ============================================
-- Speed Hack (CFrame Walk Speed)
-- ============================================
run.Heartbeat:Connect(function()
    if flags["speed_enabled"] and lp.Character and lp.Character:FindFirstChild("Humanoid") then
        local hum = lp.Character.Humanoid
        hum.WalkSpeed = flags["speed_value"] or 16
    elseif lp.Character and lp.Character:FindFirstChild("Humanoid") then
        lp.Character.Humanoid.WalkSpeed = 16
    end
end)

-- ============================================
-- Ping Spoofer
-- ============================================
local function spoofPing(value)
    if MainEvent then
        local notifString = "setting ping to <font color=\"#00ff00\">" .. tostring(value) .. "</font> ms"
        MainEvent:FireServer("RequestNotification", notifString)
        for i = 1, 13 do
            MainEvent:FireServer("GetPing")
            wait(0.05)
        end
    end
end

-- ============================================
-- UI Construction
-- ============================================
local window = library:window({
    name = "AtlantaHub",
    suffix = "",
    gameInfo = "Advanced Cheat Menu"
})

-- Main Tab: Target Aim, Rage, Self, Misc
local main_page_target, main_page_rage, main_page_self, main_page_misc = window:tab({name = "Main", tabs = {"Target Aim", "Rage", "Self", "Misc"}})

-- ========== Target Aim Page ==========
local col_target = main_page_target:column({})
local target_section = col_target:section({name = "Target Aim", default = true})

local toggle = target_section:toggle({name = "Enabled", flag = "target_aim_enabled", default = false, seperator = true, callback = function(v)
    Combat.Target.Enabled = v
end})
toggle:keybind({name = "Keybind", flag = "target_aim_key", key = Enum.KeyCode.E})

target_section:toggle({name = "FOV", flag = "target_fov_enabled", default = false, seperator = true})
target_section:slider({name = "Prediction", min = 0, max = 1, default = 0.2, interval = 0.01, flag = "target_aim_prediction", seperator = true, callback = function(v)
    Combat.Target.Prediction = v
end})

-- ========== Rage Page ==========
local col_rage1 = main_page_rage:column({})
local force_section = col_rage1:section({name = "Force Hit", default = true})

local force_toggle = force_section:toggle({name = "Enabled", flag = "forcehit_enabled", default = false, seperator = true})
force_toggle:keybind({name = "Manual Key", flag = "forcehit_key", key = Enum.KeyCode.C})

force_section:toggle({name = "Auto FOV", flag = "forcehit_auto_fov", default = false, seperator = true})
force_section:slider({name = "Max Distance", min = 50, max = 500, default = 200, interval = 10, flag = "forcehit_max_distance", seperator = true})
force_section:toggle({name = "Auto Reload", flag = "rage_autoreload", default = false, seperator = true})

force_section:label({name = "Tracer", seperator = true})
force_section:colorpicker({name = "Color", flag = "tracer_color", color = Color3.fromRGB(255,0,0), seperator = true})
force_section:slider({name = "Thickness", min = 1, max = 5, default = 2, interval = 0.5, flag = "tracer_thickness", seperator = true})
force_section:toggle({name = "Glow Effect", flag = "bullet_tracer_glow", default = false, seperator = true})

force_section:label({name = "Target Highlight", seperator = true})
local highlight_toggle = force_section:toggle({name = "Enabled", flag = "target_highlight", default = false, seperator = true})
highlight_toggle:colorpicker({name = "Color", flag = "forcehit_cham_color", color = Color3.fromRGB(255,0,0)})
:slider({name = "Transparency", min = 0, max = 1, default = 0.3, interval = 0.01, flag = "forcehit_cham_transparency"})

force_section:label({name = "Bullet Visuals", seperator = true})
force_section:toggle({name = "Tracer", flag = "bullet_tracer", default = true, seperator = true})
force_section:dropdown({name = "Sound", items = {"None", "Gunshot", "Laser"}, default = "Gunshot", flag = "bullet_sound", seperator = true})

local col_rage2 = main_page_rage:column({})
local god_section = col_rage2:section({name = "God Mode", default = true})
local god_toggle = god_section:toggle({name = "Enabled", flag = "godmode", default = false, seperator = true, callback = function(v)
    if v then startGodMode() else stopGodMode() end
end})
god_toggle:keybind({name = "Key", flag = "godmode_key", key = Enum.KeyCode.Delete})

-- ========== Self Page ==========
local col_self = main_page_self:column({})
local wings_section = col_self:section({name = "Angel Wings", default = true})
local wings_toggle = wings_section:toggle({name = "Enable", flag = "wings_enabled", default = false, seperator = true})
wings_toggle:colorpicker({name = "Color", flag = "wings_color", color = Color3.fromRGB(255,255,255)})

local hat_section = col_self:section({name = "Chinese Hat", default = true})
local hat_toggle = hat_section:toggle({name = "Enable", flag = "hat_enabled", default = false, seperator = true})
hat_toggle:colorpicker({name = "Color", flag = "hat_color", color = Color3.fromRGB(255,0,0)})

-- ========== Misc Page ==========
local col_misc = main_page_misc:column({})
local misc_section = col_misc:section({name = "Ping Spoofer", default = true})
misc_section:slider({name = "Ping (ms)", min = 0, max = 10000, default = 0, interval = 1, flag = "ping_value", seperator = true})
misc_section:button({name = "Spoof", callback = function()
    spoofPing(flags["ping_value"] or 0)
end})

misc_section:label({name = "Speed Hack", seperator = true})
local speed_toggle = misc_section:toggle({name = "Enabled", flag = "speed_enabled", default = false, seperator = true})
speed_toggle:keybind({name = "Key", flag = "speed_key", key = Enum.KeyCode.LeftControl})
misc_section:slider({name = "Speed", min = 16, max = 200, default = 50, interval = 1, flag = "speed_value", seperator = true})

-- ========== Visuals Tab ==========
local visuals_page_esp, visuals_page_chams, visuals_page_fov = window:tab({name = "Visuals", tabs = {"ESP", "Chams", "FOV"}})

-- ESP Page
local col_esp = visuals_page_esp:column({})
local esp_section = col_esp:section({name = "ESP", default = true})
esp_section:toggle({name = "Enabled", flag = "esp_enabled", default = false, seperator = true})

esp_section:dropdown({name = "Font", items = fontOptions, default = "UI", flag = "esp_font", seperator = true})

local names = esp_section:toggle({name = "Names", flag = "esp_names", default = false, seperator = true})
names:colorpicker({flag = "name_color", color = Color3.fromRGB(255,255,255)})
esp_section:toggle({name = "Name Outline", flag = "esp_name_outline", default = false, seperator = true})
esp_section:toggle({name = "Name Background", flag = "esp_name_bg", default = false, seperator = true})
:colorpicker({flag = "esp_name_bg_color", color = Color3.fromRGB(0,0,0)})
:slider({name = "BG Transparency", min = 0, max = 1, default = 0.5, interval = 0.01, flag = "esp_name_bg_transparency", seperator = true})

local boxes = esp_section:toggle({name = "Boxes", flag = "esp_boxes", default = false, seperator = true})
boxes:colorpicker({flag = "box_color", color = Color3.fromRGB(255,255,255)})
esp_section:slider({name = "Box Thickness", min = 1, max = 3, default = 1, interval = 0.5, flag = "box_thickness", seperator = true})
esp_section:toggle({name = "Rounded Corners", flag = "box_rounded", default = false, seperator = true})

local health = esp_section:toggle({name = "Healthbar", flag = "esp_healthbar", default = false, seperator = true})
health:colorpicker({flag = "health_high", color = Color3.fromRGB(0,255,0)})
:colorpicker({flag = "health_low", color = Color3.fromRGB(255,0,0)})
esp_section:dropdown({name = "Health Bar Side", items = {"Left", "Right"}, default = "Left", flag = "healthbar_side", seperator = true})
esp_section:toggle({name = "Health Text", flag = "esp_health_text", default = false, seperator = true})
esp_section:dropdown({name = "Health Text Format", items = {"Number", "Percentage"}, default = "Number", flag = "health_text_format", seperator = true})

local distance = esp_section:toggle({name = "Distance", flag = "esp_distance", default = false, seperator = true})
distance:colorpicker({flag = "distance_color", color = Color3.fromRGB(255,255,255)})

local weapon = esp_section:toggle({name = "Weapon", flag = "esp_weapon", default = false, seperator = true})
weapon:colorpicker({flag = "weapon_color", color = Color3.fromRGB(255,255,255)})

esp_section:slider({name = "Max Distance", min = 0, max = 1000, default = 500, interval = 10, flag = "esp_max_distance", seperator = true})

esp_section:toggle({name = "Head Dot", flag = "esp_head_dot", default = false, seperator = true})
:colorpicker({flag = "head_dot_color", color = Color3.fromRGB(255,0,0)})
:slider({name = "Head Dot Size", min = 2, max = 10, default = 4, interval = 1, flag = "head_dot_size", seperator = true})

esp_section:toggle({name = "Tracer (Crosshair)", flag = "esp_tracer", default = false, seperator = true})
esp_section:toggle({name = "Skeleton", flag = "esp_skeleton", default = false, seperator = true})
:colorpicker({flag = "skeleton_color", color = Color3.fromRGB(255,255,255)})

-- Chams Page
local col_chams = visuals_page_chams:column({})
local chams_section = col_chams:section({name = "Chams", default = true})
chams_section:toggle({name = "Enable", flag = "chams_enabled", default = false, seperator = true})
chams_section:colorpicker({name = "Color", flag = "chams_color", color = Color3.fromRGB(255,0,0), seperator = true})

-- FOV Page
local col_fov = visuals_page_fov:column({})
local fov_section = col_fov:section({name = "FOV Settings", default = true})
fov_section:toggle({name = "Show FOV", flag = "fov_show", default = true, seperator = true})
fov_section:dropdown({name = "Style", items = {"Screen Center", "Mouse", "Both"}, default = "Screen Center", flag = "fov_style", seperator = true})
fov_section:colorpicker({name = "Color", flag = "fov_color", color = Color3.fromRGB(255,255,255), seperator = true})
fov_section:slider({name = "Radius", min = 50, max = 500, default = 150, interval = 5, flag = "fov_radius", seperator = true})
fov_section:slider({name = "Thickness", min = 1, max = 5, default = 1, interval = 0.5, flag = "fov_thickness", seperator = true})
fov_section:slider({name = "Fill Transparency", min = 0, max = 1, default = 1, interval = 0.01, flag = "fov_fill_transparency", seperator = true})

-- ========== Configs Tab ==========
local configs_tab = window:tab({name = "Configs", tabs = {"Configs"}})
local col_configs = configs_tab:column({})
local config_section = col_configs:section({name = "Config Management", default = true})

local configList = config_section:list({options = listConfigs(), flag = "config_list", seperator = true})
config_section:textbox({name = "Config Name", flag = "config_name", default = "MyConfig", seperator = true})
config_section:button({name = "Save", callback = function()
    saveConfig(flags["config_name"] or "config")
    configList.refresh_options(listConfigs())
end})
config_section:button({name = "Load", callback = function()
    loadConfig(flags["config_list"])
end})
config_section:button({name = "Delete", callback = function()
    deleteConfig(flags["config_list"])
    configList.refresh_options(listConfigs())
end})
config_section:button({name = "Refresh", callback = function()
    configList.refresh_options(listConfigs())
end})

local menu_section = col_configs:section({name = "Menu Settings", default = true})
menu_section:colorpicker({name = "Accent", flag = "menu_accent", color = Color3.fromRGB(155,150,219), callback = function(color)
    library:update_theme("accent", color)
end})
menu_section:keybind({name = "Menu Toggle", flag = "menu_key", key = Enum.KeyCode.Insert, callback = function()
    window.toggle_menu(not window.opened)
end})

-- ============================================
-- Notifications
-- ============================================
library:init_config(window)

library.notifications:create_notification({
    name = "AtlantaHub",
    info = "Loaded",
    lifetime = 2
})
