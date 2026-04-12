-- loadstring(game:HttpGet('https://raw.githubusercontent.com/euryz/euryz/refs/heads/main/archived/sols-rng-easter.lua'))()
--[[
    SOLS RNG — Egg Farm v2
    Dark Horizontal GUI | Mobile Optimized
    SimplePath AI Pathfinding Engine
]]

---------------------------------------
-- SERVICES
---------------------------------------
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")

---------------------------------------
-- PLAYER
---------------------------------------
local Player = Players.LocalPlayer
local character = Player.Character or Player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

Player.CharacterAdded:Connect(function(char)
    character = char
    humanoid = char:WaitForChild("Humanoid")
    rootPart = char:WaitForChild("HumanoidRootPart")
end)

---------------------------------------
-- CONFIG & STATE
---------------------------------------
local DEBUG_WEBHOOK = false -- Установите true чтобы включить подробное логирование действий для ВСЕХ яиц и клеверов

local Config = {
    Enabled = false,
    EggReachDist = 10,
    StuckThreshold = 2,
    StuckTimeout = 3,
    WaypointSpacing = 4,
    PROMPT_DISTANCE = 3,
    PATH_RECOMPUTE_MAX = 5,
    WALK_SPEED_BOOST = 0,
    AUTO_EQUIP_ABYSSAL = false,
    COLLECT_CLOVERS = false,
    AURA_NOTIFY_ENABLED = false,
    AURA_MIN_SEND = 3,       -- exponent: 10^3 = 1,000 (send auras rarer than 1 in 1,000)
    AURA_MIN_PING = 6,       -- exponent: 10^6 = 1,000,000 (ping for auras rarer than 1 in 1M)
    MAX_EGG_HEIGHT = 130,
    SEARCH_INTERVAL = 1,
    AUTO_USE_STRANGE_CONTROLLER = false,
    AUTO_USE_BIOME_RANDOMIZER = false,
    ITEM_USE_INTERVAL = 20,  -- minutes

    -- Webhooks
    WEBHOOK_URL = "",
    WEBHOOK_WEATHER = "",
    WEBHOOK_RARE_EGGS = "",
    WEBHOOK_MERCHANTS = "",
    WEBHOOK_AURAS = "",
    WEBHOOK_ENABLED = false,
    WEBHOOK_PING_ID = "",
    VIP_SERVER_LINK = "",
    PING_MERCHANT_JESTER = true,
    PING_MERCHANT_RIN = true,
    PING_MERCHANT_MARI = true,
}

local CONFIG_FILE = "SolsRngSettingsV3.json"

local function saveConfig()
    if writefile then
        pcall(function()
            writefile(CONFIG_FILE, HttpService:JSONEncode(Config))
        end)
    end
end

local function loadConfig()
    if readfile and isfile and isfile(CONFIG_FILE) then
        pcall(function()
            local decoded = HttpService:JSONDecode(readfile(CONFIG_FILE))
            if decoded then
                local SKIP_KEYS = {
                    Enabled = true,
                }
                for k, v in pairs(decoded) do
                    if Config[k] ~= nil and not SKIP_KEYS[k] then
                        Config[k] = v
                    end
                end
            end
        end)
    end
end

loadConfig()
-- Always start with farming disabled
Config.Enabled = false
saveConfig()
warn("[SolsFarm] Config loaded. WEBHOOK_ENABLED = " .. tostring(Config.WEBHOOK_ENABLED))
warn("[SolsFarm] WEBHOOK_URL = " .. (Config.WEBHOOK_URL ~= "" and "SET" or "EMPTY"))
warn("[SolsFarm] WEBHOOK_WEATHER = " .. (Config.WEBHOOK_WEATHER ~= "" and "SET" or "EMPTY"))
warn("[SolsFarm] WEBHOOK_RARE_EGGS = " .. (Config.WEBHOOK_RARE_EGGS ~= "" and "SET" or "EMPTY"))

local State = {
    Status = "Idle",
    EggsVisited = 0,
    FarmThread = nil,
    Connections = {},
    LastPosition = nil,
    StuckTimer = 0,
    currentTarget = "—",
    currentEggInstance = nil,
    eggsFound = 0,
    lastStrangeControllerUse = 0,
    lastBiomeRandomizerUse = 0,
}

local ignoredEggs = setmetatable({}, {__mode = "k"})
local sendGenericWebhook = nil

game:GetService("LogService").MessageOut:Connect(function(message, messageType)
    if message:match("Invalid egg") and State.currentEggInstance then
        ignoredEggs[State.currentEggInstance] = true
    end
end)

---------------------------------------
-- EXCLUDED ZONES (from old script)
---------------------------------------
local EXCLUDED_ZONES = {
    { center = Vector3.new(55.676, 102.85, -594.476), radius = 100 },
    { center = Vector3.new(-50.29, 95.5, -102.54), radius = 80 },
    { center = Vector3.new(16.326, 93.75, -438.988), radius = 20 },
    { center = Vector3.new(235.3, 95.8, -622.64), radius = 40 },
    { cframe = CFrame.new(120.687668, 108.350014, -395.919312, 1, -0, 0, 0, 1, -0, 0, 0, 1), size = Vector3.new(25, 15, 25) },
    { cframe = CFrame.new(365, 95, -71, 0, 0, 1, 0, 1, 0, -1, 0, 0), size = Vector3.new(20, 20, 20) },
    { cframe = CFrame.new(-64, 96, -151, 0, 0, 1, 0, 1, 0, -1, 0, 0), size = Vector3.new(20, 20, 20) },
    { cframe = CFrame.new(-10, 95, -138, 0, 0, 1, 0, 1, 0, -1, 0, 0), size = Vector3.new(20, 20, 20) },
    { cframe = CFrame.new(123, 102, -387, 0, 0, 1, 0, 1, 0, -1, 0, 0), size = Vector3.new(10, 10, 10) },
    { cframe = CFrame.new(-48.8700027, 95.6000137, -110.410004, 1, 0, 0, 0, 1, 0, 0, 0, 1), size = Vector3.new(10, 10, 10) },
    { cframe = CFrame.new(-39.512001, 102.799988, -79.0240021, 1, 0, 0, 0, 1, 0, 0, 0, 1), size = Vector3.new(10, 10, 10) },
    { cframe = CFrame.new(202.722015, 103.999969, -660.192017, 1, 0, 0, 0, 1, 0, 0, 0, 1), size = Vector3.new(10, 10, 10) },
    { cframe = CFrame.new(221.343155, 96.5700226, -609.875244, 0, 0, 1, 0, 1, -0, -1, 0, 0), size = Vector3.new(20, 20, 20) },
    { cframe = CFrame.new(155.315994, 97.8000336, -689.891968, 1, 0, 0, 0, 1, 0, 0, 0, 1), size = Vector3.new(20, 20, 20) },
    { cframe = CFrame.new(630.699951, 99.7500458, -102.714005, 1, 0, 0, 0, 1, 0, 0, 0, 1), size = Vector3.new(10, 10, 10) },
    { cframe = CFrame.new(116.350006, 105.799973, -681.98999, 1, 0, 0, 0, 1, 0, 0, 0, 1), size = Vector3.new(10, 10, 10) },
}

local function isPositionExcluded(pos)
    for _, zone in ipairs(EXCLUDED_ZONES) do
        if zone.radius and zone.center then
            if (pos - zone.center).Magnitude <= zone.radius then
                return true
            end
        elseif zone.cframe and zone.size then
            local localPos = zone.cframe:PointToObjectSpace(pos)
            local halfSize = zone.size / 2
            if math.abs(localPos.X) <= halfSize.X and math.abs(localPos.Y) <= halfSize.Y and math.abs(localPos.Z) <= halfSize.Z then
                return true
            end
        end
    end
    return false
end

---------------------------------------
-- EGG PATTERNS
---------------------------------------
local EGG_PATTERNS = {
    "^point_egg_%d+$",
    "^random_potion_egg_%d+$",
}

---------------------------------------
-- UTILITY
---------------------------------------
local function getCharacter()
    return Player.Character or Player.CharacterAdded:Wait()
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRootPart()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getObjPosition(obj)
    if obj:IsA("BasePart") then
        return obj.Position
    elseif obj:IsA("Model") then
        local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
        return primary and primary.Position or obj:GetPivot().Position
    end
    return nil
end

local function isEggName(name)
    for _, pattern in ipairs(EGG_PATTERNS) do
        if string.match(name, pattern) then
            return true
        end
    end
    return false
end

local function getEggPriority(name)
    if string.match(name, "^random_potion_egg_%d+$") then
        return 1
    elseif string.match(name, "^point_egg_%d+$") then
        return 2
    end
    return 3
end

local function distanceTo(pos)
    if not rootPart or not rootPart.Parent then return math.huge end
    return (rootPart.Position - pos).Magnitude
end

local trackedTargetState = setmetatable({}, {__mode = "k"})

local function trackTargetAction(eggObj, action, customName)
    if not DEBUG_WEBHOOK then return end
    if not eggObj or not eggObj.Parent then return end
    
    local currentState = trackedTargetState[eggObj]
    if currentState == action then return end
    -- Prevent background scanner from reverting state and spamming webhooks
    if action == "Detected" and currentState then return end
    trackedTargetState[eggObj] = action

    local displayName = customName or eggObj.Name
    local isPotion = string.match(displayName, "potion")
    local isClover = (displayName == "Clover") or (eggObj:FindFirstChild("effect") and eggObj.effect:FindFirstChild("luckyeffect"))
    if isClover then displayName = "Clover" end
    
    local typeName = isClover and "🍀 Clover" or (isPotion and "🧪 Potion Egg" or "🥚 Egg")
    local typeColor = isClover and 65280 or (isPotion and 10181046 or 14925732)

    local emoji = "🔹"
    if action == "Detected" then emoji = "🔍"
    elseif action == "Moving to collect" then emoji = "🏃"
    elseif action == "Deleted (Exclusion Zone)" then emoji = "🗑️"
    elseif action == "Ignored (Timeout or Error)" then emoji = "🚫"
    elseif action == "Ignored (Already collected)" then emoji = "👻"
    elseif action == "Failed to pathfind" then emoji = "⚠️"
    end

    local pos = "Unknown"
    local part = eggObj:IsA("BasePart") and eggObj or eggObj:FindFirstChildWhichIsA("BasePart", true)
    if part then
        pos = string.format("(%.0f, %.0f, %.0f)", part.Position.X, part.Position.Y, part.Position.Z)
    end

    sendGenericWebhook(
        Config.WEBHOOK_URL,
        emoji .. " Tracking: " .. action,
        "**Target:** `" .. displayName .. "` (" .. typeName .. ")\n**Location:** `" .. pos .. "`\n**Action Taken:** " .. action,
        typeColor,
        "",
        {}
    )
end

local function findAllEggs()
    local eggs = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isEggName(obj.Name) then
            if ignoredEggs[obj] then continue end
            local part = nil
            if obj:IsA("BasePart") then
                part = obj
            elseif obj:IsA("Model") then
                part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
            end

            if part then
                if part.Position.Y > Config.MAX_EGG_HEIGHT then
                    continue
                end

                if isPositionExcluded(part.Position) then
                    trackTargetAction(obj, "Deleted (Exclusion Zone)")
                    pcall(function() obj:Destroy() end)
                    continue
                end

                -- Skip already-collected eggs (mesh becomes transparent after collection)
                local alreadyCollected = false
                if not string.match(obj.Name, "^random_potion_egg_%d+$") then
                    for _, desc in ipairs(obj:GetDescendants()) do
                        if (desc:IsA("MeshPart") or desc:IsA("BasePart") or desc:IsA("SpecialMesh")) and desc.Transparency and desc.Transparency > 0 then
                            alreadyCollected = true
                            break
                        end
                    end
                end
                if alreadyCollected then continue end

                trackTargetAction(obj, "Detected")
                local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                table.insert(eggs, {
                    instance = obj,
                    part     = part,
                    position = part.Position,
                    prompt   = prompt,
                    name     = obj.Name,
                    priority = getEggPriority(obj.Name),
                })
            end
        end
    end

    table.sort(eggs, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        end
        return distanceTo(a.position) < distanceTo(b.position)
    end)

    State.eggsFound = #eggs
    return eggs
end

---------------------------------------
-- CLOVER FINDER
---------------------------------------
local function findClovers()
    local clovers = {}
    local mapFolder = Workspace:FindFirstChild("Map")
    if not mapFolder then return clovers end

    for _, model in ipairs(mapFolder:GetChildren()) do
        if not model:IsA("Model") then continue end

        -- Look for model.effect.luckyeffect
        local effectFolder = model:FindFirstChild("effect")
        if not effectFolder then continue end

        local luckyEffect = effectFolder:FindFirstChild("luckyeffect")
        if not luckyEffect then continue end

        -- Find a part to navigate to
        local part = nil
        if model.PrimaryPart then
            part = model.PrimaryPart
        else
            part = model:FindFirstChildWhichIsA("BasePart", true)
        end
        if not part then continue end

        -- Height & excluded zone check (same as eggs)
        if part.Position.Y > Config.MAX_EGG_HEIGHT then continue end

        if isPositionExcluded(part.Position) then 
            trackTargetAction(model, "Deleted (Exclusion Zone)")
            pcall(function() model:Destroy() end)
            continue 
        end

        trackTargetAction(model, "Detected")
        -- Find proximity prompt
        local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)

        table.insert(clovers, {
            instance = model,
            part     = part,
            position = part.Position,
            prompt   = prompt,
            name     = "Clover",
            priority = 10,  -- lowest priority
        })
    end

    -- Sort by distance
    table.sort(clovers, function(a, b)
        return distanceTo(a.position) < distanceTo(b.position)
    end)

    return clovers
end

---------------------------------------
-- GUI CREATION
---------------------------------------
local guiParent = (typeof(gethui) == "function" and gethui()) or Player:WaitForChild("PlayerGui")

-- cleanup old
local old = guiParent:FindFirstChild("SolsEggFarmV2")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SolsEggFarmV2"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = guiParent

-- Main bar — widened to 500 to fit gear + close btns
local MainBar = Instance.new("Frame")
MainBar.Name = "MainBar"
MainBar.Size = UDim2.new(0, 500, 0, 52)
MainBar.Position = UDim2.new(0.5, 0, 1, 0)
MainBar.AnchorPoint = Vector2.new(0.5, 1)
MainBar.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
MainBar.BorderSizePixel = 0
MainBar.ClipsDescendants = true
MainBar.Active = true
MainBar.ZIndex = 20
MainBar.Parent = ScreenGui

Instance.new("UICorner", MainBar).CornerRadius = UDim.new(0, 14)

local barStroke = Instance.new("UIStroke")
barStroke.Color = Color3.fromRGB(38, 38, 50)
barStroke.Thickness = 1.2
barStroke.Transparency = 0.2
barStroke.Parent = MainBar

