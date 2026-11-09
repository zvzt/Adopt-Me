-- Adopt Me | Universal Hub (client-side Luau)
-- Source analysis: 2026-11-09 decompiled client modules
-- All money and inventory operations are user opt-in. No guaranteed rewards.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end
local env = (getgenv and getgenv()) or _G
if type(env.AdoptMeUniversalHubStop) == "function" then
    pcall(env.AdoptMeUniversalHubStop)
end

local Hub = { alive = true, version = "2.0.0", connections = {}, logs = {}, statistics = {
    actions = 0, fed = 0, luresClaimed = 0, luresBaited = 0, moneyTrees = 0,
    pettings = 0, equipped = 0, moves = 0, errors = 0
}}
local DEFAULT = {
    autoNeeds = false, autoFeed = false, autoFurniture = true, autoArea = true,
    autoWalk = true, autoPetMe = true, autoLures = false, autoBait = false,
    autoMoneyTree = false, autoEquip = false, autoAntiAfk = true,
    noClip = false, infiniteJump = false, antiVoid = true,
    lowGraphics = false, playerESP = false, walkSpeed = 16, jumpPower = 50,
    selectedPet = "", visible = true, minimized = false
}
local config = table.clone(DEFAULT)
local function storage(name)
    local f = env[name]
    if type(f) == "function" then return f end
    if type(_G[name]) == "function" then return _G[name] end
    return nil
end
local function log(level, message)
    local line = string.format("[%s] %-5s %s", os.date("%H:%M:%S"), tostring(level), tostring(message))
    table.insert(Hub.logs, 1, line)
    while #Hub.logs > 75 do table.remove(Hub.logs) end
    if level == "ERROR" then Hub.statistics.errors += 1 end
    if level == "ERROR" or level == "WARN" then warn("[AdoptMe Hub] " .. line) end
    if Hub.logLabel and Hub.logLabel.Parent then
        Hub.logLabel.Text = table.concat(Hub.logs, "\n")
    end
end
local function safe(label, fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then log("ERROR", label .. ": " .. tostring(result):sub(1, 260)) end
    return ok, result
end
local function connect(signal, fn)
    local connection = signal:Connect(fn)
    table.insert(Hub.connections, connection)
    return connection
end
local function readSettings()
    local read = storage("readfile")
    local exists = storage("isfile")
    if not read then return end
    if exists and not (select(2, pcall(exists, "AdoptMeUniversalHub.json"))) then return end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(read("AdoptMeUniversalHub.json"))
    end)
    if ok and type(data) == "table" then
        for k, v in pairs(DEFAULT) do
            if type(data[k]) == type(v) then config[k] = data[k] end
        end
    end
end
readSettings()
local function saveSettings()
    local write = storage("writefile")
    if write then safe("SAVE", function()
        write("AdoptMeUniversalHub.json", HttpService:JSONEncode(config))
    end) end
end

local api = {}
local function initApi()
    local ok, fsys = pcall(function()
        return require(RS:WaitForChild("Fsys", 8))
    end)
    if not ok or type(fsys) ~= "table" or type(fsys.load) ~= "function" then
        log("WARN", "Fsys unavailable. UI and local utilities still work.")
        return
    end
    local getIdentity = storage("getthreadidentity") or storage("getidentity")
    local setIdentity = storage("setthreadidentity") or storage("setidentity")
    local oldIdentity
    if getIdentity then
        local identityOk, identity = pcall(getIdentity)
        if identityOk then oldIdentity = tonumber(identity) end
    end
    if (oldIdentity == 3 or oldIdentity == 6 or oldIdentity == 8) and setIdentity then
        pcall(setIdentity, 2)
    end
    for key, moduleName in pairs({
        Data = "ClientData", Router = "RouterClient", Tool = "ClientToolManager",
        Pets = "EquippedPets", PetActions = "PetActions", Interior = "InteriorsM",
        Nav = "new:NavigationHelper", Interactions = "InteractionsEngine",
        UI = "UIManager", Items = "InventoryDB",
        UseItem = "new:UseItemHelper"
    }) do
        local loaded, value = pcall(fsys.load, moduleName)
        if loaded then api[key] = value end
    end
    if oldIdentity and setIdentity and (oldIdentity == 3 or oldIdentity == 6 or oldIdentity == 8) then
        pcall(setIdentity, oldIdentity)
    end
    local lureModules = RS:FindFirstChild("new")
    lureModules = lureModules and lureModules:FindFirstChild("modules")
    lureModules = lureModules and lureModules:FindFirstChild("Lures")
    if lureModules then
        local net = lureModules:FindFirstChild("LuresNet")
        if net then
            local loaded, value = pcall(require, net)
            if loaded then api.Lures = value end
        end
    end
    log("INFO", "Game interfaces loaded: " .. tostring(api.Data ~= nil) .. " / " .. tostring(api.Router ~= nil))
end
local function data(key)
    if not api.Data then return nil end
    local ok, value = pcall(api.Data.get, key)
    return ok and value or nil
end
local function remote(name)
    if not api.Router then return nil end
    local ok, value = pcall(api.Router.get, name)
    return ok and value or nil
