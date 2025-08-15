local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua'))()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- CONFIGS DON'T CHANGE
local MoneyLoop = false
local TeleportHeight = 9e16
local InfMoney2Loop = false

-- LOADER CONFIGS
local Window = Rayfield:CreateWindow({
    Name = "I'm goated Lol",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "Please wait",
    Theme = "Dark",
    ToggleKey = Enum.KeyCode.RightAlt
})

-- MAIN TAB
local MainTab = Window:CreateTab("Build a Rocket Ship", 4483362458)

MainTab:CreateToggle({
    Name = "Infinite Money (Not really Infinite)",
    Default = false,
    Callback = function(state)
        MoneyLoop = state
        if MoneyLoop then
            task.spawn(function()
                while MoneyLoop do
                    pcall(function()
                        Workspace:WaitForChild("__THINGS"):WaitForChild("__REMOTES"):WaitForChild("vehicle_spawn"):InvokeServer()
                    end)
                    task.wait(1)
                    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                    if char:FindFirstChild("HumanoidRootPart") then
                        char.HumanoidRootPart.CFrame = CFrame.new(0, TeleportHeight, 0)
                    end
                    task.wait(1)
                    pcall(function()
                        Workspace:WaitForChild("__THINGS"):WaitForChild("__REMOTES"):WaitForChild("vehicle_stop"):InvokeServer()
                    end)
                    task.wait(0.1)
                end
            end)
        end
    end
})

local SlideTab = Window:CreateTab("Climb and Slide", 4483362458)
SlideTab:CreateLabel("MUST USE ATLEAST 3 PETS FROM THE OP ONE TO HAVE CRAZY AMOUNT OF CASH ALSO DON'T SPAM CLICKING ON THE INF MONEY")

SlideTab:CreateToggle({
    Name = "Inf Money (Not Really 2)",
    Default = false,
    Callback = function(state)
        InfMoney2Loop = state
        if InfMoney2Loop then
            task.spawn(function()
                
                for i = 1, 20 do
                    local args = { "Give_Pet", "Pet_Honey_Huge" }
                    ReplicatedStorage:WaitForChild("R_Pets"):FireServer(unpack(args))
                    task.wait(0.05)
                end
                        
                local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                if char:FindFirstChild("HumanoidRootPart") then
                    char.HumanoidRootPart.CFrame = CFrame.new(3.85000086, 1.21827173, -6.88838387, -1, 0, 0, 0, 1, 0, 0, 0, -1)
                end
                task.wait(0.5)

                if char:FindFirstChild("HumanoidRootPart") then
                    char.HumanoidRootPart.CFrame = CFrame.new(4.50105143, 7004.95605, 15026.1152, 1, -0, 0, 0, 0.90629667, 0.422642082, -0, -0.422642082, 0.90629667)
                end
                task.wait(0.5)

                if char:FindFirstChild("HumanoidRootPart") then
                    char.HumanoidRootPart.CFrame = CFrame.new(13.4999981, 7014.99512, 15088.0918)
                end
                task.wait(0.5)

                if char:FindFirstChild("HumanoidRootPart") then
                    char.HumanoidRootPart.CFrame = CFrame.new(20.3828087, -0.893063188, -0.393669128)
                end
                task.wait(0.5)
                        
                local startTime = tick()
                while tick() - startTime < 5 do
                    for i = 1, 6 do
                        local args = { "Slide", Workspace:WaitForChild("Maps"):WaitForChild("Map_1") }
                        ReplicatedStorage:WaitForChild("R_Server"):FireServer(unpack(args))
                    end
                    task.wait()
                end

                InfMoney2Loop = false
                Rayfield:Notify({
                    Title = "Done",
                    Content = "5 seconds passed",
                    Duration = 3
                })
            end)
        end
    end
})