-- Accent gradient line at top
local AccentLine = Instance.new("Frame")
AccentLine.Size = UDim2.new(1, -16, 0, 2)
AccentLine.Position = UDim2.new(0, 8, 0, 3)
AccentLine.BackgroundColor3 = Color3.new(1, 1, 1)
AccentLine.BorderSizePixel = 0
AccentLine.Parent = MainBar
Instance.new("UICorner", AccentLine).CornerRadius = UDim.new(0, 2)

local accentGrad = Instance.new("UIGradient")
accentGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 180, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 60, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 40, 180)),
})
accentGrad.Parent = AccentLine

-- Bottom glow line
local BottomGlow = Instance.new("Frame")
BottomGlow.Size = UDim2.new(0.6, 0, 0, 1)
BottomGlow.Position = UDim2.new(0.2, 0, 1, -2)
BottomGlow.BackgroundColor3 = Color3.fromRGB(0, 160, 255)
BottomGlow.BackgroundTransparency = 0.5
BottomGlow.BorderSizePixel = 0
BottomGlow.Parent = MainBar

-- Content area (below accent line)
local contentY = 10
local contentH = 36

-- helper: vertical divider (absolute pos)
local function makeDivider(xPos)
    local d = Instance.new("Frame")
    d.Size = UDim2.new(0, 1, 0, 22)
    d.Position = UDim2.new(0, xPos, 0, contentY + 6)
    d.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    d.BorderSizePixel = 0
    d.Parent = MainBar
    return d
end

-- ===== TITLE (drag handle) =====
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(0, 100, 0, contentH)
TitleLabel.Position = UDim2.new(0, 12, 0, contentY)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🥚 SOLS FARM"
TitleLabel.TextColor3 = Color3.fromRGB(225, 225, 240)
TitleLabel.TextSize = 13
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = MainBar

makeDivider(118)

-- ===== TOGGLE =====
local ToggleWrap = Instance.new("Frame")
ToggleWrap.Size = UDim2.new(0, 80, 0, contentH)
ToggleWrap.Position = UDim2.new(0, 126, 0, contentY)
ToggleWrap.BackgroundTransparency = 1
ToggleWrap.Parent = MainBar

local ToggleLbl = Instance.new("TextLabel")
ToggleLbl.Size = UDim2.new(1, 0, 0, 12)
ToggleLbl.Position = UDim2.new(0, 0, 0, 0)
ToggleLbl.BackgroundTransparency = 1
ToggleLbl.Text = "AUTO FARM"
ToggleLbl.TextColor3 = Color3.fromRGB(120, 120, 145)
ToggleLbl.TextSize = 9
ToggleLbl.Font = Enum.Font.GothamMedium
ToggleLbl.TextXAlignment = Enum.TextXAlignment.Center
ToggleLbl.Parent = ToggleWrap

local ToggleTrack = Instance.new("Frame")
ToggleTrack.Size = UDim2.new(0, 42, 0, 20)
ToggleTrack.Position = UDim2.new(0.5, -21, 0, 14)
ToggleTrack.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
ToggleTrack.BorderSizePixel = 0
ToggleTrack.Parent = ToggleWrap
Instance.new("UICorner", ToggleTrack).CornerRadius = UDim.new(1, 0)

local trkStroke = Instance.new("UIStroke")
trkStroke.Color = Color3.fromRGB(50, 50, 65)
trkStroke.Thickness = 1
trkStroke.Parent = ToggleTrack

local Knob = Instance.new("Frame")
Knob.Size = UDim2.new(0, 16, 0, 16)
Knob.Position = UDim2.new(0, 2, 0.5, -8)
Knob.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
Knob.BorderSizePixel = 0
Knob.Parent = ToggleTrack
Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(1, 12, 1, 12)
ToggleBtn.Position = UDim2.new(0, -6, 0, -6)
ToggleBtn.BackgroundTransparency = 1
ToggleBtn.Text = ""
ToggleBtn.Parent = ToggleTrack

makeDivider(212)

-- ===== STATUS =====
local StatusWrap = Instance.new("Frame")
StatusWrap.Size = UDim2.new(0, 130, 0, contentH)
StatusWrap.Position = UDim2.new(0, 220, 0, contentY)
StatusWrap.BackgroundTransparency = 1
StatusWrap.Parent = MainBar

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.new(0, 7, 0, 7)
StatusDot.Position = UDim2.new(0, 2, 0.5, -3)
StatusDot.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
StatusDot.BorderSizePixel = 0
StatusDot.Parent = StatusWrap
Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)

local StatusText = Instance.new("TextLabel")
StatusText.Size = UDim2.new(1, -16, 1, 0)
StatusText.Position = UDim2.new(0, 16, 0, 0)
StatusText.BackgroundTransparency = 1
StatusText.Text = "Idle"
StatusText.TextColor3 = Color3.fromRGB(150, 150, 170)
StatusText.TextSize = 11
StatusText.Font = Enum.Font.GothamMedium
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.TextTruncate = Enum.TextTruncate.AtEnd
StatusText.Parent = StatusWrap

makeDivider(354)

-- ===== EGG COUNTER =====
local EggLabel = Instance.new("TextLabel")
EggLabel.Size = UDim2.new(0, 50, 0, contentH)
EggLabel.Position = UDim2.new(0, 362, 0, contentY)
EggLabel.BackgroundTransparency = 1
EggLabel.Text = "🥚 0"
EggLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
EggLabel.TextSize = 11
EggLabel.Font = Enum.Font.GothamBold
EggLabel.TextXAlignment = Enum.TextXAlignment.Center
EggLabel.Parent = MainBar

makeDivider(416)

-- ===== SETTINGS GEAR BTN =====
local GearBtn = Instance.new("TextButton")
GearBtn.Size = UDim2.new(0, 28, 0, 28)
GearBtn.Position = UDim2.new(0, 424, 0, contentY + 4)
GearBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
GearBtn.BorderSizePixel = 0
GearBtn.Text = "⚙"
GearBtn.TextColor3 = Color3.fromRGB(140, 140, 160)
GearBtn.TextSize = 16
GearBtn.Font = Enum.Font.GothamBold
GearBtn.AutoButtonColor = false
GearBtn.Parent = MainBar
Instance.new("UICorner", GearBtn).CornerRadius = UDim.new(0, 8)

-- ===== CLOSE BTN =====
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(0, 460, 0, contentY + 4)
CloseBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = ""
CloseBtn.TextColor3 = Color3.fromRGB(140, 140, 160)
CloseBtn.TextSize = 14
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = MainBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)

-- Рисуем X из двух наклонных линий
local function makeXLine(rotation)
    local line = Instance.new("Frame")
    line.Size = UDim2.new(0, 16, 0, 2)
    line.Position = UDim2.new(0.5, -8, 0.5, -1)
    line.AnchorPoint = Vector2.new(0, 0)
    line.BackgroundColor3 = Color3.fromRGB(140, 140, 160)
    line.BorderSizePixel = 0
    line.Rotation = rotation
    line.Parent = CloseBtn
    Instance.new("UICorner", line).CornerRadius = UDim.new(0, 1)
    return line
end

local xLine1 = makeXLine(45)
local xLine2 = makeXLine(-45)

---------------------------------------
-- SETTINGS MODAL (centered overlay)
---------------------------------------

-- Dimmed backdrop
local SettingsOverlay = Instance.new("Frame")
SettingsOverlay.Name = "SettingsOverlay"
SettingsOverlay.Size = UDim2.new(1, 0, 1, 0)
SettingsOverlay.Position = UDim2.new(0, 0, 0, 0)
SettingsOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
SettingsOverlay.BackgroundTransparency = 1
SettingsOverlay.BorderSizePixel = 0
SettingsOverlay.Visible = false
SettingsOverlay.ZIndex = 10
SettingsOverlay.Active = true
SettingsOverlay.Parent = ScreenGui

-- Modal container (centered, responsive)
local SettingsPanel = Instance.new("Frame")
SettingsPanel.Name = "SettingsPanel"
SettingsPanel.AnchorPoint = Vector2.new(0.5, 0.5)
SettingsPanel.Size = UDim2.new(0.88, 0, 0.78, 0)
SettingsPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
SettingsPanel.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
SettingsPanel.BorderSizePixel = 0
SettingsPanel.ClipsDescendants = true
SettingsPanel.ZIndex = 11
SettingsPanel.Parent = SettingsOverlay
Instance.new("UICorner", SettingsPanel).CornerRadius = UDim.new(0, 14)

local UISizeConstraint = Instance.new("UISizeConstraint")
UISizeConstraint.MaxSize = Vector2.new(650, 420)
UISizeConstraint.MinSize = Vector2.new(450, 280)
UISizeConstraint.Parent = SettingsPanel

local spStroke = Instance.new("UIStroke")
spStroke.Color = Color3.fromRGB(40, 40, 55)
spStroke.Thickness = 1.5
spStroke.Parent = SettingsPanel

local headerBar = Instance.new("Frame")
headerBar.Size = UDim2.new(1, 0, 0, 40)
headerBar.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
headerBar.BorderSizePixel = 0
headerBar.ZIndex = 12
headerBar.Parent = SettingsPanel
Instance.new("UICorner", headerBar).CornerRadius = UDim.new(0, 14)

local headerCover = Instance.new("Frame")
headerCover.Size = UDim2.new(1, 0, 0, 14)
headerCover.Position = UDim2.new(0, 0, 1, -14)
headerCover.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
headerCover.BorderSizePixel = 0
headerCover.ZIndex = 12
headerCover.Parent = headerBar

local spTitle = Instance.new("TextLabel")
spTitle.Size = UDim2.new(1, -44, 1, 0)
spTitle.Position = UDim2.new(0, 14, 0, 0)
spTitle.BackgroundTransparency = 1
spTitle.Text = "\u{2699}  Settings"
spTitle.TextColor3 = Color3.fromRGB(220, 220, 240)
spTitle.TextSize = 15
spTitle.Font = Enum.Font.GothamBold
spTitle.TextXAlignment = Enum.TextXAlignment.Left
spTitle.ZIndex = 13
spTitle.Parent = headerBar

local versionLbl = Instance.new("TextLabel")
versionLbl.Size = UDim2.new(0, 50, 1, 0)
versionLbl.Position = UDim2.new(1, -95, 0, 0)
versionLbl.BackgroundTransparency = 1
versionLbl.Text = "v1.15" -- CHANGE IT ALWAYS AFTER UPDATING SCRIPT +0.01 (dont remove this comment)
versionLbl.TextColor3 = Color3.fromRGB(100, 100, 130)
versionLbl.TextSize = 11
versionLbl.Font = Enum.Font.GothamBold
versionLbl.TextXAlignment = Enum.TextXAlignment.Right
versionLbl.ZIndex = 13
versionLbl.Parent = headerBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -36, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
closeBtn.BorderSizePixel = 0
closeBtn.Text = ""
closeBtn.AutoButtonColor = false
closeBtn.ZIndex = 13
closeBtn.Parent = headerBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

local function makeModalXLine(rotation)
    local line = Instance.new("Frame")
    line.Size = UDim2.new(0, 16, 0, 2)
    line.Position = UDim2.new(0.5, -8, 0.5, -1)
    line.AnchorPoint = Vector2.new(0, 0)
    line.BackgroundColor3 = Color3.fromRGB(160, 160, 180)
    line.BorderSizePixel = 0
    line.Rotation = rotation
    line.ZIndex = 14
    line.Parent = closeBtn
    Instance.new("UICorner", line).CornerRadius = UDim.new(0, 1)
    return line
end
local cX1 = makeModalXLine(45)
local cX2 = makeModalXLine(-45)
closeBtn.MouseEnter:Connect(function()
    game:GetService("TweenService"):Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(200, 50, 60)}):Play()
    cX1.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    cX2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
end)
closeBtn.MouseLeave:Connect(function()
    game:GetService("TweenService"):Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(30, 30, 40)}):Play()
    cX1.BackgroundColor3 = Color3.fromRGB(160, 160, 180)
    cX2.BackgroundColor3 = Color3.fromRGB(160, 160, 180)
end)

local SettingsScroll = Instance.new("ScrollingFrame")
SettingsScroll.Name = "SettingsScroll"
SettingsScroll.Size = UDim2.new(1, 0, 1, -40)
SettingsScroll.Position = UDim2.new(0, 0, 0, 40)
SettingsScroll.BackgroundTransparency = 1
SettingsScroll.BorderSizePixel = 0
SettingsScroll.CanvasSize = UDim2.new(0, 0, 0, 400)
SettingsScroll.ScrollBarThickness = 3
SettingsScroll.ScrollBarImageColor3 = Color3.fromRGB(50, 50, 70)
SettingsScroll.ZIndex = 11
SettingsScroll.Parent = SettingsPanel

local LeftCol = Instance.new("Frame")
LeftCol.Size = UDim2.new(0.5, -10, 1, 0)
LeftCol.Position = UDim2.new(0, 10, 0, 0)
LeftCol.BackgroundTransparency = 1
LeftCol.Parent = SettingsScroll
local LeftList = Instance.new("UIListLayout", LeftCol)
LeftList.SortOrder = Enum.SortOrder.LayoutOrder
LeftList.Padding = UDim.new(0, 6)

local RightCol = Instance.new("Frame")
RightCol.Size = UDim2.new(0.5, -20, 1, 0)
RightCol.Position = UDim2.new(0.5, 0, 0, 0)
RightCol.BackgroundTransparency = 1
RightCol.Parent = SettingsScroll
local RightList = Instance.new("UIListLayout", RightCol)
RightList.SortOrder = Enum.SortOrder.LayoutOrder
RightList.Padding = UDim.new(0, 6)

local function updateScroll()
    SettingsScroll.CanvasSize = UDim2.new(0, 0, 0, math.max(LeftList.AbsoluteContentSize.Y, RightList.AbsoluteContentSize.Y) + 20)
end
LeftList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateScroll)
RightList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateScroll)

local function getTargetCol(y)
    return y < 380 and LeftCol or RightCol
end

local function createSectionHeader(yPos, text)
    local target = getTargetCol(yPos)
    local group = Instance.new("Frame")
    group.Size = UDim2.new(1, 0, 0, 24)
    group.BackgroundTransparency = 1
    group.ZIndex = 11
    group.Parent = target
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, 0, 1, 0)
    header.BackgroundTransparency = 1
    header.Text = text
    header.TextColor3 = Color3.fromRGB(0, 170, 255)
    header.TextSize = 13
    header.Font = Enum.Font.GothamBold
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.ZIndex = 11
    header.Parent = group
    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 1, -1)
    line.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    line.BorderSizePixel = 0
    line.ZIndex = 11
    line.Parent = group
end