end
local function invoke(name, ...)
    local r = remote(name)
    if not r then return false end
    return safe("REMOTE " .. name, function(...) return r:InvokeServer(...) end, ...)
end
local function fire(name, ...)
    local r = remote(name)
    if not r then return false end
    return safe("REMOTE " .. name, function(...) r:FireServer(...) end, ...)
end
local function character()
    return LocalPlayer.Character
end
local function root()
    local c = character()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function humanoid()
    local c = character()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function currentInterior()
    if not api.Interior then return "?" end
    local ok, loc = pcall(api.Interior.get_current_location)
    return ok and loc and loc.destination_id or "?"
end
local function travel(destination)
    if not api.Interior then return false, "InteriorsM unavailable" end
    if currentInterior() == destination then return true, "Already there" end
    local ok, err = pcall(function()
        api.Interior.enter(destination, "MainDoor", {})
    end)
    if ok then
        log("TRAVEL", "Requested " .. destination)
        return true, "Requested " .. destination
    end
    log("WARN", "Travel " .. destination .. ": " .. tostring(err))
    return false, tostring(err)
end
local function getInventory(category)
    local inv = data("inventory")
    return inv and inv[category] or {}
end
local function listPets()
    local result = {}
    for key, pet in pairs(getInventory("pets")) do
        if type(pet) == "table" and pet.unique then
            table.insert(result, {unique = tostring(pet.unique), kind = tostring(pet.kind or pet.id or "Pet"),
                entry = pet})
        end
    end
    table.sort(result, function(a, b)
        if a.kind == b.kind then return a.unique < b.unique end
        return a.kind < b.kind
    end)
    return result
end
local function findPet(unique)
    for _, pet in ipairs(listPets()) do
        if pet.unique == unique then return pet end
    end
    return nil
end
local function equippedPets()
    if not api.Pets then return {} end
    local ok, result = pcall(api.Pets.get_my_equipped)
    return ok and type(result) == "table" and result or {}
end
local function selectedPet()
    local pet = findPet(config.selectedPet)
    if pet then return pet end
    local equipped = equippedPets()
    if equipped[1] then
        for _, p in ipairs(listPets()) do
            if p.unique == tostring(equipped[1].unique) then return p end
        end
    end
    return listPets()[1]
end
local function wrapperFor(pet)
    if not pet or not api.Pets then return nil end
    local ok, result = pcall(api.Pets.get_wrapper_from_item, pet.entry)
    if ok then return result end
    return nil
end
local function equipPet(pet)
    if not pet or not api.Tool then return false end
    local ok, result = safe("EQUIP PET", function()
        return api.Tool.equip(pet.entry, {suppress_fail_message = true})
    end)
    if ok and result ~= false then
        Hub.statistics.equipped += 1
        log("PET", "Equipped " .. pet.kind)
        return true
    end
    return false
end
local function petAilments(pet)
    local manager = data("ailments_manager")
    local perPet = manager and manager.ailments
    local list = {}
    if not pet or type(perPet) ~= "table" then return list end
    for ailmentKey, ailment in pairs(perPet[pet.unique] or {}) do
        if type(ailment) == "table" and type(ailment.kind) == "string" then
            table.insert(list, { key = tostring(ailmentKey), kind = ailment.kind,
                progress = tonumber(ailment.progress) or 0 })
        end
    end
    return list
end
local priority = {
    pet_me = 1, sleepy = 2, dirty = 3, thirsty = 4, hungry = 5,
    sick = 6, toilet = 7, walk = 8, ride = 9,
    school = 10, salon = 11, camping = 12, bored = 13,
    beach_party = 14, pizza_party = 15, cat_cafe = 16, party_zone = 17,
    play = 18
}
local function chooseAilment(pet)
    local list = petAilments(pet)
    table.sort(list, function(a, b)
        return (priority[a.kind] or 100) < (priority[b.kind] or 100)
    end)
    for _, item in ipairs(list) do
        if priority[item.kind] then return item end
    end
    return nil
end
local function findInteraction(ailmentKind)
    if not api.Interactions then return nil end
    local ok, all = pcall(function() return api.Interactions:get_interactions() end)
    if not ok or type(all) ~= "table" then return nil end
    local currentRoot = root()
    local nearest, distance
    for _, interaction in pairs(all) do
        if interaction.tag == ailmentKind and interaction.part and interaction.part:IsA("BasePart") then
            local d = currentRoot and (currentRoot.Position - interaction.part.Position).Magnitude or math.huge
            local visible = true
            if type(interaction.get_visibility) == "function" then
                local vOk, value = pcall(function() return interaction:get_visibility() end)
                visible = vOk and value
            end
            if visible and d < 26 and (not distance or d < distance) then
                nearest, distance = interaction, d
            end
        end
    end
    return nearest
end
local function activateInteraction(interaction, wrapper)
    if not api.UI or not api.UI.apps or not api.UI.apps.InteractionsApp then return false end
    local app = api.UI.apps.InteractionsApp
    local ok, err = pcall(function()
        app:call_on_selected(interaction, function(char)
            return interaction.on_selected(char, wrapper)
        end)
    end)
    if not ok then log("WARN", "Interaction: " .. tostring(err)) end
    return ok
