-- aserhub.lua
-- Aser Hub: GitHub-hostable main script
-- Key: aserthegoat67 saved in session (getgenv)
-- Draggable UI, mobile & PC toggle, infinite money loop, 9e16 attempt (adaptive)

-- ========== CONFIG ==========
local REQUIRED_KEY = "aserthegoat67"
local TARGET_TOTAL = 9e16          -- requested target total height
local DEFAULT_SAFE_JUMP = 5e5      -- baseline per-jump (studs)
local MAX_JUMPS_CAP = 20000        -- max iterations allowed (prevents infinite loops)
local MIN_WAIT_BETWEEN_JUMPS = 0.01 -- minimal wait for "instant" feel
local STEP_DELAY = 1
local RETURN_OFFSET = Vector3.new(0,5,0)

local UI_TRANSPARENCY = 0.12
local MOBILE_BTN_TRANSPARENCY = 0.55

-- ========== SESSION GLOBALS ==========
local G = getgenv and getgenv() or _G
G.__ASERHUB_key_entered = G.__ASERHUB_key_entered or false
G.__ASERHUB_saved_key    = G.__ASERHUB_saved_key or nil
G.__ASERHUB_running      = G.__ASERHUB_running or false

-- ========== SERVICES ==========
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ========== UTIL ==========
local function getCharAndHRP(timeout)
    timeout = timeout or 6
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", timeout)
    return char, hrp
end

local function getRemotes()
    local things = Workspace:FindFirstChild("__THINGS") or Workspace:WaitForChild("__THINGS")
    local remotes = things:FindFirstChild("__REMOTES") or things:WaitForChild("__REMOTES")
    local spawnRemote = remotes:FindFirstChild("vehicle_spawn") or remotes:WaitForChild("vehicle_spawn")
    local stopRemote  = remotes:FindFirstChild("vehicle_stop")  or remotes:WaitForChild("vehicle_stop")
    return spawnRemote, stopRemote
end

-- Adaptive instant stacked teleport
local function adaptiveInstantTeleport(totalHeight, statusCallback)
    local safeJump = DEFAULT_SAFE_JUMP
    local naiveJumps = math.ceil(totalHeight / safeJump)
    if naiveJumps > MAX_JUMPS_CAP then
        safeJump = math.ceil(totalHeight / MAX_JUMPS_CAP)
        naiveJumps = math.ceil(totalHeight / safeJump)
        if statusCallback then
            statusCallback(("Target huge: using %d jumps of ~%s studs each (cap %d)."):format(naiveJumps, tostring(math.floor(safeJump)), MAX_JUMPS_CAP))
        end
    else
        if statusCallback then
            statusCallback(("Using %d jumps of %s studs."):format(naiveJumps, tostring(math.floor(safeJump))))
        end
    end

    for i = 1, naiveJumps do
        if not G.__ASERHUB_running then return false, "stopped" end
        local ok, char = pcall(function() return getCharAndHRP() end)
        local hrp = nil
        if ok and char then hrp = char:FindFirstChild("HumanoidRootPart") or nil end
        if not hrp then
            local ok2, c2 = pcall(getCharAndHRP)
            if ok2 then hrp = c2 and c2:FindFirstChild("HumanoidRootPart") or nil end
        end
        if hrp then
            local posOk, pos = pcall(function() return hrp.Position end)
            if posOk and pos then
                local success = pcall(function()
                    hrp.CFrame = CFrame.new(pos + Vector3.new(0, safeJump, 0))
                end)
                if not success then
                    pcall(function() hrp.CFrame = hrp.CFrame + Vector3.new(0, math.max(1e4, safeJump/2), 0) end)
                end
            else
                pcall(function() hrp.CFrame = hrp.CFrame + Vector3.new(0, safeJump, 0) end)
            end
        end
        task.wait(MIN_WAIT_BETWEEN_JUMPS)
    end

    return true, "done"
end