local function createSettingsToggle(yPos, label, configKey)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -10, 0, 38)
    row.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    row.BorderSizePixel = 0
    row.ZIndex = 11
    row.Parent = getTargetCol(yPos)
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(190, 190, 210)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 11
    lbl.Parent = row
    local switchTrack = Instance.new("Frame")
    switchTrack.Size = UDim2.new(0, 38, 0, 20)
    switchTrack.Position = UDim2.new(1, -48, 0.5, -10)
    switchTrack.BackgroundColor3 = Config[configKey] and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(40, 40, 55)
    switchTrack.BorderSizePixel = 0
    switchTrack.ZIndex = 12
    switchTrack.Parent = row
    Instance.new("UICorner", switchTrack).CornerRadius = UDim.new(1, 0)
    local switchKnob = Instance.new("Frame")
    switchKnob.Size = UDim2.new(0, 16, 0, 16)
    switchKnob.Position = Config[configKey] and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    switchKnob.BackgroundColor3 = Color3.new(1, 1, 1)
    switchKnob.BorderSizePixel = 0
    switchKnob.ZIndex = 13
    switchKnob.Parent = switchTrack
    Instance.new("UICorner", switchKnob).CornerRadius = UDim.new(1, 0)
    local switchBtn = Instance.new("TextButton")
    switchBtn.Size = UDim2.new(1, 0, 1, 0)
    switchBtn.BackgroundTransparency = 1
    switchBtn.Text = ""
    switchBtn.ZIndex = 14
    switchBtn.Parent = switchTrack
    switchBtn.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        saveConfig()
        local on = Config[configKey]
        local ti = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        TweenService:Create(switchTrack, ti, {BackgroundColor3 = on and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(40, 40, 55)}):Play()
        TweenService:Create(switchKnob, ti, {Position = on and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}):Play()
    end)
end

local function createSettingsSlider(yPos, label, min, max, configKey)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -10, 0, 38)
    row.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    row.BorderSizePixel = 0
    row.ZIndex = 11
    row.Parent = getTargetCol(yPos)
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 95, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(190, 190, 210)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 11
    lbl.Parent = row
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -155, 0, 4)
    track.Position = UDim2.new(0, 110, 0.5, -2)
    track.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    track.BorderSizePixel = 0
    track.ZIndex = 11
    track.Parent = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    local valDisplay = Instance.new("TextLabel")
    valDisplay.Size = UDim2.new(0, 28, 1, 0)
    valDisplay.Position = UDim2.new(1, -36, 0, 0)
    valDisplay.BackgroundTransparency = 1
    valDisplay.Text = tostring(Config[configKey])
    valDisplay.TextColor3 = Color3.fromRGB(0, 170, 255)
    valDisplay.TextSize = 13
    valDisplay.Font = Enum.Font.GothamBold
    valDisplay.ZIndex = 11
    valDisplay.Parent = row
    local initRel = math.clamp((Config[configKey] - min) / (max - min), 0, 1)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(initRel, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    fill.BorderSizePixel = 0
    fill.ZIndex = 11
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(initRel, -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 12
    knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local sliding = false
    local function updateFromInput(inputX)
        local tPos = track.AbsolutePosition.X
        local tSize = track.AbsoluteSize.X
        local rel = math.clamp((inputX - tPos) / tSize, 0, 1)
        local value = math.floor(min + rel * (max - min) + 0.5)
        rel = (value - min) / (max - min)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -7, 0.5, -7)
        valDisplay.Text = tostring(value)
        Config[configKey] = value
    end
    local hitBtn = Instance.new("TextButton")
    hitBtn.Size = UDim2.new(1, 10, 0, 24)
    hitBtn.Position = UDim2.new(0, -5, 0.5, -12)
    hitBtn.BackgroundTransparency = 1
    hitBtn.Text = ""
    hitBtn.ZIndex = 13
    hitBtn.Parent = track
    hitBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            updateFromInput(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromInput(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if sliding then
                sliding = false
                saveConfig()
            end
        end
    end)
end

local function formatRarityExp(exp)
    local val = math.pow(10, exp)
    if val >= 1e9 then return string.format("1 in %.0fB", val / 1e9)
    elseif val >= 1e6 then return string.format("1 in %.0fM", val / 1e6)
    elseif val >= 1e3 then return string.format("1 in %.0fK", val / 1e3)
    else return "1 in " .. tostring(math.floor(val)) end
end

local function createRaritySlider(yPos, label, configKey)
    local min, max = 1, 10
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -10, 0, 38)
    row.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    row.BorderSizePixel = 0
    row.ZIndex = 11
    row.Parent = getTargetCol(yPos)
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 64, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(190, 190, 210)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 11
    lbl.Parent = row
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -145, 0, 4)
    track.Position = UDim2.new(0, 78, 0.5, -2)
    track.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    track.BorderSizePixel = 0
    track.ZIndex = 11
    track.Parent = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    local valDisplay = Instance.new("TextLabel")
    valDisplay.Size = UDim2.new(0, 54, 1, 0)
    valDisplay.Position = UDim2.new(1, -60, 0, 0)
    valDisplay.BackgroundTransparency = 1
    valDisplay.Text = formatRarityExp(Config[configKey])
    valDisplay.TextColor3 = Color3.fromRGB(255, 200, 50)
    valDisplay.TextSize = 10
    valDisplay.Font = Enum.Font.GothamBold
    valDisplay.ZIndex = 11
    valDisplay.Parent = row
    local initRel = math.clamp((Config[configKey] - min) / (max - min), 0, 1)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(initRel, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
    fill.BorderSizePixel = 0
    fill.ZIndex = 11
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(initRel, -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 12
    knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local sliding = false
    local function updateFromInput(inputX)
        local tPos = track.AbsolutePosition.X
        local tSize = track.AbsoluteSize.X
        local rel = math.clamp((inputX - tPos) / tSize, 0, 1)
        local value = math.floor(min + rel * (max - min) + 0.5)
        rel = (value - min) / (max - min)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -7, 0.5, -7)
        valDisplay.Text = formatRarityExp(value)
        Config[configKey] = value
    end
    local hitBtn = Instance.new("TextButton")
    hitBtn.Size = UDim2.new(1, 10, 0, 24)
    hitBtn.Position = UDim2.new(0, -5, 0.5, -12)
    hitBtn.BackgroundTransparency = 1
    hitBtn.Text = ""
    hitBtn.ZIndex = 13
    hitBtn.Parent = track
    hitBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            updateFromInput(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromInput(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if sliding then
                sliding = false
                saveConfig()
            end
        end
    end)
end

local function createWebhookInput(yPos, label, configKey, placeholder)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -10, 0, 52)
    row.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    row.BorderSizePixel = 0
    row.ZIndex = 11
    row.Parent = getTargetCol(yPos)
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -24, 0, 18)
    lbl.Position = UDim2.new(0, 12, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(140, 140, 170)
    lbl.TextSize = 10
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 11
    lbl.Parent = row
    local inputBox = Instance.new("TextBox")
    inputBox.Size = UDim2.new(1, -24, 0, 24)
    inputBox.Position = UDim2.new(0, 12, 0, 22)
    inputBox.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
    inputBox.BorderSizePixel = 0
    inputBox.Text = Config[configKey] or ""
    inputBox.PlaceholderText = placeholder or "Paste webhook URL..."
    inputBox.TextColor3 = Color3.fromRGB(100, 180, 255)
    inputBox.PlaceholderColor3 = Color3.fromRGB(50, 50, 70)
    inputBox.TextSize = 9
    inputBox.Font = Enum.Font.GothamMedium
    inputBox.TextXAlignment = Enum.TextXAlignment.Left
    inputBox.ClearTextOnFocus = false
    inputBox.ClipsDescendants = true
    inputBox.TextTruncate = Enum.TextTruncate.AtEnd
    inputBox.ZIndex = 12
    inputBox.Parent = row
    Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0, 5)
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 6)
    pad.PaddingRight = UDim.new(0, 6)
    pad.Parent = inputBox
    local statusDot = Instance.new("Frame")
    statusDot.Size = UDim2.new(0, 7, 0, 7)
    statusDot.Position = UDim2.new(1, -18, 0, 9)
    statusDot.BackgroundColor3 = (Config[configKey] ~= "" and Config[configKey] ~= nil) and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(200, 50, 50)
    statusDot.BorderSizePixel = 0
    statusDot.ZIndex = 12
    statusDot.Parent = row
    Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)
    inputBox.FocusLost:Connect(function()
        local newUrl = inputBox.Text
        Config[configKey] = newUrl
        statusDot.BackgroundColor3 = (newUrl ~= "" and newUrl ~= nil) and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(200, 50, 50)
        saveConfig()
        warn("[Settings] " .. configKey .. " updated")
    end)
end

createSectionHeader(4, "\u{1F527}  General")
createSettingsToggle(30, "Abyssal Auto Equip", "AUTO_EQUIP_ABYSSAL")
createSettingsToggle(72, "Enable Webhooks", "WEBHOOK_ENABLED")
createSettingsToggle(114, "Collect Clovers", "COLLECT_CLOVERS")

createSectionHeader(160, "\u{1F3AE}  Auto Items")
createSectionHeader(380, "\u{1F39A}  Adjustments")
createSettingsToggle(186, "Use Strange Controller", "AUTO_USE_STRANGE_CONTROLLER")
createSettingsToggle(228, "Use Biome Randomizer", "AUTO_USE_BIOME_RANDOMIZER")
createSettingsSlider(270, "Use Interval (m)", 1, 60, "ITEM_USE_INTERVAL")

createSettingsSlider(186, "Collect Dist", 2, 12, "PROMPT_DISTANCE")

createSectionHeader(232, "\u{2728}  Aura Notifications")
createSettingsToggle(258, "Aura Roll Alerts", "AURA_NOTIFY_ENABLED")
createRaritySlider(300, "Min Send", "AURA_MIN_SEND")
createRaritySlider(342, "Min Ping", "AURA_MIN_PING")

createSectionHeader(388, "\u{1F517}  Webhook URLs")
createWebhookInput(414, "Eggs Collected", "WEBHOOK_URL")
createWebhookInput(470, "Weather / Biome", "WEBHOOK_WEATHER")
createWebhookInput(526, "Rare Eggs", "WEBHOOK_RARE_EGGS")
createWebhookInput(582, "Merchants", "WEBHOOK_MERCHANTS")
createWebhookInput(638, "Aura Rolls", "WEBHOOK_AURAS")
createWebhookInput(694, "Discord Ping ID", "WEBHOOK_PING_ID", "Paste Discord ID...")
createWebhookInput(720, "Private Server Link", "VIP_SERVER_LINK", "Paste your server link...")

createSectionHeader(750, "\u{1F4E2}  Merchant Pings")
createSettingsToggle(776, "Ping on Jester", "PING_MERCHANT_JESTER")
createSettingsToggle(818, "Ping on Rin", "PING_MERCHANT_RIN")
createSettingsToggle(860, "Ping on Mari", "PING_MERCHANT_MARI")

local settingsOpen = false
local function openSettings()
    settingsOpen = true
    SettingsOverlay.Visible = true
    SettingsPanel.Size = UDim2.new(0.85, 0, 0, 0)
    TweenService:Create(SettingsPanel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0.85, 0, 0.65, 0)}):Play()
    TweenService:Create(GearBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(0, 120, 200)}):Play()
end
local function closeSettings()
    settingsOpen = false
    TweenService:Create(SettingsPanel, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Size = UDim2.new(0.85, 0, 0, 0)}):Play()
    TweenService:Create(GearBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(25, 25, 32)}):Play()
    task.delay(0.2, function()
        if not settingsOpen then
            SettingsOverlay.Visible = false
        end
    end)
end

GearBtn.MouseButton1Click:Connect(function()
    if settingsOpen then
        closeSettings()
    else
        openSettings()
    end
end)

closeBtn.MouseButton1Click:Connect(closeSettings)

-- Draggable Settings Panel
local dragging = false
local dragInput, dragStart, startPos

headerBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = SettingsPanel.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

headerBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        SettingsPanel.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

-- Gear hover effect
GearBtn.MouseEnter:Connect(function()
    if not settingsOpen then
        TweenService:Create(GearBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(38, 38, 50)}):Play()
    end
end)
GearBtn.MouseLeave:Connect(function()
    if not settingsOpen then
        TweenService:Create(GearBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(25, 25, 32)}):Play()
    end
end)



--[[
SettingsPanel.Position = UDim2.new(0, 0, 0, 0)
SettingsPanel.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
SettingsPanel.BorderSizePixel = 0
SettingsPanel.Visible = false
SettingsPanel.Active = true
SettingsPanel.ClipsDescendants = true
SettingsPanel.Parent = ScreenGui
Instance.new("UICorner", SettingsPanel).CornerRadius = UDim.new(0, 12)

local spStroke = Instance.new("UIStroke")
spStroke.Color = Color3.fromRGB(45, 45, 60)
spStroke.Thickness = 1
spStroke.Parent = SettingsPanel

-- Title
local spTitle = Instance.new("TextLabel")
spTitle.Size = UDim2.new(1, 0, 0, 28)
spTitle.Position = UDim2.new(0, 0, 0, 0)
spTitle.BackgroundTransparency = 1
spTitle.Text = "  \u{2699}  Settings"
spTitle.TextColor3 = Color3.fromRGB(200, 200, 220)
spTitle.TextSize = 12
spTitle.Font = Enum.Font.GothamBold
spTitle.TextXAlignment = Enum.TextXAlignment.Left
spTitle.ZIndex = 3
spTitle.Parent = SettingsPanel

-- Scrollable content area
local CONTENT_HEIGHT = 640  -- total scrollable content height
local SettingsScroll = Instance.new("ScrollingFrame")
SettingsScroll.Name = "SettingsScroll"
SettingsScroll.Size = UDim2.new(1, 0, 1, -28)
SettingsScroll.Position = UDim2.new(0, 0, 0, 28)
SettingsScroll.BackgroundTransparency = 1
SettingsScroll.BorderSizePixel = 0
SettingsScroll.CanvasSize = UDim2.new(0, 0, 0, CONTENT_HEIGHT)
SettingsScroll.ScrollBarThickness = 3
SettingsScroll.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 80)
SettingsScroll.Parent = SettingsPanel

local function createSettingsToggle(yPos, label, configKey)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -20, 0, 36)
    row.Position = UDim2.new(0, 10, 0, yPos)
    row.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
    row.BorderSizePixel = 0
    row.Parent = SettingsScroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -56, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(180, 180, 200)
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local switchTrack = Instance.new("Frame")
    switchTrack.Size = UDim2.new(0, 36, 0, 18)
    switchTrack.Position = UDim2.new(1, -46, 0.5, -9)
    switchTrack.BackgroundColor3 = Config[configKey] and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(40, 40, 55)
    switchTrack.BorderSizePixel = 0
    switchTrack.Parent = row
    Instance.new("UICorner", switchTrack).CornerRadius = UDim.new(1, 0)

    local switchKnob = Instance.new("Frame")
    switchKnob.Size = UDim2.new(0, 14, 0, 14)
    switchKnob.Position = Config[configKey] and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    switchKnob.BackgroundColor3 = Color3.new(1, 1, 1)
    switchKnob.BorderSizePixel = 0
    switchKnob.Parent = switchTrack
    Instance.new("UICorner", switchKnob).CornerRadius = UDim.new(1, 0)

    local switchBtn = Instance.new("TextButton")
    switchBtn.Size = UDim2.new(1, 0, 1, 0)
    switchBtn.BackgroundTransparency = 1
    switchBtn.Text = ""
    switchBtn.Parent = switchTrack

    switchBtn.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        saveConfig()
        local on = Config[configKey]
        local ti = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        TweenService:Create(switchTrack, ti, {
            BackgroundColor3 = on and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(40, 40, 55)
        }):Play()
        TweenService:Create(switchKnob, ti, {
            Position = on and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        }):Play()
    end)