end
local function feedForAilment(pet, kind)
    if not config.autoFeed or not api.PetActions then return false end
    local wrapper = wrapperFor(pet)
    if not wrapper or not wrapper.char then return false end
    for _, item in pairs(getInventory("food")) do
        if type(item) == "table" and item.kind then
            local definition = api.Items and api.Items.food and api.Items.food[item.kind]
            if definition and definition.ailment_to_boost == kind and not definition.can_only_feed_to_egg then
                local ok, result = pcall(api.PetActions.feed_pet, wrapper, {item = item})
                if ok and result then
                    Hub.statistics.fed += 1
                    log("NEED", "Fed pet for " .. kind)
                    return true
                end
            end
        end
    end
    return false
end
local function petPet(pet)
    if not config.autoPetMe then return false end
    local ok = fire("AilmentsAPI/ProgressPetMeAilment", pet.unique)
    if ok then Hub.statistics.pettings += 1; log("NEED", "Pet Me progress requested") end
    return ok
end
local lastMove = false
local function walkPet()
    if not config.autoWalk then return false end
    local r, hum = root(), humanoid()
    if not r or not hum then return false end
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {character()}
    local offset = (lastMove and -1 or 1) * 13
    lastMove = not lastMove
    local candidate = r.Position + r.CFrame.RightVector * offset
    local ground = workspace:Raycast(candidate + Vector3.new(0, 12, 0),
        Vector3.new(0, -30, 0), rayParams)
    if not ground then return false end
    hum:MoveTo(ground.Position + Vector3.new(0, 2, 0))
    Hub.statistics.moves += 1
    return true
end
local areaTargets = {
    school = "School", salon = "Salon", cat_cafe = "CatCafe",
    pizza_party = "PizzaShop", sick = "Hospital", party_zone = "MainMap",
    beach_party = "MainMap", camping = "MainMap", bored = "MainMap"
}
local function handleArea(kind)
    if not config.autoArea then return false end
    local destination = areaTargets[kind]
    if not destination then return false end
    if currentInterior() ~= destination then
        travel(destination)
        return true
    end
    if kind == "bored" or kind == "camping" then
        local map = workspace:FindFirstChild("StaticMap")
        local site = map and map:FindFirstChild(kind == "bored" and "Park" or "Campsite")
        local target = site and site:FindFirstChild(kind == "bored" and "BoredAilmentTarget" or "CampsiteOrigin", true)
        local r = root()
        if target and r and target:IsA("BasePart") then
            if (r.Position - target.Position).Magnitude > 95 then
                r.CFrame = CFrame.new(target.Position + Vector3.new(0, 4, 0))
                log("NEED", "Moved to " .. kind .. " area")
            end
        end
    elseif kind == "sick" then
        local interiors = workspace:FindFirstChild("Interiors")
        local hospital = interiors and interiors:FindFirstChild("Hospital")
        local target = hospital and hospital:FindFirstChild("SickAilmentTarget", true)
        if target and root() and target:IsA("BasePart") then
            root().CFrame = target.CFrame + Vector3.new(0, 3, 0)
        end
    end
    return true
end
local lastNeed = {}
local needsBusy = false
local function handleNeed(pet, need)
    local key = pet.unique .. "/" .. need.kind
    if os.clock() - (lastNeed[key] or -1000) < 16 then return end
    lastNeed[key] = os.clock()
    local kind = need.kind
    local acted = false
    if kind == "pet_me" then
        acted = petPet(pet)
    elseif kind == "walk" then
        acted = walkPet()
    elseif kind == "hungry" or kind == "thirsty" then
        acted = feedForAilment(pet, kind)
    elseif kind == "sleepy" or kind == "dirty" or kind == "toilet" then
        if config.autoFurniture then
            local interaction = findInteraction(kind)
            if interaction then acted = activateInteraction(interaction, wrapperFor(pet)) end
        end
        if not acted and config.autoArea and currentInterior() ~= "housing" then
            local destination = api.Nav and api.Nav.get_house_location_for_player(LocalPlayer) or "housing"
            if type(destination) == "string" then acted = select(1, travel(destination)) end
        end
    elseif areaTargets[kind] then
        acted = handleArea(kind)
    elseif kind == "ride" then
        if config.autoWalk then acted = walkPet() end
    end
    if acted then
        Hub.statistics.actions += 1
        log("NEED", "Attempted " .. kind .. " for " .. pet.kind)
    end
end

local lureCooldown = {}
local function allowed(name, seconds)
    local t = os.clock()
    if t - (lureCooldown[name] or -10000) < seconds then return false end
    lureCooldown[name] = t
    return true