-- Main cycle
local function infiniteLoop(statusCallback)
    while G.__ASERHUB_running do
        local okC, char_or_err = pcall(getCharAndHRP)
        if not okC then
            if statusCallback then statusCallback("Waiting for character...") end
            task.wait(0.5)
            continue
        end
        local char, hrp = char_or_err, (char_or_err and char_or_err:FindFirstChild("HumanoidRootPart")) or nil
        if not hrp then
            local _, hrp2 = pcall(getCharAndHRP)
            hrp = hrp2
        end
        local originCF = hrp and hrp.CFrame or nil

        local spawnRemote, stopRemote
        local okR = pcall(function() spawnRemote, stopRemote = getRemotes() end)
        if not okR then
            if statusCallback then statusCallback("Remotes not found") end
            task.wait(1)
            continue
        end

        pcall(function() spawnRemote:InvokeServer() end)
        if statusCallback then statusCallback("Spawned vehicle") end

        task.wait(STEP_DELAY)
        if not G.__ASERHUB_running then break end

        if statusCallback then statusCallback("Teleporting (instant stack)...") end
        local okT, res = adaptiveInstantTeleport(TARGET_TOTAL, statusCallback)
        if not okT then
            if statusCallback then statusCallback("Teleport aborted: "..tostring(res)) end
        else
            if statusCallback then statusCallback("Teleport complete (attempt).") end
        end

        task.wait(STEP_DELAY)
        if not G.__ASERHUB_running then break end
        pcall(function() stopRemote:InvokeServer() end)
        if statusCallback then statusCallback("Stopped vehicle") end

        task.wait(0.12)

        if originCF then
            local ok2, _ = pcall(getCharAndHRP)
            if ok2 then
                local _, hrpNow = pcall(getCharAndHRP)
                if hrpNow then
                    pcall(function() hrpNow.CFrame = originCF + RETURN_OFFSET end)
                end
            end
        end

        if statusCallback then statusCallback("Cycle complete") end

        task.wait(0.1)
    end
    if statusCallback then
        if G.__ASERHUB_running then statusCallback("Stopping...") else statusCallback("Stopped") end
    end
end

