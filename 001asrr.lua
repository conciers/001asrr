local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua'))()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local MoneyLoop = false
local TeleportHeight = 9e16

local Window = Rayfield:CreateWindow({
    Name = "I'm goated Lol",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "Please wait",
    Theme = "Dark",
    ToggleKey = Enum.KeyCode.RightAlt
})

-- MainTab

local MainTab = Window:CreateTab("Build a Rocket Ship", 4483362458)

MainTab:CreateToggle({
    Name = "Infinite Money (Not really Infinite)",
    Default = false,
    Callback = function(state)
        MoneyLoop = state
        if MoneyLoop then
            -- Start loop
            task.spawn(function()
                while MoneyLoop do
                    -- Spawn Vehicle
                    pcall(function()
                        Workspace:WaitForChild("__THINGS"):WaitForChild("__REMOTES"):WaitForChild("vehicle_spawn"):InvokeServer()
                    end)
                    task.wait(1)
                    -- Teleport
                    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                    if char:FindFirstChild("HumanoidRootPart") then
                        char.HumanoidRootPart.CFrame = CFrame.new(0, TeleportHeight, 0)
                    end
                    task.wait(1)
                    -- Stop Vehicle
                    pcall(function()
                        Workspace:WaitForChild("__THINGS"):WaitForChild("__REMOTES"):WaitForChild("vehicle_stop"):InvokeServer()
                    end)
                    task.wait(0.1)
                end
            end)
        end
    end
})