end
local function manageLures()
    if not config.autoLures or not api.Lures then return end
    local manager = data("lures_2023_lure_manager")
    if not manager or type(manager.lures_map) ~= "table" then return end
    local types = {"BasicLure"}
    if manager.owns_premium_lure or manager.lures_map.PremiumLure then
        table.insert(types, "PremiumLure")
    end
    for _, lureType in ipairs(types) do
        local active = manager.lures_map[lureType]
        if active and active.finished and allowed(lureType .. "/claim", 16) then
            local ok = safe("CLAIM LURE", function()
                api.Lures.ClaimLure:fire_server(lureType)
            end)
            if ok then
                Hub.statistics.luresClaimed += 1
                log("LURE", "Claim requested: " .. lureType)
            end
        elseif not active and config.autoBait and allowed(lureType .. "/bait", 18) then
            local bait
            for _, item in pairs(getInventory("food")) do
                local info = item and api.Items and api.Items.food and api.Items.food[item.kind]
                if info and info.is_lure_bait == true then bait = item; break end
            end
            if bait then
                local ok = safe("BAIT LURE", function()
                    api.Lures.BaitLure:fire_server({lure_type = lureType, bait_unique = bait.unique})
                end)
                if ok then
                    Hub.statistics.luresBaited += 1
                    log("LURE", "Bait requested: " .. lureType)
                end
            end
        end
    end
end
local function collectMoneyTrees()
    if not config.autoMoneyTree or not api.Interactions then return end
    local ok, all = pcall(function() return api.Interactions:get_interactions() end)
    if not ok or type(all) ~= "table" then return end
    for _, interaction in pairs(all) do
        local part = interaction.part
        if part and part.Parent then
            local m = part.Parent
            local label = (m.Name .. " " .. tostring(interaction.tag or "")):lower()
            if m.Parent then label ..= " " .. m.Parent.Name:lower() end
            if label:find("moneytree", 1, true) or label:find("money_tree", 1, true) then
                if activateInteraction(interaction, nil) then
                    Hub.statistics.moneyTrees += 1
                    log("MONEY", "Money tree collection requested")
                    break
                end
            end
        end
    end
end

-- Local utilities. Every modification is reversible on stop.
local originalCollisions = setmetatable({}, {__mode = "k"})
local originalVisuals = setmetatable({}, {__mode = "k"})
local originalLighting = {GlobalShadows = Lighting.GlobalShadows}
local originalHumanoid = setmetatable({}, {__mode = "k"})
local espCache = {}
local lastSafeCFrame
local function paintPerformance(enabled)
    if enabled then
        Lighting.GlobalShadows = false
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                if not originalVisuals[obj] then
                    originalVisuals[obj] = {material = obj.Material, reflectance = obj.Reflectance}
                end
                obj.Material = Enum.Material.Plastic
                obj.Reflectance = 0
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
                if originalVisuals[obj] == nil then originalVisuals[obj] = {enabled = obj.Enabled} end
                obj.Enabled = false
            end
        end
    else
        Lighting.GlobalShadows = originalLighting.GlobalShadows
        for obj, state in pairs(originalVisuals) do
            if obj and obj.Parent then
                if state.material then obj.Material = state.material; obj.Reflectance = state.reflectance end
                if state.enabled ~= nil then obj.Enabled = state.enabled end
            end
        end
        table.clear(originalVisuals)
    end
end
local function restoreCollisions()
    for part, original in pairs(originalCollisions) do
        if part and part.Parent then part.CanCollide = original end
    end
    table.clear(originalCollisions)
end
local function clearESP()
    for player, gui in pairs(espCache) do
        if gui and gui.Parent then gui:Destroy() end
        espCache[player] = nil
    end
end
local function updateESP()
    if not config.playerESP then clearESP(); return end
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= LocalPlayer then
            local char = other.Character
            local head = char and char:FindFirstChild("Head")
            local old = espCache[other]
            if old and old.Adornee ~= head then
                old:Destroy(); espCache[other] = nil; old = nil
            end
            if head and not old then
                local board = Instance.new("BillboardGui")
                board.Name = "AdoptMeHubESP"
                board.Adornee = head
                board.Size = UDim2.fromOffset(160, 35)
                board.StudsOffset = Vector3.new(0, 2.5, 0)
                board.AlwaysOnTop = true
                board.Parent = Hub.gui
                local label = Instance.new("TextLabel")
                label.Size = UDim2.fromScale(1, 1)
                label.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
                label.BackgroundTransparency = 0.3
                label.TextColor3 = Color3.fromRGB(235, 235, 250)
                label.TextStrokeTransparency = 0.5
                label.Font = Enum.Font.GothamBold
                label.TextSize = 12
                label.Text = other.DisplayName
                label.Parent = board
                espCache[other] = board
            end
        end
    end
end
local function stepLocal()
    local hum = humanoid()
    local r = root()
    if hum then
        if not originalHumanoid[hum] then
            originalHumanoid[hum] = {speed = hum.WalkSpeed, jump = hum.JumpPower}
        end
        if config.walkSpeed ~= 16 then hum.WalkSpeed = config.walkSpeed end
        if config.jumpPower ~= 50 and hum.UseJumpPower then hum.JumpPower = config.jumpPower end
    end
    if r then
        if config.antiVoid then
            if r.Position.Y > -35 and r.Position.Y < 1500 and hum and hum.Health > 0 then
                lastSafeCFrame = r.CFrame
            elseif r.Position.Y < -55 and lastSafeCFrame then
                r.CFrame = lastSafeCFrame + Vector3.new(0, 5, 0)
            end
        end
    end
    local c = character()
    if c and config.noClip then
        for _, part in ipairs(c:GetDescendants()) do
            if part:IsA("BasePart") then
                if originalCollisions[part] == nil then originalCollisions[part] = part.CanCollide end
                part.CanCollide = false
            end
        end
    end