-- ========== UI (draggable) ==========
local function buildUI()
    if player and player:FindFirstChild("PlayerGui") then
        local old = player.PlayerGui:FindFirstChild("AserHub_Root")
        if old then old:Destroy() end
        local oldBtn = player.PlayerGui:FindFirstChild("AserHub_ShowBtn")
        if oldBtn then oldBtn:Destroy() end
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AserHub_Root"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, 480, 0, 300)
    main.Position = UDim2.new(0.5, -240, 0.35, -150)
    main.BackgroundColor3 = Color3.fromRGB(20,20,24)
    main.BackgroundTransparency = UI_TRANSPARENCY
    main.Parent = screenGui
    local corner = Instance.new("UICorner", main); corner.CornerRadius = UDim.new(0,12)

    local topbar = Instance.new("Frame", main)
    topbar.Size = UDim2.new(1, 0, 0, 44)
    topbar.Position = UDim2.new(0,0,0,0)
    topbar.BackgroundColor3 = Color3.fromRGB(30,30,34)
    local topCorner = Instance.new("UICorner", topbar); topCorner.CornerRadius = UDim.new(0,12)

    local title = Instance.new("TextLabel", topbar)
    title.Size = UDim2.new(1, -100, 1, 0); title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1; title.Text = "Aser Hub"; title.Font = Enum.Font.GothamBold
    title.TextSize = 18; title.TextColor3 = Color3.fromRGB(235,235,238); title.TextXAlignment = Enum.TextXAlignment.Left

    local closeBtn = Instance.new("TextButton", topbar)
    closeBtn.Size = UDim2.new(0,28,0,28); closeBtn.Position = UDim2.new(1, -40, 0.5, -14)
    closeBtn.Text = "✕"; closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 18
    closeBtn.BackgroundColor3 = Color3.fromRGB(60,60,66); local cc = Instance.new("UICorner", closeBtn); cc.CornerRadius = UDim.new(1,0)

    closeBtn.MouseButton1Click:Connect(function() screenGui.Enabled = false end)

    -- draggable logic
    local dragging, dragInput, dragStart, startPos
    local function update(input)
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    topbar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then update(input) end
    end)

    local content = Instance.new("Frame", main)
    content.Position = UDim2.new(0,12,0,52)
    content.Size = UDim2.new(1, -24, 1, -64)
    content.BackgroundTransparency = 1

    local tabBtn = Instance.new("TextButton", content)
    tabBtn.Size = UDim2.new(0, 200, 0, 36) tabBtn.Position = UDim2.new(0,0,0,0)
    tabBtn.Text = "Build a Rocket Ship"; tabBtn.Font = Enum.Font.Gotham; tabBtn.TextSize = 15
    tabBtn.BackgroundColor3 = Color3.fromRGB(40,40,46); local tc = Instance.new("UICorner", tabBtn); tc.CornerRadius = UDim.new(0,8)

    local panel = Instance.new("Frame", content)
    panel.Position = UDim2.new(0,0,0,48); panel.Size = UDim2.new(1,0,1,-48); panel.BackgroundColor3 = Color3.fromRGB(26,26,30)
    local pc = Instance.new("UICorner", panel); pc.CornerRadius = UDim.new(0,8)

    local statusLbl = Instance.new("TextLabel", panel)
    statusLbl.Position = UDim2.new(0,12,0,12); statusLbl.Size = UDim2.new(1, -24, 0, 24)
    statusLbl.BackgroundTransparency = 1; statusLbl.Font = Enum.Font.Gotham; statusLbl.TextSize = 14
    statusLbl.Text = "Status: Idle"; statusLbl.TextColor3 = Color3.fromRGB(210,210,215); statusLbl.TextXAlignment = Enum.TextXAlignment.Left

    local toggleCont = Instance.new("Frame", panel)
    toggleCont.Position = UDim2.new(0,12,0,48); toggleCont.Size = UDim2.new(0,360,0,72); toggleCont.BackgroundTransparency = 1

    local toggleLabel = Instance.new("TextLabel", toggleCont)
    toggleLabel.Position = UDim2.new(0,0,0,0); toggleLabel.Size = UDim2.new(0,220,0,26)
    toggleLabel.BackgroundTransparency = 1; toggleLabel.Text = "Infinite Money (not really infinite)"
    toggleLabel.Font = Enum.Font.GothamBold; toggleLabel.TextSize = 16; toggleLabel.TextColor3 = Color3.fromRGB(235,235,235)

    local switch = Instance.new("Frame", toggleCont)
    switch.Position = UDim2.new(0,0,0,34); switch.Size = UDim2.new(0,90,0,34); switch.BackgroundColor3 = Color3.fromRGB(64,64,70)
    local sc = Instance.new("UICorner", switch); sc.CornerRadius = UDim.new(1,0)
    local knob = Instance.new("Frame", switch); knob.Position = UDim2.new(0,4/90,0,4); knob.Size = UDim2.new(0,26,0,26)
    knob.BackgroundColor3 = Color3.fromRGB(235,235,238); local kc = Instance.new("UICorner", knob); kc.CornerRadius = UDim.new(1,0)
    local onColor = Color3.fromRGB(24,190,120); local offColor = Color3.fromRGB(64,64,70)

    local function setStatus(s) statusLbl.Text = "Status: "..tostring(s) end

    local function animateSwitch(isOn)
        TweenService:Create(switch, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = isOn and onColor or offColor}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {Position = isOn and UDim2.new(1, -30, 0, 4) or UDim2.new(0, 4/90, 0, 4)}):Play()
    end

    local function start()
        if G.__ASERHUB_running then return end
        G.__ASERHUB_running = true
        animateSwitch(true)
        setStatus("Running...")
        task.spawn(function() infiniteLoop(setStatus) end)
    end
    local function stop()
        G.__ASERHUB_running = false
        animateSwitch(false)
        setStatus("Stopping...")
    end

    switch.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if G.__ASERHUB_running then stop() else start() end
        end
    end)

    -- key overlay
    local keyOverlay = Instance.new("Frame", screenGui)
    keyOverlay.Name = "KeyOverlay"; keyOverlay.Size = UDim2.new(1,0,1,0)
    keyOverlay.BackgroundColor3 = Color3.fromRGB(12,12,14); keyOverlay.BackgroundTransparency = 0; keyOverlay.ZIndex = 10
    local prompt = Instance.new("TextLabel", keyOverlay)
    prompt.Position = UDim2.new(0.5, -220, 0.28, 0); prompt.Size = UDim2.new(0,440,0,40)
    prompt.BackgroundTransparency = 1; prompt.Font = Enum.Font.GothamBold; prompt.TextSize = 20
    prompt.Text = "Enter Key to Unlock Aser Hub"; prompt.TextColor3 = Color3.fromRGB(235,235,235)

    local textBox = Instance.new("TextBox", keyOverlay)
    textBox.Position = UDim2.new(0.5, -160, 0.5, -22); textBox.Size = UDim2.new(0,320,0,44)
    textBox.PlaceholderText = "Enter key..." ; textBox.Font = Enum.Font.Gotham; textBox.TextSize = 18
    textBox.BackgroundColor3 = Color3.fromRGB(30,30,36); textBox.TextColor3 = Color3.fromRGB(235,235,235)
    local tcorner = Instance.new("UICorner", textBox); tcorner.CornerRadius = UDim.new(0,8)
    local submit = Instance.new("TextButton", keyOverlay)
    submit.Position = UDim2.new(0.5, 170, 0.5, -22); submit.Size = UDim2.new(0,100,0,44)
    submit.Text = "Submit"; submit.Font = Enum.Font.GothamBold; submit.BackgroundColor3 = Color3.fromRGB(54,120,255); submit.TextColor3 = Color3.new(1,1,1)
    local scorner = Instance.new("UICorner", submit); scorner.CornerRadius = UDim.new(0,8)
    local msg = Instance.new("TextLabel", keyOverlay)
    msg.Position = UDim2.new(0.5, -220, 0.5, 36); msg.Size = UDim2.new(0,440,0,22); msg.BackgroundTransparency = 1
    msg.Font = Enum.Font.Gotham; msg.TextSize = 15; msg.TextColor3 = Color3.fromRGB(255,110,110); msg.Text = ""

    local function tryKey()
        local val = tostring(textBox.Text or "")
        if val == REQUIRED_KEY then
            G.__ASERHUB_key_entered = true
            G.__ASERHUB_saved_key = val
            TweenService:Create(keyOverlay, TweenInfo.new(0.18), {BackgroundTransparency = 1}):Play()
            task.delay(0.18, function() if keyOverlay and keyOverlay.Parent then keyOverlay:Destroy() end end)
        else
            msg.Text = "Wrong key."
            TweenService:Create(submit, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(200,60,60)}):Play()
            task.delay(0.16, function() TweenService:Create(submit, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(54,120,255)}):Play() end)
        end
    end

    submit.MouseButton1Click:Connect(tryKey)
    textBox.FocusLost:Connect(function(enter) if enter then tryKey() end end)

    if G.__ASERHUB_key_entered and G.__ASERHUB_saved_key == REQUIRED_KEY then
        if keyOverlay and keyOverlay.Parent then keyOverlay:Destroy() end
    end

    return {
        root = screenGui,
        setStatus = setStatus
    }
