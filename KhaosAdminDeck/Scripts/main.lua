-- Khaos Admin Deck UI Preview
-- Client-side Palworld 1.0.x administration helper.
-- This mod never grants or bypasses server permissions.

local MOD_NAME = "KhaosAdminDeck"
local MOD_VERSION = "0.2.0-preview"

local ok_config, Config = pcall(require, "config")
if not ok_config or type(Config) ~= "table" then
    Config = {
        allow_raw = false,
        enable_hotkeys = true,
        verbose_logging = false,
        ipc_poll_ms = 250,
        status_refresh_ms = 2000
    }
end

local ok_helpers, UEHelpers = pcall(require, "UEHelpers")
if not ok_helpers then
    print(string.format("[%s] ERROR: UEHelpers failed to load: %s\n", MOD_NAME, tostring(UEHelpers)))
    return
end

local SEP = package.config:sub(1, 1)

local function dirname(path)
    return type(path) == "string" and path:match("^(.*)[/\\][^/\\]+$") or nil
end

local source = debug.getinfo(1, "S").source or ""
if source:sub(1, 1) == "@" then source = source:sub(2) end

local ScriptsDir = dirname(source)
local ModRoot = ScriptsDir and dirname(ScriptsDir) or "."
local IpcDir = ModRoot .. SEP .. "ipc"
local UiDir = ModRoot .. SEP .. "UI"
local RequestPath = IpcDir .. SEP .. "request.kad"
local StatusPath = IpcDir .. SEP .. "status.kad"
local StatusTempPath = IpcDir .. SEP .. "status.kad.tmp"
local ActivityPath = IpcDir .. SEP .. "activity.log"
local UiLauncherPath = UiDir .. SEP .. "Launch-Khaos-Admin-Deck.cmd"

local Runtime = {
    connected = false,
    admin = false,
    player = "",
    last_action = "Startup",
    last_result = "Waiting for a local player controller",
    last_request = ""
}

local function log(message)
    print(string.format("[%s] %s\n", MOD_NAME, tostring(message)))
end

local function debug_log(message)
    if Config.verbose_logging then log("DEBUG: " .. tostring(message)) end
end

local function clean(value)
    return tostring(value or ""):gsub("[\r\n]+", " ")
end

local function redact(command)
    command = tostring(command or "")
    if command:lower():match("^/adminpassword%s+") then
        return "/AdminPassword <redacted>"
    end
    return command
end

local function append_activity(level, message)
    local file = io.open(ActivityPath, "a")
    if file then
        file:write(string.format("%s\t%s\t%s\n", os.date("%Y-%m-%d %H:%M:%S"), clean(level), clean(message)))
        file:close()
    end
    log(string.format("%s: %s", level, message))
end

local function hex_encode(value)
    return (tostring(value or ""):gsub(".", function(character)
        return string.format("%02X", string.byte(character))
    end))
end