end
connect(RunService.Stepped, function()
    if Hub.alive then stepLocal() end
end)
connect(UIS.JumpRequest, function()
    if config.infiniteJump and humanoid() then
        humanoid():ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)
connect(LocalPlayer.Idled, function()
    if config.autoAntiAfk then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(0.08)
            VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end
end)

-- Original hub controls, no third-party UI library.
local function create(class, parent, props)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local color = {
    bg = Color3.fromRGB(12, 13, 19), panel = Color3.fromRGB(19, 20, 29),
    surface = Color3.fromRGB(26, 28, 39), accent = Color3.fromRGB(123, 105, 241),
    border = Color3.fromRGB(58, 59, 79), text = Color3.fromRGB(238, 238, 246),
    muted = Color3.fromRGB(151, 154, 173), green = Color3.fromRGB(113, 209, 166)
}
local function corner(obj, radius)
    create("UICorner", obj, {CornerRadius = UDim.new(0, radius or 8)})
end
local function stroke(obj)
    create("UIStroke", obj, {Color = color.border, Transparency = 0.35, Thickness = 1})
end
local playerGui = LocalPlayer:WaitForChild("PlayerGui", 12)
if not playerGui then return end
local previous = playerGui:FindFirstChild("AdoptMeUniversalHub")
if previous then previous:Destroy() end
local gui = create("ScreenGui", playerGui, {
    Name = "AdoptMeUniversalHub", ResetOnSpawn = false, IgnoreGuiInset = false,
    DisplayOrder = 9898, ZIndexBehavior = Enum.ZIndexBehavior.Sibling
})
Hub.gui = gui
local window = create("Frame", gui, {
    Name = "Window", BackgroundColor3 = color.bg, BorderSizePixel = 0,
    Size = UDim2.fromOffset(640, 438), Position = UDim2.new(0.5, -320, 0.5, -219),
    Visible = config.visible
})
corner(window, 11); stroke(window)
local header = create("Frame", window, {
    Size = UDim2.new(1, 0, 0, 51), BackgroundColor3 = color.panel, BorderSizePixel = 0
})
corner(header, 10)
create("TextLabel", header, {
    Text = "ADOPT ME  /  UNIVERSAL HUB", Font = Enum.Font.GothamBold, TextSize = 15,
    TextColor3 = color.text, BackgroundTransparency = 1,
    Position = UDim2.fromOffset(19, 9), Size = UDim2.new(1, -140, 0, 19),
    TextXAlignment = Enum.TextXAlignment.Left
})
create("TextLabel", header, {
    Text = "v2.0  •  client-side  •  no auto purchases", Font = Enum.Font.Gotham,
    TextSize = 10, TextColor3 = color.muted, BackgroundTransparency = 1,
    Position = UDim2.fromOffset(19, 28), Size = UDim2.new(1, -140, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left
})
local function headButton(text, x, fn)
    local b = create("TextButton", header, {
        Text = text, Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = color.text,
        BackgroundColor3 = color.surface, BorderSizePixel = 0,
        Size = UDim2.fromOffset(29, 29), Position = UDim2.new(1, x, 0, 11)
    })
    corner(b, 7)
    connect(b.MouseButton1Click, fn)
    return b
end
local minimized = config.minimized
headButton("–", -79, function()
    minimized = not minimized
    config.minimized = minimized
    window.Size = minimized and UDim2.fromOffset(640, 51) or UDim2.fromOffset(640, 438)
    saveSettings()
end)
headButton("×", -41, function() env.AdoptMeUniversalHubStop() end)
local sidebar = create("Frame", window, {
    BackgroundColor3 = color.panel, BorderSizePixel = 0,
    Position = UDim2.fromOffset(9, 61), Size = UDim2.new(0, 142, 1, -71)
})
corner(sidebar, 8)
local sideLayout = create("UIListLayout", sidebar, {Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder})
create("UIPadding", sidebar, {PaddingTop = UDim.new(0, 9),
    PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7)})
local content = create("ScrollingFrame", window, {
    Position = UDim2.fromOffset(160, 61), Size = UDim2.new(1, -171, 1, -71),
    BackgroundColor3 = color.panel, BorderSizePixel = 0,
    AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.fromOffset(0, 0),
    ScrollBarThickness = 3, ScrollBarImageColor3 = color.accent
})
corner(content, 8)
create("UIPadding", content, {PaddingTop = UDim.new(0, 11),
    PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 11),
    PaddingBottom = UDim.new(0, 12)})
local contentLayout = create("UIListLayout", content, {Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder})
local tabButtons = {}
local selectedTab = "Dashboard"
local renderTab

local function section(text)
    return create("TextLabel", content, {
        Text = string.upper(text), Font = Enum.Font.GothamBold, TextSize = 11,
        TextColor3 = color.accent, TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20)
    })
end
local function note(text)
    return create("TextLabel", content, {
        Text = text, Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = color.muted, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 25)
    })