end

createSettingsToggle(32, "Abyssal Auto Equip", "AUTO_EQUIP_ABYSSAL")
createSettingsToggle(74, "Enable Webhooks", "WEBHOOK_ENABLED")
createSettingsToggle(116, "Collect Clovers", "COLLECT_CLOVERS")

-- Slider helper for settings panel
local function createSettingsSlider(yPos, label, min, max, configKey)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -20, 0, 36)
    row.Position = UDim2.new(0, 10, 0, yPos)
    row.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
    row.BorderSizePixel = 0
    row.Parent = SettingsScroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 90, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(180, 180, 200)
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local valDisplay = Instance.new("TextLabel")
    valDisplay.Size = UDim2.new(0, 24, 1, 0)
    valDisplay.Position = UDim2.new(1, -32, 0, 0)
    valDisplay.BackgroundTransparency = 1
    valDisplay.Text = tostring(Config[configKey])
    valDisplay.TextColor3 = Color3.fromRGB(0, 170, 255)
    valDisplay.TextSize = 12
    valDisplay.Font = Enum.Font.GothamBold
    valDisplay.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 56, 0, 4)
    track.Position = UDim2.new(0, 106, 0.5, -2)
    track.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    track.BorderSizePixel = 0
    track.Parent = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local initRel = math.clamp((Config[configKey] - min) / (max - min), 0, 1)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(initRel, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.Position = UDim2.new(initRel, -6, 0.5, -6)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local sliding = false

    local function updateFromInput(inputX)
        local tPos = track.AbsolutePosition.X
        local tSize = track.AbsoluteSize.X
        local rel = math.clamp((inputX - tPos) / tSize, 0, 1)
        local value = math.floor(min + rel * (max - min) + 0.5)
        rel = (value - min) / (max - min)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -6, 0.5, -6)
        valDisplay.Text = tostring(value)
        Config[configKey] = value
    end

    -- Invisible hit area over the track for easier clicking
    local hitBtn = Instance.new("TextButton")
    hitBtn.Size = UDim2.new(1, 8, 0, 20)
    hitBtn.Position = UDim2.new(0, -4, 0.5, -10)
    hitBtn.BackgroundTransparency = 1
    hitBtn.Text = ""
    hitBtn.Parent = track

    hitBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            updateFromInput(input.Position.X)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromInput(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if sliding then
                sliding = false
                saveConfig()
            end
        end
    end)
end

createSettingsSlider(158, "Collect Dist", 2, 12, "PROMPT_DISTANCE")

createSettingsToggle(200, "Aura Notifications", "AURA_NOTIFY_ENABLED")

-- Special rarity slider (logarithmic: exponent 1-10 -> 1 in 10^N)
local function formatRarityExp(exp)
    local val = math.pow(10, exp)
    if val >= 1e9 then return string.format("1 in %.0fB", val / 1e9)
    elseif val >= 1e6 then return string.format("1 in %.0fM", val / 1e6)
    elseif val >= 1e3 then return string.format("1 in %.0fK", val / 1e3)
    else return "1 in " .. tostring(math.floor(val)) end
end

local function createRaritySlider(yPos, label, configKey)
    local min, max = 1, 10
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -20, 0, 36)
    row.Position = UDim2.new(0, 10, 0, yPos)
    row.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
    row.BorderSizePixel = 0
    row.Parent = SettingsScroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 70, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(180, 180, 200)
    lbl.TextSize = 10
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local valDisplay = Instance.new("TextLabel")
    valDisplay.Size = UDim2.new(0, 54, 1, 0)
    valDisplay.Position = UDim2.new(1, -60, 0, 0)
    valDisplay.BackgroundTransparency = 1
    valDisplay.Text = formatRarityExp(Config[configKey])
    valDisplay.TextColor3 = Color3.fromRGB(255, 200, 50)
    valDisplay.TextSize = 9
    valDisplay.Font = Enum.Font.GothamBold
    valDisplay.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 50, 0, 4)
    track.Position = UDim2.new(0, 82, 0.5, -2)
    track.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    track.BorderSizePixel = 0
    track.Parent = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local initRel = math.clamp((Config[configKey] - min) / (max - min), 0, 1)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(initRel, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.Position = UDim2.new(initRel, -6, 0.5, -6)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local sliding = false
    local function updateFromInput(inputX)
        local tPos = track.AbsolutePosition.X
        local tSize = track.AbsoluteSize.X
        local rel = math.clamp((inputX - tPos) / tSize, 0, 1)
        local value = math.floor(min + rel * (max - min) + 0.5)
        rel = (value - min) / (max - min)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -6, 0.5, -6)
        valDisplay.Text = formatRarityExp(value)
        Config[configKey] = value
    end

    local hitBtn = Instance.new("TextButton")
    hitBtn.Size = UDim2.new(1, 8, 0, 20)
    hitBtn.Position = UDim2.new(0, -4, 0.5, -10)
    hitBtn.BackgroundTransparency = 1
    hitBtn.Text = ""
    hitBtn.Parent = track

    hitBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            updateFromInput(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromInput(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if sliding then
                sliding = false
                saveConfig()
            end
        end
    end)
end

createRaritySlider(242, "Min Send", "AURA_MIN_SEND")
createRaritySlider(284, "Min Ping", "AURA_MIN_PING")

-- Divider
local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -30, 0, 1)
divider.Position = UDim2.new(0, 15, 0, 326)
divider.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
divider.BorderSizePixel = 0
divider.Parent = SettingsScroll

local webhookTitle = Instance.new("TextLabel")
webhookTitle.Size = UDim2.new(1, 0, 0, 20)
webhookTitle.Position = UDim2.new(0, 10, 0, 330)
webhookTitle.BackgroundTransparency = 1
webhookTitle.Text = "  Webhook URLs"
webhookTitle.TextColor3 = Color3.fromRGB(160, 160, 180)
webhookTitle.TextSize = 10
webhookTitle.Font = Enum.Font.GothamBold
webhookTitle.TextXAlignment = Enum.TextXAlignment.Left
webhookTitle.Parent = SettingsScroll

local function createWebhookInput(yPos, label, configKey, placeholder)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -20, 0, 48)
    row.Position = UDim2.new(0, 10, 0, yPos)
    row.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
    row.BorderSizePixel = 0
    row.Parent = SettingsScroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -10, 0, 16)
    lbl.Position = UDim2.new(0, 8, 0, 2)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(140, 140, 160)
    lbl.TextSize = 9
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local inputBox = Instance.new("TextBox")
    inputBox.Size = UDim2.new(1, -16, 0, 22)
    inputBox.Position = UDim2.new(0, 8, 0, 18)
    inputBox.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
    inputBox.BorderSizePixel = 0
    inputBox.Text = Config[configKey] or ""
    inputBox.PlaceholderText = placeholder or "Paste webhook URL..."
    inputBox.TextColor3 = Color3.fromRGB(100, 180, 255)
    inputBox.PlaceholderColor3 = Color3.fromRGB(60, 60, 80)
    inputBox.TextSize = 8
    inputBox.Font = Enum.Font.GothamMedium
    inputBox.TextXAlignment = Enum.TextXAlignment.Left
    inputBox.ClearTextOnFocus = false
    inputBox.ClipsDescendants = true
    inputBox.TextTruncate = Enum.TextTruncate.AtEnd
    inputBox.Parent = row
    Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0, 4)
    Instance.new("UIPadding", inputBox).PaddingLeft = UDim.new(0, 4)

    -- Status indicator (green dot if URL set, red if empty)
    local statusDot = Instance.new("Frame")
    statusDot.Size = UDim2.new(0, 6, 0, 6)
    statusDot.Position = UDim2.new(1, -14, 0, 7)
    statusDot.BackgroundColor3 = (Config[configKey] ~= "" and Config[configKey] ~= nil) and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(200, 50, 50)
    statusDot.BorderSizePixel = 0
    statusDot.Parent = row
    Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

    inputBox.FocusLost:Connect(function()
        local newUrl = inputBox.Text
        Config[configKey] = newUrl
        statusDot.BackgroundColor3 = (newUrl ~= "" and newUrl ~= nil) and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(200, 50, 50)
        saveConfig()
        warn("[Settings] " .. configKey .. " updated")
    end)
end

createWebhookInput(354, "Eggs Collected", "WEBHOOK_URL")
createWebhookInput(406, "Weather / Biome", "WEBHOOK_WEATHER")
createWebhookInput(458, "Rare Eggs", "WEBHOOK_RARE_EGGS")
createWebhookInput(510, "Merchants", "WEBHOOK_MERCHANTS")
createWebhookInput(562, "Aura Rolls", "WEBHOOK_AURAS")
createWebhookInput(614, "Discord Ping ID", "WEBHOOK_PING_ID", "Paste Discord ID...")
--]]



---------------------------------------
-- DRAGGABLE (touch + mouse)
---------------------------------------
local dragging = false
local dragStartPos = nil
local frameStartPos = nil

MainBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStartPos = input.Position
        frameStartPos = MainBar.Position
    end
end)

MainBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartPos
        MainBar.Position = UDim2.new(
            frameStartPos.X.Scale,
            frameStartPos.X.Offset + delta.X,
            frameStartPos.Y.Scale,
            frameStartPos.Y.Offset + delta.Y
        )
    end
end)

---------------------------------------
-- GUI ANIMATIONS & STATE
---------------------------------------
local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function setStatus(text, dotColor)
    StatusText.Text = text
    State.Status = text
    if dotColor then
        TweenService:Create(StatusDot, tweenInfo, {BackgroundColor3 = dotColor}):Play()
    end
end

local function updateEggCount()
    EggLabel.Text = "🥚 " .. tostring(State.EggsVisited)
end

local function animateToggle(enabled)
    local knobPos = enabled and UDim2.new(0, 24, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    local trackCol = enabled and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(32, 32, 42)
    local knobCol = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(100, 100, 120)
    local strokeCol = enabled and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(50, 50, 65)

    TweenService:Create(Knob, tweenInfo, {Position = knobPos, BackgroundColor3 = knobCol}):Play()
    TweenService:Create(ToggleTrack, tweenInfo, {BackgroundColor3 = trackCol}):Play()
    TweenService:Create(trkStroke, tweenInfo, {Color = strokeCol}):Play()
end

-- Intro slide-up
MainBar.Position = UDim2.new(0.5, 0, 1, 20)
task.defer(function()
    task.wait(0.2)
    TweenService:Create(MainBar, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 1, -12)
    }):Play()
end)

-- Accent shimmer
local shimmerConn = RunService.RenderStepped:Connect(function()
    accentGrad.Offset = Vector2.new(math.sin(tick() * 0.8) * 0.3, 0)
end)
table.insert(State.Connections, shimmerConn)

-- Status dot pulse when active
local pulseConn = RunService.RenderStepped:Connect(function()
    if Config.Enabled then
        local alpha = (math.sin(tick() * 4) + 1) / 2
        StatusDot.BackgroundTransparency = alpha * 0.4
    else
        StatusDot.BackgroundTransparency = 0
    end
end)
table.insert(State.Connections, pulseConn)

---------------------------------------
-- SIMPLEPATH LOADING
---------------------------------------
local SimplePath
local spSuccess, spErr = pcall(function()
    SimplePath = loadstring(game:HttpGet("https://raw.githubusercontent.com/grayzcale/simplepath/main/src/SimplePath.lua"))()
end)

if not SimplePath then
    warn("Failed to load SimplePath: " .. tostring(spErr))
end

local pathAgent = nil

local function initPathAgent()
    if pathAgent then
        pcall(function() 
            if type(pathAgent) == "table" and pathAgent.Destroy then
                pathAgent:Destroy() 
            end
        end)
    end
    if not SimplePath or not character then return end

    -- Using SimplePath with no custom parameters ensures that Roblox PathfindingService
    -- dynamically calculates the exact bounds of the character.
    -- This completely fixes the "walk-stop-walk-stop" stuttering caused by
    -- false "Blocked" path recalculations.
    pathAgent = SimplePath.new(character)
end

if character then initPathAgent() end

Player.CharacterAdded:Connect(function(char)
    task.wait(1)
    character = char
    humanoid = char:WaitForChild("Humanoid")
    rootPart = char:WaitForChild("HumanoidRootPart")
    initPathAgent()
end)

---------------------------------------
-- INVISIBLE GRASS BLOCKERS
---------------------------------------
local mapFixed = false
local function fixMapGeometry()
    if mapFixed then return end
    mapFixed = true

    local leafygrass = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("leafygrass")
    if not leafygrass then return end

    setStatus("Fixing ledges...", Color3.fromRGB(255, 180, 0))
    local extensionDown = 25

    for _, obj in ipairs(leafygrass:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name ~= "PathBlocker" then
            local blocker = Instance.new("Part")
            blocker.Name = "PathBlocker"
            blocker.Size = Vector3.new(obj.Size.X, extensionDown, obj.Size.Z)
            blocker.CFrame = obj.CFrame * CFrame.new(0, -(obj.Size.Y / 2 + extensionDown / 2), 0)
            blocker.Anchored = true
            blocker.CanCollide = true
            blocker.Transparency = 1
            blocker.Parent = obj
        end
    end
end

---------------------------------------
-- PROXIMITY PROMPT
---------------------------------------
local function fireProximityPromptSafe(prompt)
    if not prompt or not prompt.Parent then return false end

    -- Method 1: executor-provided function (best)
    if fireproximityprompt then
        pcall(fireproximityprompt, prompt)
        return true
    end

    -- Method 2: teleport close + press E via VirtualInputManager
    local hrp = getRootPart()
    local promptParent = prompt:FindFirstAncestorWhichIsA("BasePart") or prompt.Parent
    if hrp and promptParent and promptParent:IsA("BasePart") then
        local oldCFrame = hrp.CFrame
        hrp.CFrame = promptParent.CFrame + Vector3.new(0, 2, 0)
        task.wait(0.15)
    end

    -- Increase distance & remove hold so E key works instantly
    local oldDist = prompt.MaxActivationDistance
    local oldHold = prompt.HoldDuration
    pcall(function()
        prompt.MaxActivationDistance = 9999
        prompt.HoldDuration = 0
    end)

    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.15)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end)
    end

    task.wait(0.2)

    pcall(function()
        prompt.MaxActivationDistance = oldDist
        prompt.HoldDuration = oldHold
    end)

    return true
end

---------------------------------------
-- ITEM AUTO-USE SYSTEM
---------------------------------------
local function smartClickBtn(button)
    if not button then return false end

    -- VirtualInputManager is the only reliable way to fire UI elements.
    pcall(function()
        local pos = button.AbsolutePosition
        local size = button.AbsoluteSize
        local inset = GuiService:GetGuiInset()
        
        local cx = pos.X + (size.X / 2)
        local cy = pos.Y + (size.Y / 2) + inset.Y
        
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
    end)
    return true
end

