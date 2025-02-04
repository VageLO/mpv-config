utils = require 'mp.utils'
local json = require 'dkjson'
local input = require "user-input-module"
local M = {}

function M.loadConfig(config, folder)
    local scripts_dir = mp.find_config_file(folder)
    local file = io.open(scripts_dir .. "/" .. config, "r")

    if file then
        local content = file:read("*a")
        file:close()

        return json.decode(content)
    else
        return nil
    end
end

function M.file_loaded(sub)
    local filename = mp.get_property("filename")
    if filename then
        if sub == '' then
            return
        end
        mp.osd_message(filename .. " loaded", 3)
        print(sub.. " loaded")
        M.loadSub(sub, sub)
    end
end

function M.loadFile(file)
    if file == nil then
        mp.osd_message("loadVideo: url is nil", 5)
    end

    mp.msg.info("Loading File: " .. file)
    mp.osd_message("Video is loading. Wait a minute!", 5)

    mp.commandv("loadfile", file)
    mp.command("set pause no")
end

function M.loadSub(sub, title)
    mp.commandv("sub-add", sub, "auto", title)
end

function M.displayInput(message, func)
    mp.osd_message("🕳 Enter " .. message)

    input.get_user_input(func, {
        request_text = "❤ " .. message .. ":",
        replace = true
    }, "replace")
end

function M.pythonCommand(args, path)
    args = json.encode(args)
    local handle = io.popen([[python]] .. " " .. path .. " '" .. args .. "'")

    local result = handle:read("*a")
    handle:close()

    return result
end

function M.check(result)
    --local jsonStr = result:gsub("'", '"')
    print("RAW: "..json.encode(result))
    local data, pos, err = json.decode(result, 1, nil)
    --print("JSON: "..json.encode(data))

    if err then
        mp.osd_message("Error decoding JSON: " .. err, 5)
        return nil
    end

    if data ~= nil and data["error"] then
        mp.osd_message(data["error"], 5)
        return nil
    elseif not data then
        mp.osd_message("parse: data is nil", 5)
        return nil
    end

    return data
end

function M.sortTableByKey(t)
    local keys = {}
    for k in pairs(t) do
        table.insert(keys, k)
    end

    table.sort(keys, function(a, b)
        return tonumber(a) < tonumber(b)
    end)

    local sortedTable = {}
    for _, k in pairs(keys) do
        table.insert(sortedTable, {key = k, value = t[k]})
    end

    return sortedTable
end

function M.split(str, sep)
    local result = {}
    for match in (str..sep):gmatch("(.-)"..sep) do
        table.insert(result, match)
    end
    return result
end

return M