end
local function actionButton(label, callback)
    local b = create("TextButton", content, {
        Text = label, Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = color.text, BackgroundColor3 = color.surface,
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 33),
        TextXAlignment = Enum.TextXAlignment.Center
    })
    corner(b, 7); stroke(b)
    connect(b.MouseButton1Click, function()
        task.spawn(function()
            local ok, err = pcall(callback)
            if not ok then log("ERROR", label .. ": " .. tostring(err)) end
        end)
    end)
    return b
end
local function toggle(label, key, description)
    local b = create("TextButton", content, {
        Text = "", BackgroundColor3 = color.surface, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, description and 49 or 36)
    })
    corner(b, 7)
    local title = create("TextLabel", b, {
        Text = label, Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = color.text, TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(11, 5), Size = UDim2.new(1, -80, 0, 22)
    })
    if description then
        create("TextLabel", b, {
            Text = description, Font = Enum.Font.Gotham, TextSize = 10,
            TextColor3 = color.muted, TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(11, 27), Size = UDim2.new(1, -80, 0, 17)
        })
    end
    local value = create("TextLabel", b, {
        Text = config[key] and "ON" or "OFF", Font = Enum.Font.GothamBold,
        TextSize = 11, TextColor3 = config[key] and color.green or color.muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        BackgroundColor3 = color.bg, BorderSizePixel = 0,
        Position = UDim2.new(1, -62, 0.5, -12), Size = UDim2.fromOffset(49, 24)
    })
    corner(value, 6)
    connect(b.MouseButton1Click, function()
        config[key] = not config[key]
        value.Text = config[key] and "ON" or "OFF"
        value.TextColor3 = config[key] and color.green or color.muted
        if key == "lowGraphics" then paintPerformance(config.lowGraphics) end
        if key == "noClip" and not config[key] then restoreCollisions() end
        if key == "playerESP" and not config[key] then clearESP() end
        saveSettings()
    end)
    return b
end
local function statLine(label, callback)
    local row = create("TextLabel", content, {
        Text = label .. ": loading...", Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = color.text, TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundColor3 = color.surface, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 31)
    })
    corner(row, 6)
    local inset = create("UIPadding", row, {PaddingLeft = UDim.new(0, 10)})
    task.spawn(function()
        while Hub.alive and row.Parent do
            local ok, value = pcall(callback)
            row.Text = label .. ": " .. (ok and tostring(value) or "unavailable")
            task.wait(1.5)
        end
    end)
    return row
end
local function numericSetting(label, key, minValue, maxValue, step)
    section(label .. "  (" .. tostring(config[key]) .. ")")
    local b = actionButton("–          " .. tostring(config[key]) .. "          +", function() end)
    local decrement = create("TextButton", b, {Text = "−", Font = Enum.Font.GothamBold,
        TextSize = 16, TextColor3 = color.text, BackgroundTransparency = 1,
        Size = UDim2.new(0.35, 0, 1, 0)})
    local increment = create("TextButton", b, {Text = "+", Font = Enum.Font.GothamBold,
        TextSize = 16, TextColor3 = color.text, BackgroundTransparency = 1,
        Position = UDim2.new(.65, 0, 0, 0), Size = UDim2.new(.35, 0, 1, 0)})
    local function change(amount)
        config[key] = math.clamp(config[key] + amount, minValue, maxValue)
        b.Text = tostring(config[key])
        saveSettings()
    end
    connect(decrement.MouseButton1Click, function() change(-step) end)
    connect(increment.MouseButton1Click, function() change(step) end)
    b.Text = tostring(config[key])
end

local function refreshPetsTab()
    section("Select an owned pet")
    note("Click a pet to select and equip it. The selected pet is used by Needs automation.")
    local pets = listPets()
    if #pets == 0 then note("Pet inventory unavailable or empty.") end
    for i, pet in ipairs(pets) do
        if i > 60 then
            note("Showing first 60 pets. Additional pets remain in your inventory.")
            break
        end
        local prefix = config.selectedPet == pet.unique and "● " or "○ "
        actionButton(prefix .. pet.kind .. "  [" .. pet.unique:sub(1, 9) .. "]", function()
            config.selectedPet = pet.unique
            equipPet(pet)
            saveSettings()
            renderTab()
        end)
    end
end
local function setTab(name)
    selectedTab = name
    for tab, button in pairs(tabButtons) do
        button.TextColor3 = tab == name and color.text or color.muted
        button.BackgroundColor3 = tab == name and color.accent or color.surface
    end
    renderTab()