end

-- ========== MOBILE SHOW BUTTON ==========
local function makeMobileButton(onClick)
    if not player or not player:FindFirstChild("PlayerGui") then return end
    local gui = Instance.new("ScreenGui", player.PlayerGui)
    gui.Name = "AserHub_ShowBtn"
    gui.ResetOnSpawn = false
    local btn = Instance.new("TextButton", gui)
    btn.Size = UDim2.new(0,44,0,44); btn.Position = UDim2.new(0,8,0.2,0)
    btn.Text = "Hub"; btn.Font = Enum.Font.GothamBold; btn.TextSize = 14
    btn.BackgroundColor3 = Color3.fromRGB(40,40,46); btn.BackgroundTransparency = MOBILE_BTN_TRANSPARENCY
    local c = Instance.new("UICorner", btn); c.CornerRadius = UDim.new(0,8)
    btn.MouseButton1Click:Connect(function() if type(onClick)=="function" then onClick() end end)
    return gui, btn
end

-- ========== BOOT ==========
local ui = buildUI()

local mobileGui, mobileBtn
if UserInputService.TouchEnabled then
    mobileGui, mobileBtn = makeMobileButton(function()
        if ui and ui.root then ui.root.Enabled = not ui.root.Enabled end
    end)
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightAlt then
        if ui and ui.root then ui.root.Enabled = not ui.root.Enabled end
    end
end)

if G.__ASERHUB_key_entered and G.__ASERHUB_saved_key == REQUIRED_KEY then
    if ui and ui.root then ui.root.Enabled = true end
else
    if ui and ui.root then ui.root.Enabled = true end
end

if G.__ASERHUB_running then
    task.spawn(function() infiniteLoop(function(s) if ui and ui.setStatus then ui.setStatus(s) end end) end)
end

print("Aser Hub (GitHub ready) loaded. Key saved in session:", tostring(G.__ASERHUB_key_entered))
