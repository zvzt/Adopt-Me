local env = (getgenv and getgenv()) or _G
if type(env.AdoptMeEventAutofarmStop) == "function" then
    pcall(env.AdoptMeEventAutofarmStop)
end
if type(env.LightningFarmStop) == "function" then
    pcall(env.LightningFarmStop)
end

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer
if not Player then return end

local TweenService = game:GetService("TweenService")
local startupGui, startupPanel, startupText, startupTitle
local startupClosed = false
local function makeStartupToast()
    local playerGui = Player:FindFirstChildOfClass("PlayerGui") or Player:WaitForChild("PlayerGui", 10)
    if not playerGui then return end
    local previous = playerGui:FindFirstChild("AdoptMeEventStartup")
    if previous then previous:Destroy() end
    startupGui = Instance.new("ScreenGui")
    startupGui.Name = "AdoptMeEventStartup"
    startupGui.ResetOnSpawn = false
    startupGui.DisplayOrder = 9900
    startupGui.Parent = playerGui
    startupPanel = Instance.new("Frame")
    startupPanel.Size = UDim2.fromOffset(306, 66)
    startupPanel.Position = UDim2.new(1, 330, 1, -95)
    startupPanel.BorderSizePixel = 0
    startupPanel.BackgroundColor3 = Color3.fromRGB(8, 8, 11)
    startupPanel.Parent = startupGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = startupPanel
    local border = Instance.new("UIStroke")
    border.Color = Color3.fromRGB(55, 55, 66)
    border.Transparency = 0.25
    border.Parent = startupPanel
    local function text(value, y, size, color, bold)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -30, 0, 23)
        label.Position = UDim2.fromOffset(15, y)
        label.BackgroundTransparency = 1
        label.Font = bold and Enum.Font.BuilderSansBold or Enum.Font.BuilderSans
        label.TextSize = size
        label.TextColor3 = color
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Text = value
        label.Parent = startupPanel
        return label
    end
    startupTitle = text("ADOPT ME EVENT AUTOFARM", 10, 11, Color3.fromRGB(248, 248, 250), true)
    startupText = text("Preparing game modules...", 33, 12, Color3.fromRGB(185, 185, 195), false)
    TweenService:Create(startupPanel, TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -322, 1, -95)
    }):Play()
end
local function toastProgress(message)
    if startupText and startupText.Parent and not startupClosed then
        startupText.Text = tostring(message):sub(1, 70)
    end
end
local function dismissStartupToast(message, seconds)
    if startupClosed then return end
    if message then toastProgress(message) end
    startupClosed = true
    if not startupGui or not startupGui.Parent then return end
    task.delay(seconds or 2.5, function()
        if not startupGui or not startupGui.Parent then return end
        if startupPanel and startupPanel.Parent then
            TweenService:Create(startupPanel, TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
                Position = UDim2.new(1, 345, 1, -95), BackgroundTransparency = 1
            }):Play()
            for _, child in ipairs(startupPanel:GetChildren()) do
                if child:IsA("TextLabel") then
                    TweenService:Create(child, TweenInfo.new(0.28), {TextTransparency = 1}):Play()
                elseif child:IsA("UIStroke") then
                    TweenService:Create(child, TweenInfo.new(0.28), {Transparency = 1}):Play()
                end
            end
        end
        task.delay(0.44, function()
            if startupGui then startupGui:Destroy() end
        end)
    end)
end
makeStartupToast()
local function requiredChild(parent, name, seconds)
    if not parent then error("STARTUP | Missing parent for " .. tostring(name), 0) end
    local found = parent:FindFirstChild(name) or parent:WaitForChild(name, seconds or 8)
    if not found then
        error("STARTUP | Timed out loading " .. parent:GetFullName() .. "." .. name, 0)
    end
    return found
end
local function requireGameModule(module, name)
    toastProgress("Loading " .. name .. "...")
    local ok, value = pcall(require, module)
    if not ok then
        error("MODULE/" .. name .. " | " .. tostring(value), 0)
    end
    if value == nil then error("MODULE/" .. name .. " | returned nil", 0) end
    return value
end
local function initializeModules()
    toastProgress("Loading event modules...")
    local fsysModule = requiredChild(RS, "Fsys")
    local fsys = requireGameModule(fsysModule, "Fsys")
    if type(fsys.load) ~= "function" then error("Fsys loader unavailable", 0) end
    local gameFolder = requiredChild(requiredChild(requiredChild(RS, "SharedModules"), "ContentPacks"), "LightningDimension2026")
    local lightning = requiredChild(gameFolder, "Game")
    local lureModules = requiredChild(requiredChild(requiredChild(RS, "new"), "modules"), "Lures")
    local refs = {
        Net = requireGameModule(requiredChild(lightning, "LightningDimensionNet"), "LightningDimensionNet"),
        K = requireGameModule(requiredChild(lightning, "LightningDimensionConstants"), "LightningDimensionConstants"),
        LureNet = requireGameModule(requiredChild(lureModules, "LuresNet"), "LuresNet"),
        LureActions = requireGameModule(requiredChild(lureModules, "LureActions"), "LureActions"),
    }
    toastProgress("Loading client services...")
    for _, item in ipairs({
        {"ClientData", "ClientData"},
        {"ClientToolManager", "ClientToolManager"},
        {"InventoryDB", "InventoryDB"},
        {"LiveOpsTime", "LiveOpsTime"},
        {"RouterClient", "RouterClient"},
        {"InteriorsM", "InteriorsM"},
        {"NavigationHelper", "new:NavigationHelper"},
    }) do
        toastProgress("Initializing " .. item[1] .. "...")
        local ok, value = pcall(fsys.load, item[2])
        if not ok then error("CLIENT/" .. item[1] .. " | " .. tostring(value), 0) end
        if value == nil then error("Missing client service: " .. item[1], 0) end
        refs[item[1]] = value
        task.wait()
    end
    return refs
end
local function isModuleContextError(message)
    message = tostring(message)
    return message:find("Cannot require a non-RobloxScript module from a RobloxScript", 1, true) ~= nil
end
local function initializeInCompatibleContext()
    local getIdentity = (type(getthreadidentity) == "function" and getthreadidentity)
        or (type(getidentity) == "function" and getidentity)
        or (type(env.getthreadidentity) == "function" and env.getthreadidentity)
        or (type(env.getidentity) == "function" and env.getidentity)
    local setIdentity = (type(setthreadidentity) == "function" and setthreadidentity)
        or (type(setidentity) == "function" and setidentity)
        or (type(env.setthreadidentity) == "function" and env.setthreadidentity)
        or (type(env.setidentity) == "function" and env.setidentity)
    local okIdentity, identity = false, nil
    if getIdentity then okIdentity, identity = pcall(getIdentity) end
    identity = okIdentity and tonumber(identity) or nil
    if identity == 3 or identity == 6 or identity == 8 then
        if not setIdentity then
            return false, "INCOMPATIBLE_CONTEXT | RobloxScript identity " .. identity .. " and no executor game-context switch is available"
        end
        local changed, changeError = pcall(setIdentity, 2)
        if not changed then
            return false, "INCOMPATIBLE_CONTEXT | Cannot use normal game context: " .. tostring(changeError)
        end
        local ok, value = pcall(initializeModules)
        local restored, restoreError = pcall(setIdentity, identity)
        if not restored then
            return false, "INCOMPATIBLE_CONTEXT | Could not restore original thread context: " .. tostring(restoreError)
        end
        if not ok and isModuleContextError(value) then
            return false, "INCOMPATIBLE_CONTEXT | Executor cannot require game modules even at identity 2: " .. tostring(value)
        end
        return ok, value
    end
    local ok, value = pcall(initializeModules)
    if not ok and isModuleContextError(value) then
        return false, "INCOMPATIBLE_CONTEXT | Executor launched in a RobloxScript VM; normal game ModuleScripts are inaccessible. " .. tostring(value)
    end
    return ok, value
end
local init = {done = false, ok = false, value = nil}
local initThread = task.spawn(function()
    init.ok, init.value = initializeInCompatibleContext()
    init.done = true
end)
local initDeadline = os.clock() + 20
while not init.done and os.clock() < initDeadline do task.wait(0.12) end
if not init.done then
    pcall(task.cancel, initThread)
    toastProgress("Startup timed out. Check game modules.")
    dismissStartupToast(nil, 6)
    return
end
if not init.ok then
    local message = tostring(init.value)
    local permissionsError = message:find("LPS:", 1, true)
        or message:find("lacking capability", 1, true)
        or message:find("Cannot require", 1, true)
    toastProgress(permissionsError and "Module access blocked by executor. See error file." or "Startup failed. Check error file.")
    local writer = type(writefile) == "function" and writefile or env.writefile
    if type(writer) == "function" then
        pcall(writer, "AdoptMeEventAutofarm_Errors.txt", "Startup failure: " .. message:sub(1, 1500) .. "\n")
    end
    dismissStartupToast(nil, 6)
    return
end
local dependencies = init.value
local Net = dependencies.Net
local K = dependencies.K
local LureNet = dependencies.LureNet
local ClientData = dependencies.ClientData
local ClientToolManager = dependencies.ClientToolManager
local InventoryDB = dependencies.InventoryDB
local LiveOpsTime = dependencies.LiveOpsTime
local RouterClient = dependencies.RouterClient
local InteriorsM = dependencies.InteriorsM
local NavigationHelper = dependencies.NavigationHelper
local LureActions = dependencies.LureActions

local CONFIG = {
    TP_HEIGHT = 3.0,
    TICK = 0.30,
    REFILL_DELAY = 0.30,
    TRADE_RETRY = 1.8,
    TRADE_RESPONSE_WAIT = 6,
    TRADE_PENDING_LIMIT = 35,
    TRADE_BACKOFF = 45,
    MAIN_STALL_TIMEOUT = 30,
    LURE_RETRY = 3.0,
    LURE_CHECK = 2.5,
    CLAIM_RETRY = 15,
    BAIT_RETRY = 12,
    LURE_VERIFY_WAIT = 4,
    STATUS_EVERY = 5.0,
    TRADE_BUFFER = 2.2,
    AUTO_TRADE = true,
    AUTO_LURE = true,
    PREMIUM_IF_OWNED = true,
    LOW_GRAPHICS = false,
    ANTI_AFK = true,
    ERROR_LOGGING = true,
    ANTI_FLING = false,
    ANTI_VOID = true,
    LOG_FLUSH_EVERY = 8,
    LOG_MAX_ENTRIES = 45,
    LOG_MAX_GAME_ENTRIES = 5,
    LOG_REPEAT_COOLDOWN = 120,
    NAV_RETRY = 14,
    NAV_CONFIRM_TIMEOUT = 25,
    NAV_CHECK = 0.35,
    TRAP_RANGE = 65,
    BATCH_PLACE = true,
    BATCH_DELAY = 0.04,
    CAP_DELAY = 0.04,
    PLACE_SETTLE = 0.30,
    CAP_SETTLE = 0.12,
    PLACE_RETRIES = 3,
    CAP_RETRIES = 3,
    BATCH_SAMPLE_POINTS = 32,
    BATCH_SPACING_MARGIN = 2.5,
}