end
renderTab = function()
    for _, child in ipairs(content:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
    content.CanvasPosition = Vector2.zero
    if selectedTab == "Dashboard" then
        section("Live session")
        statLine("Location", currentInterior)
        statLine("Bucks", function() return data("money") or "?" end)
        statLine("Pet", function()
            local p = selectedPet(); return p and p.kind or "none"
        end)
        statLine("Needs", function()
            local p = selectedPet(); local a = petAilments(p); local names = {}
            for _, v in ipairs(a) do table.insert(names, v.kind) end
            return #a == 0 and "none" or table.concat(names, ", ")
        end)
        statLine("Actions", function() return Hub.statistics.actions end)
        statLine("Lures", function()
            return Hub.statistics.luresClaimed .. " claimed, " .. Hub.statistics.luresBaited .. " baited"
        end)
        actionButton("START FULL FARM MODE", function()
            config.autoNeeds = true; config.autoLures = true
            config.autoFurniture = true; config.autoArea = true
            config.autoPetMe = true; config.autoWalk = true
            saveSettings(); renderTab(); log("INFO", "Farm mode enabled")
        end)
        actionButton("STOP ALL FARMS", function()
            config.autoNeeds = false; config.autoLures = false
            config.autoBait = false; config.autoMoneyTree = false
            saveSettings(); renderTab(); log("INFO", "All farms paused")
        end)
        note("No guaranteed earnings: the game's server decides rewards and whether each action is valid.")
    elseif selectedTab == "Farms" then
        section("Pet / Bucks / XP")
        toggle("Auto Needs", "autoNeeds", "Prioritized pet ailment worker")
        toggle("Auto Feed / Drink", "autoFeed", "Uses existing food only; consumes items")
        toggle("Auto Furniture", "autoFurniture", "Uses nearby eligible sleep/bath/toilet objects")
        toggle("Auto Area Needs", "autoArea", "Travels to school, salon, hospital and outdoor needs")
        toggle("Auto Walk", "autoWalk", "Uses character movement when walking is required")
        toggle("Auto Pet Me", "autoPetMe", "Server-validated petting progress requests")
        toggle("Auto Equip Selected Pet", "autoEquip", "Re-equips chosen pet when needed")
        section("Lure farm")
        toggle("Auto Claim Lures", "autoLures", "Uses normal and owned premium lures")
        toggle("Auto Place Bait", "autoBait", "Consumes owned lure bait; no purchases")
        toggle("Auto Money Trees", "autoMoneyTree", "Interacts with a nearby money tree when found")
        note("Furniture, movement, and area tasks depend on game state. This is not an instant-completion script.")
    elseif selectedTab == "Pets" then
        refreshPetsTab()
        section("Pet commands")
        actionButton("Equip Selected Pet", function()
            equipPet(selectedPet())
        end)
        actionButton("Pet Me once", function()
            local p = selectedPet(); if p then petPet(p) end
        end)
        actionButton("Feed existing hunger item once", function()
            local p = selectedPet(); if p then
                local previous = config.autoFeed; config.autoFeed = true
                feedForAilment(p, "hungry"); config.autoFeed = previous
            end
        end)
        actionButton("Feed existing thirst item once", function()
            local p = selectedPet(); if p then
                local previous = config.autoFeed; config.autoFeed = true
                feedForAilment(p, "thirsty"); config.autoFeed = previous
            end
        end)
    elseif selectedTab == "Travel" then
        section("Interiors")
        for _, place in ipairs({"MainMap", "Neighborhood", "Nursery", "School",
            "Hospital", "Salon", "PizzaShop", "PetShop", "ToyShop",
            "CoffeeShop", "SkyCastle", "VIP", "TradingHub", "IceCream"}) do
            actionButton("Travel to " .. place, function() travel(place) end)
        end
        actionButton("Travel Home", function()
            if api.Nav then
                local ok, destination = pcall(api.Nav.get_house_location_for_player, LocalPlayer)
                if ok and type(destination) == "string" then travel(destination); return end
            end
            travel("housing")
        end)
        section("Position")
        actionButton("Save current position", function()
            if root() then Hub.position = root().CFrame; log("TRAVEL", "Position saved") end
        end)
        actionButton("Return to saved position", function()
            if root() and Hub.position then root().CFrame = Hub.position end
        end)
    elseif selectedTab == "Utilities" then
        section("Character")
        toggle("Anti AFK", "autoAntiAfk", "Idle input prevention; executor dependent")
        toggle("Anti Void", "antiVoid", "Restore last safe location after a fall")
        toggle("Noclip", "noClip", "Local collision toggle")
        toggle("Infinite Jump", "infiniteJump", "Press jump repeatedly")
        toggle("Player ESP", "playerESP", "Name markers for other players")
        toggle("Low Graphics", "lowGraphics", "Reversible client-only lighting / part simplification")
        numericSetting("Walk speed", "walkSpeed", 16, 100, 4)
        numericSetting("Jump power", "jumpPower", 50, 150, 10)
        section("Session")
        actionButton("Rejoin", function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
        actionButton("Copy coordinates", function()
            local r = root()
            if r and storage("setclipboard") then
                storage("setclipboard")(tostring(r.Position))
            end
        end)
    elseif selectedTab == "Events" then
        section("Lightning Dimension 2026")
        note("Your original event script is preserved as main.lua. This hub launches it as a separate worker and window.")
        actionButton("Launch Original Lightning Autofarm", function()
            if type(loadstring) ~= "function" then
                log("WARN", "Executor has no loadstring")
                return
            end
            local ok, err = pcall(function()
                loadstring(game:HttpGet(
                    "https://raw.githubusercontent.com/zvzt/Adopt-Me/main/main.lua"
                ))()
            end)
            if not ok then log("ERROR", "Legacy Lightning: " .. tostring(err)) end
        end)
        actionButton("Stop Lightning Autofarm", function()
            if type(env.AdoptMeEventAutofarmStop) == "function" then
                pcall(env.AdoptMeEventAutofarmStop)
            end
        end)
        section("Pet pen")
        actionButton("Claim ready lures once", function()
            local was = config.autoLures; config.autoLures = true
            manageLures(); config.autoLures = was
        end)
        actionButton("Bait empty lures once (consumes bait)", function()
            local was, oldBait = config.autoLures, config.autoBait
            config.autoLures = true; config.autoBait = true
            manageLures(); config.autoLures = was; config.autoBait = oldBait
        end)
    elseif selectedTab == "Logs" then
        section("Diagnostics")
        note("Errors and game API mismatches are reported here. Scripts were statically reviewed, not tested in a live server.")
        actionButton("Copy logs", function()
            local copy = storage("setclipboard")
            if copy then copy(table.concat(Hub.logs, "\n")) end
        end)
        actionButton("Save logs", function()
            local write = storage("writefile")
            if write then write("AdoptMeUniversalHub_Log.txt", table.concat(Hub.logs, "\n")) end
        end)
        Hub.logLabel = create("TextLabel", content, {
            Text = table.concat(Hub.logs, "\n"),
            Font = Enum.Font.Code, TextSize = 10, TextColor3 = color.muted,
            BackgroundColor3 = color.bg, BorderSizePixel = 0,
            TextWrapped = false, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Size = UDim2.new(1, 0, 0, 250)
        })
        corner(Hub.logLabel, 6)
        create("UIPadding", Hub.logLabel, {PaddingLeft = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 8)})
    end
end
for i, name in ipairs({"Dashboard", "Farms", "Pets", "Travel", "Utilities", "Events", "Logs"}) do
    local b = create("TextButton", sidebar, {
        LayoutOrder = i, Text = name, Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = color.muted, BackgroundColor3 = color.surface,
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 37)
    })
    corner(b, 6)
    tabButtons[name] = b
    connect(b.MouseButton1Click, function() setTab(name) end)
