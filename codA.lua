local success, result = pcall(function()
    local game = game
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")

    local localPlayer = Players.LocalPlayer
    local character = localPlayer.Character
    if not character then
        localPlayer.CharacterAdded:Wait()
        character = localPlayer.Character
    end

    -- Create a custom UI for the script
    local playerGui = Instance.new("ScreenGui")
    playerGui.Name = "EggStealerUI"
    playerGui.Parent = localPlayer:WaitForChild("PlayerGui")

    mainFrame = Instance.new("Frame", playerGui)
    mainFrame.Size = UDim2.new(0, 300, 0, 150)
    mainFrame.Position = UDim2.new(0.5, -150, 0.5, -75)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true

    local corner = Instance.new("UICorner", mainFrame)
    corner.CornerRadius = UDim.new(0, 10)

    title = Instance.new("TextLabel", mainFrame)
    title.Size = UDim2.new(1, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    title.BackgroundTransparency = 0.5
    title.Text = "Egg Stealer Pro"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16

    -- Bypass status indicator
    bypassLabel = Instance.new("TextLabel", mainFrame)
    bypassLabel.Size = UDim2.new(1, -20, 0, 20)
    bypassLabel.Position = UDim2.new(0, 10, 0, 35)
    bypassLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    bypassLabel.BackgroundTransparency = 0.5
    bypassLabel.Text = "Status: Initializing..."
    bypassLabel.TextColor3 = Color3.new(1, 1, 1)
    bypassLabel.Font = Enum.Font.Gotham
    bypassLabel.TextSize = 14

    -- Button to start/stop the script
    startButton = Instance.new("TextButton", mainFrame)
    startButton.Size = UDim2.new(0, 140, 0, 30)
    startButton.Position = UDim2.new(0, 10, 0, 60)
    startButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    startButton.Text = "Start Stealing"
    startButton.TextColor3 = Color3.new(1, 1)
    startButton.Font = Enum.Font.GothamBold
    startButton.TextSize = 14
    startButton.AutoButtonColor = true

    -- Button to close the UI
    closeButton = Instance.new("TextButton", mainFrame)
    closeButton.Size = UDim2.new(0, 140, 0, 30)
    closeButton.Position = UDim2.new(0, 150, 0, 60)
    closeButton.BackgroundColor3 = Color3.fromRGB(150, 0)
    closeButton.Text = "Close"
    closeButton.TextColor3 = Color3.new(1, 1, 1)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 14
    closeButton.AutoButtonColor = true

    -- Variables for the script
    local isStealing = false
    local targetEgg = nil
    local lastStealTime = 0

    -- Function to find the nearest egg
    local function findNearestEgg()
        local nearestEgg = nil
        local nearestDistance = math.huge

        local eggs = {}
        -- Find all eggs in the workspace
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name:lower():find("egg") then
                table.insert(eggs, obj)
            end
        end

        for _, egg in ipairs(eggs) do
            local distance = (character:GetPivot().Position - egg.Position).Magnitude
            if distance < nearestDistance then
                nearestDistance = distance
                nearestEgg = egg
            end
        end

        return nearestEgg
    end

    -- Function to steal the egg
    local function stealEgg(egg)
        if not egg or not egg:IsA("BasePart") then
            return false
        end

        -- Change the egg's owner to the local player
        pcall(function()
            egg.Parent = workspace
            egg.CanCollide = false
            egg.Anchored = true
            egg.Transparency = 0.7
            egg.Color = Color3.fromRGB(255, 255, 0)
            egg.Name = "StolenEgg_" .. localPlayer.Name
        end)

        return true
    end

    -- Function to start/stop the stealing
    local function toggleStealing()
        isStealing = not isStealing

        if isStealing then
            startButton.Text = "Stop Stealing"
            startButton.BackgroundColor3 = Color3.fromRGB(150, 150, 0)
            bypassLabel.Text = "Status: Stealing..."
            bypassLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
        else
            startButton.Text = "Start Stealing"
            startButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
            bypassLabel.Text = "Status: Stopped"
            bypassLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end

    -- Connect the buttons
    startButton.MouseButton1Click:Connect(toggleStealing)
    closeButton.MouseButton1Click:Connect(function()
        playerGui:Destroy()
    end)

    -- Main loop for stealing
    RunService.Heartbeat:Connect(function()
        if isStealing and character then
            local currentEgg = findNearestEgg()
            if currentEgg and currentEgg ~= targetEgg then
                targetEgg = currentEgg
                stealEgg(currentEgg)
            end
        end
    end)

    -- Anti-detection: hide the script from admin tools
    local function hideScript()
        pcall(function()
            playerGui.Name = "ScreenGui"
            mainFrame.Name = "Frame"
        end)
    end

    -- Call the hide function after a delay
    task.delay(5, hideScript)

    -- Initial status update
    bypassLabel.Text = "Status: Ready"
    bypassLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
end)

if not success then
    print("Error: " .. result)
end