local function isGameInventoryVisible()
    local pg = Player:FindFirstChild("PlayerGui")
    if not pg then return false end
    local mi = pg:FindFirstChild("MainInterface")
    if not mi then return false end
    local inv = mi:FindFirstChild("Inventory")
    if not inv then return false end
    return inv.Visible and inv.AbsolutePosition.X > -500
end

local function toggleGameInventory()
    local pg = Player:FindFirstChild("PlayerGui")
    if not pg then return false end

    local mi = pg:FindFirstChild("MainInterface")
    if not mi then return false end
    local sb = mi:FindFirstChild("SideButtons")
    if not sb then return false end

    local invBtn = nil
    for _, child in ipairs(sb:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("ImageButton") then
            local usage = child:FindFirstChild("Usage")
            if usage and usage:IsA("TextLabel") and usage.Text == "Inventory" then
                invBtn = child
                break
            end
        end
    end

    if not invBtn then
        local btns = {}
        for _, child in ipairs(sb:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("ImageButton") then
                table.insert(btns, child)
            end
        end
        table.sort(btns, function(a, b) return a.AbsolutePosition.Y < b.AbsolutePosition.Y end)
        invBtn = btns[1]
    end

    if invBtn then
        smartClickBtn(invBtn)
        task.wait(0.3)
        return true
    end
    return false
end

local function closeGameInventory()
    local pg = Player:FindFirstChild("PlayerGui")
    if not pg then return false end
    local mi = pg:FindFirstChild("MainInterface")
    if not mi then return false end

    local targetBtn = nil
    for _, desc in ipairs(mi:GetDescendants()) do
        if desc:IsA("ImageLabel") and (desc.Image == "http://www.roblox.com/asset/?id=6031094678" or desc.Image == "rbxassetid://6031094678") then
            if desc.Parent and (desc.Parent:IsA("ImageButton") or desc.Parent:IsA("TextButton")) then
                -- Проверяем видимость (чтобы не схватить кнопку от закрытого меню)
                local isVisible = true
                local curr = desc.Parent
                while curr and curr ~= mi do
                    if curr:IsA("GuiObject") and not curr.Visible then
                        isVisible = false
                        break
                    end
                    curr = curr.Parent
                end
                
                if isVisible then
                    targetBtn = desc.Parent
                    break
                end
            end
        end
    end

    if targetBtn then
        pcall(function()
            GuiService.SelectedObject = targetBtn
            task.wait(0.05)
            if VirtualInputManager then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
            end
            task.wait(0.1)
            GuiService.SelectedObject = nil
        end)
        task.wait(0.3)
        return true
    end

    return toggleGameInventory()
end

local function useGameItem(itemName)
    local pg = Player:FindFirstChild("PlayerGui")
    if not pg then return false, "PlayerGui not found" end

    local mi = pg:FindFirstChild("MainInterface")
    if not mi then return false, "MainInterface not found" end

    local inv = mi:FindFirstChild("Inventory")
    if not inv then return false, "Inventory not found" end

    local wasOpen = isGameInventoryVisible()
    if not wasOpen then
        toggleGameInventory()
        task.wait(0.5)
        if not isGameInventoryVisible() then
            return false, "Failed to open inventory"
        end
    end

    -- Switch to the 'ItemsTab' specifically
    pcall(function()
        local itemsFrame = inv:FindFirstChild("Items")
        if itemsFrame then
            local itemsTab = itemsFrame:FindFirstChild("ItemsTab")
            if itemsTab then
                smartClickBtn(itemsTab)
                task.wait(0.3)
            end
        end
    end)

    -- Click the QuickCategory button (Tool / Remote filter) by its exact Image ID
    pcall(function()
        local quickCategory = inv:FindFirstChild("QuickCategory")
        if quickCategory then
            local targetBtn = nil
            for _, child in ipairs(quickCategory:GetChildren()) do
                if child:IsA("ImageButton") then
                    local iconLabel = nil
                    for _, desc in ipairs(child:GetDescendants()) do
                        if desc:IsA("ImageLabel") and desc.Image == "rbxassetid://100436585165147" then
                            iconLabel = desc
                            break
                        end
                    end
                    
                    if iconLabel then
                        if iconLabel.Parent:IsA("ImageButton") then
                            targetBtn = iconLabel.Parent
                        else
                            targetBtn = child
                        end
                        break
                    end
                end
            end
            
            if targetBtn then
                smartClickBtn(targetBtn)
                task.wait(0.4)
            end
        end
    end)

    local gridFrame = nil
    pcall(function()
        gridFrame = inv.Items.ItemGrid.ItemGridScrollingFrame
    end)

    if not gridFrame then
        pcall(function()
            for _, desc in ipairs(inv:GetDescendants()) do
                if desc:IsA("ScrollingFrame") and desc.Name:find("Grid") then
                    gridFrame = desc
                    break
                end
            end
        end)
    end

    if not gridFrame then
        if not wasOpen then closeGameInventory() end
        return false, "Item grid not found"
    end

    local itemFrame = nil
    local searchNames = {
        "Item\n" .. itemName,
        itemName,
        "item\n" .. itemName,
    }

    for _, searchName in ipairs(searchNames) do
        itemFrame = gridFrame:FindFirstChild(searchName)
        if itemFrame then break end
    end

    if not itemFrame then
        for _, child in ipairs(gridFrame:GetChildren()) do
            if child.Name:find(itemName) then
                itemFrame = child
                break
            end
        end
    end

    if not itemFrame then
        if not wasOpen then closeGameInventory() end
        return false, "Item '" .. itemName .. "' not found."
    end

    local itemBtn = itemFrame:FindFirstChild("Button") or itemFrame:FindFirstChildWhichIsA("TextButton") or itemFrame:FindFirstChildWhichIsA("ImageButton")
    if not itemBtn then
        if itemFrame:IsA("TextButton") or itemFrame:IsA("ImageButton") then
            itemBtn = itemFrame
        else
            if not wasOpen then closeGameInventory() end
            return false, "No clickable button in item frame"
        end
    end

    smartClickBtn(itemBtn)
    task.wait(0.4)

    local useBtn = nil

    pcall(function()
        useBtn = inv.Index.ItemIndex.UseHolder.UseButton
    end)

    if not useBtn then
        for _, desc in ipairs(inv:GetDescendants()) do
            if (desc.Name == "UseButton" or desc.Name == "Use") and
               (desc:IsA("TextButton") or desc:IsA("ImageButton")) then
                useBtn = desc
                break
            end
        end
    end

    if not useBtn or not useBtn.Visible then
        if not wasOpen then closeGameInventory() end
        return false, "Use button hidden/missing"
    end

    smartClickBtn(useBtn)
    task.wait(0.3)

    if not wasOpen then
        closeGameInventory()
    end

    return true, "Successfully used " .. itemName
end

local function tryAutoUseItems()
    local now = tick()
    local interval = Config.ITEM_USE_INTERVAL * 60

    if Config.AUTO_USE_STRANGE_CONTROLLER then
        if (now - State.lastStrangeControllerUse) >= interval then
            setStatus("Using Strange Controller...", Color3.fromRGB(255, 200, 50))
            local ok, msg = useGameItem("Strange Controller")
            if ok then
                State.lastStrangeControllerUse = now
                warn("[AutoItem] Strange Controller used")
            else
                warn("[AutoItem] Strange Controller failed: " .. tostring(msg))
            end
            task.wait(0.5)
        end
    end

    if Config.AUTO_USE_BIOME_RANDOMIZER then
        local shouldUseBiome = false
        
        if Config.AUTO_USE_STRANGE_CONTROLLER then
            if State.lastStrangeControllerUse > 0 and 
               State.lastBiomeRandomizerUse < State.lastStrangeControllerUse and 
               (now - State.lastStrangeControllerUse) >= 300 then
                 shouldUseBiome = true
            end
        else
            if (now - State.lastBiomeRandomizerUse) >= interval then
                shouldUseBiome = true
            end
        end

        if shouldUseBiome then
            setStatus("Using Biome Randomizer...", Color3.fromRGB(255, 200, 50))
            local ok, msg = useGameItem("Biome Randomizer")
            if ok then
                State.lastBiomeRandomizerUse = now
                warn("[AutoItem] Biome Randomizer used")
            else
                warn("[AutoItem] Biome Randomizer failed: " .. tostring(msg))
            end
            task.wait(0.5)
        end
    end
end

---------------------------------------
-- WEBHOOKS (будем переделывать потом)
---------------------------------------
local WEATHER_COLORS = {
    normal = 16777215, windy = 11393254, snowy = 11393254, rainy = 3447003,
    sandstorm = 15787660, hell = 16753920, starfall = 3447003, heaven = 16777184,
    corruption = 8388736, null = 8421504, dreamspace = 16761035, glitched = 3800852,
    cyberspace = 11393254, eggland = 9502544
}

local RARE_EGGS = {
    -- {chat message pattern, egg display name}
    -- Hatch & Royal both say "A special egg has spawned" — detected as same message
    {"A special egg has spawned", "Hatch / Royal Egg"},
    {"Am I in spaaaace right now?!", "Andromeda Egg"},
    {"Holy Eggsus", "Angelic Egg"},
    {"Don't forget to water the", "Blooming Egg"},
    {"small plant", "Blooming Egg"},
    {"Let's have an egg hunt here!", "Forest Egg"},
    {"Scanning. Egg cannon charging 2000%", "The Egg of the Sky"},
    {"Scanning. Egg cannon", "The Egg of the Sky"},
    {"Preparing Protocol", "Egg V2.0"},
    {"Do you want to be my friend?", "Egg V2.0"},
    {"Wait, am I still dreaming?", "Dreamer Egg"},
}

-- Rarity info for each rare egg (exact data from wiki)
local RARE_EGG_INFO = {
    ["Hatch Egg"] = {
        aura = "Hatchwarden",
        spawnChance = "0.1% (1 in 1,000)",
        despawnTime = "30 Minutes",
        emoji = "\u{1F423}",  -- 🐣
        color = 5763719,  -- green
    },
    ["Royal Egg"] = {
        aura = "Emperor",
        spawnChance = "0.05% (1 in 2,000)",
        despawnTime = "30 Minutes",
        emoji = "\u{1F451}",  -- 👑
        color = 16766720,  -- gold
    },
    -- Combined entry for chat detection (both say same message)
    ["Hatch / Royal Egg"] = {
        aura = "Hatchwarden / Emperor",
        spawnChance = "0.1% / 0.05% (1 in 1,000 / 2,000)",
        despawnTime = "30 Minutes",
        emoji = "\u{1F451}",  -- 👑
        color = 16766720,  -- gold
    },
    ["Andromeda Egg"] = {
        aura = "Eggsistence",
        spawnChance = "0.013% (1 in 7,692)",
        despawnTime = "1 Hour",
        emoji = "\u{1F30C}",  -- 🌌
        color = 7419530,  -- purple
    },
    ["Angelic Egg"] = {
        aura = "Revive",
        spawnChance = "0.0062% (1 in 16,129)",
        despawnTime = "1 Hour",
        emoji = "\u{1F47C}",  -- 👼
        color = 16777200,  -- light yellow
    },
    ["Blooming Egg"] = {
        aura = "EGGORE",
        spawnChance = "0.0057% (1 in 17,543)",
        despawnTime = "1 Hour",
        emoji = "\u{1F33A}",  -- 🌺
        color = 16744448,  -- orange
    },
    ["Forest Egg"] = {
        aura = "Eostre",
        spawnChance = "0.004% (1 in 25,000)",
        despawnTime = "2 Hours",
        emoji = "\u{1F332}",  -- 🌲
        color = 3066993,  -- forest green
    },
    ["The Egg of the Sky"] = {
        aura = "EGGIS",
        spawnChance = "0.0035% (1 in 28,571)",
        despawnTime = "2 Hours",
        emoji = "\u{2601}",  -- ☁
        color = 3447003,  -- sky blue
    },
    ["Egg V2.0"] = {
        aura = "Y.O.L.K.E.G.G.",
        spawnChance = "0.0023% (1 in 43,478)",
        despawnTime = "2 Hours",
        emoji = "\u{1F916}",  -- 🤖
        color = 3800852,  -- teal
    },
    ["Dreamer Egg"] = {
        aura = "Sky Festival",
        spawnChance = "0.002% (1 in 50,000)",
        despawnTime = "2 Hours",
        emoji = "\u{1F4AB}",  -- 💫
        color = 16761035,  -- pink
    },
}

local function getRareEggInfo(eggName)
    return RARE_EGG_INFO[eggName]
end

local function buildRarityFields(eggName)
    local info = getRareEggInfo(eggName)
    if not info then return nil end
    return {
        {["name"] = "🎭 Aura", ["value"] = "**" .. info.aura .. "**", ["inline"] = true},
        {["name"] = "🎲 Spawn Chance", ["value"] = info.spawnChance, ["inline"] = true},
        {["name"] = "⏱ Despawn Time", ["value"] = info.despawnTime, ["inline"] = true},
    }
end

local function getRareEggColor(eggName)
    local info = getRareEggInfo(eggName)
    return info and info.color or 16753920
end

-- Explorer-based rare egg identifiers (name patterns to look for in Workspace)
local RARE_EGG_IDENTIFIERS = {
    -- model/part names (case-insensitive matching)
    {namePattern = "royal.?egg",        displayName = "Royal Egg"},
    {namePattern = "hatch.?egg",         displayName = "Hatch Egg"},
    {namePattern = "andromeda.?egg",     displayName = "Andromeda Egg"},
    {namePattern = "angelic.?egg",       displayName = "Angelic Egg"},
    {namePattern = "blooming.?egg",      displayName = "Blooming Egg"},
    {namePattern = "forest.?egg",        displayName = "Forest Egg"},
    {namePattern = "sky.?egg",           displayName = "The Egg of the Sky"},
    {namePattern = "egg.?v2",            displayName = "Egg V2.0"},
    {namePattern = "dreamer.?egg",       displayName = "Dreamer Egg"},
}

-- Proximity prompt text patterns for rare eggs
local RARE_PROMPT_PATTERNS = {
    {"special egg",       "Hatch / Royal Egg"},
    {"royal",             "Royal Egg"},
    {"hatch",             "Hatch Egg"},
    {"andromeda",         "Andromeda Egg"},
    {"angelic",           "Angelic Egg"},
    {"blooming",          "Blooming Egg"},
    {"forest egg",        "Forest Egg"},
    {"egg of the sky",    "The Egg of the Sky"},
    {"egg cannon",        "The Egg of the Sky"},
    {"egg v2",            "Egg V2.0"},
    {"y.o.l.k",           "Egg V2.0"},
    {"dreamer",           "Dreamer Egg"},
    {"sky festival",      "Dreamer Egg"},
}

-- Strip HTML/rich text tags (e.g. <font color="#50ff7c">text</font> -> text)
local function stripRichText(text)
    if not text or typeof(text) ~= "string" then return "" end
    -- Remove all HTML-like tags: <font ...>, </font>, <b>, </b>, etc.
    local stripped = string.gsub(text, "<[^>]+>", "")
    -- Trim whitespace
    stripped = string.gsub(stripped, "^%s+", "")
    stripped = string.gsub(stripped, "%s+$", "")
    return stripped
end

local function getPingText()
    if Config.WEBHOOK_PING_ID and Config.WEBHOOK_PING_ID ~= "" then
        local id = string.gsub(Config.WEBHOOK_PING_ID, "[^%d]", "")
        if id ~= "" then
            return "<@" .. id .. ">"
        end
    end
    return ""
end

sendGenericWebhook = function(webhookUrl, title, description, color, ping, fields)
    -- Debug: check if webhooks are enabled
    if not Config.WEBHOOK_ENABLED then
        warn("[Webhook] SKIPPED (disabled): " .. tostring(title))
        return
    end
    if not webhookUrl or webhookUrl == "" then
        warn("[Webhook] SKIPPED (no URL): " .. tostring(title))
        return
    end

    local finalPing = ping or ""
    if finalPing ~= "" and Config.VIP_SERVER_LINK and Config.VIP_SERVER_LINK ~= "" then
        finalPing = finalPing .. "\n\n🔗 **Join server:** " .. Config.VIP_SERVER_LINK
    end

    local data = {
        ["content"] = finalPing,
        ["allowed_mentions"] = { ["parse"] = {"users", "roles"} },
        ["embeds"] = {{
            ["title"] = title,
            ["description"] = description,
            ["color"] = color,
            ["fields"] = fields,
            ["footer"] = { ["text"] = "Sols RNG Webhook System" }
        }}
    }

    -- Try to find the HTTP request function
    local req = nil
    if typeof(request) == "function" then
        req = request
    elseif typeof(http_request) == "function" then
        req = http_request
    elseif syn and typeof(syn.request) == "function" then
        req = syn.request
    elseif http and typeof(http.request) == "function" then
        req = http.request
    elseif fluxus and typeof(fluxus.request) == "function" then
        req = fluxus.request
    end

    if not req then
        warn("[Webhook] ERROR: No HTTP request function found! Your executor may not support HTTP requests.")
        return
    end

    local ok, err = pcall(function()
        local response = req({
            Url = webhookUrl,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
        if response and response.StatusCode then
            if response.StatusCode == 204 or response.StatusCode == 200 then
                warn("[Webhook] OK (" .. response.StatusCode .. "): " .. tostring(title))
            else
                warn("[Webhook] HTTP " .. response.StatusCode .. ": " .. tostring(title) .. " | Body: " .. tostring(response.Body))
            end
        else
            warn("[Webhook] Sent (no response object): " .. tostring(title))
        end
    end)

    if not ok then
        warn("[Webhook] REQUEST FAILED: " .. tostring(err) .. " | Title: " .. tostring(title))
    end
end

local recentlyNotifiedEggs = {}

---------------------------------------
-- MERCHANT DETECTION
---------------------------------------
local recentlyNotifiedMerchants = {}
local function checkMerchantMessage(text)
    if not text or typeof(text) ~= "string" then return end
    local cleanText = stripRichText(text)
    
    -- Only process [Merchant] messages
    if not string.find(cleanText, "[Merchant]", 1, true) then return end
    
    local lowerText = string.lower(cleanText)
    local merchantName = nil
    local ping = ""
    local color = 8421504  -- grey default
    
    if string.find(lowerText, "jester") then
        merchantName = "Jester"
        ping = Config.PING_MERCHANT_JESTER and getPingText() or ""
        color = 16711680  -- red
    elseif string.find(lowerText, "rin") then
        merchantName = "Rin"
        ping = Config.PING_MERCHANT_RIN and getPingText() or ""
        color = 3447003  -- blue
    elseif string.find(lowerText, "mari") then
        merchantName = "Mari"
        ping = Config.PING_MERCHANT_MARI and getPingText() or ""
        color = 16761035  -- pink
    end
    
    local dupeKey = merchantName or cleanText
    
    -- Prevent duplicate notifications (tick-based, immune to concurrent handlers)
    local now = tick()
    if recentlyNotifiedMerchants[dupeKey] and (now - recentlyNotifiedMerchants[dupeKey]) < 30 then return end
    recentlyNotifiedMerchants[dupeKey] = now
    
    if merchantName then
        sendGenericWebhook(
            Config.WEBHOOK_MERCHANTS,
            "\u{1F3AA} " .. merchantName .. " has arrived!",
            "**" .. merchantName .. "** appeared on the island!\nMessage: `" .. cleanText .. "`",
            color,
            ping
        )
        warn("[Merchant] Detected: " .. merchantName)
    else
        -- Unknown merchant — forward the raw message
        sendGenericWebhook(
            Config.WEBHOOK_MERCHANTS,
            "\u{1F3AA} Merchant Appeared!",
            "Unknown merchant detected!\nMessage: `" .. cleanText .. "`",
            color
        )
        warn("[Merchant] Unknown: " .. cleanText)
    end
end

---------------------------------------
-- AURA ROLL DETECTION
---------------------------------------
local recentlyNotifiedAuras = {}
local function checkAuraRollMessage(text)
    if not text or typeof(text) ~= "string" then return end
    if not Config.AURA_NOTIFY_ENABLED then return end

    local cleanText = stripRichText(text)

    -- Quick check: must contain "HAS FOUND" and "CHANCE OF"
    if not string.find(cleanText, "HAS FOUND", 1, true) then return end
    if not string.find(cleanText, "CHANCE OF", 1, true) then return end

    -- Format: "DisplayName(@user) HAS FOUND AuraName, CHANCE OF 1 IN 70,000!"
    -- Also: "DisplayName(@user) HAS FOUND Solar, CHANCE OF 1 IN 5,000 [From Day]!"
    local playerInfo, auraName, chanceStr = string.match(cleanText, 
        "(.+) HAS FOUND (.+), CHANCE OF 1 IN ([%d,%.]+)")

    -- Fallback: lowercase "in"
    if not auraName then
        playerInfo, auraName, chanceStr = string.match(cleanText, 
            "(.+) HAS FOUND (.+), CHANCE OF 1 in ([%d,%.]+)")
    end

    -- Fallback: no "1 IN" prefix
    if not auraName then
        playerInfo, auraName, chanceStr = string.match(cleanText, 
            "(.+) HAS FOUND (.+), CHANCE OF ([%d,%.]+)")
    end

    if not auraName or not chanceStr then return end

    -- Check if it's the local player
    if not string.find(playerInfo, "(@" .. Player.Name .. ")", 1, true) then
        return
    end

    -- Clean aura name: remove trailing stuff like " [From Day]" etc.
    auraName = string.gsub(auraName, "%s*%[.-%]%s*$", "")
    auraName = string.gsub(auraName, "%s+$", "")

    -- Clean up the chance number (remove commas/dots used as thousand separators)
    local chanceClean = string.gsub(chanceStr, ",", "")
    chanceClean = string.gsub(chanceClean, "%.$", "")  -- remove trailing dot
    local chanceNumber = tonumber(chanceClean)
    if not chanceNumber or chanceNumber < 1 then return end

    -- Check minimum rarity threshold for sending
    local minSend = math.pow(10, Config.AURA_MIN_SEND)
    if chanceNumber < minSend then return end

    -- Prevent duplicate notifications
    local dupeKey = playerInfo .. "_" .. auraName .. "_" .. tostring(chanceNumber)
    if recentlyNotifiedAuras[dupeKey] then return end
    recentlyNotifiedAuras[dupeKey] = true
    task.delay(30, function() recentlyNotifiedAuras[dupeKey] = nil end)

    -- Format the chance nicely
    local function formatChance(n)
        if n >= 1e9 then return string.format("%.2fB", n / 1e9)
        elseif n >= 1e6 then return string.format("%.2fM", n / 1e6)
        elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
        else return tostring(math.floor(n)) end
    end

    -- Determine color based on rarity
    local color = 8421504  -- grey
    if chanceNumber >= 1e9 then color = 16711680      -- red (1B+)
    elseif chanceNumber >= 1e8 then color = 16753920   -- orange (100M+)
    elseif chanceNumber >= 1e7 then color = 16766720   -- gold (10M+)
    elseif chanceNumber >= 1e6 then color = 7419530    -- purple (1M+)
    elseif chanceNumber >= 1e5 then color = 3447003    -- blue (100K+)
    elseif chanceNumber >= 1e4 then color = 3066993    -- green (10K+)
    end

    -- Check if should ping
    local minPing = math.pow(10, Config.AURA_MIN_PING)
    local ping = ""
    if chanceNumber >= minPing then
        ping = getPingText()
    end

    local fields = {
        {["name"] = "Aura", ["value"] = "**" .. auraName .. "**", ["inline"] = true},
        {["name"] = "Rarity", ["value"] = "1 in " .. formatChance(chanceNumber), ["inline"] = true},
    }

    local playerName = playerInfo or "Someone"

    sendGenericWebhook(
        Config.WEBHOOK_AURAS,
        "HAS FOUND " .. auraName .. "!",
        "**" .. playerName .. "** obtained **" .. auraName .. "**\nChance: **1 in " .. formatChance(chanceNumber) .. "**",
        color,
        ping,
        fields
    )
    warn("[Aura] " .. playerName .. " found " .. auraName .. " (1 in " .. formatChance(chanceNumber) .. ")")
end

local function identifyRareEgg(obj)
    local name = string.lower(obj.Name)

    -- Check name against known rare egg patterns (fast, no children traversal)
    for _, id in ipairs(RARE_EGG_IDENTIFIERS) do
        if string.find(name, id.namePattern) then
            return id.displayName
        end
    end

    -- Check direct ProximityPrompt (FindFirstChild is fast, no recursive)
    local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt")
    if not prompt and obj:IsA("Model") then
        -- Check one level deep for models
        for _, child in ipairs(obj:GetChildren()) do
            prompt = child:FindFirstChildWhichIsA("ProximityPrompt")
            if prompt then break end
        end
    end
    if prompt then
        local actionText = string.lower(prompt.ActionText or "")
        local objText = string.lower(prompt.ObjectText or "")
        for _, pp in ipairs(RARE_PROMPT_PATTERNS) do
            if string.find(actionText, pp[1]) or string.find(objText, pp[1]) then
                return pp[2]
            end
        end
    end

    return nil
end

local function checkRareEggMessage(text)
    -- Disabled chat-based rare egg detection to prevent inaccurate "Hatch / Royal" notifications.
    -- We now rely entirely on the exact Workspace scanner (scanForRareEggs / rareEggAddedConn).
end

---------------------------------------
-- RARE EGG EXPLORER SCANNER
---------------------------------------
local detectedRareEggs = setmetatable({}, {__mode = "k"})  -- weak keys, auto-cleanup on GC
local rareEggQueue = {}  -- queue of rare eggs to collect next

local function buildRareEggEntry(obj, displayName)
    local part = nil
    if obj:IsA("BasePart") then
        part = obj
    elseif obj:IsA("Model") then
        part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    else
        -- Maybe it's a child of something useful
        part = obj:FindFirstAncestorWhichIsA("BasePart") or obj:FindFirstChildWhichIsA("BasePart", true)
    end
    if not part then return nil end

    local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
    return {
        instance = obj,
        part     = part,
        position = part.Position,
        prompt   = prompt,
        name     = displayName,
        priority = 0,  -- highest priority (above potions)
        isRare   = true,
    }
end

local function scanForRareEggs()
    -- Rare eggs sit directly in Workspace, same as point_egg_N
    -- e.g. workspace.SomeRareEgg.Attachment.ProximityPrompt
    for _, obj in ipairs(Workspace:GetChildren()) do
        if detectedRareEggs[obj] then continue end
        if isEggName(obj.Name) then continue end
        if not (obj:IsA("Model") or obj:IsA("BasePart")) then continue end

        local rareName = identifyRareEgg(obj)
        if rareName then
            detectedRareEggs[obj] = true

            if not recentlyNotifiedEggs["explorer_" .. rareName] then
                recentlyNotifiedEggs["explorer_" .. rareName] = true
                
                local emoji = getRareEggInfo(rareName) and getRareEggInfo(rareName).emoji or "✨"
                sendGenericWebhook(
                    Config.WEBHOOK_RARE_EGGS,
                    emoji .. " RARE EGG FOUND IN MAP!",
                    "Script detected a rare egg: **" .. rareName .. "**\nNavigating to collect it!",
                    getRareEggColor(rareName),
                    getPingText(),
                    buildRarityFields(rareName)
                )
                task.delay(120, function() recentlyNotifiedEggs["explorer_" .. rareName] = nil end)
            end

            local entry = buildRareEggEntry(obj, rareName)
            if entry then
                table.insert(rareEggQueue, entry)
                setStatus("Rare: " .. rareName .. "!", Color3.fromRGB(255, 215, 0))
            end
        end
    end
end

local rareEggAddedConn = Workspace.DescendantAdded:Connect(function(obj)
    task.delay(0.5, function()  -- small delay so children (prompts, labels) load
        if not obj or not obj.Parent then return end
        if detectedRareEggs[obj] then return end
        if isEggName(obj.Name) then return end
        if not (obj:IsA("Model") or obj:IsA("BasePart")) then return end

        local rareName = identifyRareEgg(obj)
        if rareName then
            detectedRareEggs[obj] = true

            if not recentlyNotifiedEggs["explorer_" .. rareName] then
                recentlyNotifiedEggs["explorer_" .. rareName] = true
                
                local emoji = getRareEggInfo(rareName) and getRareEggInfo(rareName).emoji or "✨"
                sendGenericWebhook(
                    Config.WEBHOOK_RARE_EGGS,
                    emoji .. " RARE EGG JUST SPAWNED!",
                    "A rare egg just appeared: **" .. rareName .. "**\nScript is collecting it!",
                    getRareEggColor(rareName),
                    getPingText(),
                    buildRarityFields(rareName)
                )
                task.delay(120, function() recentlyNotifiedEggs["explorer_" .. rareName] = nil end)
            end

            local entry = buildRareEggEntry(obj, rareName)
            if entry then
                table.insert(rareEggQueue, 1, entry)  -- insert at front = top priority
                setStatus("Rare spawned: " .. rareName .. "!", Color3.fromRGB(255, 215, 0))
            end
        end
    end)
end)
table.insert(State.Connections, rareEggAddedConn)

local lastWeather = ""

-- Normalize biome text: strip spaces so "sand storm" -> "sandstorm", etc.
local function normalizeBiomeName(text)
    return string.gsub(string.lower(text), "%s+", "")
end

local function isValidBiome(name)
    local lower = string.lower(name)
    if lower == "none" or lower == "tip" or lower == "system" then return false end
    -- Reject egg-related labels (e.g. "GLITCHED EGG", "HATCH EGG", "ROYAL EGG") but allow "eggland"
    if string.find(lower, "%segg") or (lower == "egg") then return false end
    if lower == "normal" then return true end
    local normalized = normalizeBiomeName(name)
    for k, v in pairs(WEATHER_COLORS) do
        if string.find(normalized, k) then return true end
    end
    return false
end

local function updateWeatherStatus(rawText)
    local text = string.lower(rawText)
    if text ~= lastWeather and rawText ~= "" and text ~= "label" then
        lastWeather = text

        local isGlitched = false
        if string.find(text, "glitch") or (string.match(rawText, "[%?@!%$#%^&]") and string.match(rawText, "%d")) then
            isGlitched = true
        end

        local biomeName = text
        local color = WEATHER_COLORS.normal
        local ping = ""
        -- Normalize: strip spaces for lookup ("sand storm" -> "sandstorm")
        local normalized = normalizeBiomeName(rawText)

        if isGlitched then
            biomeName = "glitched"
        else
            for k, v in pairs(WEATHER_COLORS) do
                if string.find(normalized, k) then
                    biomeName = k
                    color = v
                    break
                end
            end
        end

        if biomeName == "glitched" then color = WEATHER_COLORS.glitched end

        if biomeName == "dreamspace" or biomeName == "glitched" or biomeName == "cyberspace" then
            ping = Config.WEBHOOK_PING_ID and getPingText() or ""
        end

        -- Make it clean
        if string.find(biomeName, "none") then return end

        sendGenericWebhook(Config.WEBHOOK_WEATHER, "🌦 Weather Changed!", "Biome: **" .. rawText .. "**", color, ping)
    end
end

local function checkWeather()
    local rawText = nil
    pcall(function()
        local mi = Players.LocalPlayer.PlayerGui.MainInterface
        for _, obj in ipairs(mi:GetDescendants()) do
            if obj:IsA("TextLabel") then
                local txt = obj.Text
                if txt and txt ~= "" and txt ~= "Label" and not string.match(txt, "^v%d+%.%d+") then
                    -- Skip any label that mentions eggs as a standalone word ("GLITCHED EGG", etc.) but not "eggland"
                    local txtLower = string.lower(txt)
                    if string.find(txtLower, "%segg") or (txtLower == "egg") then continue end
                    local inner = string.match(txt, "^%[%s*(.-)%s*%]$")
                    if inner and isValidBiome(inner) then
                        rawText = txt
                        break
                    -- Secondary check using ZIndex 2 as user suggested, for edge cases without brackets
                    elseif (obj.ZIndex == 2 or obj.ZIndex == 3) and isValidBiome(txt) and not string.find(string.lower(txt), "none") then
                        if not inner then rawText = "[ " .. string.upper(txt) .. " ]" end
                        break
                    end
                end
            end
        end
    end)

    if rawText then
        updateWeatherStatus(rawText)
    end
end

local function checkWeatherMessage(text)
    if not text or typeof(text) ~= "string" then return end
    local cleanText = stripRichText(text)
    
    -- Match biome names including multi-word ones like "SAND STORM"
    local biomeMatch = string.match(cleanText, "^%[([%a%s]+)%]%:")
    if biomeMatch then
        -- Trim trailing spaces
        biomeMatch = string.gsub(biomeMatch, "%s+$", "")
        if isValidBiome(biomeMatch) then
            local rawText = "[ " .. string.upper(biomeMatch) .. " ]"
            updateWeatherStatus(rawText)
        end
    end
end

local function initChatMonitor()
    pcall(function()
        local TextChatService = game:GetService("TextChatService")
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            TextChatService.MessageReceived:Connect(function(msg)
                checkRareEggMessage(msg.Text)
                checkMerchantMessage(msg.Text)
                checkAuraRollMessage(msg.Text)
                checkWeatherMessage(msg.Text)
            end)
        end
    end)

    pcall(function()
        local ev = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
        if ev then
            local onMsg = ev:FindFirstChild("OnNewMessage")
            if onMsg then
                onMsg.OnClientEvent:Connect(function(data)
                    if type(data) == "table" and data.Message then
                        checkRareEggMessage(data.Message)
                        checkMerchantMessage(data.Message)
                        checkAuraRollMessage(data.Message)
                        checkWeatherMessage(data.Message)
                    end
                end)
            end
        end
    end)

    local playerGui = Player:WaitForChild("PlayerGui")
    playerGui.DescendantAdded:Connect(function(obj)
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            task.delay(0.2, function()
                pcall(function()
                    checkRareEggMessage(obj.Text)
                    checkMerchantMessage(obj.Text)
                    checkAuraRollMessage(obj.Text)
                    checkWeatherMessage(obj.Text)
                end)
            end)
        end
    end)
end

task.spawn(initChatMonitor)

local function sendWebhook(eggName)
    local num = tonumber(string.match(eggName, "%d+") or 0)
    local isPointEgg = string.match(eggName, "point_egg")
    local pointsGained = "Unknown"

    if isPointEgg then
        local ptData = {50, 100, 150, 200, 300, 500}
        pointsGained = ptData[num] or "Unknown"
    elseif string.match(eggName, "potion") then
        pointsGained = "Potion"
    end

    task.wait(1.5)

    local curPoints = "0"
    pcall(function()
        local MainInterface = Players.LocalPlayer.PlayerGui.MainInterface
        for _, obj in ipairs(MainInterface:GetChildren()) do
            if obj:IsA("Frame") then
                local lbl = obj:FindFirstChild("TextLabel")
                if lbl and lbl:IsA("TextLabel") then
                    local stripped = string.gsub(lbl.Text, "[,%s]", "")
                    if tonumber(stripped) then
                        curPoints = lbl.Text
                    end
                end
            end
        end
    end)

    local isClover = (eggName == "Clover")
    local isPotion = string.match(eggName, "potion") ~= nil
    local titleText = isClover and "🍀 Clover Collected!" or (isPotion and "🧪 Potion Egg Collected!" or "🥚 Egg Collected!")
    local embedColor = isClover and 65280 or (isPotion and 10181046 or 14925732) -- Green for clover, Purple for potion, Beige for regular egg

    local embedFields = {}
    if not isClover and not isPotion then
        table.insert(embedFields, {["name"] = "💎 Points Gained", ["value"] = tostring(pointsGained), ["inline"] = true})
    end
    table.insert(embedFields, {["name"] = "💰 Total Points", ["value"] = curPoints, ["inline"] = true})

    sendGenericWebhook(
        Config.WEBHOOK_URL,
        titleText,
        "Collected **" .. eggName .. "**",
        embedColor,
        "",
        embedFields
    )
end

---------------------------------------
-- ABYSSAL HUNTER AUTO EQUIP
---------------------------------------
local function autoEquipAbyssal()
    local PlayerGui = Player:WaitForChild("PlayerGui")
    local GuiService = game:GetService("GuiService")

    local function cleverClick(target)
        pcall(function()
            -- Only set SelectedObject if target is a valid, visible GuiButton
            if target and target:IsA("GuiButton") and target.Visible and target.AbsoluteSize.X > 0 and target.AbsoluteSize.Y > 0 then
                GuiService.SelectedObject = target
                task.wait()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
                task.wait()
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
                GuiService.SelectedObject = nil
            end
        end)

        pcall(function()
            if getconnections then
                local events = {target.MouseButton1Down, target.MouseButton1Click, target.Activated}
                for _, ev in ipairs(events) do
                    for _, conn in ipairs(getconnections(ev) or {}) do
                        if type(conn) == "table" and conn.Function then conn.Function() end
                        if type(conn) == "userdata" and type(conn.Fire) == "function" then conn:Fire() end
                    end
                end
            end
        end)
    end

    local function toggleInventory()
        local sideButtons = PlayerGui:FindFirstChild("MainInterface")
        if sideButtons then sideButtons = sideButtons:FindFirstChild("SideButtons") end

        if sideButtons then
            local btns = {}
            for _, btn in ipairs(sideButtons:GetChildren()) do
                if btn:IsA("TextButton") then table.insert(btns, btn) end
            end
            table.sort(btns, function(a, b) return a.AbsolutePosition.Y < b.AbsolutePosition.Y end)

            local bagBtn = btns[1]
            if bagBtn then
                cleverClick(bagBtn)
                task.wait(0.1)
            end
        end
    end

    setStatus("Equipping Abyssal...", Color3.fromRGB(140, 60, 255))
    
    local wasAurasOpen = false
    local mi = PlayerGui:FindFirstChild("MainInterface")
    if mi then
        for _, frame in ipairs(mi:GetChildren()) do
            if frame:IsA("Frame") and frame.Visible then
                local hasRegularTab = false
                pcall(function()
                    for _, desc in ipairs(frame:GetDescendants()) do
                        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and string.match(string.lower(desc.Text or ""), "^regular") then
                            hasRegularTab = true
                            break
                        end
                    end
                end)
                if hasRegularTab then
                    wasAurasOpen = true
                    break
                end
            end
        end
    end

    if not wasAurasOpen then
        toggleInventory()
    end

    task.wait(0.2)
    -- Switch to the 'Regular' tab before searching
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and string.match(string.lower(obj.Text), "^regular") then
            if obj.AbsoluteSize.X > 0 and obj.AbsoluteSize.Y > 0 then
                local btn = obj:IsA("GuiButton") and obj or obj:FindFirstAncestorWhichIsA("GuiButton")
                if btn then
                    cleverClick(btn)
                    break
                end
            end
        end
    end
    task.wait(0.2)

    local auraClicked = false

    -- Navigate to the ScrollingFrame that holds all aura entries
    local scrollingFrame = nil
    pcall(function()
        local mi = PlayerGui:FindFirstChild("MainInterface")
        if mi then
            -- Path: MainInterface.Frame.Frame.Frame.ScrollingFrame
            -- Use GetDescendants to find the ScrollingFrame inside the inventory panel
            for _, desc in ipairs(mi:GetDescendants()) do
                if desc:IsA("ScrollingFrame") and desc.Parent and desc.Parent:IsA("Frame") then
                    -- Verify this is the aura inventory ScrollingFrame by checking it has children with TextButton class
                    local hasAuraEntries = false
                    for _, child in ipairs(desc:GetChildren()) do
                        if child:IsA("TextButton") then
                            hasAuraEntries = true
                            break
                        end
                    end
                    if hasAuraEntries then
                        scrollingFrame = desc
                        break
                    end
                end
            end
        end
    end)

    if scrollingFrame then
        -- Iterate through ScrollingFrame children (each is a TextButton with a random numeric ID)
        for _, entry in ipairs(scrollingFrame:GetChildren()) do
            if entry:IsA("TextButton") then
                -- Check all descendant TextLabels for "Abyssal Hunter" text
                for _, label in ipairs(entry:GetDescendants()) do
                    if label:IsA("TextLabel") then
                        local labelText = string.gsub(label.Text, "%s+", " ")
                        labelText = string.gsub(labelText, "^%s+", "")
                        labelText = string.gsub(labelText, "%s+$", "")
                        if string.lower(labelText) == "abyssal hunter" then
                            cleverClick(entry)
                            auraClicked = true
                            break
                        end
                    end
                end
                if auraClicked then break end
            end
        end
    end

    -- Fallback: scan all descendants if ScrollingFrame approach didn't work
    if not auraClicked then
        for _, obj in ipairs(PlayerGui:GetDescendants()) do
            if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and string.match(string.lower(obj.Text), "abyssal") then
                if obj.AbsoluteSize.X > 0 and obj.AbsoluteSize.Y > 0 then
                    local btn = obj:FindFirstAncestorWhichIsA("GuiButton")
                    if btn then
                        cleverClick(btn)
                        auraClicked = true
                        break
                    end
                end
            end
        end
    end

    if not auraClicked then
        setStatus("Abyssal not found!", Color3.fromRGB(255, 180, 0))
        closeGameInventory()
        return
    end

    -- Wait a bit for the panel to update
    task.wait(0.2)
    
    -- Find ALL Equip buttons. The Storage Upgrade button inexplicably contains "Equip" text internally
    -- and gets found first in normal iteration. We sort by geometric Y position to guarantee we 
    -- pick the real Equip button (which is always physically above Storage Upgrade).
    local possibleEquips = {}
    pcall(function()
        local mi = PlayerGui:FindFirstChild("MainInterface")
        if not mi then return end

        for _, desc in ipairs(mi:GetDescendants()) do
            if desc:IsA("ImageButton") and desc.Visible and desc.AbsoluteSize.X > 0 then
                for _, child in ipairs(desc:GetChildren()) do
                    if child:IsA("TextLabel") then
                        local content = ""
                        pcall(function() content = child.ContentText end)
                        if content == "" then content = child.Text or "" end
                        content = string.match(content, "^%s*(.-)%s*$") or ""

                        if string.lower(content) == "equip" then
                            table.insert(possibleEquips, desc)
                            break
                        end
                    end
                end
            end
        end
    end)

    local equipBtn = nil
    if #possibleEquips > 0 then
        -- Math sort: smallest Y means highest on the screen
        table.sort(possibleEquips, function(a, b)
            return a.AbsolutePosition.Y < b.AbsolutePosition.Y
        end)
        equipBtn = possibleEquips[1]
    end

    if equipBtn then
        cleverClick(equipBtn)
        setStatus("Aura equipped!", Color3.fromRGB(0, 220, 140))
    else
        setStatus("Equip btn not found", Color3.fromRGB(255, 80, 80))
        warn("[AbyssalEquip] equipBtn is nil, could not equip")
    end

    task.wait(0.2)

    closeGameInventory()
end

---------------------------------------
-- EGG COLLECTION
local function isEggCollected(eggInstance)
    if not eggInstance or not eggInstance.Parent then return true end -- gone = collected
    
    local nameLower = string.lower(eggInstance.Name)
    local isClover = string.find(nameLower, "clover") or (eggInstance:FindFirstChild("luckyeffect", true) ~= nil)
    
    if not isClover then
        -- Check if the object ITSELF is a MeshPart/BasePart and is transparent
        if (eggInstance:IsA("MeshPart") or eggInstance:IsA("BasePart")) then
            if eggInstance.Transparency and eggInstance.Transparency > 0.9 then
                return true
            end
        end

        -- Prompt check (disabled = collected)
        local prompt = eggInstance:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt and not prompt.Enabled then 
            return true 
        end
        if not prompt and eggInstance:IsA("Model") and string.find(nameLower, "egg") then
            return true
        end

        for _, desc in ipairs(eggInstance:GetDescendants()) do
            if desc:IsA("MeshPart") or desc:IsA("SpecialMesh") or desc:IsA("BasePart") then
                -- Ignore purely invisible hitboxes that were always invisible
                if desc.Name ~= "Hitbox" and desc.Name ~= "HumanoidRootPart" then
                    if desc.Transparency and desc.Transparency > 0.9 then
                        return true
                    end
                end
            end
        end
    end
    
    return false
end

local function collectEgg(egg)
    local prompt = egg.prompt or egg.instance:FindFirstChildWhichIsA("ProximityPrompt", true)
    local collected = false
    local maxAttempts = 3

    for attempt = 1, maxAttempts do
        if prompt then
            fireProximityPromptSafe(prompt)
            collected = true
        else
            if VirtualInputManager then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                task.wait(0.2)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                collected = true
            end
        end

        task.wait(0.3)

        -- We now assume it collected successfully based on prompt activation
        if collected then
            break
        end
    end

    -- Clear current target specifically so it searches for a new one upon restart
    State.currentEggInstance = nil
    State.currentTarget = "None"

    if collected then
        if egg.name ~= "Clover" then
            State.EggsVisited = State.EggsVisited + 1
            updateEggCount()
        end

        task.spawn(function()
            sendWebhook(egg.name)
        end)

        if humanoid and humanoid.Health > 0 then
            humanoid.Health = 0
        end
    else
        setStatus("Egg not collected!", Color3.fromRGB(255, 80, 80))
        task.wait(0.5)
        if humanoid and humanoid.Health > 0 then
            humanoid.Health = 0
        end
    end
end

---------------------------------------
-- SIMPLEPATH NAVIGATION
---------------------------------------
local function moveToEgg(egg)
    State.currentEggInstance = egg.instance
    if not rootPart or not egg.part or not egg.part.Parent then return false end
    if not pathAgent then
        setStatus("No SimplePath!", Color3.fromRGB(255, 80, 80))
        return false
    end

    if egg.isRare then
        setStatus("→ Rare: " .. egg.name, Color3.fromRGB(255, 215, 0))
    elseif egg.name == "Clover" then
        setStatus("→ Clover", Color3.fromRGB(0, 200, 100))
    else
        local eggNum = egg.name:match("(%d+)$") or "?"
        setStatus("→ Egg #" .. eggNum, Color3.fromRGB(0, 220, 140))
    end

    if Config.WALK_SPEED_BOOST > 0 and humanoid then
        humanoid.WalkSpeed = Config.WALK_SPEED_BOOST
    end
    
    -- Optimize pathAgent spacing for current walk speed to prevent stuttering
    initPathAgent()

    local maxErrors = Config.PATH_RECOMPUTE_MAX * 3
    local errors = 0
    local isCompleted = false

    local conReached, conBlocked, conError, conWaypoint

    local function cleanup()
        if conReached then conReached:Disconnect() end
        if conBlocked then conBlocked:Disconnect() end
        if conError then conError:Disconnect() end
        if conWaypoint then conWaypoint:Disconnect() end
        pcall(function()
            if pathAgent and tostring(pathAgent.Status) ~= "Idle" then
                pathAgent:Stop()
            end
        end)
    end

    conReached = pathAgent.Reached:Connect(function()
        isCompleted = true
    end)

    local lastRunTime = 0
    conBlocked = pathAgent.Blocked:Connect(function()
        if tick() - lastRunTime > 0.5 then
            lastRunTime = tick()
            pcall(function() pathAgent:Run(egg.part.Position) end)
        end
    end)

    conError = pathAgent.Error:Connect(function()
        if tick() - lastRunTime > 0.5 then
            lastRunTime = tick()
            errors = errors + 1
            if humanoid then
                humanoid.Jump = true
                humanoid:MoveTo(rootPart.Position + rootPart.CFrame.RightVector * math.random(-4, 4))
            end
            task.wait(0.2)
            pcall(function() pathAgent:Run(egg.part.Position) end)
        end
    end)

    conWaypoint = pathAgent.WaypointReached:Connect(function()
        local dist = distanceTo(egg.part.Position)
        local requiredDist = (egg.name == "Clover") and 1.5 or Config.PROMPT_DISTANCE
        if dist <= requiredDist then
            isCompleted = true
        end
        State.currentTarget = egg.name .. string.format(" (%.0f m)", dist)
    end)

    pcall(function() pathAgent:Run(egg.part.Position) end)

    local lastPos = rootPart.Position
    local timeStuck = 0
    local moveStartTime = tick()
    local initialDist = distanceTo(egg.part.Position)
    local maxMoveTime = math.max(30, (initialDist / 10) + 15)

    while Config.Enabled and not isCompleted do
        if tick() - moveStartTime > maxMoveTime then
            setStatus("Timeout!", Color3.fromRGB(255, 80, 80))
            if State.currentEggInstance then
                ignoredEggs[State.currentEggInstance] = true
                trackTargetAction(State.currentEggInstance, "Ignored (Timeout or Error)")
            end
            break
        end

        if not egg.part or not egg.part.Parent then
            local distToCache = distanceTo(egg.position)
            if distToCache <= 15 then
                -- Target disappeared while we were close to it.
                -- For clovers, this means we literally walked into it and collected it!
                isCompleted = true
                break
            else
                local displayNum = egg.name and egg.name:match("(%d+)$") or "?"
                setStatus("Egg / Clover gone: " .. displayNum, Color3.fromRGB(255, 180, 0))
                cleanup()
                return false
            end
        end

        -- Check if it became transparent/collected mid-walk
        if isEggCollected(egg.instance) then
            setStatus("Egg already transparent!", Color3.fromRGB(255, 180, 0))
            if State.currentEggInstance then 
                ignoredEggs[State.currentEggInstance] = true 
                trackTargetAction(State.currentEggInstance, "Ignored (Already collected)")
            end
            cleanup()
            return false -- Gracefully exit without triggering "Pathfinding Failed" webhook
        end

        local dist = distanceTo(egg.part.Position)
        local requiredDist = (egg.name == "Clover") and 1.5 or Config.PROMPT_DISTANCE
        if dist <= requiredDist then
            isCompleted = true
            break
        end

        if errors > maxErrors then
            setStatus("Too many errors", Color3.fromRGB(255, 180, 0))
            break
        end

        local currentPos = rootPart.Position
        local deltaMove = (currentPos - lastPos).Magnitude

        if deltaMove < 0.2 then
            timeStuck = timeStuck + 0.1
            if timeStuck > 1.5 then
                if humanoid then
                    humanoid.Jump = true
                    humanoid:MoveTo(currentPos + rootPart.CFrame.RightVector * math.random(-5, 5) - rootPart.CFrame.LookVector * 2)
                end
                errors = errors + 1
                task.wait(0.5)
                pcall(function() pathAgent:Run(egg.part.Position) end)
                timeStuck = 0
            end
        else
            timeStuck = 0
        end
        lastPos = currentPos

        task.wait(0.1)
    end

    cleanup()

    if not Config.Enabled then return false end

    local requiredDistFinal = (egg.name == "Clover") and 2.5 or Config.PROMPT_DISTANCE
    if isCompleted or (egg.part and egg.part.Parent and distanceTo(egg.part.Position) <= requiredDistFinal) then
        if egg.name == "Clover" and humanoid then
            humanoid:MoveTo(egg.part.Position)
            task.wait(0.2)
        end
        collectEgg(egg)
        return true
    end

    if egg.part and egg.part.Parent then
        if State.currentEggInstance then
            trackTargetAction(State.currentEggInstance, "Failed to pathfind")
        end
        local posFormat = tostring(egg.part.CFrame)
        local itemName = egg.name == "Clover" and "clover" or "egg"
        task.spawn(function()
            sendGenericWebhook(
                Config.WEBHOOK_URL,
                "⚠️ Pathfinding Failed",
                "Failed to collect " .. itemName .. " at: " .. posFormat,
                16711680,
                ""
            )
        end)
    end

    return false
end

---------------------------------------
-- FARMING LOOP
---------------------------------------
local function startFarming()
    fixMapGeometry()
    setStatus("Starting...", Color3.fromRGB(0, 200, 255))
    task.wait(0.5)

    local idleStartTime = tick()
    local lastAfkJumpTime = tick()

    while Config.Enabled do
        local hum = getHumanoid()
        if not hum or hum.Health <= 0 then
            setStatus("Waiting respawn...", Color3.fromRGB(255, 180, 0))
            Player.CharacterAdded:Wait()
            task.wait(2)
            continue
        end

        -- Abyssal Hunter auto equip
        if Config.AUTO_EQUIP_ABYSSAL then
            if rootPart and rootPart.Parent and not rootPart:FindFirstChild("FishSpin") then
                autoEquipAbyssal()
                task.wait(0.5)
            end
        end

        -- Auto-use items (Strange Controller, Biome Randomizer)
        pcall(tryAutoUseItems)

        -- Scan for rare eggs in explorer
        pcall(scanForRareEggs)

        -- Process rare egg queue FIRST (highest priority)
        while #rareEggQueue > 0 and Config.Enabled do
            local rareEgg = table.remove(rareEggQueue, 1)
            if rareEgg.part and rareEgg.part.Parent then
                setStatus("→ RARE: " .. rareEgg.name, Color3.fromRGB(255, 215, 0))
                local collected = moveToEgg(rareEgg)
                if collected then
                    -- Send "collected" notification
                    sendGenericWebhook(
                        Config.WEBHOOK_RARE_EGGS,
                        "🎉 RARE EGG COLLECTED!",
                        "Successfully collected rare egg: **" .. rareEgg.name .. "**!",
                        65280,  -- green
                        "<@1289915272731295787>",
                        buildRarityFields(rareEgg.name)
                    )
                    task.wait(0.3)
                    if Config.Enabled then
                        task.spawn(function()
                            if State.FarmThread then pcall(function() task.cancel(State.FarmThread) end) end
                            State.FarmThread = task.spawn(startFarming)
                        end)
                        return
                    end
                end
                task.wait(0.3)
            end
        end

        local eggs = findAllEggs()

        if #eggs > 0 then
            idleStartTime = tick()
        end

        if #eggs == 0 then
            -- No eggs found — try clovers if enabled
            if Config.COLLECT_CLOVERS then
                local clovers = findClovers()
                if #clovers > 0 then
                    setStatus("Clovers: " .. #clovers, Color3.fromRGB(0, 200, 100))
                    for _, clover in ipairs(clovers) do
                        if not Config.Enabled then break end
                        -- Check if eggs appeared while collecting clovers
                        local freshEggs = findAllEggs()
                        if #freshEggs > 0 then break end
                        if clover.part and clover.part.Parent then
                            local collected = moveToEgg(clover)
                            task.wait(0.3)
                            if collected and Config.Enabled then
                                task.spawn(function()
                                    if State.FarmThread then pcall(function() task.cancel(State.FarmThread) end) end
                                    State.FarmThread = task.spawn(startFarming)
                                end)
                                return
                            end
                        end
                    end
                else
                    if tick() - idleStartTime >= 60 then
                        task.spawn(function()
                            if State.FarmThread then pcall(function() task.cancel(State.FarmThread) end) end
                            State.FarmThread = task.spawn(startFarming)
                        end)
                        return
                    end
                    setStatus("No eggs/clovers", Color3.fromRGB(255, 180, 0))
                    task.wait(Config.SEARCH_INTERVAL)
                end
            else
                if tick() - idleStartTime >= 60 then
                    task.spawn(function()
                        if State.FarmThread then pcall(function() task.cancel(State.FarmThread) end) end
                        State.FarmThread = task.spawn(startFarming)
                    end)
                    return
                end
                setStatus("Scanning...", Color3.fromRGB(255, 180, 0))
                task.wait(Config.SEARCH_INTERVAL)
            end

            if tick() - lastAfkJumpTime >= 30 then
                local hum = getHumanoid()
                if hum then hum.Jump = true end
                lastAfkJumpTime = tick()
            end

            continue
        end

        setStatus("Found " .. #eggs .. " eggs", Color3.fromRGB(0, 220, 140))

        for i, egg in ipairs(eggs) do
            if not Config.Enabled then break end
            -- Check rare queue mid-loop (interrupt normal farming for rare eggs)
            if #rareEggQueue > 0 then break end
            if egg.part and egg.part.Parent then
                trackTargetAction(egg.instance, "Moving to collect")
                local collected = moveToEgg(egg)
                task.wait(0.3)
                if collected and Config.Enabled then
                    task.spawn(function()
                        if State.FarmThread then pcall(function() task.cancel(State.FarmThread) end) end
                        State.FarmThread = task.spawn(startFarming)
                    end)
                    return
                end
            end
        end

        task.wait(Config.SEARCH_INTERVAL)
    end

    setStatus("Idle", Color3.fromRGB(70, 70, 90))
end

local function togglePrompts(state)
    local routes = {
        {"Map", "QuestBoard", "Proximity", "ProximityPrompt"},
        {"Map", "17597ef9-f805-4ff9-9cd4-86652e056ef9", "Torso", "ProximityPrompt"},
        {"Map", "UGCShop", "Title", "Attachment", "ProximityPrompt"},
        {"Boss Portal", "Portal", "Attachment", "ProximityPrompt"},
        {"Map", "Miscs", "FishShop", "NPC", "ProximityPrompt"},
        {"Map", "Miscs", "Rig", "HumanoidRootPart", "ProximityPrompt"},
        {"Map", "Miscs", "HoodedFigure", "ProximityPrompt"},
        {"Map", "SHOP", "Jake", "ProximityPrompt"},
    }
    
    for _, route in ipairs(routes) do
        local current = Workspace
        for _, name in ipairs(route) do
            if current then
                current = current:FindFirstChild(name)
            end
        end
        if current and current:IsA("ProximityPrompt") then
            current.Enabled = state
        end
    end
end

---------------------------------------
-- TOGGLE HANDLER
---------------------------------------
ToggleBtn.MouseButton1Click:Connect(function()
    Config.Enabled = not Config.Enabled
    animateToggle(Config.Enabled)
    togglePrompts(not Config.Enabled)

    if Config.Enabled then
        if State.FarmThread then
            pcall(function() task.cancel(State.FarmThread) end)
        end
        State.FarmThread = task.spawn(startFarming)
    else
        setStatus("Stopping...", Color3.fromRGB(255, 180, 0))
        task.wait(0.3)
        setStatus("Idle", Color3.fromRGB(70, 70, 90))
    end
end)

---------------------------------------
-- CLOSE HANDLER
---------------------------------------
CloseBtn.MouseButton1Click:Connect(function()
    Config.Enabled = false
    togglePrompts(true)
    task.wait(0.3)

    -- cleanup connections
    for _, c in pairs(State.Connections) do
        if c and c.Connected then c:Disconnect() end
    end

    -- fade out
    TweenService:Create(MainBar, TweenInfo.new(0.35, Enum.EasingStyle.Quint), {
        Position = UDim2.new(0.5, 0, 1, 60)
    }):Play()
    task.wait(0.4)
    ScreenGui:Destroy()
end)

-- Hover effect on close button
CloseBtn.MouseEnter:Connect(function()
    TweenService:Create(CloseBtn, tweenInfo, {BackgroundColor3 = Color3.fromRGB(180, 40, 50)}):Play()
    xLine1.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    xLine2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
end)
CloseBtn.MouseLeave:Connect(function()
    TweenService:Create(CloseBtn, tweenInfo, {BackgroundColor3 = Color3.fromRGB(25, 25, 32)}):Play()
    xLine1.BackgroundColor3 = Color3.fromRGB(140, 140, 160)
    xLine2.BackgroundColor3 = Color3.fromRGB(140, 140, 160)
end)

---------------------------------------
-- STARTUP
---------------------------------------
updateEggCount()
animateToggle(Config.Enabled)

task.spawn(function()
    while true do
        pcall(checkWeather)
        task.wait(5)
    end
end)

local VirtualUser = game:GetService("VirtualUser")
Player.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
end)

if Config.Enabled then
    if State.FarmThread then
        pcall(function() task.cancel(State.FarmThread) end)
    end
    State.FarmThread = task.spawn(startFarming)
end

warn("[SolsFarm] V3 Settings Script fully loaded and successfully started!")