end
-- Drag and keyboard visibility
do
    local dragging, dragOrigin, frameOrigin
    connect(header.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
            input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragOrigin = input.Position
            frameOrigin = window.Position
        end
    end)
    connect(header.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
            input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    connect(UIS.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
            input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragOrigin
            window.Position = UDim2.new(frameOrigin.X.Scale, frameOrigin.X.Offset + delta.X,
                frameOrigin.Y.Scale, frameOrigin.Y.Offset + delta.Y)
        end
    end)
    connect(UIS.InputBegan, function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.RightShift then
            window.Visible = not window.Visible
            config.visible = window.Visible
        end
    end)
end
local reopen = create("TextButton", gui, {
    Text = "ADOPT ME HUB", Font = Enum.Font.GothamBold, TextSize = 11,
    TextColor3 = color.text, BackgroundColor3 = color.accent,
    BorderSizePixel = 0, Size = UDim2.fromOffset(113, 32),
    Position = UDim2.fromOffset(12, 170)
})
corner(reopen, 8)
connect(reopen.MouseButton1Click, function()
    window.Visible = not window.Visible
    config.visible = window.Visible
end)
setTab("Dashboard")
initApi()
if config.lowGraphics then paintPerformance(true) end
log("INFO", "Hub ready. Farms are opt-in.")

task.spawn(function()
    while Hub.alive do
        local ok, err = pcall(function()
            if config.autoNeeds then
                local p = selectedPet()
                if p then
                    if config.autoEquip then
                        local equipped = false
                        for _, e in ipairs(equippedPets()) do
                            if tostring(e.unique) == p.unique then equipped = true; break end
                        end
                        if not equipped and allowed("equip", 20) then equipPet(p) end
                    end
                    local ailment = chooseAilment(p)
                    if ailment and not needsBusy then
                        needsBusy = true
                        task.spawn(function()
                            local okNeed, errNeed = pcall(handleNeed, p, ailment)
                            if not okNeed then log("ERROR", "Need " .. ailment.kind .. ": " .. tostring(errNeed)) end
                            needsBusy = false
                        end)
                    end
                end
            end
        end)
        if not ok then log("ERROR", "Needs loop: " .. tostring(err)) end
        task.wait(3.5)
    end
end)
task.spawn(function()
    while Hub.alive do
        safe("LURE LOOP", manageLures)
        task.wait(6)
    end
end)
task.spawn(function()
    while Hub.alive do
        safe("MONEY LOOP", collectMoneyTrees)
        task.wait(65)
    end
end)
task.spawn(function()
    while Hub.alive do
        safe("ESP", updateESP)
        task.wait(2)
    end
end)

local stopping = false
local function stopHub()
    if stopping then return end
    stopping = true
    Hub.alive = false
    for _, conn in ipairs(Hub.connections) do pcall(function() conn:Disconnect() end) end
    restoreCollisions()
    paintPerformance(false)
    clearESP()
    for hum, original in pairs(originalHumanoid) do
        if hum and hum.Parent then
            hum.WalkSpeed = original.speed
            if hum.UseJumpPower then hum.JumpPower = original.jump end
        end
    end
    saveSettings()
    if gui and gui.Parent then gui:Destroy() end
    env.AdoptMeUniversalHubStop = nil
end
env.AdoptMeUniversalHubStop = stopHub
env.AdoptMeUniversalHub = Hub
