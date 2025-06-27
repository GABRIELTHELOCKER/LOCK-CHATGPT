local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local camlockEnabled = false
local target = nil
local hitboxParts = {}

-- SETTINGS:
local aimParts = {"HumanoidRootPart"}
local prediction = 0.14314
local offset = 0.09
local fallOffset = 0.09
local antiGroundDistance = 3

-- Function to get the closest target (players + NPCs)
local function getClosestTarget()
    local closest = nil
    local shortestDist = math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, model in ipairs(workspace:GetDescendants()) do
        if model:IsA("Model") and model ~= LocalPlayer.Character then
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            local part = model:FindFirstChild("LowerTorso") or model:FindFirstChild("HumanoidRootPart")
            if humanoid and humanoid.Health > 0 and part then
                local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                    if dist < shortestDist then
                        shortestDist = dist
                        closest = model
                    end
                end
            end
        end
    end

    return closest
end

-- Hitbox visuals
local function updateHitboxVisual(enable)
    for _, part in pairs(hitboxParts) do
        if part and part.Parent then
            part:Destroy()
        end
    end
    hitboxParts = {}

    if enable and target then
        for _, partName in ipairs(aimParts) do
            local bodyPart = target:FindFirstChild(partName)
            if bodyPart then
                local sphere = Instance.new("Part")
                sphere.Shape = Enum.PartType.Ball
                sphere.Size = Vector3.new(4, 4, 4)
                sphere.Anchored = false
                sphere.CanCollide = false
                sphere.Transparency = 0.3
                sphere.Material = Enum.Material.Neon
                sphere.Color = Color3.fromRGB(255, 0, 0)
                sphere.Name = "HitSphere"
                sphere.CFrame = bodyPart.CFrame
                sphere.Parent = bodyPart

                local weld = Instance.new("WeldConstraint")
                weld.Part0 = bodyPart
                weld.Part1 = sphere
                weld.Parent = bodyPart

                table.insert(hitboxParts, sphere)
            end
        end
    end
end

-- UI Button
local function createToggleButton()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CamlockUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 140, 0, 50)
    button.Position = UDim2.new(1, -150, 1, -60)
    button.Text = "Camlock: OFF"
    button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextScaled = true
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Parent = screenGui

    local hue = 0
    RunService.RenderStepped:Connect(function()
        hue = (hue + 0.005) % 1
        button.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
    end)

    -- Draggable GUI
    local dragging = false
    local dragInput, dragStart, startPos

    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = button.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    button.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                        startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    button.Activated:Connect(function()
        if not camlockEnabled then
            target = getClosestTarget()
            if target then
                camlockEnabled = true
                button.Text = "Camlock: ON"
                updateHitboxVisual(true)
            end
        else
            camlockEnabled = false
            button.Text = "Camlock: OFF"
            updateHitboxVisual(false)
            target = nil
        end
    end)
end

-- Relock after target respawn
local function waitForRespawnAndRelock()
    if target then
        local player = Players:GetPlayerFromCharacter(target)
        if player then
            player.CharacterAdded:Connect(function(newChar)
                newChar:WaitForChild("HumanoidRootPart", 5)
                if camlockEnabled then
                    target = newChar
                end
            end)
        end
    end
end

-- Aimbot logic
RunService.RenderStepped:Connect(function()
    if camlockEnabled and target and target:FindFirstChild("HumanoidRootPart") then
        local part = target.HumanoidRootPart
        local predicted = part.Position + (part.Velocity * prediction) + Vector3.new(0, offset, 0)

        -- Anti-groundshot (raise if close to floor)
        local rayOrigin = part.Position
        local rayDirection = Vector3.new(0, -10, 0)
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Blacklist
        rayParams.FilterDescendantsInstances = {target}
        local ray = workspace:Raycast(rayOrigin, rayDirection, rayParams)

        if ray and ray.Distance < antiGroundDistance then
            predicted = predicted + Vector3.new(0, fallOffset, 0)
        end

        Camera.CFrame = CFrame.new(Camera.CFrame.Position, predicted)

        local humanoid = target:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health <= 0 then
            waitForRespawnAndRelock()
            camlockEnabled = true
        end
    end
end)

-- Start GUI
createToggleButton()