local function hex_decode(value)
    value = tostring(value or "")
    if value == "" then return "" end
    if (#value % 2) ~= 0 or value:find("[^0-9A-Fa-f]") then return nil end
    return (value:gsub("%x%x", function(pair)
        return string.char(tonumber(pair, 16))
    end))
end

local function write_status()
    local content = table.concat({
        "version=1",
        "modVersion=" .. MOD_VERSION,
        "heartbeat=" .. tostring(os.time()),
        "connected=" .. (Runtime.connected and "1" or "0"),
        "admin=" .. (Runtime.admin and "1" or "0"),
        "player=" .. hex_encode(Runtime.player),
        "lastAction=" .. hex_encode(Runtime.last_action),
        "lastResult=" .. hex_encode(Runtime.last_result),
        "lastRequest=" .. clean(Runtime.last_request)
    }, "\n") .. "\n"

    local file = io.open(StatusTempPath, "w")
    if not file then return end
    file:write(content)
    file:close()
    os.remove(StatusPath)
    os.rename(StatusTempPath, StatusPath)
end

local function set_result(request_id, action, success, message)
    Runtime.last_request = tostring(request_id or "")
    Runtime.last_action = tostring(action or "")
    Runtime.last_result = (success and "OK: " or "ERROR: ") .. tostring(message or "")
    append_activity(success and "INFO" or "ERROR", Runtime.last_action .. " — " .. tostring(message))
    write_status()
end

local function valid(object)
    if object == nil then return false end
    local ok, result = pcall(function() return object:IsValid() end)
    return ok and result == true or not ok
end

local function get_controller()
    local ok, controller = pcall(function() return UEHelpers:GetPlayerController() end)
    if ok and valid(controller) then return controller end

    local controllers = nil
    pcall(function() controllers = FindAllOf("PalPlayerController") end)
    if controllers then
        for _, candidate in ipairs(controllers) do
            if valid(candidate) then return candidate end
        end
    end
    return nil
end

local function get_state(controller)
    if not valid(controller) then return nil end
    local ok, state = pcall(function() return controller.PlayerState end)
    return ok and valid(state) and state or nil
end

local function get_name(state)
    if not valid(state) then return "" end
    for _, getter in ipairs({
        function() return state.PlayerNamePrivate end,
        function() return state.SavedPlayerName end
    }) do
        local ok, value = pcall(getter)
        if ok and value ~= nil then
            local string_ok, result = pcall(function() return value:ToString() end)
            if string_ok and result and result ~= "" then return result end
            if type(value) == "string" and value ~= "" then return value end
        end
    end
    return ""
end

local function get_guid(state)
    local guid = { A = 0, B = 0, C = 0, D = 0 }
    if not valid(state) then return guid end

    local ok, uid = pcall(function() return state.PlayerUId end)
    if not ok or uid == nil then return guid end

    for _, part in ipairs({ "A", "B", "C", "D" }) do
        local part_ok, value = pcall(function() return uid[part] end)
        guid[part] = part_ok and value or 0
    end
    return guid
end

local function is_admin(controller)
    if not valid(controller) then return false end
    local ok, value = pcall(function() return controller.bAdmin end)
    return ok and value == true
end

local function refresh_status()
    ExecuteInGameThread(function()
        local controller = get_controller()
        Runtime.connected = controller ~= nil
        Runtime.admin = controller and is_admin(controller) or false
        Runtime.player = controller and get_name(get_state(controller)) or ""
        write_status()
    end)
end

local function chat_message(controller, command)
    local state = get_state(controller)
    return {
        Category = 1,
        Sender = get_name(state),
        SenderPlayerUId = get_guid(state),
        Message = command,
        ReceiverPlayerUIds = {},
        MessageId = FName("None"),
        MessageArgKeys = {},
        MessageArgValues = {}
    }, state
end

local function submit(command, allow_without_admin, request_id, action)
    if type(command) ~= "string" or command == "" then
        set_result(request_id, action, false, "Command was empty")
        return
    end

    ExecuteInGameThread(function()
        local controller = get_controller()
        if not controller then
            Runtime.connected = false
            Runtime.admin = false
            set_result(request_id, action, false, "Join a world or server first")
            return
        end

        Runtime.connected = true
        Runtime.admin = is_admin(controller)
        Runtime.player = get_name(get_state(controller))

        if not allow_without_admin and not Runtime.admin then
            set_result(request_id, action, false, "Palworld does not report this client as an authenticated administrator")
            return
        end

        local message, state = chat_message(controller, command)
        local sent = false
        local transport_error = ""

        local controller_ok, controller_error = pcall(function()
            controller:EnterChat_Receive(message)
        end)
        if controller_ok then
            sent = true
            debug_log("Used PalPlayerController:EnterChat_Receive")
        else
            transport_error = tostring(controller_error)
        end

        if not sent and state then
            local state_ok, state_error = pcall(function()
                state:EnterChat_Receive(message)
            end)
            if state_ok then
                sent = true
                debug_log("Used PalPlayerState fallback")
            else
                transport_error = transport_error .. " | fallback: " .. tostring(state_error)
            end
        end

        if sent then
            set_result(request_id, action, true, "Submitted to server: " .. redact(command))
        else
            set_result(request_id, action, false, "Chat RPC failed: " .. transport_error)
        end
    end)
end

local function parse_request(content)
    local request = {}
    for line in tostring(content or ""):gmatch("[^\r\n]+") do
        local key, value = line:match("^([^=]+)=(.*)$")
        if key then request[key] = value end
    end
    for index = 1, 8 do
        local key = "arg" .. tostring(index)
        if request[key] then request[key] = hex_decode(request[key]) end
    end
    return request
end

local function safe_id(value)
    local text = tostring(value or "")
    if text == "" or text:find("%s") then return nil end
    return text
end

local function confirmed(request, action)
    if request.confirmed == "1" then return true end
    set_result(request.id, action, false, "The UI did not include destructive-action confirmation")
    return false
end

local function handle(request)
    local id = request.id or ""
    local action = tostring(request.action or ""):lower()

    if action == "status" then
        refresh_status()
    elseif action == "auth" then
        local password = tostring(request.arg1 or "")
        if password == "" then set_result(id, "Authenticate", false, "Admin password was empty")
        else submit("/AdminPassword " .. password, true, id, "Authenticate") end
    elseif action == "save" then
        submit("/Save", false, id, "Save world")
    elseif action == "players" then
        submit("/ShowPlayers", false, id, "Show players")
    elseif action == "info" then
        submit("/Info", false, id, "Server info")
    elseif action == "broadcast" then
        local text = tostring(request.arg1 or "")
        if text == "" then set_result(id, "Broadcast", false, "Message was empty")
        else submit("/Broadcast " .. text, false, id, "Broadcast") end
    elseif action == "spectate" then
        submit("/ToggleSpectate", false, id, "Toggle spectate")
    elseif action == "shutdown" then
        if not confirmed(request, "Shutdown") then return end
        local seconds = tonumber(request.arg1 or "")
        if not seconds or seconds < 0 or seconds > 86400 then
            set_result(id, "Shutdown", false, "Seconds must be between 0 and 86400")
            return
        end
        local text = tostring(request.arg2 or "")
        if text == "" then text = "Scheduled server shutdown" end
        submit(string.format("/Shutdown %d %s", math.floor(seconds), text), false, id, "Shutdown")
    elseif action == "exit" then
        if confirmed(request, "Forced server exit") then submit("/DoExit", false, id, "Forced server exit") end
    elseif action == "kick" or action == "ban" or action == "unban" or action == "teleport" or action == "bring" then
        if (action == "kick" or action == "ban") and not confirmed(request, action) then return end
        local identifier = safe_id(request.arg1)
        if not identifier then
            set_result(id, action, false, "Player ID was invalid")
            return
        end
        local commands = {
            kick = "/KickPlayer ",
            ban = "/BanPlayer ",
            unban = "/UnBanPlayer ",
            teleport = "/TeleportToPlayer ",
            bring = "/TeleportToMe "
        }
        submit(commands[action] .. identifier, false, id, action)
    elseif action == "raw" then
        if not Config.allow_raw then
            set_result(id, "Raw command", false, "Raw command mode is disabled")
            return
        end
        if not confirmed(request, "Raw command") then return end
        local command = tostring(request.arg1 or "")
        if command:sub(1, 1) ~= "/" then set_result(id, "Raw command", false, "Raw command must begin with /")
        else submit(command, false, id, "Raw command") end
    else
        set_result(id, action ~= "" and action or "Unknown", false, "Unknown UI action")
    end
end

local function process_request()
    local file = io.open(RequestPath, "r")
    if not file then return end
    local content = file:read("*a")
    file:close()
    os.remove(RequestPath)
    if not content or content == "" then return end

    local request = parse_request(content)
    if request.id and request.id == Runtime.last_request then return end
    handle(request)
end

local function launch_ui()
    if SEP ~= "\\" then
        append_activity("ERROR", "The preview UI currently supports Windows only")
        return
    end
    local command = 'cmd.exe /c start "" "' .. UiLauncherPath .. '"'
    local ok, result = pcall(function() return os.execute(command) end)
    append_activity(ok and "INFO" or "ERROR", ok and "UI launch requested" or ("UI launch failed: " .. tostring(result)))
end

local function join(parameters, start_index)
    local values = {}
    for index = start_index or 1, #parameters do table.insert(values, tostring(parameters[index])) end
    return table.concat(values, " ")
end

local function output(device, message)
    if device then
        local ok = pcall(function() device:Log(string.format("[%s] %s", MOD_NAME, message)) end)
        if ok then return end
    end
    log(message)
end

local function console_handler(_, parameters, device)
    local action = tostring(parameters[1] or "help"):lower()
    local id = "console-" .. tostring(os.time())

    if action == "help" then
        for _, line in ipairs({
            "knadmin ui", "knadmin status", "knadmin auth <password>",
            "knadmin save", "knadmin players", "knadmin info",
            "knadmin broadcast <message>", "F9 opens the UI"
        }) do output(device, line) end
    elseif action == "ui" then launch_ui()
    elseif action == "status" then refresh_status(); output(device, "Connected: " .. tostring(Runtime.connected)); output(device, "Admin: " .. tostring(Runtime.admin))
    elseif action == "auth" then submit("/AdminPassword " .. tostring(parameters[2] or ""), true, id, "Authenticate")
    elseif action == "save" then submit("/Save", false, id, "Save world")
    elseif action == "players" then submit("/ShowPlayers", false, id, "Show players")
    elseif action == "info" then submit("/Info", false, id, "Server info")
    elseif action == "broadcast" then submit("/Broadcast " .. join(parameters, 2), false, id, "Broadcast")
    else output(device, "Unknown command. Run: knadmin help") end
    return true
end

local registered, register_error = pcall(function()
    RegisterConsoleCommandHandler("knadmin", console_handler)
end)
if not registered then
    log("ERROR: Could not register knadmin: " .. tostring(register_error))
    return
end

if Config.enable_hotkeys then
    pcall(function() RegisterKeyBind(Key.F9, function() launch_ui() end) end)
    pcall(function() RegisterKeyBind(Key.F5, { ModifierKey.CONTROL }, function()
        submit("/Save", false, "hotkey-" .. tostring(os.time()), "Save world")
    end) end)
end

append_activity("INFO", string.format("v%s loaded from %s", MOD_VERSION, ModRoot))
refresh_status()

LoopAsync(tonumber(Config.ipc_poll_ms) or 250, function()
    local ok, error_message = pcall(process_request)
    if not ok then append_activity("ERROR", "IPC poll failed: " .. tostring(error_message)) end
    return false
end)

LoopAsync(tonumber(Config.status_refresh_ms) or 2000, function()
    local ok, error_message = pcall(refresh_status)
    if not ok then append_activity("ERROR", "Status refresh failed: " .. tostring(error_message)) end
    return false
end)