local alive = true
local running = true
local subs = {}
local warnings = {}
local placed = {}
local batchBusy = false
local activeFarmAction = nil
local batchCooldownUntil = 0
local batchFailures = 0
local capQueue = {}
local capQueued = {}
local capBusy = false
local currentWarningId = nil
local nextId = 0
local lastRefill = 0
local lastEquipAttempt = 0
local equipFailCount = 0
local lastToolInventoryChange = 0
local lastLocalTeleportAt = -math.huge
local equipInProgress = false
local lastBoreScan = 0
local cachedBore = nil
local lastTrade = 0
local tradeRequest = nil
local tradeCooldownUntil = 0
local lastMainPulse = os.clock()
local lastWarningPulse = os.clock()
local nextStrikeDiagnostic = os.clock() + 45
local lastCookieUnequip = 0
local lastCookieCheck = 0
local cookieUnequipFailures = 0
local lastLure = 0
local lastStatus = "Starting"
local gui, statusLabel, countsLabel, errorsLabel, lureStatusLabel
local bottlesValueLabel, forksValueLabel, cookiesValueLabel, farmStatusDot
local errors = 0
local busy = false
local lureBusy = false
local totalCaptured = 0
local totalTraded = 0
local totalClaimed = 0
local lastCounts = {captured = 0, cookie = 0}
local lureLastAttempt = {}
local lureNeedsCheck = true
local lastLureStatus = 0
local lureDisplaySummary = "No lure information yet"
local lastSafePivot = nil
local mode = "TRAVEL"
local navigating = false
local navigationPermissionBlocked = false
local nextHomeAttempt = 0
local nextLightningAttempt = 0
local lastDestination = ""
local logPath = "AdoptMeEventAutofarm_Errors.txt"
local fileWrite = type(writefile) == "function" and writefile or env.writefile
local fileAppend = type(appendfile) == "function" and appendfile or env.appendfile
local fileReady = false
local fullLog = ""
local queuedErrors = {}
local fileFailure = false
local fileErrorEntries = 0
local gameErrorEntries = 0
local lastLoggedError = {}
if CONFIG.ERROR_LOGGING and type(fileWrite) == "function" then
    local ok = pcall(fileWrite, logPath, "Adopt Me Event Autofarm error log\nStarted: "
        .. os.date("!%Y-%m-%d %H:%M:%S UTC") .. "\n\n")
    fileReady = ok
end
env.AdoptMeEventAutofarmErrorFile = fileReady and logPath or nil
env.AdoptMeEventAutofarmErrors = queuedErrors

local function flushErrors()
    if not CONFIG.ERROR_LOGGING or not fileReady or #queuedErrors == 0 then return end
    local chunk = table.concat(queuedErrors, "\n") .. "\n"
    local ok
    if type(fileAppend) == "function" then
        ok = pcall(fileAppend, logPath, chunk)
    else
        local previous = fullLog
        fullLog = fullLog .. chunk
        ok = pcall(fileWrite, logPath,
            "Adopt Me Event Autofarm error log\nStarted: " .. os.date("!%Y-%m-%d") .. "\n\n" .. fullLog)
        if not ok then fullLog = previous end
    end
    if ok then
        table.clear(queuedErrors)
    else
        fileReady = false
        fileFailure = true
    end
end

local function log(tag, msg)
    msg = tostring(msg)
    local isError = tag == "ERROR" or tag == "GAME ERROR"
    local isLogged = isError or tag == "WARN"
    if isLogged and CONFIG.ERROR_LOGGING and fileErrorEntries < CONFIG.LOG_MAX_ENTRIES
        and (tag ~= "GAME ERROR" or gameErrorEntries < CONFIG.LOG_MAX_GAME_ENTRIES) then
        local firstLine = msg:match("^[^\r\n]*") or msg
        local key = tostring(tag) .. "|" .. firstLine:sub(1, 240)
        local now = os.clock()
        local previous = lastLoggedError[key]
        if not previous or now - previous >= CONFIG.LOG_REPEAT_COOLDOWN then
            lastLoggedError[key] = now
            if tag ~= "GAME ERROR" or gameErrorEntries < CONFIG.LOG_MAX_GAME_ENTRIES then
                if fileErrorEntries < CONFIG.LOG_MAX_ENTRIES then
                    local limited = (tag == "GAME ERROR" and (msg:match("^[^\r\n]*") or msg) or msg):sub(1, tag == "GAME ERROR" and 500 or 1000)
                    table.insert(queuedErrors, os.date("!%Y-%m-%d %H:%M:%S")
                        .. " UTC [LIGHTNING][" .. tostring(tag) .. "] " .. limited)
                    fileErrorEntries += 1
                    if tag == "GAME ERROR" then gameErrorEntries += 1 end
                    if isError then errors += 1 end
                    if #queuedErrors >= 20 then flushErrors() end
                end
            end
        end
    end
    if statusLabel and tag ~= "HEALTH" and tag ~= "GAME ERROR" then
        statusLabel.Text = msg:sub(1, 150)
    end
    if errorsLabel then
        errorsLabel.Text = ("Errors %d  |  Captured %d  |  Bait %d  |  Claims %d")
            :format(errors, totalCaptured, totalTraded, totalClaimed)
        if CONFIG.ERROR_LOGGING and (fileFailure or not env.AdoptMeEventAutofarmErrorFile) then
            errorsLabel.Text ..= "   |   LOG UNAVAILABLE"
        end
    end
    lastStatus = msg
end

local function setErrorLogging(enabled)
    enabled = enabled == true
    if CONFIG.ERROR_LOGGING == enabled then return end
    if not enabled then flushErrors() end
    CONFIG.ERROR_LOGGING = enabled
    if enabled and not fileReady and type(fileWrite) == "function" then
        local ok = pcall(fileWrite, logPath, "Adopt Me Event Autofarm error log\nStarted: "
            .. os.date("!%Y-%m-%d %H:%M:%S UTC") .. "\n\n")
        fileReady = ok
        fileFailure = not ok
        env.AdoptMeEventAutofarmErrorFile = ok and logPath or nil
    end
    if not enabled then table.clear(queuedErrors) end
end

local function traceback(err)
    if debug and debug.traceback then
        return debug.traceback(tostring(err), 2)
    end
    return tostring(err)
end

local function safe(label, callback)
    local ok, a, b = xpcall(callback, traceback)
    if not ok then
        log("ERROR", label .. " | " .. tostring(a))
        return false
    end
    return true, a, b
end

local function enterNormalClientThread()
    local platformOk, platform = pcall(function()
        return game:GetService("UserInputService"):GetPlatform()
    end)
    if platformOk and platform ~= Enum.Platform.Windows then return true end
    local getter = (type(getthreadidentity) == "function" and getthreadidentity)
        or (type(getidentity) == "function" and getidentity)
        or (type(env.getthreadidentity) == "function" and env.getthreadidentity)
        or (type(env.getidentity) == "function" and env.getidentity)
    local setter = (type(setthreadidentity) == "function" and setthreadidentity)
        or (type(setidentity) == "function" and setidentity)
        or (type(env.setthreadidentity) == "function" and env.setthreadidentity)
        or (type(env.setidentity) == "function" and env.setidentity)
    if not getter then return true end
    local ok, identity = pcall(getter)
    if not ok then return true end
    identity = tonumber(identity)
    if not identity or identity == 2 then return true end
    if not setter then
        return false, "Client thread identity " .. tostring(identity) .. " cannot be changed"
    end
    local changed, failure = pcall(setter, 2)
    if not changed then return false, tostring(failure) end
    local verified, current = pcall(getter)
    if verified and tonumber(current) ~= 2 then
        return false, "Client identity remains " .. tostring(current)
    end
    return true
end

local function interior()
    local location = InteriorsM.get_current_location()
    if location and location.destination_id == K.DESTINATION_ID then
        local scene = location.interior
        if scene and scene.Parent and scene:FindFirstChild("Game") then
            return scene
        end
        local interiors = workspace:FindFirstChild("Interiors")
        if interiors then
            local exact = interiors:FindFirstChild(K.DESTINATION_ID)
            if exact and exact:FindFirstChild("Game") then return exact end
            for _, candidate in ipairs(interiors:GetChildren()) do
                if candidate.Name:sub(1, #K.DESTINATION_ID + 1) == K.DESTINATION_ID .. "!"
                    and candidate:FindFirstChild("Game") then
                    return candidate
                end
            end
        end
    end
    return nil
end

local function character()
    return Player.Character
end

local function root()
    local char = character()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function currentDestination()
    local location = InteriorsM.get_current_location()
    return location and location.destination_id
end

local function inLightning()
    return currentDestination() == K.DESTINATION_ID
end

local function items(category, kind)
    local data = ClientData.get("inventory")
    local list = {}
    for key, item in pairs((data and data[category]) or {}) do
        if item.kind == kind then
            table.insert(list, {
                unique = tostring(item.unique or key),
                item = item,
            })
        end
    end
    table.sort(list, function(a, b)
        return a.unique < b.unique
    end)
    return list
end

local function cookies()
    return items("food", K.COOKIE_BAIT_KIND)
end

local function caught()
    return items("toys", K.CAPTURED_LIGHTNING_KIND)
end

local function forks()
    local list = {}
    for _, entry in ipairs(items("toys", K.FORKED_BOTTLE_KIND)) do
        if not placed[entry.unique] then
            table.insert(list, entry)
        end
    end
    return list
end

local function refreshCounts()
    local a, b, c = #caught(), #forks(), #cookies()
    if countsLabel then
        countsLabel.Text = ("Lightning %d   Forks %d   Cookie bait %d"):format(a, b, c)
    end
    if bottlesValueLabel then bottlesValueLabel.Text = tostring(a) end
    if forksValueLabel then forksValueLabel.Text = tostring(b) end
    if cookiesValueLabel then cookiesValueLabel.Text = tostring(c) end
    if a > lastCounts.captured then
        totalCaptured += a - lastCounts.captured
        log("CAPTURE", "+" .. (a - lastCounts.captured) .. " Lightning Bottle(s)")
    end
    lastCounts.captured = a
    lastCounts.cookie = c
end

local function floorAt(pos)
    local opts = RaycastParams.new()
    opts.FilterType = Enum.RaycastFilterType.Exclude
    local exclusions = {character()}
    local place = interior()
    local gameFolder = place and place:FindFirstChild("Game")
    if gameFolder then
        for _, name in ipairs({"Cloud", "BottlePile", "BaitDisplays", "NoThrowZones"}) do
            local thing = gameFolder:FindFirstChild(name)
            if thing then table.insert(exclusions, thing) end
        end
    end
    opts.FilterDescendantsInstances = exclusions
    local hit = workspace:Raycast(
        pos + Vector3.new(0, 450, 0),
        Vector3.new(0, -1000, 0),
        opts
    )
    return hit and hit.Position.Y or pos.Y
end

local function tpCenter(pos, height)
    local r = root()
    if not r then
        log("ERROR", "TELEPORT | No HumanoidRootPart (respawning?)")
        return false
    end
    local y = floorAt(pos) + (height or CONFIG.TP_HEIGHT)
    r.CFrame = CFrame.new(pos.X, y, pos.Z)
    lastLocalTeleportAt = os.clock()
    r.AssemblyLinearVelocity = Vector3.zero
    r.AssemblyAngularVelocity = Vector3.zero
    return true
end

local function tpExactNear(targetPosition, yOffset)
    local c = character()
    local r = root()
    if not c or not r then
        log("ERROR", "TELEPORT | Character/root missing")
        return false
    end
    local desired = targetPosition + Vector3.new(0, yOffset or 2, 0)
    c:PivotTo(CFrame.new(desired))
    lastLocalTeleportAt = os.clock()
    r.AssemblyLinearVelocity = Vector3.zero
    r.AssemblyAngularVelocity = Vector3.zero
    lastSafePivot = c:GetPivot()
    return true
end

local function rangeTo(targetPosition)
    local c = character()
    return c and (c:GetPivot().Position - targetPosition).Magnitude or math.huge
end

local function nearXZ(a, b, distance)
    local delta = a - b
    return Vector3.new(delta.X, 0, delta.Z).Magnitude <= distance
end

local function pile()
    local place = interior()
    local gameFolder = place and place:FindFirstChild("Game")
    return gameFolder and gameFolder:FindFirstChild("BottlePile")
end

local function refill()
    if not running then return false end
    if #forks() > 0 then return true end
    if not interior() then return false end
    local target = pile()
    if not target then
        log("ERROR", "REFILL | BottlePile missing; enter Lightning Dimension")
        return false
    end
    local pilePosition = target:GetPivot().Position
    for attempt = 1, 3 do
        if not alive or not running then return false end
        if not tpExactNear(pilePosition, 1.5) then return false end
        task.wait(CONFIG.REFILL_DELAY + (attempt - 1) * 0.18)
        local distance = rangeTo(pilePosition)
        local ok, response = safe("REFILL/TakeBottle", function()
            return Net.TakeBottle:invoke_server_async()
        end)
        if not ok then return false end
        if type(response) == "table" and response.ok then
            log("REFILL", ("SUCCESS | %s empty bottles; local range %.1f studs")
                :format(tostring(response.count), distance))
            return true
        end
        local reason = type(response) == "table" and response.reason or tostring(response)
        if reason == "too_far" and attempt < 3 then
            task.wait(0.2)
        else
            log("ERROR", ("REFILL | Server rejected: %s | attempts=%d | local distance=%.1f")
                :format(tostring(reason), attempt, distance))
            return false
        end
    end
    return false
end

local function unequipCookie()
    if not running then return false end
    local equipped = ClientToolManager.get_equipped_by_category("food") or {}
    local held = {}
    for _, item in ipairs(equipped) do
        if item.kind == K.COOKIE_BAIT_KIND then
            table.insert(held, item)
        end
    end
    if #held == 0 then
        cookieUnequipFailures = 0
        return true
    end
    if os.clock() - lastCookieUnequip < 5 then return false end
    lastCookieUnequip = os.clock()
    for _, item in ipairs(held) do
        local ok, success, detail = safe("COOKIE/Unequip", function()
            return ClientToolManager.unequip(item)
        end)
        if not ok or not success then
            cookieUnequipFailures += 1
            if cookieUnequipFailures == 1 or cookieUnequipFailures % 8 == 0 then
                local reason = type(detail) == "table"
                    and (detail.message or detail.action) or tostring(detail or "client refused")
                log("WARN", ("COOKIE | Unequip not confirmed (%d): %s")
                    :format(cookieUnequipFailures, tostring(reason)))
            end
        end
    end
    task.wait(0.15)
    if not ClientToolManager.is_kind_equipped({
        category = "food", kind = K.COOKIE_BAIT_KIND
    }) then
        cookieUnequipFailures = 0
        return true
    end
    return false
end

local function equippedForkUnique()
    for _, item in ipairs(ClientToolManager.get_equipped_by_category("toys") or {}) do
        if item.kind == K.FORKED_BOTTLE_KIND then
            return tostring(item.unique)
        end
    end
    return nil
end

local function equip(entry)
    if not running or not alive or not entry or equipInProgress then return false end
    if equippedForkUnique() then
        equipFailCount = 0
        return true
    end
    local now = os.clock()
    if now - lastToolInventoryChange < 0.75 or now - lastEquipAttempt < 0.8 then
        return false
    end
    if capBusy or #capQueue > 0 then return false end
    for _, warning in ipairs(warnings) do
        if warning.due - now < 0.8 and warning.due > now - 0.4 then
            return false
        end
    end
    local unique = tostring(entry.unique)
    if placed[unique] then return false end
    local inventory = ClientData.get("inventory")
    local toys = inventory and inventory.toys or {}
    local fresh = toys[unique]
    if not fresh then
        for _, item in pairs(toys) do
            if tostring(item.unique) == unique then
                fresh = item
                break
            end
        end
    end
    if not fresh or fresh.kind ~= K.FORKED_BOTTLE_KIND then
        return false
    end
    equipInProgress = true
    lastEquipAttempt = now
    local ok, success, detail = safe("EQUIP/ToolAPI", function()
        return ClientToolManager.equip(fresh)
    end)
    equipInProgress = false
    if ok and (success or equippedForkUnique()) then
        equipFailCount = 0
        log("EQUIP", "Equipped fork=" .. unique)
        return true
    end
    equipFailCount += 1
    if equipFailCount <= 3 or equipFailCount % 8 == 0 then
        local reason = type(detail) == "table" and (detail.message or detail.action)
            or (detail == nil and "equip rejected without reason" or tostring(detail))
        log("ERROR", ("EQUIP | fork=%s | failure #%d | reason=%s")
            :format(unique, equipFailCount, tostring(reason)))
    end
    return false
end

local function placeFork(entry, pos, warning)
    local throwRange = tonumber(K.get("BOTTLE_THROW_RANGE")) or 15
    local safeDistance = math.max(3, throwRange - 5)
    local char = character()
    local needMove = not char or not nearXZ(char:GetPivot().Position, pos, safeDistance)
    for attempt = 1, CONFIG.PLACE_RETRIES do
        if not alive or not running or mode ~= "FARM" or not inLightning() then return false, "stopped" end
        if needMove then
            if not tpExactNear(pos, 1.3) then return false, "teleport" end
        end
        local requiredSettle = CONFIG.PLACE_SETTLE + (attempt - 1) * 0.20
        local sinceMove = os.clock() - lastLocalTeleportAt
        if sinceMove < requiredSettle then
            task.wait(requiredSettle - sinceMove)
        elseif attempt > 1 then
            task.wait(0.16 * attempt)
        end
        if not alive or not running or mode ~= "FARM" or not inLightning() then return false, "stopped" end
        char = character()
        if not char or not nearXZ(char:GetPivot().Position, pos, safeDistance) then
            if not tpExactNear(pos, 1.3) then return false, "teleport" end
            task.wait(requiredSettle)
        end
        local ok, result = safe("PLACE/PlaceBottle", function()
            return Net.PlaceBottle:invoke_server_async({unique = entry.unique, position = pos})
        end)
        if not ok then return false, "request_failed" end
        if result and result.ok then
            placed[entry.unique] = {
                position = pos,
                state = "forked",
                warningId = warning and warning.id or 0,
                strikeCenter = warning and warning.position or pos,
            }
            return true
        end
        local reason = type(result) == "table" and result.reason or tostring(result)
        if reason == "too_far" and attempt < CONFIG.PLACE_RETRIES then
            needMove = true
        else
            if reason ~= "too_close" and reason ~= "no_throw_zone" then
                char = character()
                local position = char and char:GetPivot().Position
                local localRange = position and (Vector3.new(position.X - pos.X, 0, position.Z - pos.Z)).Magnitude or -1
                log("ERROR", ("PLACE | %s | attempt=%d | local horizontal range=%.1f | limit=%.1f")
                    :format(tostring(reason), attempt, localRange, throwRange))
            end
            return false, reason
        end
    end
    return false, "retries_exhausted"
end

local function findNextWarning()
    local now = os.clock()
    for i = #warnings, 1, -1 do
        if warnings[i].due < now - 0.5 then
            table.remove(warnings, i)
        end
    end
    table.sort(warnings, function(a, b) return a.due < b.due end)
    return warnings[1]
end

local function imminent()
    local first = findNextWarning()
    return first and first.due - os.clock() <= CONFIG.TRADE_BUFFER
end

local function localPositionAllowed(pos, otherPositions, spacing)
    local site = interior()
    local world = site and site:FindFirstChild("Game")
    local zones = world and world:FindFirstChild("NoThrowZones")
    if zones then
        for _, zone in ipairs(zones:GetChildren()) do
            if zone:IsA("BasePart") then
                local delta = zone.Position - pos
                if Vector3.new(delta.X, 0, delta.Z).Magnitude
                    < math.min(zone.Size.Y, zone.Size.Z) / 2 then
                    return false
                end
            end
        end
    end
    for _, spot in ipairs(otherPositions) do
        local diff = spot - pos
        if Vector3.new(diff.X, 0, diff.Z).Magnitude < spacing then
            return false
        end
    end
    return true
end

local function pullUnchargedOldBottles(warning)
    for unique, entry in pairs(placed) do
        if not alive or not running or mode ~= "FARM" or not inLightning() then return end
        if entry.warningId ~= warning.id and entry.state ~= "charged" then
            if entry.position and typeof(entry.position) == "Vector3" then
                tpExactNear(entry.position, 2)
                task.wait(CONFIG.CAP_SETTLE)
            end
            local ok, response = safe("BATCH/PickupOld", function()
                return Net.PickupPlacedBottle:invoke_server_async({unique = unique})
            end)
            if ok and response and response.ok then
                placed[unique] = nil
            elseif response and response.reason == "too_far" then
                local updated, remote = safe("BATCH/RefreshOld", function()
                    return Net.GetPlacedBottles:invoke_server_async()
                end)
                if updated and remote and remote.ok and type(remote.bottles) == "table" then
                    for _, bottle in pairs(remote.bottles) do
                        if tostring(bottle.unique) == unique
                            and typeof(bottle.position) == "Vector3" then
                            entry.position = bottle.position
                            break
                        end
                    end
                end
            elseif response and response.reason == "cant_pickup" then
                placed[unique] = nil
            else
                log("WARN", "BATCH | Old bottle pickup pending: " .. tostring(response and response.reason))
            end
            task.wait(CONFIG.BATCH_DELAY)
        end
    end
end

local function readPlacedSnapshot()
    local ok, reply = safe("BATCH/GetPlacedBottles", function()
        return Net.GetPlacedBottles:invoke_server_async()
    end)
    if not ok or not reply or not reply.ok or type(reply.bottles) ~= "table" then
        return nil
    end
    local positions = {}
    local seen = {}
    for _, bottle in pairs(reply.bottles) do
        if typeof(bottle.position) == "Vector3" then
            table.insert(positions, bottle.position)
            if bottle.owner == Player.UserId and bottle.unique then
                local unique = tostring(bottle.unique)
                seen[unique] = true
                local existing = placed[unique]
                if existing then
                    existing.position = bottle.position
                    existing.state = bottle.state or existing.state
                else
                    placed[unique] = {
                        position = bottle.position,
                        state = bottle.state or "forked",
                        warningId = 0,
                        strikeCenter = bottle.position,
                    }
                end
            end
        end
    end
    for unique in pairs(placed) do
        if not seen[unique] then placed[unique] = nil end
    end
    return positions
end

local function batchCandidate(center, obstacles, spacing, radius, ignored)
    local best, bestScore
    for i = 1, CONFIG.BATCH_SAMPLE_POINTS do
        local ring = math.floor((i - 1) / 16)
        local angle = ((i - 1) % 16) * (math.pi / 8) + ring * (math.pi / 16)
        local distance = radius * (ring == 0 and 1 or 0.77)
        local point = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
        if localPositionAllowed(point, obstacles, spacing) then
            local usable = true
            for _, excluded in ipairs(ignored) do
                if nearXZ(point, excluded, spacing) then usable = false break end
            end
            if usable then
                local clearance = 100
                for _, other in ipairs(obstacles) do
                    local d = (point - other).Magnitude
                    if d < clearance then clearance = d end
                end
                local score = math.min(30, clearance) + distance * 0.06
                if not bestScore or score > bestScore then
                    best, bestScore = point, score
                end
            end
        end
    end
    if not best then return nil end
    return Vector3.new(best.X, floorAt(best), best.Z)
end

local function batchPrepare(warning)
    if not alive or not running or mode ~= "FARM" or not inLightning() then return end
    if not tpCenter(warning.position) then return end
    task.wait(0.12)
    local obstacles = readPlacedSnapshot()
    if not obstacles then obstacles = {} end
    if next(placed) ~= nil and warning.due - os.clock() > 5 then
        pullUnchargedOldBottles(warning)
        if not alive or not running or mode ~= "FARM" or not inLightning() then return end
        obstacles = readPlacedSnapshot() or obstacles
    end
    local available = forks()
    local heldCatch = K.get("HELD_BOTTLE_CATCH") ~= false
    local maxPlaced = math.min(heldCatch and 4 or 5,
        math.max(0, #available - (heldCatch and 1 or 0)))
    if not CONFIG.BATCH_PLACE or os.clock() < batchCooldownUntil then maxPlaced = 0 end
    local spacing = (tonumber(K.get("BOTTLE_MIN_SPACING")) or 8) + CONFIG.BATCH_SPACING_MARGIN
    local strikeRadius = tonumber(K.get("STRIKE_RADIUS")) or 25
    local throwRange = tonumber(K.get("BOTTLE_THROW_RANGE")) or 15
    local radius = math.max(2, math.min(strikeRadius - 3, throwRange - 3))
    local placedCount = 0
    for slot = 1, maxPlaced do
        if not alive or not running or mode ~= "FARM" or not inLightning()
            or warning.due - os.clock() < 1.8 then break end
        local entry = forks()[1]
        if not entry then break end
        local skipped = {}
        local successful = false
        for attempt = 1, 3 do
            if warning.due - os.clock() < 1.8 then break end
            local point = batchCandidate(warning.position, obstacles, spacing, radius, skipped)
            if not point then break end
            local good, reason = placeFork(entry, point, warning)
            if good then
                table.insert(obstacles, point)
                placedCount += 1
                successful = true
                break
            end
            table.insert(skipped, point)
            if reason == "too_close" or reason == "no_throw_zone" then
                obstacles = readPlacedSnapshot() or obstacles
            elseif reason == "no_bottle" or reason == "not_in_dimension" or reason == "stopped" then
                break
            end
        end
        if not successful then
            batchFailures += 1
            if batchFailures >= 3 then
                batchCooldownUntil = os.clock() + 18
                batchFailures = 0
                log("WARN", "BATCH | Placement rejected repeatedly; held-bottle fallback for 18 seconds")
            end
            break
        else
            batchFailures = 0
        end
        if warning.due - os.clock() < 2.1 then break end
        task.wait(CONFIG.BATCH_DELAY)
    end
    if heldCatch then
        local remaining = forks()
        if #remaining > 0 then
            for _ = 1, 2 do
                if equippedForkUnique() then break end
                equip(remaining[1])
                task.wait(0.2)
            end
        end
    end
    if placedCount > 0 then
        log("BATCH", "Placed " .. placedCount .. " bottle(s) near strike")
    end
    tpCenter(warning.position)
end

local function aimAtStrike()
    if not running or mode ~= "FARM" or not inLightning() or batchBusy or capBusy or navigating or busy then return end
    local first = findNextWarning()
    if not first or not interior() then return end
    local r = root()
    if not r then return end
    if currentWarningId ~= first.id or not nearXZ(r.Position, first.position, 5) then
        if not tpCenter(first.position) then return end
        currentWarningId = first.id
    end
    if not first.batchStarted and not batchBusy then
        first.batchStarted = true
        batchBusy = true
        task.spawn(function()
            safe("BATCH/PREPARE", function()
                batchPrepare(first)
            end)
            batchBusy = false
        end)
    elseif not batchBusy and K.get("HELD_BOTTLE_CATCH") ~= false then
        if not equippedForkUnique() and #forks() > 0 then
            equip(forks()[1])
        end
    end
end

local function refreshCapPosition(unique)
    local ok, response = safe("CAP/GetPlacedBottles", function()
        return Net.GetPlacedBottles:invoke_server_async()
    end)
    if not ok or not response or not response.ok or type(response.bottles) ~= "table" then
        return false
    end
    for _, bottle in pairs(response.bottles) do
        if tostring(bottle.unique) == unique and bottle.owner == Player.UserId
            and typeof(bottle.position) == "Vector3" then
            local entry = placed[unique]
            if entry then
                entry.position = bottle.position
                if bottle.state then entry.state = bottle.state end
            end
            return true
        end
    end
    return false
end

local function capOne(unique)
    for attempt = 1, CONFIG.CAP_RETRIES do
        if not alive or not running or mode ~= "FARM" or not inLightning() then return end
        local entry = placed[unique]
        if not entry or entry.state ~= "charged" then return end
        if not tpExactNear(entry.position, 2) then return end
        task.wait(CONFIG.CAP_SETTLE + (attempt - 1) * 0.1)
        if not alive or not running or mode ~= "FARM" or not inLightning() then return end
        local ok, response = safe("CAP/CloseCap", function()
            return Net.CloseCap:invoke_server_async({unique = unique})
        end)
        if not ok then return end
        if response and response.ok then
            placed[unique] = nil
            return
        end
        local reason = type(response) == "table" and response.reason or tostring(response)
        if reason == "too_far" and attempt < CONFIG.CAP_RETRIES then
            refreshCapPosition(unique)
        else
            if reason ~= "cant_close_cap" then
                log("ERROR", ("CAP | %s | attempts=%d | range=%.1f")
                    :format(tostring(reason), attempt, rangeTo(entry.position)))
            end
            if reason == "cant_close_cap" or reason == "too_late" then
                local current = placed[unique]
                if current then current.state = "forked" end
            end
            return
        end
    end
end

local function drainCapQueue()
    if capBusy then return end
    capBusy = true
    task.spawn(function()
        while alive and running and #capQueue > 0 do
            local unique = table.remove(capQueue, 1)
            capQueued[unique] = nil
            safe("CAP/PROCESS", function()
                capOne(unique)
            end)
            task.wait(CONFIG.CAP_DELAY)
        end
        capBusy = false
        if alive and running and #capQueue > 0 then drainCapQueue() end
    end)
end

local function boreModel()
    if cachedBore and cachedBore.Parent and cachedBore:GetAttribute("furniture_unique") ~= nil then
        return cachedBore
    end
    local now = os.clock()
    if now - lastBoreScan < 6 then return nil end
    lastBoreScan = now
    local kind = "lightning_dimension_2026_bore"
    for _, obj in ipairs(CollectionService:GetTagged("furniture:" .. kind)) do
        if obj.Parent and obj:GetAttribute("furniture_unique") ~= nil then
            cachedBore = obj
            return obj
        end
    end
    local house = workspace:FindFirstChild("HouseInteriors")
    if house then
        for _, obj in ipairs(house:GetDescendants()) do
            if obj:IsA("Model") and (obj:GetAttribute("furniture_kind") == kind
                or obj.Name == "LightningDimension2026Bore")
                and obj:GetAttribute("furniture_unique") ~= nil then
                cachedBore = obj
                return obj
            end
        end
    end
    return nil
end

local function finishTradeRequest()
    local pending = tradeRequest
    if not pending or not pending.done then return false, false end
    tradeRequest = nil
    if not pending.ok then
        log("ERROR", "TRADE | Server call failed: " .. tostring(pending.response))
        return false, false
    end
    for _ = 1, 15 do
        lastMainPulse = os.clock()
        if #cookies() > pending.cookiesBefore
            or #caught() <= pending.bottlesBefore - pending.price then
            totalTraded += 1
            log("TRADE", "SUCCESS | Cookie purchased (inventory verified)")
            return true, #caught() <= pending.bottlesBefore - pending.price
        end
        if not alive then return false, false end
        task.wait(0.12)
    end
    log("WARN", "TRADE | Response returned but inventory did not confirm purchase")
    tradeCooldownUntil = os.clock() + 5
    return false, false
end

local function pollTradeRequest()
    local pending = tradeRequest
    if not pending then return end
    if pending.done then
        finishTradeRequest()
        return
    end
    if os.clock() - pending.started >= CONFIG.TRADE_PENDING_LIMIT then
        tradeRequest = nil
        tradeCooldownUntil = os.clock() + CONFIG.TRADE_BACKOFF
        log("ERROR", "TRADE | Server response stalled for 35s; releasing farm and retrying later")
    end
end

local function buyCookie()
    if not running then return false, false end
    if tradeRequest then
        if tradeRequest.done then return finishTradeRequest() end
        return false, false
    end
    if os.clock() < tradeCooldownUntil then return false, false end
    local price = tonumber(K.get("COOKIE_BAIT_COST") or 3) or 3
    if #caught() < price or not interior() then return false, false end
    local model = boreModel()
    if not model then
        log("ERROR", "TRADE | Bore furniture not rendered; will retry")
        return false, false
    end
    local furnitureUnique = model:GetAttribute("furniture_unique")
    local useBlocks = model:FindFirstChild("UseBlocks")
    local useBlock = useBlocks and (useBlocks:FindFirstChild("UseBlock") or useBlocks:GetChildren()[1])
    if not useBlock then
        log("ERROR", "TRADE | Bore interaction block missing")
        return false, false
    end
    local list = caught()
    local offer = {}
    for i = 1, price do offer["r_" .. i] = list[i].unique end
    local targetPos = useBlock:IsA("BasePart") and useBlock.Position or model:GetPivot().Position
    if not tpExactNear(targetPos, 2) then return false, false end
    task.wait(0.20)
    if not alive or not running or mode ~= "FARM" or not inLightning() then return false, false end
    local pending = {
        started = os.clock(),
        done = false,
        ok = false,
        response = nil,
        cookiesBefore = #cookies(),
        bottlesBefore = #caught(),
        price = price,
    }
    tradeRequest = pending
    log("TRADE", ("Buying Storm Chip Cookie Bait, cost=%d | local range=%.1f")
        :format(price, rangeTo(targetPos)))
    local tradeCharacter = character()
    task.spawn(function()
        local ok, response = xpcall(function()
            return RouterClient.get("HousingAPI/ActivateInteriorFurniture"):InvokeServer(
                furnitureUnique, useBlock.Name,
                {key = "cookie", item_list = offer}, tradeCharacter
            )
        end, traceback)
        pending.response = response
        pending.ok = ok
        pending.done = true
    end)
    local deadline = os.clock() + CONFIG.TRADE_RESPONSE_WAIT
    while alive and running and not pending.done and os.clock() < deadline do
        lastMainPulse = os.clock()
        task.wait(0.10)
    end
    if not alive then return false, false end
    if not pending.done then
        log("WARN", "TRADE | Response delayed; farming continues while waiting")
        return false, false
    end
    return finishTradeRequest()
end

local function buyAllCookies()
    if not running then return false end
    local price = tonumber(K.get("COOKIE_BAIT_COST") or 3) or 3
    if price < 1 or #caught() < price or tradeRequest or os.clock() < tradeCooldownUntil then return false end
    local availableAtStart = #caught()
    local target = math.floor(availableAtStart / price)
    local purchased = 0
    for _ = 1, target do
        if not alive or not running or mode ~= "FARM" or navigating or not inLightning()
            or not interior() or #caught() < price then break end
        local success, inventorySynced = buyCookie()
        if not success then break end
        purchased += 1
        if not inventorySynced then
            log("WARN", "TRADE | Waiting for inventory to update before another purchase")
            break
        end
        task.wait(0.15)
    end
    if purchased > 0 then
        log("TRADE", ("BATCH SUCCESS | %d cookie bait purchased from %d Lightning Bottles")
            :format(purchased, availableAtStart))
    end
    return purchased > 0
end

local function lureManager()
    return ClientData.get("lures_2023_lure_manager")
end

local function lureMap()
    local manager = lureManager()
    return manager and manager.lures_map or {}
end

local function lureTypes()
    local types = {"BasicLure"}
    local manager = lureManager()
    if CONFIG.PREMIUM_IF_OWNED and manager
        and (manager.owns_premium_lure or (manager.lures_map and manager.lures_map.PremiumLure)) then
        table.insert(types, "PremiumLure")
    end
    return types
end

local function lureSecondsLeft(active)
    if not active or active.finished then return 0 end
    local entry = InventoryDB.food and InventoryDB.food[active.bait_kind]
    local duration = entry and entry.lure_time or nil
    local started = tonumber(active.lure_start_timestamp)
    if not (duration and started) then return nil end
    local ok, now = pcall(LiveOpsTime.now)
    if not ok or type(now) ~= "number" then return nil end
    return math.max(0, started + duration - now)
end

local function formatSeconds(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    return ("%02d:%02d:%02d"):format(
        math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60)
end

local function describeReward(reward)
    if type(reward) ~= "table" then return "reward details unavailable" end
    local name = tostring(reward.kind or "unknown")
    if reward.amount then name ..= " x" .. tostring(reward.amount) end
    return tostring(reward.category or "reward") .. "/" .. name
end

local function updateLureStatus()
    local data = lureMap()
    local summaries = {}
    for _, typ in ipairs(lureTypes()) do
        local active = data[typ]
        if not active then
            table.insert(summaries, typ .. ": needs bait")
        elseif active.finished then
            table.insert(summaries, typ .. ": READY TO CLAIM")
        else
            local remaining = lureSecondsLeft(active)
            table.insert(summaries, typ .. ": "
                .. (remaining and formatSeconds(remaining) or "running"))
        end
    end
    lureDisplaySummary = table.concat(summaries, " | ")
    if lureStatusLabel then lureStatusLabel.Text = lureDisplaySummary end
end

local function actionAllowed(typ, action, delay)
    local key = typ .. "/" .. action
    local last = lureLastAttempt[key] or -math.huge
    if os.clock() - last < delay then return false end
    lureLastAttempt[key] = os.clock()
    return true
end

local function manageLures()
    if not running then return end
    if not CONFIG.AUTO_LURE then return end
    local manager = lureManager()
    if not manager or type(manager.lures_map) ~= "table" then
        if actionAllowed("all", "missing", 60) then
            log("ERROR", "LURE | Cannot read lure state; will retry automatically")
        end
        return
    end
    for _, typ in ipairs(lureTypes()) do
        if not alive or not running then return end
        local active = lureMap()[typ]
        if active then
            local remaining = lureSecondsLeft(active)
            local ready = active.finished == true or (remaining ~= nil
                and remaining <= 0 and active.lure_start_timestamp ~= nil)
            if ready and actionAllowed(typ, "claim", CONFIG.CLAIM_RETRY) then
                local rewardName = describeReward(active.reward)
                log("LURE", "AUTO CLAIM | " .. typ .. " | " .. rewardName
                    .. " | server finished=" .. tostring(active.finished))
                local ok = safe("LURE/ClaimLure", function()
                    LureNet.ClaimLure:fire_server(typ)
                end)
                if not ok then return end
                local claimed = false
                local deadline = os.clock() + CONFIG.LURE_VERIFY_WAIT
                while alive and running and os.clock() < deadline do
                    if not lureMap()[typ] then
                        claimed = true
                        break
                    end
                    task.wait(0.2)
                end
                if claimed then
                    totalClaimed += 1
                    log("LURE", "CLAIM SUCCESS | " .. typ .. " | " .. rewardName)
                    lureNeedsCheck = true
                else
                    log("WARN", "CLAIM PENDING | " .. typ
                        .. " | server did not clear lure yet; retry in "
                        .. CONFIG.CLAIM_RETRY .. "s")
                end
            end
        end
        if not lureMap()[typ] then
            local available = cookies()
            if #available == 0 then
                if actionAllowed(typ, "noBait", 90) then
                    log("LURE", "WAITING FOR COOKIE BAIT | " .. typ
                        .. " | bottles will be farmed and traded automatically")
                end
            elseif actionAllowed(typ, "bait", CONFIG.BAIT_RETRY) then
                local entry = available[1]
                log("LURE", "AUTO PLACE | " .. typ .. " | Storm Chip Cookie Bait=" .. entry.unique)
                local ok = safe("LURE/BaitLure", function()
                    LureNet.BaitLure:fire_server({
                        lure_type = typ,
                        bait_unique = entry.unique,
                    })
                end)
                if not ok then return end
                local placedSuccessfully = false
                local deadline = os.clock() + CONFIG.LURE_VERIFY_WAIT
                while alive and running and os.clock() < deadline do
                    local current = lureMap()[typ]
                    if current and current.bait_kind == K.COOKIE_BAIT_KIND then
                        placedSuccessfully = true
                        break
                    end
                    task.wait(0.2)
                end
                if placedSuccessfully then
                    log("LURE", "BAIT PLACED | " .. typ
                        .. " | countdown 02:00:00 | next reward auto-claimed")
                else
                    log("WARN", "BAIT NOT CONFIRMED | " .. typ
                        .. " | retry automatically in " .. CONFIG.BAIT_RETRY .. "s")
                end
            end
        end
    end
    unequipCookie()
    updateLureStatus()
end

local function homeDestination()
    local ok, destination = pcall(NavigationHelper.get_house_location_for_player, Player)
    if ok and type(destination) == "string" and destination ~= "" then
        return destination
    end
    return nil
end

local function findTrapModel()
    local ok, model = pcall(LureActions.get_lure_model, "BasicLure")
    if ok and model and model.Parent then return model end
    ok, model = pcall(LureActions.get_lure_model, "PremiumLure")
    if ok and model and model.Parent then return model end
    return nil
end

local function atTrap()
    local destination = homeDestination()
    if not destination or currentDestination() ~= destination then return false end
    local model = findTrapModel()
    return model ~= nil and rangeTo(model:GetPivot().Position) < CONFIG.TRAP_RANGE
end

local function needsTrapVisit()
    if not CONFIG.AUTO_LURE then return false end
    local manager = lureManager()
    if not manager or type(manager.lures_map) ~= "table" then return false end
    local hasBait = #cookies() > 0
    for _, typ in ipairs(lureTypes()) do
        local active = manager.lures_map[typ]
        if active then
            local left = lureSecondsLeft(active)
            if active.finished == true or (left ~= nil and left <= 0) then
                return true
            end
        elseif hasBait then
            return true
        end
    end
    return false
end

local function waitForFarmActions()
    local untilTime = os.clock() + 9
    while alive and running and (busy or batchBusy or capBusy or #capQueue > 0)
        and os.clock() < untilTime do
        task.wait(0.12)
    end
    if busy then
        log("WARN", "TRAVEL | Waiting for bottle trade/refill to finish")
        return false
    end
    return true
end

local function visitTrap()
    if not running then return false end
    if atTrap() then return true end
    local destination = homeDestination()
    if not destination then
        log("ERROR", "TRAVEL/HOME | Own house plot unavailable; retrying")
        return false
    end
    if not waitForFarmActions() then return false end
    lastSafePivot = nil
    local model = findTrapModel()
    if currentDestination() == destination and model then
        tpExactNear(model:GetPivot().Position + Vector3.new(4, 0, 0), 2)
        task.wait(0.25)
        if atTrap() then return true end
    end
    if InteriorsM.entering then
        log("WARN", "TRAVEL/HOME | Interior transition in progress")
        return false
    end
    log("TRAVEL", "Teleporting to pet-pen trap")
    local ok = safe("TRAVEL/HOME", function()
        LureActions.teleport_to_lure("BasicLure")
    end)
    if not ok then return false end
    local deadline = os.clock() + CONFIG.NAV_CONFIRM_TIMEOUT
    while alive and running and not navigationPermissionBlocked and os.clock() < deadline do
        if atTrap() then
            log("TRAVEL", "At trap; lightning farming paused")
            return true
        end
        if currentDestination() == destination then
            local spawned = findTrapModel()
            if spawned then
                tpExactNear(spawned:GetPivot().Position + Vector3.new(4, 0, 0), 2)
            end
        end
        task.wait(CONFIG.NAV_CHECK)
    end
    log("ERROR", "TRAVEL/HOME | Trap location not confirmed after teleport")
    return false
end

local function visitLightning()
    if not running then return false end
    if inLightning() and interior() then return true end
    if InteriorsM.entering then return false end
    lastSafePivot = nil
    if not inLightning() then
        log("TRAVEL", "Returning to Lightning Dimension")
        local ok = safe("TRAVEL/LIGHTNING", function()
            InteriorsM.enter(K.DESTINATION_ID, "MainDoor")
        end)
        if not ok then return false end
    end
    local deadline = os.clock() + CONFIG.NAV_CONFIRM_TIMEOUT
    while alive and running and not navigationPermissionBlocked and os.clock() < deadline do
        if inLightning() and interior() then
            log("TRAVEL", "Lightning farming resumed")
            return true
        end
        task.wait(CONFIG.NAV_CHECK)
    end
    local destination = tostring(currentDestination())
    if inLightning() then
        local location = InteriorsM.get_current_location()
        log("WARN", "TRAVEL/LIGHTNING | Scene not ready; location="
            .. tostring(location and location.full_destination_id)
            .. " scene=" .. tostring(location and location.interior and location.interior.Name))
    else
        log("ERROR", "TRAVEL/LIGHTNING | Entry not confirmed; current destination=" .. destination)
    end
    return false
end

local function setFarmMode(nextMode)
    if mode == nextMode then return end
    mode = nextMode
    if nextMode ~= "FARM" then
        lastSafePivot = nil
        table.clear(warnings)
        currentWarningId = nil
    end
    if nextMode == "TRAP" then
        log("TRAVEL", "Trap requires attention; pausing lightning")
    elseif nextMode == "FARM" then
        lastWarningPulse = os.clock()
        nextStrikeDiagnostic = os.clock() + 45
        log("TRAVEL", "Lightning farming active")
    end
end

local function addConnection(conn)
    table.insert(subs, conn)
end

addConnection(ClientData.register_callback("lures_2023_lure_manager", function(changedPlayer)
    if alive and running and changedPlayer == Player then
        lureNeedsCheck = true
        lastLure = -math.huge
    end
end))
addConnection(ClientData.register_callback("inventory", function(changedPlayer)
    if alive and changedPlayer == Player then
        lastToolInventoryChange = os.clock()
        if running then lureNeedsCheck = true end
    end
end))

addConnection(Net.StrikeWarning:on_client_event(function(data)
    if not alive or not running or not inLightning()
        or not data or typeof(data.position) ~= "Vector3" then return end
    nextId += 1
    lastWarningPulse = os.clock()
    local duration = tonumber(K.get("STRIKE_WARNING_SECONDS") or 7) or 7
    table.insert(warnings, {
        id = nextId,
        position = data.position,
        due = os.clock() + duration,
    })
end))

addConnection(Net.Strike:on_client_event(function(data)
    if not alive or not running or not data or typeof(data.position) ~= "Vector3" then return end
    local best, dist
    for i, warning in ipairs(warnings) do
        local v = warning.position - data.position
        local d = Vector3.new(v.X, 0, v.Z).Magnitude
        if d < 2 and (dist == nil or d < dist) then
            best, dist = i, d
        end
    end
    if best then
        table.remove(warnings, best)
        currentWarningId = nil
    end
end))

addConnection(Net.BottleStateChanged:on_client_event(function(data)
    if not alive or not running or not data or not data.unique then return end
    local entry = placed[data.unique]
    if not entry then return end
    if data.state == "charged" then
        entry.state = "charged"
        if not capQueued[data.unique] then
            capQueued[data.unique] = true
            table.insert(capQueue, data.unique)
            drainCapQueue()
        end
    elseif data.state == "forked" then
        entry.state = "forked"
        task.spawn(function()
            if mode ~= "FARM" or not inLightning() then return end
            task.wait(0.2)
            local ok, response = safe("RECOVER/PickupPlacedBottle", function()
                return Net.PickupPlacedBottle:invoke_server_async({unique = data.unique})
            end)
            if ok and response and response.ok then
                placed[data.unique] = nil
                log("RECOVER", "Reclaimed expired empty bottle")
            end
        end)
    end
end))

addConnection(Net.BottleHopped:on_client_event(function(data)
    if data and data.unique and placed[data.unique] and data.position then
        placed[data.unique].position = data.position
    end
end))

addConnection(Net.BottleCaught:on_client_event(function(data)
    if data and data.unique then placed[data.unique] = nil end
end))
addConnection(Net.BottleRemoved:on_client_event(function(data)
    if data and data.unique then placed[data.unique] = nil end
end))

local setLowGraphics
local function stop()
    if not alive then return end
    alive = false
    local active = activeFarmAction
    if active and active.thread then pcall(task.cancel, active.thread) end
    activeFarmAction = nil
    for _, conn in ipairs(subs) do
        pcall(function()
            if typeof(conn) == "RBXScriptConnection" then
                conn:Disconnect()
            elseif type(conn) == "function" then
                conn()
            elseif conn.Disconnect then
                conn:Disconnect()
            end
        end)
    end
    table.clear(subs)
    flushErrors()
    setLowGraphics(false)
    env.AdoptMeEventAutofarmStop = nil
    if gui then gui:Destroy() end
end

env.AdoptMeEventAutofarmStop = stop

safe("GAME-ERROR-CAPTURE", function()
    local LogService = game:GetService("LogService")
    addConnection(LogService.MessageOut:Connect(function(message, messageType)
        if not alive or messageType ~= Enum.MessageType.MessageError then return end
        local first = tostring(message):match("^[^\r\n]*") or ""
        if first:find("Cannot require a non-RobloxScript module from a RobloxScript", 1, true)
            and (navigating or InteriorsM.entering) then
            if not navigationPermissionBlocked then
                navigationPermissionBlocked = true
                log("ERROR", "TRAVEL/CONTEXT | Roblox rejected interior loading. Enter the Lightning portal manually; automatic travel disabled for this session.")
            end
        end
        if CONFIG.ERROR_LOGGING and
            (first:find("LightningDimension", 1, true)
                or first:find("LPS:", 1, true)
                or first:find("Cannot require a non-RobloxScript", 1, true)) then
            log("GAME ERROR", first:sub(1, 300))
        end
    end))
end)

do
    safe("ANTI-AFK/INIT", function()
        local virtualUser = game:GetService("VirtualUser")
        addConnection(Player.Idled:Connect(function()
            if not alive or not CONFIG.ANTI_AFK then return end
            safe("ANTI-AFK/INPUT", function()
                virtualUser:CaptureController()
                virtualUser:ClickButton2(Vector2.zero)
            end)
        end))
    end)
end

if CONFIG.ANTI_FLING then
    local function disableCollisions(object)
        if object:IsA("BasePart") then
            pcall(function() object.CanCollide = false end)
        end
    end
    local function watchOther(other)
        if other == Player then return end
        local function applyToCharacter(char)
            for _, obj in ipairs(char:GetDescendants()) do
                disableCollisions(obj)
            end
            addConnection(char.DescendantAdded:Connect(disableCollisions))
        end
        if other.Character then applyToCharacter(other.Character) end
        addConnection(other.CharacterAdded:Connect(applyToCharacter))
    end
    for _, other in ipairs(Players:GetPlayers()) do watchOther(other) end
    addConnection(Players.PlayerAdded:Connect(watchOther))
end

local lowGraphicsApplied = false
local graphicsBackup = nil
setLowGraphics = function(enabled)
    enabled = enabled == true
    if lowGraphicsApplied == enabled then return end
    local lighting = game:GetService("Lighting")
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if enabled then
        local backup = {effects = {}}
        pcall(function() backup.shadows = lighting.GlobalShadows end)
        pcall(function() backup.fog = lighting.FogEnd end)
        if terrain then
            pcall(function()
                backup.waveSize = terrain.WaterWaveSize
                backup.waveSpeed = terrain.WaterWaveSpeed
                backup.reflectance = terrain.WaterReflectance
            end)
        end
        for _, effect in ipairs(lighting:GetChildren()) do
            if effect:IsA("PostEffect") then
                backup.effects[effect] = effect.Enabled
                pcall(function() effect.Enabled = false end)
            end
        end
        graphicsBackup = backup
        pcall(function()
            lighting.GlobalShadows = false
            lighting.FogEnd = 1000000
        end)
        if terrain then
            pcall(function()
                terrain.WaterWaveSize = 0
                terrain.WaterWaveSpeed = 0
                terrain.WaterReflectance = 0
            end)
        end
    else
        local backup = graphicsBackup
        if backup then
            pcall(function()
                if backup.shadows ~= nil then lighting.GlobalShadows = backup.shadows end
                if backup.fog ~= nil then lighting.FogEnd = backup.fog end
            end)
            if terrain then
                pcall(function()
                    if backup.waveSize ~= nil then terrain.WaterWaveSize = backup.waveSize end
                    if backup.waveSpeed ~= nil then terrain.WaterWaveSpeed = backup.waveSpeed end
                    if backup.reflectance ~= nil then terrain.WaterReflectance = backup.reflectance end
                end)
            end
            for effect, wasEnabled in pairs(backup.effects) do
                if effect and effect.Parent then
                    pcall(function() effect.Enabled = wasEnabled end)
                end
            end
        end
        graphicsBackup = nil
    end
    lowGraphicsApplied = enabled
    CONFIG.LOW_GRAPHICS = enabled
end
if CONFIG.LOW_GRAPHICS then setLowGraphics(true) end

if CONFIG.ANTI_FLING or CONFIG.ANTI_VOID then
    local RunService = game:GetService("RunService")
    local nextPhysicsCheck = 0
    addConnection(RunService.Heartbeat:Connect(function()
        if not alive or not running then return end
        local now = os.clock()
        if now < nextPhysicsCheck then return end
        nextPhysicsCheck = now + 0.25
        local r = root()
        if not r then return end
        if CONFIG.ANTI_FLING then
            if r.AssemblyLinearVelocity.Magnitude > 170 then
                r.AssemblyLinearVelocity = Vector3.zero
            end
            if r.AssemblyAngularVelocity.Magnitude > 65 then
                r.AssemblyAngularVelocity = Vector3.zero
            end
        end
        if CONFIG.ANTI_VOID and lastSafePivot
            and r.Position.Y < lastSafePivot.Position.Y - 170 then
            local c = character()
            if c and not navigating then
                c:PivotTo(lastSafePivot)
                r.AssemblyLinearVelocity = Vector3.zero
                r.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end))
end


safe("GUI", function()
    local playerGui = requiredChild(Player, "PlayerGui")
    local previous = playerGui:FindFirstChild("AdoptMeEventAutofarmUI")
    if previous then previous:Destroy() end
    gui = Instance.new("ScreenGui")
    gui.Name = "AdoptMeEventAutofarmUI"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 900
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = playerGui

    local TweenService = game:GetService("TweenService")
    local UIS = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local T = {
        bg = Color3.fromRGB(8, 8, 11),
        surface = Color3.fromRGB(11, 12, 18),
        surface2 = Color3.fromRGB(36, 36, 44),
        line = Color3.fromRGB(55, 55, 66),
        text1 = Color3.fromRGB(248, 248, 250),
        text2 = Color3.fromRGB(185, 185, 195),
        text3 = Color3.fromRGB(125, 125, 135),
        accent = Color3.fromRGB(242, 244, 248),
        success = Color3.fromRGB(140, 230, 160),
    }
    local ease = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local soft = TweenInfo.new(0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local function tween(object, properties, info)
        if object and object.Parent then
            local t = TweenService:Create(object, info or ease, properties)
            t:Play()
            return t
        end
    end
    local function round(parent, radius)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, radius)
        c.Parent = parent
    end
    local function outline(parent, color, alpha)
        local s = Instance.new("UIStroke")
        s.Color = color or T.line
        s.Thickness = 1
        s.Transparency = alpha or 0
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = parent
    end
    local function label(parent, value, x, y, w, h, size, color, bold)
        local t = Instance.new("TextLabel")
        t.Size = UDim2.fromOffset(w, h)
        t.Position = UDim2.fromOffset(x, y)
        t.BackgroundTransparency = 1
        t.Font = bold and Enum.Font.BuilderSansBold or Enum.Font.BuilderSans
        t.Text = value
        t.TextSize = size
        t.TextColor3 = color or T.text2
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.TextYAlignment = Enum.TextYAlignment.Center
        t.TextTruncate = Enum.TextTruncate.AtEnd
        t.Parent = parent
        return t
    end
    local W, H = 364, 246
    local root = Instance.new("Frame")
    root.Name = "Window"
    root.Size = UDim2.fromOffset(W, H)
    root.AnchorPoint = Vector2.new(0.5, 0)
    root.Position = UDim2.new(0.5, 0, 0, 65)
    root.BackgroundColor3 = T.bg
    root.BorderSizePixel = 0
    root.ClipsDescendants = true
    root.Active = true
    root.Parent = gui
    round(root, 15)
    outline(root, T.line, 0.18)
    local uiScale = Instance.new("UIScale")
    uiScale.Parent = root
    local function fit()
        local camera = workspace.CurrentCamera
        if not camera then return end
        local v = camera.ViewportSize
        uiScale.Scale = math.clamp(math.min((v.X - 18) / W, (v.Y - 40) / H), 0.68, 1)
    end
    fit()
    local camera = workspace.CurrentCamera
    if camera then addConnection(camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)) end

    label(root, "Adopt Me Event Autofarm", 16, 11, 277, 21, 15, T.text1, true)
    label(root, "LIGHTNING DIMENSION  /  AUTOMATION", 16, 30, 277, 14, 10, T.text3)

    local function headButton(x, iconText)
        local b = Instance.new("TextButton")
        b.Position = UDim2.fromOffset(x, 17)
        b.Size = UDim2.fromOffset(24, 24)
        b.BackgroundColor3 = T.surface
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        b.Font = Enum.Font.BuilderSansMedium
        b.TextSize = 17
        b.TextColor3 = T.text2
        b.Text = iconText
        b.Parent = root
        round(b, 7)
        outline(b, T.line, 0.62)
        addConnection(b.MouseEnter:Connect(function() tween(b, {BackgroundColor3 = T.surface2, TextColor3 = T.text1}) end))
        addConnection(b.MouseLeave:Connect(function() tween(b, {BackgroundColor3 = T.surface, TextColor3 = T.text2}) end))
        return b
    end
    local minimize = headButton(302, "−")
    local stopButton = headButton(331, "×")
    addConnection(stopButton.MouseButton1Click:Connect(stop))

    local divider = Instance.new("Frame")
    divider.Position = UDim2.fromOffset(15, 56)
    divider.Size = UDim2.fromOffset(W - 30, 1)
    divider.BackgroundColor3 = T.line
    divider.BackgroundTransparency = 0.46
    divider.BorderSizePixel = 0
    divider.Parent = root

    local nav = Instance.new("Frame")
    nav.Name = "Navigation"
    nav.Position = UDim2.fromOffset(15, 65)
    nav.Size = UDim2.fromOffset(W - 30, 27)
    nav.BackgroundColor3 = T.surface
    nav.BorderSizePixel = 0
    nav.Parent = root
    round(nav, 13)
    outline(nav, T.line, 0.52)
    local indicator = Instance.new("Frame")
    indicator.Position = UDim2.fromOffset(3, 3)
    indicator.Size = UDim2.fromOffset(106, 21)
    indicator.BackgroundColor3 = T.surface2
    indicator.BorderSizePixel = 0
    indicator.Parent = nav
    round(indicator, 10)
    outline(indicator, T.text3, 0.83)
    local pages = {}
    local tabLabels = {}
    for i, title in ipairs({"Overview", "Session", "Settings"}) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(110, 27)
        b.Position = UDim2.fromOffset((i - 1) * 110 + 3, 0)
        b.BackgroundTransparency = 1
        b.Text = ""
        b.AutoButtonColor = false
        b.Parent = nav
        tabLabels[i] = label(b, title, 0, 0, 110, 27, 11, i == 1 and T.text1 or T.text3, i == 1)
        tabLabels[i].TextXAlignment = Enum.TextXAlignment.Center
        pages[i] = Instance.new("Frame")
        pages[i].Name = title .. "Page"
        pages[i].Position = UDim2.fromOffset(0, 98)
        pages[i].Size = UDim2.fromOffset(W, 107)
        pages[i].BackgroundTransparency = 1
        pages[i].Visible = i == 1
        pages[i].Parent = root
        addConnection(b.MouseButton1Click:Connect(function()
            for j, page in ipairs(pages) do
                local chosen = j == i
                page.Visible = chosen
                if chosen then
                    page.Position = UDim2.fromOffset(0, 104)
                    tween(page, {Position = UDim2.fromOffset(0, 98)}, soft)
                end
                tween(tabLabels[j], {TextColor3 = chosen and T.text1 or T.text3})
            end
            tween(indicator, {Position = UDim2.fromOffset(3 + (i - 1) * 110, 3)}, soft)
        end))
    end

    local function metric(parent, x, name)
        local f = Instance.new("Frame")
        f.Position = UDim2.fromOffset(x, 0)
        f.Size = UDim2.fromOffset(104, 51)
        f.BackgroundColor3 = T.surface
        f.BorderSizePixel = 0
        f.Parent = parent
        round(f, 10)
        outline(f, T.line, 0.59)
        label(f, name, 11, 6, 82, 15, 10, T.text3, false)
        return label(f, "0", 11, 22, 82, 22, 19, T.text1, true)
    end
    bottlesValueLabel = metric(pages[1], 15, "BOTTLES")
    forksValueLabel = metric(pages[1], 130, "FORKS")
    cookiesValueLabel = metric(pages[1], 245, "COOKIES")

    local trap = Instance.new("Frame")
    trap.Position = UDim2.fromOffset(15, 59)
    trap.Size = UDim2.fromOffset(W - 30, 45)
    trap.BackgroundColor3 = T.surface
    trap.BorderSizePixel = 0
    trap.Parent = pages[1]
    round(trap, 10)
    outline(trap, T.line, 0.63)
    label(trap, "TRAP", 12, 4, 90, 13, 10, T.text3)
    lureStatusLabel = label(trap, "Checking trap...", 12, 18, 310, 23, 12, T.text1)

    local session = pages[2]
    label(session, "SESSION ACTIVITY", 16, 5, 280, 18, 10, T.text3)
    local logBox = Instance.new("Frame")
    logBox.Position = UDim2.fromOffset(15, 27)
    logBox.Size = UDim2.fromOffset(W - 30, 77)
    logBox.BackgroundColor3 = T.surface
    logBox.BorderSizePixel = 0
    logBox.Parent = session
    round(logBox, 10)
    outline(logBox, T.line, 0.6)
    errorsLabel = label(logBox, "Errors 0  |  Captured 0  |  Bait 0  |  Claims 0", 12, 8, 312, 26, 11, T.text1)
    label(logBox, "Error details are saved only when logging is on.", 12, 39, 312, 20, 10, T.text3)

    local function settingsRow(index, title, getter, setter)
        local y = (index - 1) * 35
        local frame = Instance.new("Frame")
        frame.Position = UDim2.fromOffset(15, y)
        frame.Size = UDim2.fromOffset(W - 30, 31)
        frame.BackgroundColor3 = T.surface
        frame.BorderSizePixel = 0
        frame.Parent = pages[3]
        round(frame, 9)
        outline(frame, T.line, 0.69)
        label(frame, title, 12, 3, 232, 24, 12, T.text1)
        local button = Instance.new("TextButton")
        button.Position = UDim2.fromOffset(268, 4)
        button.Size = UDim2.fromOffset(55, 23)
        button.BorderSizePixel = 0
        button.AutoButtonColor = false
        button.Font = Enum.Font.BuilderSansBold
        button.TextSize = 10
        button.Parent = frame
        round(button, 7)
        local function paint()
            local enabled = getter()
            button.Text = enabled and "ON" or "OFF"
            tween(button, {
                BackgroundColor3 = enabled and T.accent or T.surface2,
                TextColor3 = enabled and T.bg or T.text2
            })
        end
        addConnection(button.MouseButton1Click:Connect(function()
            setter(not getter())
            paint()
        end))
        paint()
    end
    settingsRow(1, "Anti-AFK", function() return CONFIG.ANTI_AFK end,
        function(value) CONFIG.ANTI_AFK = value end)
    settingsRow(2, "Anti-lag", function() return CONFIG.LOW_GRAPHICS end,
        setLowGraphics)
    settingsRow(3, "Error logging", function() return CONFIG.ERROR_LOGGING end,
        setErrorLogging)

    local footDivider = Instance.new("Frame")
    footDivider.Position = UDim2.fromOffset(15, 209)
    footDivider.Size = UDim2.fromOffset(W - 30, 1)
    footDivider.BackgroundColor3 = T.line
    footDivider.BackgroundTransparency = 0.48
    footDivider.BorderSizePixel = 0
    footDivider.Parent = root
    farmStatusDot = Instance.new("Frame")
    farmStatusDot.Position = UDim2.fromOffset(17, 225)
    farmStatusDot.Size = UDim2.fromOffset(7, 7)
    farmStatusDot.BackgroundColor3 = T.success
    farmStatusDot.BorderSizePixel = 0
    farmStatusDot.Parent = root
    round(farmStatusDot, 4)
    statusLabel = label(root, "Starting farm...", 31, 216, 236, 23, 11, T.text2)

    local runButton = Instance.new("TextButton")
    runButton.Position = UDim2.fromOffset(277, 215)
    runButton.Size = UDim2.fromOffset(71, 25)
    runButton.BorderSizePixel = 0
    runButton.AutoButtonColor = false
    runButton.Font = Enum.Font.BuilderSansBold
    runButton.TextSize = 11
    runButton.Parent = root
    round(runButton, 8)
    local function paintRunButton()
        runButton.Text = running and "Stop" or "Start"
        tween(runButton, {
            BackgroundColor3 = running and T.surface2 or T.accent,
            TextColor3 = running and T.text1 or T.bg
        })
    end
    local function setRunning(enabled)
        if running == enabled then return end
        running = enabled
        if not running then
            mode = "PAUSED"
            table.clear(warnings)
            currentWarningId = nil
            if activeFarmAction and activeFarmAction.thread then
                pcall(task.cancel, activeFarmAction.thread)
            end
            activeFarmAction = nil
            busy = false
            lastStatus = "Paused"
        else
            mode = "TRAVEL"
            nextHomeAttempt = 0
            nextLightningAttempt = 0
            batchCooldownUntil = 0
            lureNeedsCheck = true
            lastRefill = 0
            lastTrade = 0
            lastMainPulse = os.clock()
            for unique, entry in pairs(placed) do
                if entry.state == "charged" and not capQueued[unique] then
                    capQueued[unique] = true
                    table.insert(capQueue, unique)
                end
            end
            task.delay(0.25, function()
                if alive and running and #capQueue > 0 and not capBusy then
                    drainCapQueue()
                end
            end)
        end
        paintRunButton()
    end
    addConnection(runButton.MouseButton1Click:Connect(function()
        setRunning(not running)
    end))
    paintRunButton()

    local collapsed = false
    addConnection(minimize.MouseButton1Click:Connect(function()
        collapsed = not collapsed
        minimize.Text = collapsed and "+" or "−"
        tween(root, {Size = UDim2.fromOffset(W, collapsed and 56 or H)}, soft)
    end))

    local dragging = false
    local dragStart, startFrame, targetFrame
    local mover
    local function stopDrag()
        dragging = false
        if mover then mover:Disconnect() mover = nil end
        if targetFrame then root.Position = targetFrame end
    end
    addConnection(root.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
            and input.Position.Y < root.AbsolutePosition.Y + 56 * uiScale.Scale
            and input.Position.X < root.AbsolutePosition.X + 295 * uiScale.Scale then
            dragging = true
            dragStart = input.Position
            startFrame = root.Position
            targetFrame = startFrame
            if mover then mover:Disconnect() end
            mover = RunService.RenderStepped:Connect(function(dt)
                if dragging and targetFrame and root.Parent then
                    root.Position = root.Position:Lerp(targetFrame, math.clamp(dt * 18, 0, 1))
                end
            end)
        end
    end))
    addConnection(UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            targetFrame = startFrame + UDim2.fromOffset(delta.X / uiScale.Scale, delta.Y / uiScale.Scale)
        end
    end))
    addConnection(UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            stopDrag()
        end
    end))
    addConnection(root.Destroying:Connect(stopDrag))
    root.BackgroundTransparency = 0.16
    tween(root, {BackgroundTransparency = 0}, soft)
end)
if not gui or not gui.Parent then
    dismissStartupToast("UI failed. Check error log.", 6)
    stop()
    return
end
safe("INITIAL COUNTS", function()
    lastCounts.captured = #caught()
    lastCounts.cookie = #cookies()
    refreshCounts()
    updateLureStatus()
end)
log("START", "Running")
dismissStartupToast("Autofarm ready", 2.8)

local function beginFarmAction(name, callback, timeout)
    if activeFarmAction or not alive or not running then return end
    local action = {name = name, started = os.clock(), timeout = timeout, done = false}
    activeFarmAction = action
    busy = true
    action.thread = task.spawn(function()
        safe("MAIN/" .. name, callback)
        action.done = true
    end)
end

local function monitorFarmAction()
    local action = activeFarmAction
    if not action then return end
    if action.done then
        activeFarmAction = nil
        busy = false
        return
    end
    if os.clock() - action.started >= action.timeout then
        log("ERROR", "WATCHDOG | " .. action.name .. " exceeded " .. action.timeout .. " seconds")
        if action.thread then pcall(task.cancel, action.thread) end
        activeFarmAction = nil
        busy = false
        if action.name == "TRADE" then
            tradeCooldownUntil = math.max(tradeCooldownUntil, os.clock() + 60)
        else
            lastRefill = os.clock() + 15
        end
    end
end

local function runMainWorker()
    local lastCount = 0
    while alive do
        lastMainPulse = os.clock()
        safe("MAIN LOOP", function()
            monitorFarmAction()
            local now = os.clock()
            pollTradeRequest()
            if not running then return end
            if now - lastCount >= 1.5 then
                refreshCounts()
                lastCount = now
            end
            if now - lastCookieCheck >= 9 and not navigating
                and not lureBusy and not busy and not batchBusy and not capBusy then
                lastCookieCheck = now
                safe("MAIN/COOKIE UNEQUIP", unequipCookie)
            end
            if mode ~= "FARM" or navigating or not inLightning() or not interior() then return end
            if busy then return end
            if not batchBusy and #capQueue == 0 and not capBusy
                and next(placed) == nil and #forks() == 0
                and now - lastRefill > 1.5 then
                lastRefill = now
                beginFarmAction("REFILL", refill, 25)
            end
            if CONFIG.AUTO_TRADE and not busy and not tradeRequest
                and os.clock() >= tradeCooldownUntil
                and #caught() >= (tonumber(K.get("COOKIE_BAIT_COST")) or 3)
                and now - lastTrade >= CONFIG.TRADE_RETRY
                and not batchBusy and #capQueue == 0 and not capBusy and not imminent() then
                lastTrade = now
                beginFarmAction("TRADE", buyAllCookies, 75)
            end
            if not busy and not capBusy then aimAtStrike() end
            if now >= nextStrikeDiagnostic and now - lastWarningPulse > 40 then
                nextStrikeDiagnostic = now + 90
                local scene = interior()
                log("WARN", "LIGHTNING | No strike warning for "
                    .. math.floor(now - lastWarningPulse)
                    .. "s; destination=" .. tostring(currentDestination())
                    .. "; scene=" .. tostring(scene and scene.Name)
                    .. "; forks=" .. tostring(#forks()))
            end
        end)
        task.wait(running and CONFIG.TICK or 1)
    end
end

task.spawn(runMainWorker)

task.spawn(function()
    while alive do
        if statusLabel then
            local currentState = not running and "Paused" or mode == "FARM" and "Farming lightning"
                or (mode == "TRAP" and "Managing trap" or "Traveling")
            local tradeState = tradeRequest and (tradeRequest.done and " | Trade updating"
                or " | Trade pending") or ""
            if navigationPermissionBlocked and not inLightning() then
                currentState = "Enter Lightning portal manually (travel unavailable)"
            elseif inLightning() and not interior() then
                currentState = "Waiting for Lightning scene"
            elseif mode == "FARM" and os.clock() - lastWarningPulse > 30 then
                currentState = ("Waiting for strike warning (%ds)"):format(
                    math.floor(os.clock() - lastWarningPulse))
            end
            if not running then
                statusLabel.Text = "PAUSED | Press Start to resume"
                if farmStatusDot then farmStatusDot.BackgroundColor3 = Color3.fromRGB(125, 125, 135) end
            elseif os.clock() - lastMainPulse > 8 then
                statusLabel.Text = "STALLED | Farm loop delayed"
                if farmStatusDot then farmStatusDot.BackgroundColor3 = Color3.fromRGB(228, 166, 96) end
            else
                statusLabel.Text = "ACTIVE | " .. currentState .. tradeState
                if farmStatusDot then farmStatusDot.BackgroundColor3 = Color3.fromRGB(131, 211, 166) end
            end
        end
        task.wait(2)
    end
end)

task.spawn(function()
    local contextOk, contextError = enterNormalClientThread()
    if not contextOk then
        navigationPermissionBlocked = true
        log("WARN", "TRAVEL/CONTEXT | " .. tostring(contextError) .. "; automatic travel unavailable on this executor")
    end
    while alive do
        safe("TRAVEL AND LURE LOOP", function()
            if not running then return end
            local now = os.clock()
            local destination = currentDestination()
            if destination ~= lastDestination then
                if lastDestination == K.DESTINATION_ID then
                    table.clear(placed)
                    table.clear(capQueue)
                    table.clear(capQueued)
                    cachedBore = nil
                end
                lastDestination = destination or ""
                table.clear(warnings)
                currentWarningId = nil
            end
            if needsTrapVisit() and (not navigationPermissionBlocked or atTrap()) then
                setFarmMode("TRAP")
                if not atTrap() then
                    if not navigating and now >= nextHomeAttempt then
                        navigating = true
                        nextHomeAttempt = now + CONFIG.NAV_RETRY
                        local ok, arrived = safe("NAVIGATE TO TRAP", visitTrap)
                        navigating = false
                        if ok and arrived then nextHomeAttempt = 0 end
                    end
                elseif not navigating and not lureBusy
                    and (lureNeedsCheck or now - lastLure >= CONFIG.LURE_RETRY) then
                    lastLure = now
                    lureNeedsCheck = false
                    lureBusy = true
                    local ok = safe("LURE/AUTO", manageLures)
                    lureBusy = false
                    if not ok then lureNeedsCheck = true end
                end
            else
                if not inLightning() or not interior() then
                    setFarmMode("TRAVEL")
                    if not navigationPermissionBlocked and not navigating and now >= nextLightningAttempt then
                        navigating = true
                        nextLightningAttempt = now + CONFIG.NAV_RETRY
                        local ok, arrived = safe("NAVIGATE TO LIGHTNING", visitLightning)
                        navigating = false
                        if ok and arrived then nextLightningAttempt = 0 end
                    end
                else
                    setFarmMode("FARM")
                end
            end
            if os.clock() - lastLureStatus >= CONFIG.STATUS_EVERY then
                lastLureStatus = os.clock()
                updateLureStatus()
            end
        end)
        task.wait(CONFIG.LURE_CHECK)
    end
end)

task.spawn(function()
    while alive do
        flushErrors()
        task.wait(CONFIG.LOG_FLUSH_EVERY)
    end
    flushErrors()
end)